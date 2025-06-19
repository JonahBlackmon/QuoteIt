//
//  UsernameGenerator.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/25/25.
//

import Firebase
import FirebaseFirestore
import FirebaseAuth

class UsernameGenerator : ObservableObject {
    
    struct Username: Identifiable, Codable {
        @DocumentID var id: String?
        var createdAt: Date?
        var userId: String
    }
    
    // Will get these from db or json in the future
    private static let adjectives = [
            "happy", "brave", "wise", "calm", "bold", "kind", "swift", "witty", "cool", "eager",
            "quiet", "smart", "loyal", "sharp", "quick", "deep", "bright", "wild", "gentle", "clever",
            "mighty", "noble", "proud", "silent", "tough", "warm", "fresh", "keen", "grand", "jolly"
    ]
    
    private static let nouns = [
        "tiger", "eagle", "wolf", "fox", "panda", "dragon", "shark", "raven", "hawk", "bear",
        "falcon", "dolphin", "phoenix", "badger", "lynx", "owl", "koala", "whale", "jaguar", "raccoon",
        "turtle", "otter", "robot", "ninja", "pirate", "wizard", "hunter", "knight", "ranger", "sage"
    ]
    
    private let db = Firestore.firestore()
    
    private let usernameCollection = Firestore.firestore().collection("usernames")
    
    private let userCollection = Firestore.firestore().collection("users")
    
    private func checkUsername(username: String) async -> Bool {
        do {
            let document = try await usernameCollection.document(username).getDocument()
            return !document.exists
        }
        catch {
            print("Error checking username: \(error)")
            return false
        }
    }
    
    private func arrangeWords() -> String {
        let randomAdj = UsernameGenerator.adjectives.randomElement() ?? "deafult"
        let randomNoun = UsernameGenerator.nouns.randomElement() ?? "user"
        return "\(randomAdj)-\(randomNoun)"
    }
    
    func generateUsername() async -> String {
        var username = "deafult-user"
        var found = false
        while !found {
            username = arrangeWords()
            found = await checkUsername(username: username)
        }
        return username
    }
    
    func reserveUsername(username: String, userId: String) async -> Bool {
        let newUsername = Username(createdAt: Date(), userId: userId)
        do {
            try usernameCollection.document(username).setData(from: newUsername)
            return true
        } catch {
            print("Error: \(error)")
            return false
        }
    }
}
