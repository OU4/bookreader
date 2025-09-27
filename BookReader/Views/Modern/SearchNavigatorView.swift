//
//  SearchNavigatorView.swift
//  BookReader
//
//  Inline control to move through search results without leaving the reader
//

import UIKit

protocol SearchNavigatorViewDelegate: AnyObject {
    func searchNavigatorDidTapNext(_ navigator: SearchNavigatorView)
    func searchNavigatorDidTapPrevious(_ navigator: SearchNavigatorView)
    func searchNavigatorDidTapClose(_ navigator: SearchNavigatorView)
}

final class SearchNavigatorView: UIView {
    weak var delegate: SearchNavigatorViewDelegate?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .label
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let counterLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let previousButton = SearchNavigatorView.makeButton(systemImage: "chevron.up")
    private let nextButton = SearchNavigatorView.makeButton(systemImage: "chevron.down")
    private let closeButton = SearchNavigatorView.makeButton(systemImage: "xmark")
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func update(term: String, currentIndex: Int, total: Int) {
        titleLabel.text = "“\(term)”"
        if total > 0 {
            counterLabel.text = "\(currentIndex) of \(total)"
        } else {
            counterLabel.text = "No results"
        }
        previousButton.isEnabled = total > 0
        nextButton.isEnabled = total > 0
    }
    
    private func setup() {
        layer.cornerRadius = 14
        layer.masksToBounds = true
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        layer.borderColor = UIColor.label.withAlphaComponent(0.12).cgColor
        layer.borderWidth = 0.5
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, counterLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        addSubview(previousButton)
        addSubview(nextButton)
        addSubview(closeButton)
        
        previousButton.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            previousButton.leadingAnchor.constraint(equalTo: stack.trailingAnchor, constant: 12),
            previousButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 30),
            previousButton.heightAnchor.constraint(equalToConstant: 30),
            
            nextButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor, constant: 8),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalTo: previousButton.widthAnchor),
            nextButton.heightAnchor.constraint(equalTo: previousButton.heightAnchor),
            
            closeButton.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalTo: previousButton.widthAnchor),
            closeButton.heightAnchor.constraint(equalTo: previousButton.heightAnchor)
        ])
    }
    
    private static func makeButton(systemImage: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemImage), for: .normal)
        button.tintColor = .label
        button.backgroundColor = UIColor.secondarySystemBackground
        button.layer.cornerRadius = 15
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = systemImage
        return button
    }
    
    @objc private func previousTapped() {
        delegate?.searchNavigatorDidTapPrevious(self)
    }
    
    @objc private func nextTapped() {
        delegate?.searchNavigatorDidTapNext(self)
    }
    
    @objc private func closeTapped() {
        delegate?.searchNavigatorDidTapClose(self)
    }
}
