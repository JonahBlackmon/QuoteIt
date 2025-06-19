//
//  UserProfile.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/22/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore


@MainActor class UserProfile : ObservableObject {
    
    private let db = Firestore.firestore()
    
    private let userCollection = Firestore.firestore().collection("users")

    private let quoteCollection = Firestore.firestore().collection("quotes")
    
    private let likeCollection = Firestore.firestore().collection("likes")
    
    private let followCollection = Firestore.firestore().collection("follow")
    
    private let usernameCollection = Firestore.firestore().collection("usernames")
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    private func userDocument(userId: String) -> DocumentReference {
        userCollection.document(userId)
    }
    
    @Published var userId: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    init() {
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.userId = user.uid
            self.isAuthenticated = true
        }
        self.authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    // User is signed in
                    self?.currentUser = user
                    self?.userId = user.uid
                    self?.isAuthenticated = true
                } else {
                    // User is signed out
                    self?.userId = ""
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    // Deletes the current user and all affiliated data
    func deleteUser() async throws {
        if isAuthenticated && !userId.isEmpty {
            do {
                // Delete the current user
                try await userCollection.document(userId).delete()
                
                // Delete users quotes
                let quoteSnapshot = try await quoteCollection.whereField("userId", isEqualTo: userId).getDocuments()
                for document in quoteSnapshot.documents {
                    try await document.reference.delete()
                }
                
                // Delete users like activity
                let likeSnapshot = try await likeCollection.whereField("userId", isEqualTo: userId).getDocuments()
                for document in likeSnapshot.documents {
                    try await document.reference.delete()
                }
                
                // Delete follow connections
                let followFilter = Filter.orFilter([
                    Filter.whereField("followerId", isEqualTo: userId),
                    Filter.whereField("attributionUserId", isEqualTo: userId)
                ])
                let followSnapshot = try await followCollection.whereFilter(followFilter).getDocuments()
                for document in followSnapshot.documents {
                    try await document.reference.delete()
                }
                
                // Delete saved username
                try await usernameCollection.whereField("userId", isEqualTo: userId).getDocuments().documents.first?.reference.delete()
                
                // Edit quotes that have this user as the attribution userId
                let generalQuotes = GeneralQuotes()
                let quotesSnapshot = try await quoteCollection.whereField("attributionUserId", isEqualTo: userId).getDocuments()
                for document in quotesSnapshot.documents {
                    var quote = try document.data(as: QuoteManager.Quote.self)
                    quote.attributionUserId = ""
                    try await generalQuotes.updateQuote(quote: quote)
                }
                
                // Now delete user from Firebase Authentication
                guard let currentUser = Auth.auth().currentUser else {
                    throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No current user found"])
                }
                
                try await currentUser.delete()
                
                // Update local state
                self.isAuthenticated = false
                self.userId = ""
                
            } catch {
                print("Error deleting user: \(error)")
            }
        }
    }
    
    // Signs the current user out
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            self.error = "Error signing out: \(error.localizedDescription)"
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
