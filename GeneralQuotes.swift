//
//  GeneralQuotes.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 6/2/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
class GeneralQuotes : ObservableObject {
    
    private let db = Firestore.firestore()
    
    private let quoteCollection = Firestore.firestore().collection("quotes")
    
    private let likeCollection = Firestore.firestore().collection("likes")
    
    private let followCollection = Firestore.firestore().collection("follow")
    
    private let MAX_QUOTE_COUNT = 200
    
    private var currentQuotesListener: ListenerRegistration?
    
    var userId: String
    
    @Published var quotes: [QuoteManager.Quote] = []
    
    var sameAsCurrent: Bool
    let currentUserId = Auth.auth().currentUser?.uid
    
    init(userId: String) {
        self.userId = userId
        self.sameAsCurrent = currentUserId == userId
    }
    
    init() {
        self.userId = Auth.auth().currentUser?.uid ?? ""
        self.sameAsCurrent = true
    }
    
    
    // Gets quotes for the current userId of the general quotes
    func getQuotes() async {
        do {
            let quoteList = quoteCollection
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
            
            let snapshot = try await quoteList.getDocuments()
            
            let allQuotes = snapshot.documents.compactMap { document in
                try? document.data(as: QuoteManager.Quote.self)
            }
            
            if sameAsCurrent {
                self.quotes = allQuotes
            } else {
                self.quotes = allQuotes.filter { !$0.isPrivate }
            }
        } catch {
            print("Error getting quotes: \(error)")
            self.quotes = []
        }
        setupSimpleCurrentQuotesListener()
    }
    
    // Gets all liked quotes of the current user
    func getLikedQuotes() async {
        print("Running Get Liked Quotes")
        var quoteList: [QuoteManager.Quote] = []
        do {
            let likedQuotes = try await likeCollection.whereField("userId", isEqualTo: currentUserId ?? "").order(by: "timestamp", descending: true).getDocuments()
            for likeDoc in likedQuotes.documents {
                if let quoteId = likeDoc.data()["quoteId"] as? String {
                    try await quoteList.append(quoteCollection.document(quoteId).getDocument().data(as: QuoteManager.Quote.self))
                }
            }
        } catch {
            print("Error getting liked quotes: \(error)")
        }
        self.quotes = quoteList
        setupSimpleCurrentQuotesListener()
    }
    
    // Gets recommended quotes to display based on followed users, then recent popular quotes
    func getRecommendedQuotes() async {
        var quoteList: [QuoteManager.Quote] = []
        var addedQuoteIds: Set<String> = [] // Track quote IDs to prevent duplicates
        
        // Gets quotes from users that the user follows
        do {
            let filter = Filter.orFilter([
                Filter.whereField("followerId", isEqualTo: userId),
                Filter.whereField("attributionUserId", isEqualTo: userId)
            ])
            // Gets the current followedUsers documents
            do {
                let followedUsers = try await followCollection.whereFilter(filter).getDocuments()
                for userDoc in followedUsers.documents {
                    if let tempUser = try? userDoc.data(as: UserService.Follow.self) {
                        let userQuotes = await quotesWithinLast2Days(userId: tempUser.userId)
                        // Only add quotes that haven't been added yet
                        for quote in userQuotes {
                            if let quoteId = quote.id, !addedQuoteIds.contains(quoteId) {
                                quoteList.append(quote)
                                addedQuoteIds.insert(quoteId)
                            }
                        }
                    }
                }
            } catch {
                print("Error getting recommended quotes: \(error)")
            }
        }
        if quoteList.count < MAX_QUOTE_COUNT {
            let randomQuotes = await getRandomQuotesLast2Days(numberOfQuotes: (MAX_QUOTE_COUNT - quoteList.count))
            // Only add random quotes that haven't been added yet
            for quote in randomQuotes {
                if let quoteId = quote.id, !addedQuoteIds.contains(quoteId) {
                    quoteList.append(quote)
                    addedQuoteIds.insert(quoteId)
                    // Break if we've reached the max count
                    if quoteList.count >= MAX_QUOTE_COUNT {
                        break
                    }
                }
            }
        }
        
        self.quotes = quoteList.reversed()
        setupSimpleCurrentQuotesListener()
    }
    
    // Gets all quotes of a current user within the last 48 hours
    private func quotesWithinLast2Days(userId: String) async -> [QuoteManager.Quote] {
        var recentQuotes: [QuoteManager.Quote] = []
        let twoDaysAgo = Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date()
        do {
            let orderedCollection = try await quoteCollection
                .whereField("timestamp", isGreaterThan: twoDaysAgo)
                .whereField("userId", isEqualTo: userId)
                .whereField("isPrivate", isEqualTo: false)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            recentQuotes = orderedCollection.documents.compactMap { document in
                        try? document.data(as: QuoteManager.Quote.self)
                    }
            if recentQuotes.isEmpty {
                print("recentQuotes is Empty!")
                let allUserQuotes = try await quoteCollection
                    .whereField("userId", isEqualTo: userId)
                    .whereField("isPrivate", isEqualTo: false)
                    .order(by: "timestamp", descending: true)
                    .getDocuments()
                if let firstDocument = allUserQuotes.documents.first {
                    do {
                        let quote = try firstDocument.data(as: QuoteManager.Quote.self)
                        recentQuotes.append(quote)
                        print(quote)
                    } catch {
                        print("Error converting document: \(error)")
                    }
                }
            }
        } catch {
            print("Error getting recent quotes: \(error)")
        }
        return recentQuotes
    }
    
