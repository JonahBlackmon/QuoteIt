//
//  GeneralUser.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 6/2/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GeneralUser : Identifiable, Codable {
    // Public Information
    var profileAvatar: String = ""
    var avatarColorString: String = "sage"
    var bio: String = ""
    var username: String = ""
    var isPrivate: Bool
    // Activity tracking
    var createdAt: Date
    var lastActive: Date?
    // Counts
    var followerCount: Int?
    var followingCount: Int?
    var quoteCount: Int?
    // Authentication
    var userId: String = ""
    var id: String { userId }
    var isCurrentUser: Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return userId == currentUserId
    }
    
    // Conversion data for avatarColor
    var avatarColor: Color {
            get {
                switch avatarColorString {
                case "sage": return Color.sage
                case "cream": return Color.cream
                case "mocha": return Color.mocha
                case "olive": return Color.olive
                case "taupe": return Color.taupe
                case "lime": return Color.lime
                default: return Color.sage
                }
            }
            set {
                switch newValue {
                case Color.sage: avatarColorString = "sage"
                case Color.cream: avatarColorString = "cream"
                case Color.mocha: avatarColorString = "mocha"
                case Color.olive: avatarColorString = "olive"
                case Color.taupe: avatarColorString = "taupe"
                case Color.lime: avatarColorString = "lime"
                default: avatarColorString = "sage"
                }
            }
        }
    
    init(userId: String, data: [String: Any]) {
        self.userId = userId
        self.profileAvatar = data["profileAvatar"] as? String ?? "?"
        self.avatarColorString = data["avatarColorString"] as? String ?? "sage"
        self.bio = data["bio"] as? String ?? ""
        self.username = data["username"] as? String ?? ""
        self.isPrivate = data["isPrivate"] as? Bool ?? false
        self.createdAt = data["createdAt"] as? Date ?? Date()
        self.lastActive = Date()
        self.followerCount = data["followerCount"] as? Int ?? 0
        self.followingCount = data["followingCount"] as? Int ?? 0
        self.quoteCount = data["quoteCount"] as? Int ?? 0
    }
}
