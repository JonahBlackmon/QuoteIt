//
//  LoginController.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/25/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

class LoginController : ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var alertMessage = ""
    @Published var showingAlert = false
    private let userService: UserService
    private let db = Firestore.firestore()
    private let userCollection = Firestore.firestore().collection("users")
    private let usernameGenerator = UsernameGenerator()
    
    init(userService: UserService) {
            self.userService = userService
        }
    
    func loginUser() {
        guard !email.isEmpty else {
            self.showError(error: "Please enter your email")
            return
        }
        guard !password.isEmpty else {
            self.showError(error: "Please enter your password")
            return
        }
        self.isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    print("Error when logging in user: \(error.localizedDescription)")
                    self.showError(error: error.localizedDescription)
                } else {
                    self.email = ""
                    self.password = ""
                    self.alertMessage = ""
                    print("Login Successful")
                    self.userService.resetValues()
                }
            }
        }
    }
    
func createNewUser(username: String, profileAvatar: String, avatarColorString: String) async {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            print("Creating user with email: \(email)")
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let user = result.user
            print("User created successfully with UID: \(user.uid)")
            
            let success = await self.usernameGenerator.reserveUsername(username: username, userId: user.uid)
            if !success {
                print("Failed to reserve username, deleting user account")
                try await user.delete()
                await MainActor.run {
                    self.showError(error: "Failed to reserve username. Please try again.")
                    self.isLoading = false
                }
                return
            }
            
            // Create user document
            try await userCollection.document(user.uid).setData([
                "username": username,
                "createdAt": Date(),
                "bio": "",
                "isPrivate": false,
                "lastActive": Date(),
                "followerCount": 0,
                "followingCount": 0,
                "quoteCount": 0,
                "profileAvatar": profileAvatar,
                "avatarColorString": avatarColorString,
                "userId": user.uid
            ])
            
            await MainActor.run {
                self.email = ""
                self.password = ""
                self.isLoading = false
            }
            print("User created successfully: @\(username)")
            
            // Load the user profile immediately after creation
            await userService.resetValues()
            
        } catch {
            print("Error creating user: \(error)")
            await MainActor.run {
                self.showError(error: "Failed to create account: \(error.localizedDescription)")
                self.isLoading = false
            }
        }
    }
    
    private func showError(error: String) {
        alertMessage = error
        showingAlert = true
    }
}

struct LoginView: View {
    @EnvironmentObject var loginController: LoginController
    @StateObject private var usernameGenerator = UsernameGenerator()
    @State private var createAccountView = false
    @FocusState private var emailFocus: Bool
    @FocusState private var passFocus: Bool
    var body: some View {
        NavigationStack {
            VStack {
                Image("QuoteItLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 192, height: 108)
                    .onTapGesture {
                        emailFocus = false
                        passFocus = false
                    }
                ZStack(alignment: .leading) {
                    if loginController.email.isEmpty {
                        Text("Email")
                            .foregroundStyle(Color.mutedGray)
                            .padding()
                    }
                    TextField("Email", text: $loginController.email)
                        .focused($emailFocus)
                        .padding()
                        .foregroundStyle(Color.darkBrown)
                }
                .background(Color.darkBeige)
                .cornerRadius(8)
                ZStack(alignment: .leading) {
                    if loginController.password.isEmpty {
                        Text("Password")
                            .foregroundStyle(Color.mutedGray)
                            .padding()
                    }
                    SecureField("Password", text: $loginController.password)
                        .focused($passFocus)
                        .padding()
                        .foregroundStyle(Color.darkBrown)
                        .tint(Color.mutedGray)
                }
                .background(Color.darkBeige)
                .cornerRadius(8)
                Button("Login") {
                    emailFocus = false
                    passFocus = false
                    loginController.loginUser()
                }
                .font(.system(size: 12))
                .foregroundColor(Color.darkBrown)
                .padding()
                .bold()
                .disabled(loginController.isLoading)
                
                NavigationLink("Don't have an account? Sign Up") {
                    CreateAccountView()
                        .environmentObject(loginController)
                        .environmentObject(usernameGenerator)
                }
                .font(.system(size: 12))
                .foregroundColor(Color.darkBrown)
                .bold()
                .alert("Error", isPresented: $loginController.showingAlert) {
                    Button("OK") { }
                } message: {
                    Text(loginController.alertMessage)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.lightBeige)
            .onTapGesture {
                emailFocus = false
                passFocus = false
            }
            .ignoresSafeArea()
        }
    }
}
