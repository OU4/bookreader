//
//  ModernSettingsPanel.swift
//  BookReader
//
//  Beautiful settings panel with glassmorphism
//

import UIKit

protocol ModernSettingsPanelDelegate: AnyObject {
    func didChangeTheme(_ theme: ReadingTheme)
    func didChangeFontSize(_ size: CGFloat)
}

class ModernSettingsPanel: UIView {
    
    weak var delegate: ModernSettingsPanelDelegate?
    
    // MARK: - Properties
    private var currentFontSize: CGFloat = 18
    
    // MARK: - UI Components
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: effect)
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Reading Settings"
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Theme Section
    private lazy var themeSection = createSection(title: "🎨 Themes", content: createThemeSelector())
    
    private lazy var themeSelector: UISegmentedControl = {
        let themes = ["Light", "Dark", "Sepia", "Night"]
        let control = UISegmentedControl(items: themes)
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
        return control
    }()
    
    // MARK: - Font Section
    private lazy var fontSection = createSection(title: "📝 Font", content: createFontControls())
    
    private lazy var fontSizeSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 12
        slider.maximumValue = 32
        slider.value = 18
        slider.tintColor = .systemBlue
        slider.addTarget(self, action: #selector(fontSizeChanged), for: .valueChanged)
        return slider
    }()
    
    private lazy var fontSizeLabel: UILabel = {
        let label = UILabel()
        label.text = "Size: 18pt"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        return label
    }()
    
    // MARK: - Quick Actions Section
    private lazy var quickActionsSection = createSection(title: "⚡ Quick Actions", content: createQuickActions())
    
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
        blurView.contentView.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        // Add sections
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(themeSection)
        contentStackView.addArrangedSubview(fontSection)
        contentStackView.addArrangedSubview(quickActionsSection)
        
        setupConstraints()
        addAnimationEffects()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Blur view
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            
            // Content stack
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }
    
    private func createSection(title: String, content: UIView) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.label.withAlphaComponent(0.05)
        container.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        content.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(content)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            content.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func createThemeSelector() -> UIView {
        let container = UIView()
        
        let themesData: [(ReadingTheme, String, UIColor)] = [
            (.light, "Light", .systemBackground),
            (.dark, "Dark", .black),
            (.sepia, "Sepia", UIColor(red: 0.96, green: 0.91, blue: 0.78, alpha: 1.0)),
            (.night, "Night", UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0))
        ]
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (index, (theme, name, color)) in themesData.enumerated() {
            let themeButton = createThemeButton(theme: theme, name: name, color: color, tag: index)
            stackView.addArrangedSubview(themeButton)
        }
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        return container
    }
    
    private func createThemeButton(theme: ReadingTheme, name: String, color: UIColor, tag: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = color
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.clear.cgColor
        button.tag = tag
        
        let label = UILabel()
        label.text = name
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = theme.textColor
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(label)
        button.addTarget(self, action: #selector(themeButtonTapped(_:)), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }
    
    private func createFontControls() -> UIView {
        let container = UIView()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(fontSizeLabel)
        stackView.addArrangedSubview(fontSizeSlider)
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createQuickActions() -> UIView {
        let container = UIView()
        
        let actions = [
            ("🔍", "Search", #selector(searchTapped)),
            ("📝", "Notes", #selector(notesTapped)),
            ("🎯", "Bookmark", #selector(bookmarkTapped)),
            ("📤", "Share", #selector(shareTapped))
        ]
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        for (icon, title, action) in actions {
            let button = createQuickActionButton(icon: icon, title: title, action: action)
            stackView.addArrangedSubview(button)
        }
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        return container
    }
    
    private func createQuickActionButton(icon: String, title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: action, for: .touchUpInside)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 20)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 10)
        titleLabel.textColor = .systemBlue
        
        stackView.addArrangedSubview(iconLabel)
        stackView.addArrangedSubview(titleLabel)
        
        button.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        return button
    }
    
    private func addAnimationEffects() {
        // Add subtle shadow
        layer.shadowColor = UIColor.black.cgColor
        let shadowOffset = CGSize(width: -2.0, height: 4.0)
        layer.shadowOffset = shadowOffset
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.15
    }
    
    // MARK: - Actions
    @objc private func themeChanged() {
        let themes: [ReadingTheme] = [.light, .dark, .sepia, .night]
        let selectedTheme = themes[themeSelector.selectedSegmentIndex]
        delegate?.didChangeTheme(selectedTheme)
    }
    
    @objc private func themeButtonTapped(_ sender: UIButton) {
        let themes: [ReadingTheme] = [.light, .dark, .sepia, .night]
        let selectedTheme = themes[sender.tag]
        
        // Update UI
        updateThemeSelection(sender.tag)
        
        // Animate selection
        UIView.animate(withDuration: 0.2) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                sender.transform = .identity
            }
        }
        
        delegate?.didChangeTheme(selectedTheme)
    }
    
    private func updateThemeSelection(_ selectedIndex: Int) {
        if let container = themeSection.subviews.last?.subviews.first as? UIStackView {
            for (index, button) in container.arrangedSubviews.enumerated() {
                if let btn = button as? UIButton {
                    btn.layer.borderColor = index == selectedIndex ? 
                        UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                }
            }
        }
    }
    
    @objc private func fontSizeChanged() {
        currentFontSize = CGFloat(fontSizeSlider.value)
        fontSizeLabel.text = "Size: \(Int(currentFontSize))pt"
        delegate?.didChangeFontSize(currentFontSize)
    }
    
    @objc private func searchTapped() {
        animateButton()
        // Implement search
    }
    
    @objc private func notesTapped() {
        animateButton()
        // Implement notes
    }
    
    @objc private func bookmarkTapped() {
        animateButton()
        // Implement bookmark
    }
    
    @objc private func shareTapped() {
        animateButton()
        // Implement share
    }
    
    private func animateButton() {
        // Add subtle animation feedback
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
    }
}
