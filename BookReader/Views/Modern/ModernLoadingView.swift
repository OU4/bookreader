//
//  ModernLoadingView.swift
//  BookReader
//
//  Beautiful loading animation
//

import UIKit

class ModernLoadingView: UIView {
    
    // MARK: - Properties
    private var isAnimating = false
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var bookIconView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        imageView.image = UIImage(systemName: "book.fill", withConfiguration: config)
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading..."
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var progressDots: [UIView] = {
        return (0..<3).map { _ in
            let dot = UIView()
            dot.backgroundColor = .systemBlue
            dot.layer.cornerRadius = 3
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
            return dot
        }
    }()
    
    private lazy var dotsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: progressDots)
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
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
        
        addSubview(containerView)
        containerView.addSubview(bookIconView)
        containerView.addSubview(loadingLabel)
        containerView.addSubview(dotsStackView)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 120),
            containerView.heightAnchor.constraint(equalToConstant: 120),
            
            // Book icon
            bookIconView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            bookIconView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            bookIconView.widthAnchor.constraint(equalToConstant: 50),
            bookIconView.heightAnchor.constraint(equalToConstant: 50),
            
            // Loading label
            loadingLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: bookIconView.bottomAnchor, constant: 12),
            
            // Dots
            dotsStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            dotsStackView.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 12)
        ])
    }
    
    // MARK: - Animation
    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        
        // Book icon rotation
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = CGFloat.pi * 2
        rotationAnimation.duration = 2.0
        rotationAnimation.repeatCount = .infinity
        bookIconView.layer.add(rotationAnimation, forKey: "rotation")
        
        // Dots animation
        for (index, dot) in progressDots.enumerated() {
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 0.5
            scaleAnimation.toValue = 1.2
            scaleAnimation.duration = 0.8
            scaleAnimation.autoreverses = true
            scaleAnimation.repeatCount = .infinity
            scaleAnimation.beginTime = CACurrentMediaTime() + Double(index) * 0.2
            
            dot.layer.add(scaleAnimation, forKey: "scale")
        }
        
        // Container breathing effect
        let breatheAnimation = CABasicAnimation(keyPath: "transform.scale")
        breatheAnimation.fromValue = 0.95
        breatheAnimation.toValue = 1.05
        breatheAnimation.duration = 1.5
        breatheAnimation.autoreverses = true
        breatheAnimation.repeatCount = .infinity
        containerView.layer.add(breatheAnimation, forKey: "breathe")
        
        // Entrance animation
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    
    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        
        // Remove all animations
        bookIconView.layer.removeAllAnimations()
        containerView.layer.removeAllAnimations()
        progressDots.forEach { $0.layer.removeAllAnimations() }
        
        // Exit animation
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        })
    }
    
    // MARK: - Text Animation
    func updateLoadingText(_ text: String) {
        UIView.transition(with: loadingLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.loadingLabel.text = text
        }
    }
}