//
//  ProfileView.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/26/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Foundation

struct ProfileView: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var quoteManager: QuoteManager
    @EnvironmentObject var userService: UserService
    @State private var isLoading = true
    @State private var viewedUser: GeneralUser?
    @StateObject var currentGeneralQuotes: GeneralQuotes = GeneralQuotes()
    let userId: String
    
    var body: some View {
        ZStack {
            Color.lightBeige
                        .ignoresSafeArea()
            NavigationStack {
                ScrollView {
                    HeaderView(viewedUser: viewedUser)
                    LazyVStack {
                        ForEach(currentGeneralQuotes.quotes) { quote in
                            QuoteView(quote: quote, currentGeneralQuotes: self.currentGeneralQuotes, userId: userService.currentUserProfile?.userId ?? "", randomView: false)
                                .environmentObject(userService)
                                .environmentObject(userProfile)
                                .padding()
                        }
                    }
                }
                .background(Color.lightBeige)
                .onAppear {
                    Task {
                        await loadQuotes(userId: userId)
                        print("user id: \(viewedUser?.userId ?? "")")
                        print("Quotes: \(self.currentGeneralQuotes.quotes)")
                    }
                }
                .onChange(of: userService.currentUserProfile?.userId) { oldValue, newValue in
                    if userId == newValue {
                        viewedUser = userService.currentUserProfile
                    }
                }
            }
            .background(Color.lightBeige)
            .frame(maxWidth: .infinity)
        }
    }
    
    private func loadQuotes(userId: String) async {
        do {
            let user = try await userService.fetchUser(userId: userId)
            await MainActor.run {
                self.viewedUser = user
            }
        } catch {
            print("Error loading quotes: \(error)")
        }
        self.currentGeneralQuotes.userId = userId
        self.currentGeneralQuotes.sameAsCurrent = Auth.auth().currentUser?.uid == userId
        await self.currentGeneralQuotes.getQuotes()
    }
}

struct HeaderView: View {
    let viewedUser: GeneralUser?
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var userService: UserService
    @State private var followText = "Follow"
    @State private var followColor = Color.darkBrown
    @State private var followTextColor = Color.lightCream
    @State private var animate: Bool = false
    @State private var editProfileView: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Profile Picture
                AnimalAvatar(animal: viewedUser?.profileAvatar ?? "", color: viewedUser?.avatarColor ?? Color.sage, width: 72, height: 72, fontSize: 64)
                    .shadow(radius: 2)
                Spacer()
                
            }
            // Username and follow button row
            HStack {
                Text("@\(viewedUser?.username ?? "Loading...")")
                    .bold()
                    .font(.system(size: 20))
                    .foregroundColor(Color.lightBrown)
                Spacer()
                
                if let viewedUser = viewedUser, viewedUser.userId != userProfile.userId {
                    Button(followText) {
                        Task {
                            animate = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            animate = false
                            }
                            await userService.toggleFollowing(userId: viewedUser.userId)
                                followText = await userService.isFollowing(userId: viewedUser.userId) ? "Following" : "Follow"
                            followColor = await userService.isFollowing(userId: viewedUser.userId) ? Color.lightCream : Color.darkBrown
                                followTextColor = await userService.isFollowing(userId: viewedUser.userId) ? Color.darkBrown : Color.lightCream
                            }
                        }
                    .font(.system(size: 15))
                    .foregroundColor(followTextColor)
                    .frame(width: 85, height: 12)
                    .padding()
                    .background(followColor)
                    .cornerRadius(25)
                    .scaleEffect(animate ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: animate)
                } else {
                    Button("Edit Profile") {
                        editProfileView.toggle()
                    }
                    .foregroundStyle(Color.darkBrown)
                }
            }
            HStack(spacing: 12) {
                NavigationLink {
                    FollowView(displayFollowers: false, link: true, userId: viewedUser?.userId ?? "")
                } label: {
                    Text("\(viewedUser?.followingCount ?? 0) ")
                        .foregroundColor(Color.lightCream)
                    + Text("Following")
                        .foregroundColor(Color.lightBeige)
                }
                NavigationLink {
                    FollowView(displayFollowers: true, link: true, userId: viewedUser?.userId ?? "")
                } label: {
                    Text("\(viewedUser?.followerCount ?? 0) ")
                        .foregroundColor(Color.lightCream)
                    + Text("Followers")
                        .foregroundColor(Color.lightBeige)
                }
            }
            .navigationBarBackButtonHidden()
            .font(.system(size: 13))
            Divider()
            // Bio text
            Text("\(viewedUser?.bio ?? "")")
                .foregroundColor(Color.darkBrown)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.softGreen)
                .shadow(radius: 3)
        )
        .onAppear {
            Task {
                if let viewedUserId = viewedUser?.userId {
                    followText = await userService.isFollowing(userId: viewedUserId) ? "Following" : "Follow"
                    followColor = await userService.isFollowing(userId: viewedUserId) ? Color.lightCream : Color.darkBrown
                    followTextColor = await userService.isFollowing(userId: viewedUserId) ? Color.darkBrown : Color.lightCream
                }
            }
        }
        .onChange(of: viewedUser?.userId) { oldValue, newValue in
            if let newUserId = newValue {
                Task {
                    followText = await userService.isFollowing(userId: newUserId) ? "Following" : "Follow"
                    followColor = await userService.isFollowing(userId: newUserId) ? Color.lightCream : Color.darkBrown
                    followTextColor = await userService.isFollowing(userId: newUserId) ? Color.darkBrown : Color.lightCream
                }
            }
        }
        .sheet(isPresented: $editProfileView) {
            NavigationStack {
                ProfileEditView()
                    .environmentObject(userService)
            }
        }
    }
}


