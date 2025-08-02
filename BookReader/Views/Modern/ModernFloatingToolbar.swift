//
//  ModernFloatingToolbar.swift
//  BookReader
//
//  Beautiful floating toolbar with glassmorphism effect
//

import UIKit

protocol ModernFloatingToolbarDelegate: AnyObject {
    func didTapLibrary()
    func didTapHighlight()
    func didTapBookmarks()
    func didTapMore()
}

class ModernFloatingToolbar: UIView {
    
    weak var delegate: ModernFloatingToolbarDelegate?
    
    // MARK: - UI Components
    private lazy var blurEffect: UIBlurEffect = {
        return UIBlurEffect(style: .systemUltraThinMaterial)
    }()
    
    private lazy var blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: blurEffect)
        view.layer.cornerRadius = 30
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var libraryButton = createModernButton(
        icon: "books.vertical.fill",
        action: #selector(libraryTapped)
    )
    
    private lazy var highlightButton = createModernButton(
        icon: "highlighter",
        action: #selector(highlightTapped)
    )
    
    private lazy var bookmarksButton = createModernButton(
        icon: "bookmark.fill",
        action: #selector(bookmarksTapped)
    )
    
    private lazy var moreButton = createModernButton(
        icon: "ellipsis.circle.fill",
        action: #selector(moreTapped)
    )
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        addAnimationEffects()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        addAnimationEffects()
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        // Add blur background
        addSubview(blurView)
        
        // Add buttons to stack - only 4 for better UX
        stackView.addArrangedSubview(libraryButton)
        stackView.addArrangedSubview(highlightButton)
        stackView.addArrangedSubview(bookmarksButton)
        stackView.addArrangedSubview(moreButton)
        
        blurView.contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            // Blur view
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Stack view
            stackView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: blurView.contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: blurView.contentView.trailingAnchor, constant: -20)
        ])
        
        // Add subtle shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 20
        layer.shadowOpacity = 0.15
    }
    
    private func createModernButton(icon: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.tintColor = .label
        
        button.backgroundColor = UIColor.label.withAlphaComponent(0.08)
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // Add hover effect
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        
        return button
    }
    
    private func addAnimationEffects() {
        // Add subtle floating animation
        let floatAnimation = CABasicAnimation(keyPath: "transform.translation.y")
        floatAnimation.fromValue = -2
        floatAnimation.toValue = 2
        floatAnimation.duration = 3.0
        floatAnimation.autoreverses = true
        floatAnimation.repeatCount = .infinity
        layer.add(floatAnimation, forKey: "floating")
    }
    
    // MARK: - Button Animations
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            sender.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.allowUserInteraction]) {
            sender.transform = .identity
            sender.backgroundColor = UIColor.label.withAlphaComponent(0.08)
        }
    }
    
    // MARK: - Actions
    @objc private func libraryTapped() {
        animateButtonPress(libraryButton)
        delegate?.didTapLibrary()
    }
    
    @objc private func highlightTapped() {
        animateButtonPress(highlightButton)
        delegate?.didTapHighlight()
    }
    
    @objc private func bookmarksTapped() {
        animateButtonPress(bookmarksButton)
        delegate?.didTapBookmarks()
    }
    
    @objc private func moreTapped() {
        animateButtonPress(moreButton)
        delegate?.didTapMore()
    }
    
    private func animateButtonPress(_ button: UIButton) {
        // Create ripple effect
        let ripple = CAShapeLayer()
        let path = UIBezierPath(ovalIn: button.bounds)
        ripple.path = path.cgPath
        ripple.fillColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        ripple.opacity = 0
        
        button.layer.addSublayer(ripple)
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.8
        scaleAnimation.toValue = 1.2
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8
        opacityAnimation.toValue = 0
        
        let group = CAAnimationGroup()
        group.animations = [scaleAnimation, opacityAnimation]
        group.duration = 0.3
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        ripple.add(group, forKey: "ripple")
        
        // Remove ripple after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            ripple.removeFromSuperlayer()
        }
    }
    
    // MARK: - Theme Updates
    func updateTheme(_ theme: ReadingTheme) {
        UIView.animate(withDuration: 0.3) {
            let buttonColor = theme.isDarkMode ? UIColor.white.withAlphaComponent(0.1) : UIColor.black.withAlphaComponent(0.08)
            
            [self.libraryButton, self.highlightButton, self.bookmarksButton, 
             self.moreButton].forEach { button in
                button.backgroundColor = buttonColor
            }
        }
    }
}