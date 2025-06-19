//
//  StartView.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/25/25.
//

import SwiftUI

struct StartView: View {
    @EnvironmentObject var loginController: LoginController
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var quoteManager: QuoteManager
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var backgroundAudioManager: BackgroundAudioManager
    @State private var createAccountView = false
    
    var body: some View {
        Group {
            if userProfile.isAuthenticated {
                if userService.currentUserProfile != nil {
                    // User is authenticated and profile is loaded
                    ViewManager()
                        .environmentObject(userProfile)
                        .environmentObject(quoteManager)
                        .environmentObject(loginController)
                        .environmentObject(userService)
                        .environmentObject(backgroundAudioManager)
                } else {
                    // User is authenticated but profile is still loading
                    LoadingView()
                }
            } else {
                LoginView()
                    .environmentObject(userProfile)
                    .environmentObject(loginController)
                    .environmentObject(userService)
            }
        }
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image("QuoteItLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 192, height: 108)
            
            Text("Setting up your account...")
                .font(.system(size: 16))
                .foregroundColor(Color.darkBrown)
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.olive)
                        .frame(width: 10, height: 10)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lightBeige)
        .onAppear {
            isAnimating = true
        }
    }
}
