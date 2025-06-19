//
//  ViewManager.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/26/25.
//

import SwiftUI

class NavigationState: ObservableObject {
    @Published var currentView: String = "record"
    @Published var profileClicked: Bool = false
    @Published var backgroundColor = Color.lightBeige
    @Published var searchResults: [GeneralUser] = []
    @Published var searching: Bool = false
    @Published var viewedUserId: String = ""
}

struct ViewManager: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var quoteManager: QuoteManager
    @EnvironmentObject var loginController: LoginController
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var backgroundAudioManager: BackgroundAudioManager
    @StateObject var navigationState = NavigationState()
    @State var refreshTrigger: UUID = UUID()
    @State var isRefreshing: Bool = false
    @State private var newQuoteView: Bool = false
    var body: some View {
        ZStack {
            backgroundView
            mainContentView
            if navigationState.currentView == "explore" || navigationState.currentView == "record" {
                newQuoteButton
            }
            if !navigationState.searchResults.isEmpty && navigationState.searching {
                searchOverlay
            }
            slideOutOverlay
        }
        .background(Color.mutedBrown)
        .animation(.easeInOut(duration: 0.3), value: navigationState.profileClicked)
        .onChange(of: navigationState.currentView) {
            updateBackgroundColor()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $newQuoteView) {
            NewQuoteViews()
                .environmentObject(userService)
                .environmentObject(quoteManager)
        }
    }
    
    struct NewQuoteViews: View{
        @EnvironmentObject var userService: UserService
        @EnvironmentObject var quoteManager: QuoteManager
        @State var toggleView: Bool = false
        @State var toggleText: String = "Switch to bulk quoting?"
        @State var bulkView: Bool = false
        var body: some View {
            VStack {
                if bulkView {
                    NewQuoteBulkView()
                        .environmentObject(userService)
                        .environmentObject(quoteManager)
                } else {
                    NewQuoteViewSingle()
                        .environmentObject(userService)
                        .environmentObject(quoteManager)
                }
                Toggle(toggleText, isOn: $toggleView)
                    .onChange(of: toggleView) {
                        bulkView.toggle()
                    }
                    .foregroundStyle(Color.darkBrown)
                    .padding()
            }
            .ignoresSafeArea(.keyboard)
            .background(Color.lightBeige)
            .onChange(of: toggleView) {
                toggleText = toggleView ? "Switch to single quoting?" : "Switch to bulk quoting?"
            }
        }
    }
    
    private var newQuoteButton: some View {
        Button {
            newQuoteView = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.darkBeige)
                    .frame(width: 98, height: 98)
                Image("QuillIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
            }
        }
        .padding()
        .padding(.bottom, 70)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .shadow(radius: 3)
    }
    
    private var backgroundView: some View { navigationState.backgroundColor
            .ignoresSafeArea()
    }
    
    private var mainContentView: some View {
        VStack {
            NavBar(navigationState: navigationState)
            Spacer()
            VStack(spacing: 0) {
                contentArea
                customTabBar
            }
        }
    }
    
    private var contentArea: some View {
        currentViewContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(refreshTrigger)
            .cornerRadius(15)
            .scaleEffect(isRefreshing ? 0.95 : 1.0)
            .overlay(refreshOverlay)
            .animation(.easeInOut(duration: 0.3), value: isRefreshing)
    }
    
    @ViewBuilder
    private var currentViewContent: some View {
        switch navigationState.currentView {
        case "record":
            RecordView()
                .environmentObject(backgroundAudioManager)
                .environmentObject(userService)
                .environmentObject(userProfile)
        case "explore":
            QuoteViewTemplate(fetchFunction: { await $0.getRecommendedQuotes() })
        case "profile":
            ProfileView(userId: self.userProfile.userId)
                .environmentObject(userService)
                .environmentObject(userProfile)
        case "settings":
            SettingsView()
                .environmentObject(userService)
                .environmentObject(userProfile)
        case "liked":
            QuoteViewTemplate(fetchFunction: { await $0.getLikedQuotes() })
        case "followers":
            FollowView(displayFollowers: true, link: true, userId: navigationState.viewedUserId)
                .environmentObject(userProfile)
                .environmentObject(userService)
        case "following":
            FollowView(displayFollowers: false, link: true, userId: navigationState.viewedUserId)
                .environmentObject(userProfile)
                .environmentObject(userService)
        case "profileViewer":
            ProfileView(userId: navigationState.viewedUserId)
        case "blankView":
            BlankView()
        default:
            QuoteViewTemplate(fetchFunction: { await $0.getRecommendedQuotes() })
        }
    }
    
    struct BlankView: View {
        var body: some View {
            Color(Color.lightBeige)
        }
    }
    
    @ViewBuilder
    private var refreshOverlay: some View {
        if isRefreshing {
            Color.lightBeige
                .opacity(0.7)
        }
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabItems, id: \.0) { tab in
                tabButton(for: tab)
            }
        }
        .background(Color.darkBrown)
        .animation(.easeInOut(duration: 0.3), value: navigationState.currentView)
    }
    
    private var tabItems: [(String, String)] {
        [
            ("record", "mic.fill"),
            ("explore", "house.fill"),
            ("profile", "book.fill")
        ]
    }
    
    private func tabButton(for tab: (String, String)) -> some View {
        Button(action: {
            handleTabTap(tab.0)
        }) {
            ZStack {
                tabButtonBackground(for: tab.0)
                tabButtonIcon(tab.1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
    
    @ViewBuilder
    private func tabButtonBackground(for tabName: String) -> some View {
        if navigationState.currentView == tabName {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.lightBeige.opacity(0.3))
                .frame(width: 75, height: 40)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    private func tabButtonIcon(_ iconName: String) -> some View {
        Image(systemName: iconName)
            .font(.system(size: 20))
            .foregroundColor(Color.lightBeige)
    }
    
    @ViewBuilder
    private var searchOverlay: some View {
        VStack {
            Spacer()
                .frame(height: 60)
            ScrollView {
                LazyVStack() {
                    ForEach(navigationState.searchResults) { user in
                        Button {
                            // Logic for going to user view
                            navigationState.viewedUserId = user.userId
                            navigationState.currentView = "profileViewer"
                            navigationState.searching = false
                        } label: {
                            UserView(viewedUser: user, link: false)
                                .environmentObject(userProfile)
                                .environmentObject(userService)
                                .padding()
                            if user.id != navigationState.searchResults.last?.id {
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                .background(Color.darkBeige)
                Spacer()
            }
            .frame(width: 350, height: 400)
            .background(Color.darkBeige)
            .cornerRadius(8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .shadow(radius: 3)
    }
    
    @ViewBuilder
    private var slideOutOverlay: some View {
        if navigationState.profileClicked {
            slideOutBackground
            slideOutContent
        }
    }
    
    private var slideOutBackground: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    navigationState.profileClicked = false
                }
            }
    }
    
    private var slideOutContent: some View {
        HStack {
            if let currentUser = userService.currentUserProfile {
                SlideOutNavBar(currentGeneralUser: currentUser, navigationState: navigationState)
                    .frame(width: 280)
                    .background(Color.slideOutGreen)
            }
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .leading),
            removal: .move(edge: .leading)
        ))
        .ignoresSafeArea()
    }
    
    private func handleTabTap(_ tabName: String) {
        if navigationState.currentView == tabName {
            withAnimation(.easeInOut(duration: 0.3)) {
                isRefreshing = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                refreshTrigger = UUID()
                withAnimation(.easeInOut(duration: 0.3)) {
                    isRefreshing = false
                }
            }
        } else {
            navigationState.currentView = tabName
        }
    }
    
    private func updateBackgroundColor() {
        switch navigationState.currentView {
        case "settings":
            navigationState.backgroundColor = Color.mutedGray
        default:
            navigationState.backgroundColor = Color.lightBeige
        }
    }
}

struct SlideOutNavBar: View {
    let currentGeneralUser: GeneralUser
    let textColor: Color = Color.darkBrown
    let iconColor: Color = Color.lightCream
    let navigationState: NavigationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            topSection
            followingSection
            menuSection
            Spacer()
            supportSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
    
    private var topSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
                .frame(height: 20)
            AnimalAvatar(animal: currentGeneralUser.profileAvatar, color: currentGeneralUser.avatarColor, width: 72, height: 72, fontSize: 64)
                .shadow(radius: 2)
            Text("@\(currentGeneralUser.username)")
                .foregroundColor(textColor)
                .font(.system(size: 18))
        }
    }
    
    private var followingSection: some View {
        HStack(spacing: 12) {
            followingButton
            followersButton
        }
    }
    
    private var followingButton: some View {
        Button {
            navigationState.currentView = "following"
            navigationState.profileClicked = false
        } label: {
            Text("\(currentGeneralUser.followingCount ?? 0) ")
                .foregroundColor(iconColor)
            + Text("Following")
                .foregroundColor(Color.lightBeige)
        }
    }
    
    private var followersButton: some View {
        Button {
            navigationState.currentView = "followers"
            navigationState.profileClicked = false
        } label: {
            Text("\(currentGeneralUser.followerCount ?? 0) ")
                .foregroundColor(iconColor)
            + Text("Followers")
                .foregroundColor(Color.lightBeige)
        }
    }
    
    private var menuSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profileButton
                likedButton
                Divider()
                settingsButton
            }
        }
    }
    
    private var supportSection: some View {
        Text("Contact Us: quoteitappinformation@gmail.com")
            .font(.system(size: 11))
            .foregroundStyle(Color.darkBrown)
            .padding()
    }
    
    private var profileButton: some View {
        Button {
            navigationState.currentView = "profile"
            navigationState.profileClicked = false
        } label: {
            HStack(spacing: 18) {
                Image(systemName: "book.fill")
                    .frame(minWidth: 25, alignment: .leading)
                Text("Profile")
                    .foregroundStyle(Color.lightBeige)
            }
            .font(.system(size: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(textColor)
        }
    }
    
    private var likedButton: some View {
        Button {
            navigationState.currentView = "liked"
            navigationState.profileClicked = false
        } label: {
            HStack(spacing: 18) {
                Image(systemName: "heart")
                    .frame(minWidth: 25, alignment: .leading)
                Text("My Likes")
                    .foregroundStyle(Color.lightBeige)
            }
            .font(.system(size: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(textColor)
        }
    }
    
    private var settingsButton: some View {
        Button {
            navigationState.currentView = "settings"
            navigationState.profileClicked = false
        } label: {
            HStack(spacing: 18) {
                Image(systemName: "gear")
                    .frame(minWidth: 25, alignment: .leading)
                Text("Settings and Privacy")
                    .foregroundStyle(Color.lightBeige)
            }
            .foregroundColor(textColor)
            .font(.system(size: 15))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct NavBar: View {
    @EnvironmentObject var userService: UserService
    @ObservedObject var navigationState: NavigationState
    @State var searchText: String = ""
    @FocusState private var searchFocus: Bool
    var headerText: String {
        switch navigationState.currentView {
        case "record":
            return "Quote Capture"
        case "explore":
            return "QuoteIt"
        case "profile":
            return "My Quotes"
        case "settings":
            return "Settings"
        case "liked":
            return "My Likes"
        case "followers":
            return "Followers"
        case "following":
            return "Following"
        default:
            return "QuoteIt"
        }
    }
    
    var body: some View {
        ZStack {
            profileButtonSection
            titleSection
        }
    }
    
    @ViewBuilder
    private var profileButtonSection: some View {
        HStack {
            if navigationState.currentView != "profile" && !navigationState.searching {
                Button {
                    navigationState.profileClicked = true
                } label: {
                    AnimalAvatar(animal: userService.currentUserProfile?.profileAvatar ?? "", color: userService.currentUserProfile?.avatarColor ?? Color.sage, width: 48, height: 48, fontSize: 40)
                        .shadow(radius: 2)
                        .padding(.leading)
                }
            }
            Spacer()
        }
    }
    
    private var titleSection: some View {
        return Group {
            if !navigationState.searching {
                HStack {
                    Text(headerText)
                        .font(.custom("GillSans-SemiBold", size: 18))
                        .foregroundColor(Color.darkBrown)
                    if navigationState.currentView == "explore" || navigationState.currentView == "profileViewer" {
                        Button {
                            navigationState.searching = true
                            searchFocus = true
                            navigationState.currentView = "blankView"
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.mutedGray)
                        }
                    }
                }
                .frame(width: 175, height: 45)
            } else {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.mutedGray)
                        .padding(.leading)
                    TextField("Search...", text: $searchText)
                        .focused($searchFocus)
                        .foregroundStyle(Color.darkBrown)
                }
                .frame(width: 350, height: 45)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 50)
                .fill(Color.darkBeige)
        )
        .onChange(of: navigationState.searching) {
            if !navigationState.searching && searchFocus {
                searchFocus = false
                navigationState.searchResults = []
                searchText = ""
            }
        }
        .onChange(of: searchFocus) {
            if !searchFocus && navigationState.searching {
                navigationState.searching = false
                navigationState.searchResults = []
                searchText = ""
                navigationState.currentView = "explore"
            }
        }
        .onChange(of: searchText) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Task {
                    navigationState.searchResults = await userService.searchUser(search: searchText)
                }
            }
        }
    }
    
    
}
