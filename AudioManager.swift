//
//  AudioManager.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/24/25.
//

import AVFoundation
import UIKit
import Speech
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/*
    Class that is responsible for controlling the background audio recording for the app to transcribe quotes
 */
class BackgroundAudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    // Buffer that contains the most recent x amount of recorded time
    private var circularBuffer: [Float] = []
    private let bufferSize: Int
    // Current position in buffer where audio is being written to
    private var writeIndex = 0
    // Uses built in FileManager to handle control of audio files
    private let fileManager = FileManager.default
    
    /*
        Parameters: duration - Default parameter for the duration of recording (20 seconds)
                    sampleRate - Uses the base sample rate for the audio in video recordings
        Post: Initializes the bufferSize the circularBuffer and the audio session
     */
    init(duration: TimeInterval = 20.0, sampleRate: Double = 44100) {
        self.bufferSize = Int(duration * sampleRate)
        self.circularBuffer = Array(repeating: 0.0, count: bufferSize)
        super.init()
        setupAudioSession()
    }
    
    /*
        Pre: Make sure audioSession is valid
        Post: Sets parameters for audio session and activates it
     */
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        }
        catch {
            print("Error setting up audio session: \(error)")
        }
    }
    
    /*
        Pre: Ensure we are not currently recording
        Post: Installs the tap to enable audio callback, and sets isRecording to true
     */
    func startRecording() {
        guard !isRecording else { return }
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) {
            [weak self] buffer, time in self?.processAudioBuffer(buffer)
        }
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("Error starting recording: \(error)")
        }
    }
    
    /*
        Parameters: buffer - the current audio buffer
        Post: Writes the most recent audio captured to the buffer
     */
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData?[0] else { return }
        let frameCount =  Int(buffer.frameLength)
        
        for i in 0..<frameCount {
            circularBuffer[writeIndex] = floatData[i]
            writeIndex = (writeIndex + 1) % bufferSize
        }
    }
    
    /*
        Parameters: UserPrivacy - determines privacy of the quote to-be published
        Post: Wipes all wav files, saves the current audio sample, and calls the transcribe function
     */
    func capturePrevious(userPrivacy: Bool) {
        let capturedSamples = Array(circularBuffer)
        let currentWrite = writeIndex
        removeAllWav()
        saveAudioSamples(capturedSamples, currentWrite)
        transcribeWavFile(userPrivacy: userPrivacy)
    }
    
    /*
        Paramters: samples - current contents of the circular buffer, index - current write index to properly wrap quotes
        Post: saves the current circular buffer to a unique document path stored locally
     */
    private func saveAudioSamples(_ samples: [Float], _ index: Int) {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        
        let channelData = buffer.floatChannelData![0]
        let difference = samples.count - index
        for i in index..<samples.count {
            channelData[i - index] = samples[i]
        }
        for i in 0..<index {
            channelData[i + difference] = samples[i]
        }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "capture_\(Date().timeIntervalSince1970).wav"
        let fileURL = documentsPath.appendingPathComponent(filename)
        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            try audioFile.write(from: buffer)
            print("Audio saved to: \(fileURL)")
        } catch {
            print("Failed to save audio: \(error)")
        }
    }
    
    /*
        Post: removes all locally stored wav files
     */
    private func removeAllWav() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            
            let wavFiles = files.filter { $0.pathExtension.lowercased() == "wav" }
            
            for fileURL in wavFiles {
                try fileManager.removeItem(at: fileURL)
                print("Successfully deleted WAV file: \(fileURL)")
            }
        } catch {
            print("Error removing wav files: \(error)")
        }
    }
    
    /*
        Pre: Check if we are currently recording
        Post: Stop the recording and remove the tap, toggle isRecording respectively
     */
    func stopRecording() {
        guard isRecording else { return }
        print("Stopping Recording.")
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
    }
    
    /*
        Post: Gets the most recent wav file stored in the app (will always be the correct one
              because we wipe them prior to calling this)
     */
    private func getWavFile() -> URL? {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            return files.first(where: {$0.pathExtension == "wav"})
        } catch {
            print("Error getting wav file: \(error)")
            return nil
        }
    }

    /*
        Parameters: UserPrivacy - passed to the newly created Quote
        Post: transcribes the wav file using SFSpeechRecognizer, then saves a new Quote via QuoteManager
     */
    private func transcribeWavFile(userPrivacy: Bool) {
        guard let url = getWavFile() else { return }
        let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        _ = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let error = error {
                print("Transcription error: \(error)")
            } else if let result = result, result.isFinal {
                print("Transcription: \(result.bestTranscription.formattedString)")
                let quoteManager = QuoteManager()
                quoteManager.saveQuote(quote: result.bestTranscription.formattedString, userPrivacy: userPrivacy)
            }
        }
    }
}
