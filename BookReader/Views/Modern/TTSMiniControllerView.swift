//
//  TTSMiniControllerView.swift
//  BookReader
//
//  Floating control for text-to-speech playback
//

import UIKit

protocol TTSMiniControllerViewDelegate: AnyObject {
    func ttsControllerDidTapPlay(_ controller: TTSMiniControllerView)
    func ttsControllerDidTapPause(_ controller: TTSMiniControllerView)
    func ttsControllerDidTapStop(_ controller: TTSMiniControllerView)
}

final class TTSMiniControllerView: UIView {
    enum State {
        case idle
        case playing
        case paused
    }
    
    weak var delegate: TTSMiniControllerViewDelegate?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .label
        label.text = "Text to Speech"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let playPauseButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    
    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.trackTintColor = UIColor.secondarySystemFill
        view.progressTintColor = UIColor.systemBlue
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var state: State = .idle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setState(_ newState: State) {
        state = newState
        switch newState {
        case .idle:
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            stopButton.isEnabled = false
        case .playing:
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            stopButton.isEnabled = true
        case .paused:
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            stopButton.isEnabled = true
        }
    }
    
    func updateProgress(_ progress: Float) {
        progressView.progress = max(0, min(progress, 1))
    }
    
    private func setup() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        layer.cornerRadius = 16
        layer.masksToBounds = true
        layer.borderColor = UIColor.label.withAlphaComponent(0.1).cgColor
        layer.borderWidth = 0.5
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
        
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.tintColor = .systemBlue
        stopButton.tintColor = .label
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        stopButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        stopButton.isEnabled = false
        
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        
        addSubview(titleLabel)
        addSubview(playPauseButton)
        addSubview(stopButton)
        addSubview(progressView)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            
            playPauseButton.trailingAnchor.constraint(equalTo: stopButton.leadingAnchor, constant: -12),
            playPauseButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 32),
            playPauseButton.heightAnchor.constraint(equalToConstant: 32),
            
            stopButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stopButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 32),
            stopButton.heightAnchor.constraint(equalToConstant: 32),
            
            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    @objc private func playPauseTapped() {
        switch state {
        case .idle, .paused:
            delegate?.ttsControllerDidTapPlay(self)
        case .playing:
            delegate?.ttsControllerDidTapPause(self)
        }
    }
    
    @objc private func stopTapped() {
        delegate?.ttsControllerDidTapStop(self)
    }
}
