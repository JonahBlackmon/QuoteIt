//
//  AvatarGenerator.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 6/7/25.
//

import SwiftUI

// Current avatar icons available, could be expanded or changed in the future
let animals: [String] = ["🐵","🐶","🐺","🦊","🐱","🦁","🐯","🫎","🐮","🐷",
                       "🐽","🐭","🐹","🐰","🐻","🐻‍❄️","🐨","🐼","🐣","🐸",
                         "🐋","🦈","🐙","🦭","🐢","🐲","🦑","🪼","🦀","🦞"
                         ,"🦐","🐌","🦋","🐛"]

// Current available background colors, again could be expanded or changed
let colors: [Color] = [Color.sage, Color.cream, Color.mocha, Color.olive, Color.taupe, Color.lime]

// Easy conversion for our create account view
let colorToString: [Color: String] = [Color.sage: "sage", Color.cream: "cream", Color.mocha: "mocha", Color.olive: "olive", Color.taupe: "taupe", Color.lime: "lime"]

// Randomly assigns background colors for the view, but keeps them stored to protect against constant refreshing
var animalColors: [String: Color] = {
    var result = [String: Color]()
    for animal in animals {
        result[animal] = colors.randomElement()
    }
    return result
}()

// A circular avatar displaying an animal emoji with customizable size and color
struct AnimalAvatar: View {
    let animal: String
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let fontSize: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
            Text(animal)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: width, height: height)
    }
}

struct ChooseAvatar: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var userService: UserService
    
    // Binding Variables used for creating an account
    @Binding var boundCurrentAnimal: String
    @Binding var boundCurrentColor: Color
    @Binding var boundCurrentColorString: String
    // Local variables used for the view, and updating authenticated users avatars
    @State var localCurrentAnimal: String
    @State var localCurrentColor: Color
    
    @State var toggleText: String = "Select Color?"
    @State var colorChosen: Bool = false
    @State var choosingColor: Bool = false
    @State var showAlert: Bool = false
    private let createAccount: Bool
    
    // Init for updating authenticated accounts
    init() {
        self._boundCurrentAnimal = .constant("")
        self._boundCurrentColor = .constant(.clear)
        self._boundCurrentColorString = .constant("")
        
        self.localCurrentAnimal = "?"
        self.localCurrentColor = Color.cream
        self.createAccount = false
    }
    
    // Init for creating a new account
    init(currentAnimal: Binding<String>, currentColor: Binding<Color>, currentColorString: Binding<String>, createAccount: Bool) {
        self._boundCurrentAnimal = currentAnimal
        self._boundCurrentColor = currentColor
        self._boundCurrentColorString = currentColorString
        self.localCurrentAnimal = "?"
        self.localCurrentColor = Color.cream
        self.createAccount = true
    }
    
    // Grid layout for the view
    let columns = [
            GridItem(.adaptive(minimum: 40), spacing: 64)
        ]
    
    var body: some View {
        VStack {
            currentAvatar
            
            toggleMode
            
            selectionGrid
            
            saveButtonView
        }
        .background(Color.darkBeige)
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text("Error, must pick an avatar, please try again.")
        }
    }
    private var currentAvatar: some View {
        VStack() {
            AnimalAvatar(animal: localCurrentAnimal, color: localCurrentColor, width: 88, height: 88, fontSize: 64)
            Text("Current Avatar")
                .font(.system(size: 30))
                .foregroundStyle(Color.darkBrown)
        }
        .padding()
    }
    
    private var toggleMode: some View {
        Toggle(choosingColor ? "Select Color?" : "Select Avatar?", isOn: $choosingColor)
            .foregroundStyle(Color.darkBrown)
            .padding()
    }
    
    private var selectionGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 64) {
                if !choosingColor {
                    iconView
                } else {
                    colorView
                }
            }
            .padding()
        }
        .padding()
        .background(Color.lightBeige)
        .cornerRadius(30)
    }
    
    private var iconView: some View {
        ForEach(animals, id: \.self) { animal in
            Button {
                localCurrentAnimal = animal
                localCurrentColor = colorChosen ? localCurrentColor : animalColors[animal] ?? Color.sage
            } label: {
                AnimalAvatar(animal: animal, color: animalColors[animal] ?? Color.sage, width: 88, height: 88, fontSize: 64)
            }
        }
    }
    
    private var colorView: some View {
        ForEach(colors, id: \.self) { color in
            Button {
                colorChosen = true
                localCurrentColor = color
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 64, height: 64)
            }
        }
    }
    
    private var saveButtonView: some View {
        Button("Save") {
            if !createAccount {
                if localCurrentAnimal != "?" {
                    Task {
                        userService.currentUserProfile?.avatarColor = localCurrentColor
                        userService.currentUserProfile?.profileAvatar = localCurrentAnimal
                        try await userService.updateUserProfile(userId: userService.currentUserProfile?.userId ?? "", updatedUser: userService.currentUserProfile)
                    }
                    dismiss()
                } else {
                    showAlert = true
                }
            } else {
                if localCurrentAnimal != "?" {
                    boundCurrentColor = localCurrentColor
                    boundCurrentAnimal = localCurrentAnimal
                    boundCurrentColorString = colorToString[localCurrentColor] ?? "sage"
                    dismiss()
                } else {
                    showAlert = true
                }
            }
        }
        .font(.system(size: 15))
        .foregroundColor(Color.lightBeige)
        .frame(width: 82.5, height: 12.5)
        .padding()
        .background(Color.burntOrange)
        .cornerRadius(25)
        .bold()
    }
}