struct QuoteView: View {
    let quote: QuoteManager.Quote
    let currentGeneralQuotes: GeneralQuotes
    let userId: String
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var userService: UserService
    let randomView: Bool
    @State var animate: Bool? = false
    @State var currentViewedUser: GeneralUser?
    @State private var editView: Bool = false
    @State private var reportView: Bool = false
    var body: some View {
        HStack {
            NavigationStack {
                NavigationLink{
                    ProfileView(userId: currentViewedUser?.userId ?? "")
                } label: {if randomView {
                    AnimalAvatar(animal: currentViewedUser?.profileAvatar ?? "", color: currentViewedUser?.avatarColor ?? Color.sage, width: 48, height: 48, fontSize: 40)
                            .shadow(radius: 2)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading) {
                    HStack {
                        NavigationLink("@\(currentViewedUser?.username ?? "")") {
                            ProfileView(userId: currentViewedUser?.userId ?? "")
                        }
                        .foregroundColor(Color.coolBlue)
                        .navigationBarBackButtonHidden(true)
                        Spacer()
                        Button {
                            reportView.toggle()
                        } label: {
                            Text("...")
                                .foregroundStyle(Color.mutedGray)
                        }
                    }
                    
                    HStack {
                        Text("\(quote.title)")
                            .foregroundColor(Color.mutedTeal)
                            .bold()
                        if !quote.attribution.isEmpty {
                            Spacer()
                            Text("~ ")
                                .foregroundColor(Color.mutedTeal)
                                .italic()
                            if quote.attributionUserId.isEmpty {
                                Text(quote.attribution)
                                    .foregroundColor(Color.mutedTeal)
                                    .italic()
                            } else {
                                NavigationLink("@\(quote.attribution)") {
                                    ProfileView(userId: quote.attributionUserId)
                                }
                                .foregroundColor(Color.coolBlue)
                                .navigationBarBackButtonHidden(true)
                                .italic()
                            }
                        }
                    }
                }
                
                Text("\"\(quote.transcription)\"")
                    .foregroundColor(Color.darkBrown)
                    .lineLimit(nil)
                HStack {
                    if userProfile.userId == quote.userId {
                        Button("", systemImage: "pencil") {
                            editView.toggle()
                        }
                        .foregroundStyle(Color.darkBrown)
                    }
                    let timeText = currentGeneralQuotes.toRelativeTime(date: quote.timestamp ?? Date())
                    Text(timeText)
                        .frame(alignment: .leading)
                        .foregroundStyle(Color.darkBrown)
                    likeButton(quote: self.quote, currentGeneralQuotes: self.currentGeneralQuotes, currentUserId: self.userId)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(16)
            // Background color of the post
            .background(Color.darkBeige)
            .cornerRadius(12)
            .shadow(radius: 2)
            .scaleEffect(animate! ? 1.15 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: animate)
            .onAppear {
                print("userid: \(userId)")
                print("quote.userId: \(quote.userId)")
                Task {
                    do {
                        self.currentViewedUser = try await userService.fetchUser(userId: quote.userId)
                    } catch {
                        print("Error fetching user: \(error)")
                    }
                }
                animate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    animate = false
                }
            }
            .sheet(isPresented: $editView) {
                EditView(quote: quote, currentGeneralQuotes: currentGeneralQuotes, userId: userId)
                    .environmentObject(userService)
            }
            .sheet(isPresented: $reportView) {
                ReportView(quote: quote)
            }
        }
    }
}

struct ReportView: View {
    @Environment(\.dismiss) private var dismiss
    let quote: QuoteManager.Quote
    let quoteManager = QuoteManager()
    @State private var editableReason: String = ""
    @FocusState private var editFocus: Bool
    var body: some View {
        VStack {
            Text("Report Quote")
                .font(.system(size: 15))
                .foregroundColor(Color.darkBrown)
                .frame(width: 100, height: 12.5)
                .padding()
                .background(Color.darkBeige)
                .cornerRadius(25)
                .bold()
                .padding(.top)
            Text("Reason For Reporting This Quote:")
                .font(.system(size: 12))
                .foregroundColor(Color.mutedGray)
                .frame(alignment: .leading)
            TextEditor(text: $editableReason)
                .foregroundStyle(Color.darkBrown)
                .scrollContentBackground(.hidden)
                .background(Color.darkBeige)
                .cornerRadius(8)
                .padding()
                .frame(minHeight: 100)
                .focused($editFocus)
            Button("Report") {
                Task {
                    if !editableReason.isEmpty {
                        quoteManager.reportQuote(quote: quote, reportReason: editableReason)
                    }
                    dismiss()
                }
            }
            .font(.system(size: 15))
            .foregroundColor(Color.lightBeige)
            .frame(width: 82.5, height: 12.5)
            .padding()
            .background(Color.mutedRed)
            .cornerRadius(25)
            .bold()
        }
        .background(Color.lightBeige)
        .ignoresSafeArea(.keyboard)
        .onTapGesture {
            editFocus = false
        }
    }
}

struct EditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userService: UserService
    let quote: QuoteManager.Quote
    let currentGeneralQuotes: GeneralQuotes
    let userId: String
    @State private var editableTitle: String = ""
    @State private var editableBody: String = ""
    @State private var editableAttribution: String = ""
    @State private var quoteIsPrivate: Bool = false
    @FocusState private var titleFocus: Bool
    @FocusState private var bodyFocus: Bool
    @FocusState private var attributionFocus: Bool
    var body: some View {
        VStack {
            Text("Quote Editor")
                .font(.system(size: 15))
                .foregroundColor(Color.darkBrown)
                .frame(width: 100, height: 12.5)
                .padding()
                .background(Color.darkBeige)
                .cornerRadius(25)
                .bold()
                .padding(.top)
            // Delete Quote Button
            HStack {
                Button {
                    Task {
                        try await currentGeneralQuotes.deleteQuote(quote: quote)
                    }
                    dismiss()
                } label: {
                    Text("Delete Quote")
                        .foregroundStyle(Color.mutedRed)
                    Spacer()
                }
                Toggle("Make Private?", isOn: $quoteIsPrivate)
                    .foregroundStyle(Color.darkBrown)
            }
            .padding(.leading)
            .padding(.trailing)
            // Title Section
            ZStack {
                if editableTitle.isEmpty {
                    Text("Enter Title")
                        .foregroundStyle(Color.mutedGray.opacity(0.6))
                        .padding()
                }
                TextField("", text: $editableTitle)
                    .padding()
                    .foregroundStyle(Color.darkBrown)
                    .focused($titleFocus)
            }
            .frame(alignment: .leading)
            .background(Color.darkBeige)
            .cornerRadius(8)
            .padding()
            // Attribution Section
            ZStack(alignment: .leading) {
                if editableAttribution.isEmpty {
                    Text("Attribution")
                        .foregroundStyle(Color.mutedGray.opacity(0.6))
                        .padding()
                }
                TextField("", text: $editableAttribution)
                    .padding()
                    .foregroundStyle(Color.darkBrown)
                    .focused($attributionFocus)
            }
            .frame(alignment: .leading)
            .background(Color.darkBeige)
            .cornerRadius(8)
            .padding()
            TextEditor(text: $editableBody)
                .foregroundStyle(Color.darkBrown)
                .scrollContentBackground(.hidden)
                .background(Color.darkBeige)
                .cornerRadius(8)
                .padding()
                .frame(minHeight: 100)
                .focused($bodyFocus)
            Button("Save") {
                Task {
                    var updatedQuote = quote
                    if !editableAttribution.isEmpty {
                        do {
                            print(editableAttribution)
                            let savedAttributionUser = try await userService.fetchUserByUsername(username: editableAttribution)
                            if let attributionUser = savedAttributionUser {
                                updatedQuote.attributionUserId = attributionUser.userId
                            }
                        } catch {
                            print("Error fetching attribution user: \(error)")
                            updatedQuote.attributionUserId = ""
                        }
                    } else {
                        updatedQuote.attributionUserId = ""
                    }
                    updatedQuote.isPrivate = quoteIsPrivate
                    updatedQuote.attribution = editableAttribution
                    updatedQuote.title = editableTitle
                    updatedQuote.transcription = editableBody
                    
                    do {
                        try await currentGeneralQuotes.updateQuote(quote: updatedQuote)
                    } catch {
                        print("Error updating quote: \(error)")
                    }
                }
                dismiss()
            }
            .font(.system(size: 15))
            .foregroundColor(Color.lightBeige)
            .frame(width: 82.5, height: 12.5)
            .padding()
            .background(Color.burntOrange)
            .cornerRadius(25)
            .bold()
            .onAppear {
                editableTitle = quote.title
                editableBody = quote.transcription
                editableAttribution = quote.attribution
                quoteIsPrivate = quote.isPrivate
            }
        }
        .background(Color.lightBeige)
        .ignoresSafeArea(.keyboard)
        .onTapGesture {
            titleFocus = false
            bodyFocus = false
            attributionFocus = false
        }
    }
}

struct NewQuoteViewSingle: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var quoteManager: QuoteManager
    @State private var editableTitle: String = "New Quote"
    @State private var editableBody: String = ""
    @State private var editableAttribution: String = ""
    @FocusState private var titleFocus: Bool
    @FocusState private var bodyFocus: Bool
    @FocusState private var attributionFocus: Bool
    var body: some View {
        VStack {
            Text("Single Quoting")
                .font(.system(size: 15))
                .foregroundColor(Color.darkBrown)
                .frame(width: 150, height: 12.5)
                .padding()
                .background(Color.darkBeige)
                .cornerRadius(25)
                .bold()
                .padding(.top)
            // Title Section
            ZStack {
                if editableTitle.isEmpty {
                    Text("Enter Title")
                        .foregroundStyle(Color.mutedGray.opacity(0.6))
                        .padding()
                }
                TextField("", text: $editableTitle)
                    .padding()
                    .foregroundStyle(Color.darkBrown)
                    .focused($titleFocus)
            }
            .frame(alignment: .leading)
            .background(Color.darkBeige)
            .cornerRadius(8)
            .padding()
            // Attribution Section
            ZStack(alignment: .leading) {
                if editableAttribution.isEmpty {
                    Text("Attribution")
                        .foregroundStyle(Color.mutedGray.opacity(0.6))
                        .padding()
                }
                TextField("", text: $editableAttribution)
                    .padding()
                    .foregroundStyle(Color.darkBrown)
                    .focused($attributionFocus)
            }
            .frame(alignment: .leading)
            .background(Color.darkBeige)
            .cornerRadius(8)
            .padding()
            TextEditor(text: $editableBody)
                .foregroundStyle(Color.darkBrown)
                .scrollContentBackground(.hidden)
                .background(Color.darkBeige)
                .cornerRadius(8)
                .padding()
                .frame(minHeight: 100)
                .focused($bodyFocus)
            Button("Quote It") {
                Task {
                    var updatedQuote = QuoteManager.Quote(
                        title: "New Quote",
                        transcription: "",
                        userId: userService.currentUserProfile?.userId ?? "",
                        timestamp: Date(),
                        likes: 0,
                        isPrivate: userService.currentUserProfile?.isPrivate ?? false,
                        attribution: "",
                        attributionUserId: ""
                    )
                    
                    if !editableAttribution.isEmpty {
                        do {
                            print(editableAttribution)
                            let savedAttributionUser = try await userService.fetchUserByUsername(username: editableAttribution)
                            if let attributionUser = savedAttributionUser {
                                updatedQuote.attributionUserId = attributionUser.userId
                            }
                        } catch {
                            print("Error fetching attribution user: \(error)")
                            updatedQuote.attributionUserId = ""
                        }
                    } else {
                        updatedQuote.attributionUserId = ""
                    }
                    
                    updatedQuote.attribution = editableAttribution
                    updatedQuote.title = editableTitle
                    updatedQuote.transcription = editableBody
                    quoteManager.saveQuote(quote: updatedQuote, userPrivacy: userService.currentUserProfile?.isPrivate ?? false)
                }
                dismiss()
            }
            .font(.system(size: 15))
            .foregroundColor(Color.lightBeige)
            .frame(width: 82.5, height: 12.5)
            .padding()
            .background(Color.burntOrange)
            .cornerRadius(25)
            .bold()
        }
        .background(Color.lightBeige)
        .ignoresSafeArea(.keyboard)
        .onTapGesture {
            titleFocus = false
            bodyFocus = false
            attributionFocus = false
        }
    }
}

