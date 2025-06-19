//
//  QuoteManager.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/25/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class QuoteManager : ObservableObject {
    
    private let db = Firestore.firestore()
    private let quoteCollection = Firestore.firestore().collection("quotes")
    
    struct Quote: Identifiable, Codable {
        @DocumentID var id: String?
        var title: String
        var transcription: String
        var userId: String
        var timestamp: Date?
        var likes: Int
        var isPrivate: Bool
        var attribution: String
        var attributionUserId: String
    }
    
    func saveQuote(quote: String, userPrivacy: Bool) {
        // Get current user ID at the time of saving, not during init
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user found when saving quote")
            return
        }
        
        let newQuote = Quote(
            title: "New Quote",
            transcription: quote,
            userId: currentUserId,
            timestamp: Date(),
            likes: 0,
            isPrivate: userPrivacy,
            attribution: "",
            attributionUserId: ""
        )
        
        do {
            let ref = try quoteCollection.addDocument(from: newQuote)
            print("Document added with new reference: \(ref)")
        } catch {
            print("Error adding document: \(error)")
        }
    }
    
    
    struct Report: Identifiable, Codable {
        @DocumentID var id: String?
        var quoteId: String
        var reportReason: String
        var userReporting: String
    }
    func reportQuote(quote: QuoteManager.Quote, reportReason: String) {
        let newReport = Report(
            quoteId: quote.id ?? "",
            reportReason: reportReason,
            userReporting: Auth.auth().currentUser?.uid ?? ""
        )
        do {
            let ref = try Firestore.firestore().collection("reports").addDocument(from: newReport)
            print("Report successful with reference: \(ref)")
        } catch {
            print("Error reporting quote: \(error)")
        }
    }
    
    func saveQuote(quote: QuoteManager.Quote, userPrivacy: Bool) {
        // Get current user ID at the time of saving, not during init
        guard (Auth.auth().currentUser?.uid) != nil else {
            print("Error: No authenticated user found when saving quote")
            return
        }
        do {
            let ref = try quoteCollection.addDocument(from: quote)
            print("Document added with new reference: \(ref)")
        } catch {
            print("Error adding document: \(error)")
        }
    }
    
    func saveQuoteWithAttribution(quote: String, attribution: String, userPrivacy: Bool, userService: UserService) async {
        // Get current user ID at the time of saving, not during init
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: No authenticated user found when saving quote")
            return
        }
        
        var newQuote = Quote(
            title: "New Quote",
            transcription: quote,
            userId: currentUserId,
            timestamp: Date(),
            likes: 0,
            isPrivate: userPrivacy,
            attribution: attribution,
            attributionUserId: ""
        )
        
        
        // Setting attribution link
        do {
            let savedAttributionUser = try await userService.fetchUserByUsername(username: attribution)
            if let attributionUser = savedAttributionUser {
                newQuote.attributionUserId = attributionUser.userId
            }
        } catch {
            print("Error fetching attribution user: \(error)")
            newQuote.attributionUserId = ""
        }
        
        do {
            let ref = try quoteCollection.addDocument(from: newQuote)
            print("Document added with new reference: \(ref)")
        } catch {
            print("Error adding document: \(error)")
        }
    }
    
    func saveQuoteFromText(text: String, userPrivacy: Bool, userService: UserService) async {
        var result: [String] = []
        let normalizedText = text
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
        
        // Eliminates newlines, and filters quotes for both attributions and no attributions
        let pattern = #""([^"]+)"\s*(?:-?\s*([^\r\n]+)|\r?\n\s*-+\s*([^\r\n]+))?"#

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: normalizedText, options: [], range: NSRange(location: 0, length: normalizedText.utf16.count))
            
            for match in matches {
                if match.numberOfRanges >= 2 {
                    if let quoteRange = Range(match.range(at: 1), in: normalizedText) {
                        let quote = String(normalizedText[quoteRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        result.append(quote)
                    }
                    var attribution = ""
                    if match.numberOfRanges >= 3 {
                        if let attrRange = Range(match.range(at: 2), in: normalizedText) {
                            attribution = String(normalizedText[attrRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        } else if match.numberOfRanges >= 4,
                                  let attrRange2 = Range(match.range(at: 3), in: normalizedText) {
                            attribution = String(normalizedText[attrRange2]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    result.append(attribution)
                }
            }
        } catch {
            print("Regex error: \(error)")
        }

        for i in stride(from: 0, to: result.count - 1, by: 2) {
            await saveQuoteWithAttribution(
                quote: result[i],
                attribution: result[i + 1],
                userPrivacy: userPrivacy,
                userService: userService
            )
        }
    }

}
