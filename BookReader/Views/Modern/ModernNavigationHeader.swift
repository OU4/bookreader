//
//  ModernNavigationHeader.swift
//  BookReader
//
//  Beautiful navigation header with glassmorphism
//

import UIKit

protocol ModernNavigationHeaderDelegate: AnyObject {
    func didTapBack()
    func didTapBookmark()
}

class ModernNavigationHeader: UIView {
    
    weak var delegate: ModernNavigationHeaderDelegate?
    
    // MARK: - UI Components
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.backgroundColor = UIColor.label.withAlphaComponent(0.08)
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var bookTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .label
        label.textAlignment = .center
        label.text = "Book Reader"
        return label
    }()
    
    private lazy var authorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    private lazy var bookmarkButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "bookmark", withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.backgroundColor = UIColor.label.withAlphaComponent(0.08)
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(bookmarkTapped), for: .touchUpInside)
        return button
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
        
        titleStackView.addArrangedSubview(bookTitleLabel)
        titleStackView.addArrangedSubview(authorLabel)
        
        blurView.contentView.addSubview(backButton)
        blurView.contentView.addSubview(titleStackView)
        blurView.contentView.addSubview(bookmarkButton)
        
        NSLayoutConstraint.activate([
            // Blur view
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Back button
            backButton.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Title stack
            titleStackView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            titleStackView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            titleStackView.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 16),
            titleStackView.trailingAnchor.constraint(lessThanOrEqualTo: bookmarkButton.leadingAnchor, constant: -16),
            
            // Bookmark button
            bookmarkButton.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -16),
            bookmarkButton.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            bookmarkButton.widthAnchor.constraint(equalToConstant: 32),
            bookmarkButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.1
    }
    
    // MARK: - Actions
    @objc private func backTapped() {
        animateButton(backButton)
        delegate?.didTapBack()
    }
    
    @objc private func bookmarkTapped() {
        animateButton(bookmarkButton)
        delegate?.didTapBookmark()
    }
    
    private func animateButton(_ button: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            }
        }
    }
    
    // MARK: - Public Methods
    func setBookTitle(_ title: String, author: String) {
        UIView.transition(with: bookTitleLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.bookTitleLabel.text = title
        }
        
        UIView.transition(with: authorLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.authorLabel.text = author
            self.authorLabel.isHidden = author.isEmpty
        }
    }
    
    func updateTheme(_ theme: ReadingTheme) {
        UIView.animate(withDuration: 0.3) {
            let buttonColor = theme.isDarkMode ? UIColor.white.withAlphaComponent(0.1) : UIColor.black.withAlphaComponent(0.08)
            
            self.backButton.backgroundColor = buttonColor
            self.bookmarkButton.backgroundColor = buttonColor
        }
    }
}