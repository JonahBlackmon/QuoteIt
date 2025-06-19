//
//  CreateAccountView.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/25/25.
//

import SwiftUI

struct CreateAccountView: View {
    @EnvironmentObject var loginController: LoginController
    @EnvironmentObject var usernameGenerator: UsernameGenerator
    @State private var generatedUsername = ""
    @State private var isGenerating = false
    @State private var isCreatingAccount = false
    @State var currentAnimal: String = "?"
    @State var currentColor: Color = Color.sage
    @State var currentColorString: String = "sage"
    @FocusState private var emailFocus: Bool
    @FocusState private var passFocus: Bool
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack {
                Text("Create Account")
                    .font(.system(size: 35))
                    .foregroundStyle(Color.darkBrown)
                    .bold()
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
                Text("Your Username:")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.darkBrown)
                Text("@\(generatedUsername)")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.burntOrange)
                Button("Re-roll Username") {
                    Task {
                        await generateNewUsername()
                    }
                }
                .font(.system(size: 20))
                .foregroundColor(Color.darkBrown)
                .frame(width: 175, height: 17.5)
                .padding()
                .background(Color.darkBeige)
                .cornerRadius(8)
                .bold()
                .disabled(isGenerating)
                NavigationLink {
                    ChooseAvatar(currentAnimal: $currentAnimal, currentColor: $currentColor, currentColorString: $currentColorString, createAccount: true)
                } label: {
                    VStack {
                        AnimalAvatar(animal: currentAnimal, color: currentColor, width: 64, height: 64, fontSize: 56)
                            .shadow(radius: 3)
                        Text("Choose Avatar")
                            .foregroundStyle(Color.darkBrown)
                    }
                }
                .padding()
                
                Button("Create Account") {
                    if currentAnimal == "?" {
                        loginController.alertMessage = "Must choose an avatar, please try again."
                        loginController.showingAlert = true
                    } else {
                        Task {
                            await createAccount()
                        }
                    }
                }
                .font(.system(size: 20))
                .foregroundColor(Color.lightBeige)
                .frame(width: 175, height: 17.5)
                .padding()
                .background(Color.burntOrange)
                .cornerRadius(8)
                .bold()
                .disabled(generatedUsername.isEmpty || isCreatingAccount || loginController.email.isEmpty || loginController.password.isEmpty)
                .alert("Error", isPresented: $loginController.showingAlert) {
                    Button("OK") { }
                } message: {
                    Text(loginController.alertMessage)
                }
                .onAppear {
                    if generatedUsername.isEmpty {
                        Task {
                            await generateNewUsername()
                        }
                    }
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
    
    private func generateNewUsername() async {
        isGenerating = true
        do {
            let username = await usernameGenerator.generateUsername()
            generatedUsername = username
        }
        isGenerating = false
    }
    private func createAccount() async {
        guard !generatedUsername.isEmpty else { return }
        
        isCreatingAccount = true
        await loginController.createNewUser(username: generatedUsername, profileAvatar: currentAnimal, avatarColorString: currentColorString)
        
        isCreatingAccount = false
        
        if !loginController.showingAlert {
            dismiss()
        }
    }
}
