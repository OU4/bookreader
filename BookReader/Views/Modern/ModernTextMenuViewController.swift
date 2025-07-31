//
//  ModernTextMenuViewController.swift
//  BookReader
//
//  Beautiful text selection menu
//

import UIKit

protocol ModernTextMenuDelegate: AnyObject {
    func didSelectHighlight(color: Highlight.HighlightColor)
    func didSelectDefinition()
    func didSelectTranslate()
    func didSelectNote()
}

class ModernTextMenuViewController: UIViewController {
    
    weak var delegate: ModernTextMenuDelegate?
    private let selectedText: String
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.15
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Text Actions"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var selectedTextLabel: UILabel = {
        let label = UILabel()
        label.text = "\"\(selectedText)\""
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var actionsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var highlightSection = createHighlightSection()
    
    // MARK: - Initialization
    init(selectedText: String) {
        self.selectedText = selectedText
        super.init(nibName: nil, bundle: nil)
        
        modalPresentationStyle = .popover
        preferredContentSize = CGSize(width: 280, height: 320)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        addAnimations()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .clear
        view.addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(selectedTextLabel)
        containerView.addSubview(actionsStackView)
        
        // Add action sections
        actionsStackView.addArrangedSubview(highlightSection)
        actionsStackView.addArrangedSubview(createActionButtons())
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Selected text
            selectedTextLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            selectedTextLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            selectedTextLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Actions
            actionsStackView.topAnchor.constraint(equalTo: selectedTextLabel.bottomAnchor, constant: 20),
            actionsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            actionsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            actionsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createHighlightSection() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemGray6
        container.layer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = "🎨 Highlight"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let colorsStackView = UIStackView()
        colorsStackView.axis = .horizontal
        colorsStackView.distribution = .fillEqually
        colorsStackView.spacing = 8
        colorsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add color buttons
        for color in Highlight.HighlightColor.allCases {
            let colorButton = createColorButton(color: color)
            colorsStackView.addArrangedSubview(colorButton)
        }
        
        container.addSubview(titleLabel)
        container.addSubview(colorsStackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            
            colorsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            colorsStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            colorsStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            colorsStackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            colorsStackView.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return container
    }
    
    private func createColorButton(color: Highlight.HighlightColor) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = color.uiColor
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.cgColor
        
        button.addTarget(self, action: #selector(colorButtonTapped(_:)), for: .touchUpInside)
        button.tag = Highlight.HighlightColor.allCases.firstIndex(of: color) ?? 0
        
        // Add shadow
        button.layer.shadowColor = color.uiColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.3
        
        return button
    }
    
    private func createActionButtons() -> UIView {
        let container = UIView()
        
        let actions = [
            ("📖", "Define", #selector(defineTapped)),
            ("🌐", "Translate", #selector(translateTapped)),
            ("📝", "Add Note", #selector(noteTapped)),
            ("📋", "Copy", #selector(copyTapped))
        ]
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (icon, title, action) in actions {
            let button = createActionButton(icon: icon, title: title, action: action)
            stackView.addArrangedSubview(button)
        }
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createActionButton(icon: String, title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: action, for: .touchUpInside)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 18)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.textColor = .systemBlue
        
        stackView.addArrangedSubview(iconLabel)
        stackView.addArrangedSubview(titleLabel)
        
        button.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 44),
            stackView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }
    
    private func addAnimations() {
        // Entrance animation
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }
    }
    
    // MARK: - Actions
    @objc private func colorButtonTapped(_ sender: UIButton) {
        let colors = Highlight.HighlightColor.allCases
        let selectedColor = colors[sender.tag]
        
        // Animate button
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = .identity
            }
        }
        
        delegate?.didSelectHighlight(color: selectedColor)
        dismiss(animated: true)
    }
    
    @objc private func defineTapped() {
        animateButtonAndDismiss()
        delegate?.didSelectDefinition()
    }
    
    @objc private func translateTapped() {
        animateButtonAndDismiss()
        delegate?.didSelectTranslate()
    }
    
    @objc private func noteTapped() {
        animateButtonAndDismiss()
        delegate?.didSelectNote()
    }
    
    @objc private func copyTapped() {
        UIPasteboard.general.string = selectedText
        
        // Show success feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        animateButtonAndDismiss()
    }
    
    private func animateButtonAndDismiss() {
        UIView.animate(withDuration: 0.2, animations: {
            self.containerView.alpha = 0.8
            self.containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            self.dismiss(animated: true)
        }
    }
}