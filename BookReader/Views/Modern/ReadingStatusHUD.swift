//
//  ReadingStatusHUD.swift
//  BookReader
//
//  Compact status panel showing current progress, page and time
//

import UIKit

final class ReadingStatusHUD: UIView {
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let pageLabel = ReadingStatusHUD.makeLabel()
    private let percentageLabel = ReadingStatusHUD.makeLabel()
    private let timeLabel = ReadingStatusHUD.makeLabel()
    
    private var elapsedText: String = "0m"
    private var remainingText: String?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func update(page: Int?, totalPages: Int?, percentage: Float, elapsed: TimeInterval) {
        if let current = page, let total = totalPages, total > 0 {
            pageLabel.text = "Page \(current)/\(total)"
        } else {
            pageLabel.text = "Page –"
        }
        
        let clamped = max(0, min(percentage * 100, 100))
        percentageLabel.text = String(format: "%.0f%%", clamped)
        
        elapsedText = ReadingStatusHUD.format(time: elapsed)
        refreshTimeLabel()
    }
    
    func updateEstimatedRemaining(_ remaining: TimeInterval?) {
        guard let remaining = remaining, remaining.isFinite, remaining > 1 else {
            remainingText = nil
            refreshTimeLabel()
            return
        }
        remainingText = ReadingStatusHUD.format(time: remaining)
        refreshTimeLabel()
    }
    
    private func setup() {
        layer.cornerRadius = 14
        layer.masksToBounds = true
        backgroundColor = UIColor.label.withAlphaComponent(0.08)
        layer.borderColor = UIColor.label.withAlphaComponent(0.12).cgColor
        layer.borderWidth = 0.5
        
        addSubview(stackView)
        stackView.addArrangedSubview(pageLabel)
        stackView.addArrangedSubview(percentageLabel)
        stackView.addArrangedSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }
    
    private static func makeLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private static func format(time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        }
        return String(format: "%dm", max(0, minutes))
    }

    private func refreshTimeLabel() {
        if let remainingText {
            timeLabel.text = "Time \(elapsedText) • \(remainingText) left"
        } else {
            timeLabel.text = "Time \(elapsedText)"
        }
    }
}
