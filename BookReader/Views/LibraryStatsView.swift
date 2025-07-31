//
//  LibraryStatsView.swift
//  BookReader
//
//  Modern library statistics view with animations and glassmorphism
//

import UIKit

class LibraryStatsView: UIView {
    
    // MARK: - UI Components
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: effect)
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 1
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let totalBooksView = ModernStatItemView()
    private let booksReadView = ModernStatItemView()
    private let readingTimeView = ModernStatItemView()
    
    private let chevronView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
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
        
        addSubview(blurView)
        blurView.contentView.addSubview(stackView)
        blurView.contentView.addSubview(chevronView)
        
        stackView.addArrangedSubview(totalBooksView)
        stackView.addArrangedSubview(booksReadView)
        stackView.addArrangedSubview(readingTimeView)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -20),
            
            chevronView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -16),
            chevronView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 12),
            chevronView.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.1
    }
    
    // MARK: - Configuration
    func updateStats(totalBooks: Int, readingTime: Int, completedBooks: Int) {
        totalBooksView.configure(
            icon: "📚",
            value: "\(totalBooks)",
            title: "Total Books",
            color: .systemBlue
        )
        
        booksReadView.configure(
            icon: "✅",
            value: "\(completedBooks)",
            title: "Completed",
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
            icon: "⏱️",
            value: timeString,
            title: "Reading Time",
            color: .systemOrange
        )
        
        // Add entrance animation
        addEntranceAnimation()
    }
    
    private func addEntranceAnimation() {
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.alpha = 1
            self.transform = .identity
        }
    }
}

// MARK: - Modern Stat Item View
class ModernStatItemView: UIView {
    
    private let iconLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var accentColor: UIColor = .systemBlue
    
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
        
        addSubview(iconLabel)
        addSubview(valueLabel)
        addSubview(titleLabel)
        addSubview(separatorView)
        
        NSLayoutConstraint.activate([
            iconLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            iconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            separatorView.widthAnchor.constraint(equalToConstant: 1)
        ])
    }
    
    func configure(icon: String, value: String, title: String, color: UIColor) {
        iconLabel.text = icon
        valueLabel.text = value
        titleLabel.text = title
        accentColor = color
        
        // Add color accent to value
        valueLabel.textColor = color
        
        // Hide separator for last item
        separatorView.isHidden = false
        
        // Add entrance animation
        addEntranceAnimation()
    }
    
    private func addEntranceAnimation() {
        iconLabel.alpha = 0
        valueLabel.alpha = 0
        titleLabel.alpha = 0
        
        iconLabel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        valueLabel.transform = CGAffineTransform(translationX: 0, y: 10)
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 10)
        
        UIView.animate(withDuration: 0.5, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.iconLabel.alpha = 1
            self.iconLabel.transform = .identity
        }
        
        UIView.animate(withDuration: 0.4, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.valueLabel.alpha = 1
            self.valueLabel.transform = .identity
        }
        
        UIView.animate(withDuration: 0.4, delay: 0.4, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }
    }
    
    func hideSeparator() {
        separatorView.isHidden = true
    }
}