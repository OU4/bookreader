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
        print("🏗️ ReadingTimerWidget initialized with frame: \(frame)")
        setupUI()
        setupConstraints()
        // Don't start timer here - wait for startSession() to be called
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("🏗️ ReadingTimerWidget initialized from coder")
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
        
        sessionStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateTimer()
            }
        }
        print("⏰ Timer started at: \(sessionStartTime!)")
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimer() {
        guard let startTime = sessionStartTime else { 
            print("❌ No session start time - cannot update timer")
            return 
        }
        
        // Check for idle state
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
        
        if timeSinceLastActivity > idleThreshold && !isAutoPaused {
            // Auto-pause due to inactivity
            autoPauseForInactivity()
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        timerLabel.text = timeString
        
        print("⏱️ Timer updated: \(timeString) (elapsed: \(elapsed)s)")
        
        // Update reading stats
        updateReadingStats()
    }
    
    private func autoPauseForInactivity() {
        isAutoPaused = true
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
        print("📝 Activity recorded at: \(lastActivityTime)")
        
        if isAutoPaused {
            print("🔄 Resuming from auto-pause")
            resumeFromAutoPause()
        }
    }
    
    private func resumeFromAutoPause() {
        isAutoPaused = false
        startTimer()
        updateStatus("Reading")
        
        // Remove resume hint
        containerView.viewWithTag(999)?.removeFromSuperview()
        
        // Stop pulse effect
        containerView.layer.removeAllAnimations()
        containerView.alpha = 1.0
    }
    
    // MARK: - Stats Update
    func updateReadingStats() {
        // Get current session stats from ReadingSessionTracker
        let tracker = ReadingSessionTracker.shared
        
        // Update reading speed using actual session data
        if let startTime = sessionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > 30 { // Only show after 30 seconds for better accuracy
                // Get actual reading stats from the session tracker
                if let bookId = tracker.getCurrentSessionBookId(),
                   let stats = tracker.getReadingStats(for: bookId) {
                    let currentWPM = Int(stats.averageReadingSpeed)
                    wpmLabel.text = "\(currentWPM)\nWPM"
                } else {
                    // Fallback to time-based estimate with better calculation
                    let estimatedWordsRead = Int(elapsed / 4) // More generous: 1 word per 4 seconds
                    let wpm = Int(Double(estimatedWordsRead) / (elapsed / 60.0))
                    wpmLabel.text = "\(max(wpm, 50))\nWPM" // Minimum reasonable reading speed
                }
            } else {
                wpmLabel.text = "...\nWPM"
            }
        }
        
        // Update daily goal progress using ReadingGoalManager
        let goalProgress = ReadingGoalManager.shared.checkDailyGoalProgress()
        let progressPercentage = Int(goalProgress.percentage)
        
        goalLabel.text = "Goal:\n\(progressPercentage)%"
        
        // Change color based on progress
        if goalProgress.isCompleted {
            goalLabel.textColor = .systemGreen
        } else if progressPercentage >= 50 {
            goalLabel.textColor = .systemOrange
        } else {
            goalLabel.textColor = .secondaryLabel
        }
        
        // Check for achievements
        let achievements = ReadingGoalManager.shared.checkForAchievements()
        if !achievements.isEmpty {
            // Show achievement notification
            showAchievementNotification(achievements.first!)
        }
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
        print("🚀 ReadingTimerWidget startSession() called")
        lastActivityTime = Date() // Reset activity time
        isAutoPaused = false // Reset auto-pause state
        updateStatus("Reading")
        startTimer()
        print("✅ ReadingTimerWidget session started successfully")
    }
    
    func pauseSession() {
        stopTimer()
        updateStatus("Paused")
    }
    
    func resumeSession() {
        startTimer()
        updateStatus("Reading")
    }
    
    func endSession() {
        stopTimer()
        updateStatus("Finished")
        
        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.closeWidget()
        }
    }
    
    private func showAchievementNotification(_ achievement: Achievement) {
        // Create achievement banner
        let achievementView = UIView()
        achievementView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        achievementView.layer.cornerRadius = 8
        achievementView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = achievement.icon
        iconLabel.font = UIFont.systemFont(ofSize: 20)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = achievement.title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        achievementView.addSubview(iconLabel)
        achievementView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: achievementView.leadingAnchor, constant: 8),
            iconLabel.centerYAnchor.constraint(equalTo: achievementView.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: achievementView.trailingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: achievementView.centerYAnchor),
            
            achievementView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add to superview temporarily
        if let superview = superview {
            superview.addSubview(achievementView)
            
            NSLayoutConstraint.activate([
                achievementView.centerXAnchor.constraint(equalTo: superview.centerXAnchor),
                achievementView.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor, constant: 100),
                achievementView.widthAnchor.constraint(equalToConstant: 200)
            ])
            
            // Animate in
            achievementView.alpha = 0
            achievementView.transform = CGAffineTransform(translationX: 0, y: -20)
            
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                achievementView.alpha = 1
                achievementView.transform = .identity
            }
            
            // Auto-remove after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                UIView.animate(withDuration: 0.3, animations: {
                    achievementView.alpha = 0
                    achievementView.transform = CGAffineTransform(translationX: 0, y: -20)
                }) { _ in
                    achievementView.removeFromSuperview()
                }
            }
        }
    }
    
    deinit {
        stopTimer()
    }
}