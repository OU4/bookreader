//
//  ReadingTimerWidget.swift
//  BookReader
//
//  Live reading timer widget with session stats
//

import UIKit

class ReadingTimerWidget: UIView {
    
    // MARK: - Properties
    private var sessionStartTime: Date?
    private var timer: Timer?
    private var isMinimized = false
    private var lastActivityTime: Date = Date()
    private var idleThreshold: TimeInterval = 30 // 30 seconds of inactivity
    private var isAutoPaused = false
    private var accumulatedTime: TimeInterval = 0
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.15
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: effect)
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let timerLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.text = "00:00"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "Reading"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let wpmLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "0 WPM"
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "0%"
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let goalLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "Goal: 0%"
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var minimizeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        button.tintColor = .systemGray
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(toggleMinimized), for: .touchUpInside)
        return button
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .systemGray
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(closeWidget), for: .touchUpInside)
        return button
    }()
    
    // Constraints for expand/collapse animation
    private var expandedHeightConstraint: NSLayoutConstraint!
    private var minimizedHeightConstraint: NSLayoutConstraint!
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        // Don't start timer here - wait for startSession() to be called
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
        // Don't start timer here - wait for startSession() to be called
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(blurView)
        addSubview(containerView)
        
        containerView.addSubview(timerLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(statsStackView)
        containerView.addSubview(minimizeButton)
        containerView.addSubview(closeButton)
        
        statsStackView.addArrangedSubview(wpmLabel)
        statsStackView.addArrangedSubview(progressLabel)
        statsStackView.addArrangedSubview(goalLabel)
        
        // Add drag gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
        
        // Add tap gesture for minimized state
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Blur view matches container
            blurView.topAnchor.constraint(equalTo: containerView.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            // Container view
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 160),
            
            // Timer label
            timerLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            timerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            timerLabel.trailingAnchor.constraint(equalTo: minimizeButton.leadingAnchor, constant: -4),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 2),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: minimizeButton.leadingAnchor, constant: -4),
            
            // Stats stack view
            statsStackView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            statsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            statsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            statsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            
            // Minimize button
            minimizeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            minimizeButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            minimizeButton.widthAnchor.constraint(equalToConstant: 20),
            minimizeButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Close button
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Height constraints for animation
        expandedHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: 100)
        minimizedHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: 50)
        
        expandedHeightConstraint.isActive = true
    }
    
    // MARK: - Timer Management
    private func startTimer() {
        // Stop any existing timer first
        stopTimer()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateTimer()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimer() {
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)

        if timeSinceLastActivity > idleThreshold && !isAutoPaused {
            autoPauseForInactivity()
            return
        }

        let elapsed = totalElapsedTime()
        updateTimerLabel(for: elapsed)
        updateReadingStats(elapsed: elapsed)
    }

    private func totalElapsedTime() -> TimeInterval {
        if let start = sessionStartTime {
            return accumulatedTime + Date().timeIntervalSince(start)
        }
        return accumulatedTime
    }

    private func updateTimerLabel(for elapsed: TimeInterval) {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func autoPauseForInactivity() {
        isAutoPaused = true
        captureElapsedTime()
        stopTimer()
        updateStatus("Auto-paused")
        
        // Add tap to resume hint
        let resumeHint = UILabel()
        resumeHint.text = "Tap to resume"
        resumeHint.font = UIFont.systemFont(ofSize: 10)
        resumeHint.textColor = .secondaryLabel
        resumeHint.textAlignment = .center
        resumeHint.alpha = 0
        resumeHint.translatesAutoresizingMaskIntoConstraints = false
        resumeHint.tag = 999 // For easy removal
        
        containerView.addSubview(resumeHint)
        
        NSLayoutConstraint.activate([
            resumeHint.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
            resumeHint.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
        
        UIView.animate(withDuration: 0.3) {
            resumeHint.alpha = 1
        }
        
        // Pulse effect
        UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .autoreverse], animations: {
            self.containerView.alpha = 0.7
        })
    }
    
    func recordActivity() {
        lastActivityTime = Date()
        
        if isAutoPaused {
            resumeFromAutoPause()
        }
    }
    
    private func resumeFromAutoPause() {
        isAutoPaused = false
        sessionStartTime = Date()
        startTimer()
        updateStatus("Reading")
        
        // Remove resume hint
        containerView.viewWithTag(999)?.removeFromSuperview()
        
        // Stop pulse effect
        containerView.layer.removeAllAnimations()
        containerView.alpha = 1.0
    }
    
    // MARK: - Stats Update
    private func updateReadingStats(elapsed: TimeInterval) {
        if elapsed > 30 {
            let estimatedWordsRead = Int(elapsed / 3)
            let wpm = Int(Double(estimatedWordsRead) / max(elapsed / 60.0, 1))
            wpmLabel.text = "\(max(wpm, 50))\nWPM"
        } else {
            wpmLabel.text = "...\nWPM"
        }

        let (_, percentage) = UnifiedReadingTracker.shared.getTodayProgress()
        let progressPercentage = Int(percentage)
        
        goalLabel.text = "Goal:\n\(progressPercentage)%"
        
        // Change color based on progress
        if progressPercentage >= 100 {
            goalLabel.textColor = .systemGreen
        } else if progressPercentage >= 50 {
            goalLabel.textColor = .systemOrange
        } else {
            goalLabel.textColor = .secondaryLabel
        }
        
        // Achievement checking removed - simplified tracking
    }
    
    func updateProgress(_ progress: Float) {
        progressLabel.text = "Progress:\n\(Int(progress * 100))%"
    }
    
    func updateStatus(_ status: String) {
        statusLabel.text = status
        
        // Animate status change
        UIView.transition(with: statusLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.statusLabel.text = status
        }
    }
    
    // MARK: - Actions
    @objc private func toggleMinimized() {
        isMinimized.toggle()
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            if self.isMinimized {
                self.expandedHeightConstraint.isActive = false
                self.minimizedHeightConstraint.isActive = true
                self.statsStackView.alpha = 0
                self.statusLabel.alpha = 0
                self.minimizeButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
            } else {
                self.minimizedHeightConstraint.isActive = false
                self.expandedHeightConstraint.isActive = true
                self.statsStackView.alpha = 1
                self.statusLabel.alpha = 1
                self.minimizeButton.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
            }
            
            self.superview?.layoutIfNeeded()
        }
    }
    
    @objc private func closeWidget() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.removeFromSuperview()
        }
        
        stopTimer()
    }
    
    @objc private func handleTap() {
        if isMinimized {
            toggleMinimized()
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        
        let translation = gesture.translation(in: superview)
        
        switch gesture.state {
        case .changed:
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            gesture.setTranslation(.zero, in: superview)
            
        case .ended:
            // Snap to edges if needed
            let padding: CGFloat = 16
            var newCenter = center
            
            // Keep within safe bounds
            newCenter.x = max(frame.width/2 + padding, min(superview.bounds.width - frame.width/2 - padding, newCenter.x))
            newCenter.y = max(frame.height/2 + padding, min(superview.bounds.height - frame.height/2 - padding, newCenter.y))
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.center = newCenter
            }
            
        default:
            break
        }
    }
    
    // MARK: - Public Methods
    func startSession() {
        accumulatedTime = 0
        lastActivityTime = Date()
        isAutoPaused = false
        sessionStartTime = Date()
        updateTimerLabel(for: 0)
        updateStatus("Reading")
        startTimer()
    }

    func pauseSession() {
        guard timer != nil || sessionStartTime != nil else { return }
        captureElapsedTime()
        stopTimer()
        updateStatus("Paused")
    }
    
    func resumeSession() {
        guard timer == nil else { return }
        sessionStartTime = Date()
        startTimer()
        updateStatus("Reading")
    }

    func endSession() {
        captureElapsedTime()
        stopTimer()
        updateStatus("Finished")
        
        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.closeWidget()
        }
    }

    deinit {
        stopTimer()
    }

    func setElapsedTime(_ elapsed: TimeInterval) {
        if let start = sessionStartTime {
            let interval = Date().timeIntervalSince(start)
            accumulatedTime = max(0, elapsed - interval)
        } else {
            accumulatedTime = max(0, elapsed)
        }
        updateTimerLabel(for: elapsed)
        updateReadingStats(elapsed: elapsed)
    }

    private func captureElapsedTime() {
        if let start = sessionStartTime {
            accumulatedTime += Date().timeIntervalSince(start)
            sessionStartTime = nil
        }
        updateTimerLabel(for: accumulatedTime)
        updateReadingStats(elapsed: accumulatedTime)
    }
}