struct NewQuoteBulkView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var quoteManager: QuoteManager
    @State private var editableBody: String = ""
    @FocusState private var bodyFocus: Bool
    var body: some View {
        VStack {
            Text("Bulk Quoting")
                .font(.system(size: 15))
                .foregroundColor(Color.darkBrown)
                .frame(width: 150, height: 12.5)
                .padding()
                .background(Color.darkBeige)
                .cornerRadius(25)
                .bold()
                .padding(.top)
            HStack {
                Text("Format for bulk quoting:\n\"Quote\" - optional attribution\n\"Quote\" - optional attribution\n...")
                    .foregroundStyle(Color.mutedGray)
                    .padding()
                Spacer()
            }
            TextEditor(text: $editableBody)
                .foregroundStyle(Color.darkBrown)
                .scrollContentBackground(.hidden)
                .background(Color.darkBeige)
                .cornerRadius(8)
                .padding()
                .frame(minHeight: 100)
                .focused($bodyFocus)
            Button("Quote It") {
                Task {
                    await quoteManager.saveQuoteFromText(text: editableBody, userPrivacy: userService.currentUserProfile?.isPrivate ?? false, userService: userService)
                }
                dismiss()
            }
            .font(.system(size: 15))
            .foregroundColor(Color.lightBeige)
            .frame(width: 82.5, height: 12.5)
            .padding()
            .background(Color.burntOrange)
            .cornerRadius(25)
            .bold()
        }
        .background(Color.lightBeige)
        .ignoresSafeArea(.keyboard)
        .onTapGesture {
            bodyFocus = false
        }
    }
}

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userService: UserService
    @State private var editableBio: String = ""
    @FocusState private var bioFocus: Bool
    var body: some View {
        VStack {
            Text("Profile Editor")
                .font(.system(size: 15))
                .foregroundColor(Color.darkBrown)
                .frame(width: 100, height: 12.5)
                .padding()
                .background(Color.darkBeige)
                .cornerRadius(25)
                .bold()
                .padding(.top)
            NavigationLink {
                ChooseAvatar()
                    .navigationBarBackButtonHidden(true)
            } label: {
                Text("Edit Profile Avatar?")
                    .foregroundStyle(Color.darkBrown)
            }
            ZStack(alignment: .topLeading) {
                if editableBio.isEmpty {
                    Text("Enter Bio")
                        .foregroundStyle(Color.mutedGray.opacity(0.6))
                        .font(.system(size: 17))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 25)
                        .focused($bioFocus)
                }
                TextEditor(text: $editableBio)
                    .foregroundStyle(Color.darkBrown)
                    .scrollContentBackground(.hidden)
                    .padding()
            }
            .background(Color.darkBeige)
            .cornerRadius(8)
            .padding()
            .frame(minHeight: 100)
            Button("Save") {
                Task {
                    var updatedUser = userService.currentUserProfile
                    updatedUser?.bio = editableBio
                    Task {
                        try await userService.updateUserProfile(userId: userService.currentUserProfile?.userId ?? "", updatedUser: updatedUser)
                    }
                }
                dismiss()
            }
            .font(.system(size: 15))
            .foregroundColor(Color.lightBeige)
            .frame(width: 82.5, height: 12.5)
            .padding()
            .background(Color.burntOrange)
            .cornerRadius(25)
            .bold()
            .onAppear {
                editableBio = userService.currentUserProfile?.bio ?? ""
            }
        }
        .background(Color.lightBeige)
        .onTapGesture {
            bioFocus = false
        }
    }
}


