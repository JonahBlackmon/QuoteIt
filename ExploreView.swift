//
//  ExploreView.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/26/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Foundation

struct ExploreView: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var quoteManager: QuoteManager
    @EnvironmentObject var userService: UserService
    @StateObject var currentGeneralQuotes: GeneralQuotes = GeneralQuotes()
    var body: some View {
        ZStack {
            Color.lightBeige
                .ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    LazyVStack {
                        ForEach(currentGeneralQuotes.quotes) { quote in
                            QuoteView(quote: quote, currentGeneralQuotes: self.currentGeneralQuotes, userId: userProfile.userId, randomView: true)
                                .environmentObject(userProfile)
                                .environmentObject(userService)
                                .padding()
                        }
                    }
                }
                .background(Color.lightBeige)
                .onAppear {
                    Task {
                        await loadRandomQuotes(userId: userProfile.userId)
                    }
                }
            }
            .background(Color.lightBeige)
            .frame(maxWidth: .infinity)
        }
    }
    
    private func loadRandomQuotes(userId: String) async {
        self.currentGeneralQuotes.userId = userId
        self.currentGeneralQuotes.sameAsCurrent = Auth.auth().currentUser?.uid == userId
        await self.currentGeneralQuotes.getRecommendedQuotes()
    }
}
