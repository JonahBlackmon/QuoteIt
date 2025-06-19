//
//  FollowView.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 6/7/25.
//

import SwiftUI

struct FollowView: View {
    // if true display followers, else display following
    let displayFollowers: Bool
    let link: Bool
    @State var followers: [GeneralUser] = []
    let userId: String
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var userService: UserService
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack {
                    ForEach(followers) { user in
                        UserView(viewedUser: user, link: link)
                            .environmentObject(userProfile)
                            .environmentObject(userService)
                            .padding()
                    }
                }
            }
            .background(Color.lightBeige)
        }
        .background(Color.lightBeige)
        .frame(maxWidth: .infinity)
        .onAppear {
            Task {
                followers = displayFollowers ? try await userService.getFollowers(userId: userId) : try await userService.getFollowing(userId: userId)
            }
        }
    }
}

struct UserView: View {
    let viewedUser: GeneralUser
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var userService: UserService
    let link: Bool
    var body: some View {
        HStack {
            if link {
                NavigationLink {
                    ProfileView(userId: viewedUser.userId)
                } label: {
                    FollowerLabel
                }
            } else {
                FollowerLabel
            }
            Spacer()
        }
    }
    
    private var FollowerLabel: some View {
        HStack {
            AnimalAvatar(animal: viewedUser.profileAvatar, color: viewedUser.avatarColor, width: 48, height: 48, fontSize: 40)
                .shadow(radius: 2)
            Text("@\(viewedUser.username)")
                .foregroundStyle(Color.darkBrown)
        }
    }
}
