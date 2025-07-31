//
//  ModernEmptyStateView.swift
//  BookReader
//
//  Beautiful empty state with animations
//

import UIKit

class ModernEmptyStateView: UIView {
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray3
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    // MARK: - Properties
    var onActionTapped: (() -> Void)?
    
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
        
        addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(actionButton)
        
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Action button
            actionButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            actionButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 44),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
    }
    
    // MARK: - Configuration
    func configure(title: String, subtitle: String, imageName: String, actionTitle: String? = nil) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        iconImageView.image = UIImage(systemName: imageName, withConfiguration: config)
        
        if let actionTitle = actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }
        
        startAnimation()
    }
    
    private func startAnimation() {
        // Initial state
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(translationX: 0, y: 30)
        
        iconImageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        titleLabel.transform = CGAffineTransform(translationX: -20, y: 0)
        subtitleLabel.transform = CGAffineTransform(translationX: 20, y: 0)
        actionButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Animate container
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }
        
        // Animate icon
        UIView.animate(withDuration: 0.6, delay: 0.2, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.iconImageView.transform = .identity
        }
        
        // Animate title
        UIView.animate(withDuration: 0.5, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.titleLabel.transform = .identity
        }
        
        // Animate subtitle
        UIView.animate(withDuration: 0.5, delay: 0.4, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.subtitleLabel.transform = .identity
        }
        
        // Animate button
        UIView.animate(withDuration: 0.4, delay: 0.5, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.actionButton.transform = .identity
        }
        
        // Add floating animation to icon
        startFloatingAnimation()
    }
    
    private func startFloatingAnimation() {
        UIView.animate(withDuration: 2.0, delay: 1.0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: {
            self.iconImageView.transform = CGAffineTransform(translationX: 0, y: -10)
        })
    }
    
    // MARK: - Actions
    @objc private func actionTapped() {
        // Animate button
        UIView.animate(withDuration: 0.1, animations: {
            self.actionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.actionButton.transform = .identity
            }
        }
        
        onActionTapped?()
    }
}