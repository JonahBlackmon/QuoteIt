//
//  RecordView.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/26/25.
//

import SwiftUI
import Foundation

struct RecordView: View {
    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var audioManager: BackgroundAudioManager
    @State var animate: Bool = false
    var body: some View {
        VStack {
            Button {
                if !audioManager.isRecording {
                    audioManager.startRecording()
                } else {
                    audioManager.stopRecording()
                }
            } label: {
                RoundedRectangle(cornerRadius: audioManager.isRecording ? 25.0 : 250.0)
                    .fill(Color.mutedRed)
                    .frame(width: 150, height: 150)
                    .scaleEffect(audioManager.isRecording ? 0.5 : 1.0)
                    .padding()
                    .overlay(
                            RoundedRectangle(cornerRadius: 275)
                                .stroke(Color.darkBrown, lineWidth: 5)
                        )
            }
            Button {
                audioManager.capturePrevious(userPrivacy: self.userService.currentUserProfile?.isPrivate ?? false)
            } label: {
                Text("Quote It")
                    .font(.system(size: 27))
                    .foregroundColor(Color.lightBeige)
                    .frame(width: 160, height: 25)
                    .padding()
                    .background(Color.darkBrown)
                    .cornerRadius(15)
            }
            .opacity(audioManager.isRecording ? 1.0 : 0.0)
            .scaleEffect(audioManager.isRecording ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: audioManager.isRecording)
            .padding()
        }
    }
}
