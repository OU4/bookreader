//
//  TextToSpeechService.swift
//  BookReader
//
//  Text-to-speech functionality for reading books aloud
//

import Foundation
import AVFoundation

class TextToSpeechService: NSObject {
    static let shared = TextToSpeechService()
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentText: String = ""
    private var currentPosition: Int = 0
    private var currentLength: Int = 0
    private var isPlaying: Bool = false
    private var isPaused: Bool = false
    
    weak var delegate: TextToSpeechDelegate?
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
    }
    
    // MARK: - Speech Controls
    func startReading(text: String, from position: Int = 0) {
        stop() // Stop any current speech
        
        currentText = text
        currentPosition = position
        currentLength = text.count

        let textToSpeak = String(text.dropFirst(position))
        let utterance = AVSpeechUtterance(string: textToSpeak)
        
        // Configure speech parameters
        utterance.rate = getSpeechRate()
        utterance.pitchMultiplier = getSpeechPitch()
        utterance.volume = getSpeechVolume()
        utterance.voice = getSelectedVoice()
        
        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
        
        delegate?.speechDidStart()
    }
    
    func pause() {
        guard isPlaying && !isPaused else { return }
        
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
        
        delegate?.speechDidPause()
    }
    
    func resume() {
        guard isPlaying && isPaused else { return }
        
        synthesizer.continueSpeaking()
        isPaused = false
        
        delegate?.speechDidResume()
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        currentPosition = 0
        currentLength = 0
        
        delegate?.speechDidStop()
    }
    
    // MARK: - Settings
    private func getSpeechRate() -> Float {
        return UserDefaults.standard.float(forKey: "speechRate") != 0 ? 
               UserDefaults.standard.float(forKey: "speechRate") : 0.5
    }
    
    private func getSpeechPitch() -> Float {
        return UserDefaults.standard.float(forKey: "speechPitch") != 0 ? 
               UserDefaults.standard.float(forKey: "speechPitch") : 1.0
    }
    
    private func getSpeechVolume() -> Float {
        return UserDefaults.standard.float(forKey: "speechVolume") != 0 ? 
               UserDefaults.standard.float(forKey: "speechVolume") : 1.0
    }
    
    private func getSelectedVoice() -> AVSpeechSynthesisVoice? {
        if let voiceIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier") {
            return AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        }
        
        // Default to system voice
        return AVSpeechSynthesisVoice(language: "en-US")
    }
    
    func setSpeechRate(_ rate: Float) {
        UserDefaults.standard.set(rate, forKey: "speechRate")
    }
    
    func setSpeechPitch(_ pitch: Float) {
        UserDefaults.standard.set(pitch, forKey: "speechPitch")
    }
    
    func setSpeechVolume(_ volume: Float) {
        UserDefaults.standard.set(volume, forKey: "speechVolume")
    }
    
    func setSelectedVoice(_ voice: AVSpeechSynthesisVoice) {
        UserDefaults.standard.set(voice.identifier, forKey: "selectedVoiceIdentifier")
    }
    
    // MARK: - Voice Management
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
    }
    
    func getVoicesForLanguage(_ languageCode: String) -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix(languageCode)
        }
    }
    
    // MARK: - State
    var speaking: Bool {
        return isPlaying && !isPaused
    }
    
    var paused: Bool {
        return isPaused
    }
    
    var progress: Float {
        guard currentLength > 0 else { return 0 }
        return Float(currentPosition) / Float(currentLength)
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        delegate?.speechDidStart()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        delegate?.speechDidPause()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        delegate?.speechDidResume()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isPlaying = false
        isPaused = false
        delegate?.speechDidFinish()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isPlaying = false
        isPaused = false
        delegate?.speechDidStop()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        currentPosition = characterRange.location
        delegate?.speechDidUpdatePosition(currentPosition)
    }
}

// MARK: - Protocol
protocol TextToSpeechDelegate: AnyObject {
    func speechDidStart()
    func speechDidPause()
    func speechDidResume()
    func speechDidStop()
    func speechDidFinish()
    func speechDidUpdatePosition(_ position: Int)
}

// MARK: - Speech Settings
struct SpeechSettings {
    var rate: Float = 0.5
    var pitch: Float = 1.0
    var volume: Float = 1.0
    var voiceIdentifier: String?
    
    static func load() -> SpeechSettings {
        var settings = SpeechSettings()
        settings.rate = UserDefaults.standard.float(forKey: "speechRate") != 0 ? 
                      UserDefaults.standard.float(forKey: "speechRate") : 0.5
        settings.pitch = UserDefaults.standard.float(forKey: "speechPitch") != 0 ? 
                        UserDefaults.standard.float(forKey: "speechPitch") : 1.0
        settings.volume = UserDefaults.standard.float(forKey: "speechVolume") != 0 ? 
                         UserDefaults.standard.float(forKey: "speechVolume") : 1.0
        settings.voiceIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier")
        return settings
    }
    
    func save() {
        UserDefaults.standard.set(rate, forKey: "speechRate")
        UserDefaults.standard.set(pitch, forKey: "speechPitch")
        UserDefaults.standard.set(volume, forKey: "speechVolume")
        if let voiceId = voiceIdentifier {
            UserDefaults.standard.set(voiceId, forKey: "selectedVoiceIdentifier")
        }
    }
}
