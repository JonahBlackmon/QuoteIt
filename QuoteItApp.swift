//
//  QuoteItApp.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/14/25.
//

import SwiftUI

@main
struct QuoteItApp: App {
    @StateObject private var userProfile = UserProfile()
    @StateObject private var quoteManager = QuoteManager()
    @StateObject private var userService = UserService()
    private var loginController: LoginController {
            LoginController(userService: userService)
        }
    @StateObject private var backgroundAudioManager = BackgroundAudioManager()
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    var body: some Scene {
        WindowGroup {
            StartView()
                .environmentObject(userProfile)
                .environmentObject(quoteManager)
                .environmentObject(loginController)
                .environmentObject(userService)
                .environmentObject(backgroundAudioManager)
        }
    }
}
