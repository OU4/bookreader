//
//  TTSSettingsViewController.swift
//  BookReader
//
//  Text-to-Speech settings view controller
//

import UIKit
import AVFoundation

class TTSSettingsViewController: UITableViewController {
    
    // MARK: - Properties
    private var settings = SpeechSettings.load()
    private var availableVoices: [AVSpeechSynthesisVoice] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadVoices()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Text-to-Speech Settings"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancel)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(save)
        )
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SliderCell.self, forCellReuseIdentifier: "SliderCell")
    }
    
    private func loadVoices() {
        availableVoices = TextToSpeechService.shared.getAvailableVoices()
    }
    
    // MARK: - Actions
    @objc private func cancel() {
        dismiss(animated: true)
    }
    
    @objc private func save() {
        settings.save()
        dismiss(animated: true)
    }
    
    // MARK: - Table View Data Source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // Rate, Pitch, Volume
        case 1: return 1 // Voice selection
        case 2: return 1 // Test speech
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Speech Parameters"
        case 1: return "Voice"
        case 2: return "Test"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0: // Speech parameters
            let cell = tableView.dequeueReusableCell(withIdentifier: "SliderCell", for: indexPath) as! SliderCell
            
            switch indexPath.row {
            case 0: // Rate
                cell.configure(
                    title: "Speaking Rate",
                    value: settings.rate,
                    minValue: 0.1,
                    maxValue: 1.0
                ) { [weak self] value in
                    self?.settings.rate = value
                }
                
            case 1: // Pitch
                cell.configure(
                    title: "Pitch",
                    value: settings.pitch,
                    minValue: 0.5,
                    maxValue: 2.0
                ) { [weak self] value in
                    self?.settings.pitch = value
                }
                
            case 2: // Volume
                cell.configure(
                    title: "Volume",
                    value: settings.volume,
                    minValue: 0.1,
                    maxValue: 1.0
                ) { [weak self] value in
                    self?.settings.volume = value
                }
                
            default:
                break
            }
            
            return cell
            
        case 1: // Voice selection
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = "Voice"
            
            // Find current voice name
            if let voiceId = settings.voiceIdentifier,
               let voice = availableVoices.first(where: { $0.identifier == voiceId }) {
                cell.detailTextLabel?.text = "\(voice.name) (\(voice.language))"
            } else {
                cell.detailTextLabel?.text = "Default"
            }
            
            cell.accessoryType = .disclosureIndicator
            return cell
            
        case 2: // Test
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = "Test Speech"
            cell.textLabel?.textColor = .systemBlue
            cell.accessoryType = .none
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 1: // Voice selection
            showVoicePicker()
        case 2: // Test speech
            testSpeech()
        default:
            break
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 { // Sliders
            return 80
        }
        return 44
    }
    
    // MARK: - Voice Picker
    private func showVoicePicker() {
        let voicePickerVC = VoicePickerViewController(voices: availableVoices, selectedVoiceId: settings.voiceIdentifier)
        voicePickerVC.delegate = self
        navigationController?.pushViewController(voicePickerVC, animated: true)
    }
    
    // MARK: - Test Speech
    private func testSpeech() {
        let testText = "Hello! This is a test of the text-to-speech feature. How does it sound?"
        
        // Create a temporary utterance with current settings
        let utterance = AVSpeechUtterance(string: testText)
        utterance.rate = settings.rate
        utterance.pitchMultiplier = settings.pitch
        utterance.volume = settings.volume
        
        if let voiceId = settings.voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceId)
        }
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}

// MARK: - VoicePickerDelegate
extension TTSSettingsViewController: VoicePickerDelegate {
    func didSelectVoice(_ voice: AVSpeechSynthesisVoice) {
        settings.voiceIdentifier = voice.identifier
        tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .none)
    }
}

// MARK: - Voice Picker View Controller
protocol VoicePickerDelegate: AnyObject {
    func didSelectVoice(_ voice: AVSpeechSynthesisVoice)
}

class VoicePickerViewController: UITableViewController {
    
    private let voices: [AVSpeechSynthesisVoice]
    private let selectedVoiceId: String?
    weak var delegate: VoicePickerDelegate?
    
    init(voices: [AVSpeechSynthesisVoice], selectedVoiceId: String?) {
        self.voices = voices
        self.selectedVoiceId = selectedVoiceId
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Select Voice"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "VoiceCell")
    }
    
    // MARK: - Table View Data Source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return voices.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "VoiceCell", for: indexPath)
        let voice = voices[indexPath.row]
        
        cell.textLabel?.text = voice.name
        cell.detailTextLabel?.text = voice.language
        
        // Check if this is the selected voice
        if voice.identifier == selectedVoiceId {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedVoice = voices[indexPath.row]
        delegate?.didSelectVoice(selectedVoice)
        
        navigationController?.popViewController(animated: true)
    }
}