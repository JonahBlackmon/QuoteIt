//
//  SettingsView.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 6/5/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Foundation

struct SettingsView: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var userService: UserService
    @State private var isPrivate: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var deleteAlert: Bool = false
    var body: some View {
        ScrollView {
            VStack {
                if hasAppeared {
                    SettingsToggle(text: "Private", function: userService.togglePrivacy, toggle: $isPrivate)
                }
                SettingsButton(text: "Sign Out", function: userProfile.signOut)
                Button {
                    deleteAlert = true
                } label: {
                    Text("Delete Account")
                        .foregroundStyle(Color.mutedRed)
                }
                .padding(.bottom)
                .alert("Delete Account", isPresented: $deleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        Task {
                            try await userProfile.deleteUser()
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete your account? This action cannot be undone.")
                }
            }
            .padding(.top)
            .frame(alignment: .leading)
        }
        .cornerRadius(15)
        .background(Color.mutedGray)
        .frame(maxHeight: .infinity)
        .onAppear {
            if let userProfile = userService.currentUserProfile {
                isPrivate = userProfile.isPrivate
            }
            print(isPrivate)
            hasAppeared = true
        }
    }
}

struct SettingsToggle : View {
    let text: String
    let function: () async throws -> Void
    @Binding var toggle: Bool
    var body: some View {
        VStack {
            Toggle(text, isOn: $toggle)
                .onChange(of: toggle) {
                    Task {
                        try await function()
                    }
                }
            Divider()
        }
        .foregroundStyle(Color.darkBrown)
        .padding()
    }
}

struct SettingsButtonPage<Content: View> : View {
    let text: String
    let customView: () -> Content
    @State var showView: Bool = false
    var body: some View {
        VStack {
            Button {
                showView = true
            } label: {
                Text(text)
                    .foregroundStyle(Color.darkBrown)
            }
            .sheet(isPresented: $showView) {
                customView()
            }
            Divider()
        }
        .padding()
    }
}

struct SettingsButton : View {
    let text: String
    let function: () -> Void
    @State var showView: Bool = false
    var body: some View {
        VStack {
            Button {
                function()
            } label: {
                Text(text)
                    .foregroundStyle(Color.darkBrown)
            }
            Divider()
        }
        .padding()
    }
}
