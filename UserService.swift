//
//  UserService.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 6/2/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Foundation

/*
 This is the class responsible for fetching and updating user data
 */
@MainActor
class UserService : ObservableObject, Sendable {
    
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentUserProfile: GeneralUser?
    
    private var cachedUsers: [String: GeneralUser] = [:]
    private var cachedCount: Int
    private var MAX_CACHE_COUNT = 100
    
    private var followCollection = Firestore.firestore().collection("follow")
    private var userCollection = Firestore.firestore().collection("users")
    
    // Init the UserService
    init() {
        self.currentUserProfile = nil
        self.cachedCount = 0
        Task {
            await loadCurrentUser()
        }
    }
    
    private func loadCurrentUser() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let user = try await withTimeout(seconds: 10) {
                try await self.fetchUser(userId: currentUserId)
            }
            
            DispatchQueue.main.async {
                self.currentUserProfile = user
            }
        } catch {
            print("Error loading current user: \(error)")
            DispatchQueue.main.async {
                self.currentUserProfile = nil
            }
            // Sign out the user so they can go back to login screen
            do {
                try Auth.auth().signOut()
                print("User signed out due to profile loading error")
            } catch let signOutError {
                print("Error signing out user: \(signOutError)")
            }
        }
    }

    // Helper function for timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            group.cancelAll()
            return result
        }
    }

    struct TimeoutError: Error {
        let localizedDescription = "Operation timed out"
    }
    
    @MainActor
    func resetValues() {
        self.currentUserProfile = nil
        self.cachedCount = 0
        Task {
            await loadCurrentUser()
        }
    }
    
    // Gets all users that fit the current input string
    func searchUser(search: String) async -> [GeneralUser] {
        guard !search.isEmpty else {
            return []
        }
        let lowercaseSearch = search.lowercased()
        var returnUsers: [GeneralUser] = []
        do {
            returnUsers = try await userCollection
                .whereField("username", isGreaterThanOrEqualTo: lowercaseSearch)
                .whereField("username", isLessThan: lowercaseSearch + "\u{f8ff}")
                .limit(to: 10)
                .getDocuments()
                .documents.compactMap { document in
                            try? document.data(as: GeneralUser.self)
                        }
            return returnUsers
        } catch {
            print("Error searchinng users: \(error)")
        }
        return returnUsers
    }
    
    // Sets the current user profile, and adds user to cache
    func fetchUser(userId: String) async throws -> GeneralUser {
        // First check if user exists within cache
        if let cachedUser = cachedUsers[userId] {
            return cachedUser
        } else {
            // Fetch user from Firestore
            guard let data = try await Firestore.firestore().collection("users").document(userId).getDocument().data() else {
                throw AppError.fetchError
            }
            let user = GeneralUser(userId: userId, data: data)
            
            // Add this profile to the cache
            if cachedCount < MAX_CACHE_COUNT {
                cachedUsers[user.userId] = user
                cachedCount += 1
            } else {
                // Wipes cache and starts from scratch
                cachedUsers = [:]
                cachedCount = 1
                cachedUsers[user.userId] = user
            }
            
            return user
        }
    }
    
    func fetchUserByUsername(username: String) async throws -> GeneralUser? {
        let usernameDocSnapshot = try await Firestore.firestore().collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments()
        if !usernameDocSnapshot.isEmpty {
            guard let userId = usernameDocSnapshot.documents.first?["userId"] as? String, !userId.isEmpty else {
                throw AppError.fetchError
            }
            return try await fetchUser(userId: userId)
        }
        return nil
    }
    
    func togglePrivacy() async throws {
        let userId = currentUserProfile?.userId ?? ""
        var currentUser = try await fetchUser(userId: userId)
        currentUser.isPrivate.toggle()
        try await updateUserProfile(userId: userId, updatedUser: currentUser)
        print("User is now: \(currentUser.isPrivate ? "Private" : "Not Private")")
    }
    
    @MainActor
    func updateUserProfile(userId: String, updatedUser: GeneralUser?) async throws {
        do { try userCollection.document(userId as String).setData(from: updatedUser, merge: true) }
        catch { throw AppError.updateError }
        if cachedUsers[userId] != nil {
            // The user exists in our cache, so we must update it
            cachedUsers[userId] = updatedUser
        }
        if currentUserProfile?.userId == userId {
            //Publishing changes from background threads is not allowed; make sure to publish values from the main thread (via operators like receive(on:)) on model updates.
            currentUserProfile = updatedUser
        }
    }
    
    struct Follow: Identifiable, Codable {
        @DocumentID var id: String?
        let userId: String
        let followerId: String
        let timestamp: Date
    }
    
    // Gets all users that the account associated with the userId is following
    func getFollowing(userId: String) async throws -> [GeneralUser] {
        let followers = try await followCollection.whereField("followerId", isEqualTo: userId).getDocuments()
        let followObjects = followers.documents.compactMap { doc in
            try? doc.data(as: Follow.self)
        }
        return await withTaskGroup(of: GeneralUser?.self) { group in
                for follow in followObjects {
                    group.addTask {
                        try? await self.fetchUser(userId: follow.userId)
                    }
                }
                
                var users: [GeneralUser] = []
                for await user in group {
                    if let user = user {
                        users.append(user)
                    }
                }
                return users
            }
    }
    
    // Gets all users that the account associated with the userId is followed by
    func getFollowers(userId: String) async throws -> [GeneralUser] {
        let followers = try await followCollection.whereField("userId", isEqualTo: userId).getDocuments()
        let followObjects = followers.documents.compactMap { doc in
            try? doc.data(as: Follow.self)
        }
        return await withTaskGroup(of: GeneralUser?.self) { group in
                for follow in followObjects {
                    group.addTask {
                        try? await self.fetchUser(userId: follow.followerId)
                    }
                }
                
                var users: [GeneralUser] = []
                for await user in group {
                    if let user = user {
                        users.append(user)
                    }
                }
                return users
            }
    }
    
    // Parameter userId refers to the id of the user getting toggled
    @MainActor
    func toggleFollowing(userId: String) async {
        do {
            let snapshot = try await followCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("followerId", isEqualTo: currentUserProfile?.userId as Any)
                .getDocuments()
                
            if !snapshot.isEmpty {
                // Following already exists, so remove it
                try await snapshot.documents.first?.reference.delete()
                
                guard let selfCurrentCount = self.currentUserProfile?.followingCount else {
                    throw AppError.fetchError
                }
                self.currentUserProfile?.followingCount = selfCurrentCount - 1
                
                let updateData: [String: Any] = [
                    "followingCount": FieldValue.increment(Int64(-1))
                ]
                try await userCollection.document(self.currentUserProfile?.userId ?? "").updateData(updateData)
                
                var userToUpdate = try await fetchUser(userId: userId)
                
                guard let currentFollowerCount = userToUpdate.followerCount else {
                    throw AppError.fetchError
                }
                userToUpdate.followerCount = currentFollowerCount - 1
                
                cachedUsers[userId] = userToUpdate
                
                let userUpdateData: [String: Any] = [
                    "followerCount": FieldValue.increment(Int64(-1))
                ]
                try await userCollection.document(userToUpdate.userId).updateData(userUpdateData)
                
            } else {
                // Add new follower
                let newFollower = Follow(userId: userId, followerId: currentUserProfile?.userId ?? "", timestamp: Date())
                
                do {
                    let ref = try followCollection.addDocument(from: newFollower)
                    print("Document added with new reference: \(ref)")
                } catch {
                    print("Error adding document: \(error)")
                }
                
                guard let selfCurrentCount = self.currentUserProfile?.followingCount else {
                    throw AppError.fetchError
                }
                self.currentUserProfile?.followingCount = selfCurrentCount + 1
                
                let updateData: [String: Any] = [
                    "followingCount": FieldValue.increment(Int64(1))
                ]
                try await userCollection.document(self.currentUserProfile?.userId ?? "").updateData(updateData)
                
                var userToUpdate = try await fetchUser(userId: userId)
                
                guard let currentFollowerCount = userToUpdate.followerCount else {
                    throw AppError.fetchError
                }
                userToUpdate.followerCount = currentFollowerCount + 1
                
                cachedUsers[userId] = userToUpdate
                
                let userUpdateData: [String: Any] = [
                    "followerCount": FieldValue.increment(Int64(1))
                ]
                try await userCollection.document(userToUpdate.userId).updateData(userUpdateData)
            }
            cachedUsers[self.currentUserProfile?.userId ?? ""] = self.currentUserProfile
        } catch {
            print("Error toggling follow \(error)")
        }
    }
    
    func isFollowing(userId: String) async -> Bool {
        do {
            let snapshot = try await followCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("followerId", isEqualTo: currentUserProfile?.userId ?? "")
                .getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            print("Error checking following: \(error)")
        }
        return false
    }
    
}