    // Deletes the specified quote
    func deleteQuote(quote: QuoteManager.Quote) async throws {
        do {
            try await quoteCollection.document(quote.id!).delete()
            let likeSnapshot = try await likeCollection.whereField("quoteId", isEqualTo: quote.id!).getDocuments()
            for document in likeSnapshot.documents {
                try await document.reference.delete()
            }
        } catch {
            print("Error deleting quote document: \(error)")
        }
    }
    
    // Gets "random" quotes from the last 48 hours, based on popularity and tie posted
    private func getRandomQuotesLast2Days(numberOfQuotes: Int) async -> [QuoteManager.Quote] {
        let twoDaysAgo = Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date()
        var orderedCollection: [QuoteManager.Quote] = []
        do {
            try await orderedCollection = quoteCollection
                .whereField("timestamp", isGreaterThan: twoDaysAgo)
                .whereField("isPrivate", isEqualTo: false)
                .whereField("userId", isNotEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .limit(to: numberOfQuotes)
                .getDocuments()
                .documents.compactMap() { document in
                    try? document.data(as: QuoteManager.Quote.self)
                }
        } catch {
            print("Error getting random quotes: \(error)")
        }
        return orderedCollection
    }
    
    // Adds listener to list of quotes so they can be updated for users in real time
    nonisolated func listenToQuotes(quoteList: Query) {
        quoteList.addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            
            Task { @MainActor in
                self.quotes = documents.compactMap { document in
                    try? document.data(as: QuoteManager.Quote.self)
                }
            }
        }
    }
    
    // Defines the like document for firebase
    struct Like: Identifiable, Codable {
        @DocumentID var id: String?
        var quoteId: String
        var userId: String
        var timestamp: Date?
        
    }
    
    // Has the user liked the quote?
    func hasLiked(userId: String, quote: QuoteManager.Quote) async -> Bool {
        var returnVal: Bool = false
        do {
            returnVal = try await !likeCollection
                .whereField("quoteId", isEqualTo: quote.id ?? "")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
                .documents
                .isEmpty
        } catch {
            print("Error getting like: \(error)")
        }
        return returnVal
    }
    
    // Toggles the like of a quote based on user input
    nonisolated func toggleLike(userId: String, quote: QuoteManager.Quote) async {
        do {
            let snapshot = try await likeCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("quoteId", isEqualTo: quote.id!)
                .getDocuments()
            let hasLiked = !snapshot.documents.isEmpty
            
            if !hasLiked {
                // User hasn't liked the quote, so we create a like, and update the quote
                let newLike = Like(quoteId: quote.id!, userId: userId, timestamp: Date())
                do {
                  let ref = try likeCollection.addDocument(from: newLike)
                  print("Document added with new reference: \(ref)")
                } catch {
                  print("Error adding document: \(error)")
                }
                try await updateLikes(quoteId: quote.id, newLikeCount: quote.likes + 1)
            } else {
                // User is unliking the quote
                try await snapshot.documents.first?.reference.delete()
                try await updateLikes(quoteId: quote.id, newLikeCount: quote.likes - 1)
            }
            
        } catch {
            print("Error toggling like \(error)")
        }
    }
    
    // Updates the like data of a quote
    nonisolated func updateLikes(quoteId: String?, newLikeCount: Int) async throws {
        do {
            try await quoteCollection.document(quoteId ?? "").updateData([
                "likes": newLikeCount
            ])
        } catch {
            print("Error updating quote likes: \(error)")
            throw AppError.updateError
        }
    }
    
    // Updates quote in firebase
    nonisolated func updateQuote(quote: QuoteManager.Quote) async throws {
        guard let quoteId = quote.id else { return }
        do { try quoteCollection.document(quoteId).setData(from: quote, merge: true) }
        catch { throw AppError.updateError }
    }
    
    // Display time conversion function
    func toRelativeTime(date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        if timeInterval < 0 {
            return "fUtuRe woOooOOoo"
        }
        let seconds = Int(timeInterval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7
        let months = weeks / 4
        let years = months / 12
        switch timeInterval {
        case 0..<60:
            return seconds <= 1 ? "Just now" : "\(seconds)s ago"
        case 60..<3600:
            return minutes == 1 ? "1m ago" : "\(minutes)m ago"
        case 3600..<86400:
            return hours == 1 ? "1h ago" : "\(hours)h ago"
        case 86400..<604800:
            return days == 1 ? "1d ago" : "\(days)d ago"
        case 604800..<2629746:
            return weeks == 1 ? "1w ago" : "\(weeks)w ago"
        case 2629746..<31556952:
            return months == 1 ? "1mo ago" : "\(months)mo ago"
        default:
            return years == 1 ? "1y ago" : "\(years)y ago"
        }
    }
    
    // Listener setup for quotes
    private func setupSimpleCurrentQuotesListener() {
        // Remove existing listener
        currentQuotesListener?.remove()
        
        let currentQuoteIds = Set(self.quotes.compactMap { $0.id })
        
        currentQuotesListener = self.quoteCollection
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error listening to quotes: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                Task { @MainActor in
                    let updatedQuotes = documents.compactMap { document in
                        try? document.data(as: QuoteManager.Quote.self)
                    }.filter { currentQuoteIds.contains($0.id!) }
                    
                    for updatedQuote in updatedQuotes {
                        if let index = self.quotes.firstIndex(where: { $0.id == updatedQuote.id }) {
                            self.quotes[index] = updatedQuote
                        }
                    }
                }
            }
    }

    // Clean up listener
    deinit {
        currentQuotesListener?.remove()
    }
}
