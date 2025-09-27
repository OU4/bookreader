//
//  LibraryStatsView.swift
//  BookReader
//
//  Modern library statistics view with animations and glassmorphism
//

import UIKit

class LibraryStatsView: UIView {
    
    // MARK: - UI Components
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.06
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let statsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let totalBooksView = SimpleStatView()
    private let completedBooksView = SimpleStatView()
    private let readingTimeView = SimpleStatView()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(backgroundView)
        backgroundView.addSubview(statsStackView)
        
        statsStackView.addArrangedSubview(totalBooksView)
        statsStackView.addArrangedSubview(completedBooksView)
        statsStackView.addArrangedSubview(readingTimeView)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            statsStackView.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 20),
            statsStackView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 16),
            statsStackView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -16),
            statsStackView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Configuration
    func updateStats(totalBooks: Int, readingTime: Int, completedBooks: Int, currentStreak: Int = 0) {
        // Configure simple stat views
        totalBooksView.configure(
            value: "\(totalBooks)",
            title: "Total Books",
            color: .systemBlue
        )
        
        completedBooksView.configure(
            value: "\(completedBooks)",
            title: "Finished",
            color: .systemGreen
        )
        
        let timeString: String
        if readingTime >= 60 {
            let hours = readingTime / 60
            let minutes = readingTime % 60
            timeString = "\(hours)h \(minutes)m"
        } else {
            timeString = "\(readingTime)m"
        }
        
        readingTimeView.configure(
            value: timeString,
            title: "Time Read",
            color: .systemPurple
        )
        
        // Add entrance animation
        addEntranceAnimation()
    }
    
    private func addEntranceAnimation() {
        backgroundView.alpha = 0
        backgroundView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        // Animate background
        UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.backgroundView.alpha = 1
            self.backgroundView.transform = .identity
        }
        
        // Animate stat views with stagger
        let statViews = [totalBooksView, completedBooksView, readingTimeView]
        for (index, statView) in statViews.enumerated() {
            statView.alpha = 0
            statView.transform = CGAffineTransform(translationX: 0, y: 15)
            
            UIView.animate(withDuration: 0.5, delay: 0.2 + Double(index) * 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                statView.alpha = 1
                statView.transform = .identity
            }
        }
    }
}

// MARK: - Simple Stat View
class SimpleStatView: UIView {
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let colorIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(colorIndicator)
        addSubview(valueLabel)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            colorIndicator.topAnchor.constraint(equalTo: topAnchor),
            colorIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            colorIndicator.widthAnchor.constraint(equalToConstant: 28),
            colorIndicator.heightAnchor.constraint(equalToConstant: 4),
            
            valueLabel.topAnchor.constraint(equalTo: colorIndicator.bottomAnchor, constant: 12),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(value: String, title: String, color: UIColor) {
        valueLabel.text = value
        titleLabel.text = title
        colorIndicator.backgroundColor = color
    }
}