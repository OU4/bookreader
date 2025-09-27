//
//  NotesPeekView.swift
//  BookReader
//
//  Small chip reminding users of saved notes/highlights on the current page.
//

import UIKit

protocol NotesPeekViewDelegate: AnyObject {
    func notesPeekViewDidTapOpen(_ view: NotesPeekView)
}

final class NotesPeekView: UIView {
    weak var delegate: NotesPeekViewDelegate?
    
    private let iconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "highlighter"))
        imageView.tintColor = .systemYellow
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let textLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Highlights here"
        return label
    }()
    
    private let openButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Open", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func update(highlights: Int, notes: Int) {
        if highlights == 0 && notes == 0 {
            isHidden = true
            return
        }
        isHidden = false
        var components: [String] = []
        if highlights > 0 {
            components.append("\(highlights) highlight\(highlights == 1 ? "" : "s")")
        }
        if notes > 0 {
            components.append("\(notes) note\(notes == 1 ? "" : "s")")
        }
        textLabel.text = components.joined(separator: " • ")
    }
    
    private func setup() {
        backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.95)
        layer.cornerRadius = 14
        layer.masksToBounds = true
        layer.borderColor = UIColor.label.withAlphaComponent(0.1).cgColor
        layer.borderWidth = 0.5
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
        
        addSubview(iconView)
        addSubview(textLabel)
        addSubview(openButton)
        
        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            textLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            openButton.leadingAnchor.constraint(equalTo: textLabel.trailingAnchor, constant: 12),
            openButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            openButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    @objc private func openTapped() {
        delegate?.notesPeekViewDidTapOpen(self)
    }
}
