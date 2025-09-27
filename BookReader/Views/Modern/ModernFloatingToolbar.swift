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
    
    private var highlightCount = 0
    private var bookmarkCount = 0
    private var isHighlightModeActive = false
    
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
    private lazy var highlightBadge = createBadgeLabel()
    
    private lazy var bookmarksButton = createModernButton(
        icon: "bookmark.circle.fill",
        action: #selector(bookmarksTapped)
    )
    private lazy var bookmarkBadge = createBadgeLabel()
    
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
        highlightButton.addSubview(highlightBadge)
        bookmarksButton.addSubview(bookmarkBadge)

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
        
        NSLayoutConstraint.activate([
            highlightBadge.topAnchor.constraint(equalTo: highlightButton.topAnchor, constant: -4),
            highlightBadge.trailingAnchor.constraint(equalTo: highlightButton.trailingAnchor, constant: 4),
            bookmarkBadge.topAnchor.constraint(equalTo: bookmarksButton.topAnchor, constant: -4),
            bookmarkBadge.trailingAnchor.constraint(equalTo: bookmarksButton.trailingAnchor, constant: 4)
        ])

        // Add subtle shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 20
        layer.shadowOpacity = 0.15

        applyHighlightButtonAppearance()
        applyBookmarkButtonAppearance()
    }

    private func createModernButton(icon: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium, scale: .medium)
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.tintColor = .label
        
        button.backgroundColor = UIColor.label.withAlphaComponent(0.1)
        button.layer.cornerRadius = 22
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subtle border for better visibility
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.label.withAlphaComponent(0.2).cgColor
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // Add hover effect
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        
        return button
    }

    private func createBadgeLabel() -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = UIColor.systemRed
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        label.layer.cornerRadius = 9
        label.layer.masksToBounds = true
        label.isHidden = true
        label.heightAnchor.constraint(equalToConstant: 18).isActive = true
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 18).isActive = true
        return label
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
            sender.backgroundColor = UIColor.label.withAlphaComponent(0.1)
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
    
    // Method to show highlight mode state
    func setHighlightMode(active: Bool) {
        isHighlightModeActive = active
        UIView.animate(withDuration: 0.3) {
            if active {
                self.highlightButton.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.35)
                self.highlightButton.tintColor = .systemOrange
                self.highlightButton.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            } else {
                self.highlightButton.transform = .identity
                self.applyHighlightButtonAppearance()
            }
        }
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
    
    // MARK: - Content Updates
    func updateHighlightCount(_ count: Int) {
        highlightCount = max(0, count)
        guard !isHighlightModeActive else { return }
        UIView.animate(withDuration: 0.2) {
            self.applyHighlightButtonAppearance()
        }
    }

    func updateBookmarkCount(_ count: Int) {
        bookmarkCount = max(0, count)
        UIView.animate(withDuration: 0.2) {
            self.applyBookmarkButtonAppearance()
        }
    }

    private func applyHighlightButtonAppearance() {
        if highlightCount > 0 {
            highlightButton.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.25)
            highlightButton.tintColor = UIColor.systemOrange
            highlightBadge.isHidden = false
            highlightBadge.text = highlightCount > 9 ? "9+" : "\(highlightCount)"
        } else {
            highlightButton.backgroundColor = UIColor.label.withAlphaComponent(0.1)
            highlightButton.tintColor = .label
            highlightBadge.isHidden = true
        }
    }

    private func applyBookmarkButtonAppearance() {
        if bookmarkCount > 0 {
            bookmarksButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.25)
            bookmarksButton.tintColor = UIColor.systemBlue
            bookmarkBadge.isHidden = false
            bookmarkBadge.text = bookmarkCount > 9 ? "9+" : "\(bookmarkCount)"
        } else {
            bookmarksButton.backgroundColor = UIColor.label.withAlphaComponent(0.1)
            bookmarksButton.tintColor = .label
            bookmarkBadge.isHidden = true
        }
    }
    
    // MARK: - Theme Updates
    func updateTheme(_ theme: ReadingTheme) {
        UIView.animate(withDuration: 0.3) {
            let buttonColor = theme.isDarkMode ? UIColor.white.withAlphaComponent(0.12) : UIColor.black.withAlphaComponent(0.1)
            let borderColor = theme.isDarkMode ? UIColor.white.withAlphaComponent(0.25) : UIColor.black.withAlphaComponent(0.2)
            
            [self.libraryButton, self.highlightButton, self.bookmarksButton, 
             self.moreButton].forEach { button in
                button.backgroundColor = buttonColor
                button.layer.borderColor = borderColor.cgColor
            }
        }
    }
}