struct likeButton: View {
    let quote: QuoteManager.Quote
    let currentGeneralQuotes: GeneralQuotes
    let currentUserId: String
    @State var isLiked: Bool? = false
    @State var foregroundStyle = Color.mutedGray
    @State var systemImage: String = "heart"
    @State var animate: Bool = false
    
    private var animationScale: CGFloat {
        isLiked! ? 0.7 : 1.3
    }
    private let animationDuration: Double = 0.1
    
    var body: some View {
        HStack(spacing: 2) {
            Button("", systemImage: systemImage) {
                Task {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        animate.toggle()
                    }
                    
                    await self.currentGeneralQuotes.toggleLike(userId: self.currentGeneralQuotes.currentUserId ?? "", quote: self.quote)
                    await MainActor.run {
                        isLiked?.toggle()
                        updateHeartAppearance()
                        Task {
                            isLiked = await currentGeneralQuotes.hasLiked(userId: currentUserId, quote: quote)
                            updateHeartAppearance()
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        animate = false
                    }
                }
            }
            .foregroundStyle(foregroundStyle)
            .scaleEffect(animate ? 1.15 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: animate)
            Text("\(quote.likes)")
                .font(.footnote)
                .foregroundStyle(Color.darkBrown)
                .frame(minWidth: 25, alignment: .trailing)
        }
        .onAppear {
            Task {
                isLiked = await currentGeneralQuotes.hasLiked(userId: currentUserId, quote: quote)
                updateHeartAppearance()
            }
        }
    }
    
    private func updateHeartAppearance() {
        foregroundStyle = (isLiked == true) ? Color.mutedRed : Color.mutedGray
        systemImage = (isLiked == true) ? "heart.fill" : "heart"
    }
}
