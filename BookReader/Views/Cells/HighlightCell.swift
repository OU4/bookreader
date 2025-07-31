//
//  HighlightCell.swift
//  BookReader
//
//  Custom cell for displaying highlights
//

import UIKit

class HighlightCell: UITableViewCell {
    
    // MARK: - UI Components
    private let colorIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let highlightTextLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let noteLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(colorIndicator)
        contentView.addSubview(highlightTextLabel)
        contentView.addSubview(noteLabel)
        contentView.addSubview(dateLabel)
        
        NSLayoutConstraint.activate([
            colorIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            colorIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            colorIndicator.widthAnchor.constraint(equalToConstant: 16),
            colorIndicator.heightAnchor.constraint(equalToConstant: 16),
            
            highlightTextLabel.leadingAnchor.constraint(equalTo: colorIndicator.trailingAnchor, constant: 12),
            highlightTextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            highlightTextLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            
            noteLabel.leadingAnchor.constraint(equalTo: highlightTextLabel.leadingAnchor),
            noteLabel.trailingAnchor.constraint(equalTo: highlightTextLabel.trailingAnchor),
            noteLabel.topAnchor.constraint(equalTo: highlightTextLabel.bottomAnchor, constant: 8),
            
            dateLabel.leadingAnchor.constraint(equalTo: highlightTextLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: highlightTextLabel.trailingAnchor),
            dateLabel.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 8),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Configuration
    func configure(with highlight: Highlight) {
        colorIndicator.backgroundColor = highlight.color.uiColor
        highlightTextLabel.text = "\"\(highlight.text)\""
        
        if let note = highlight.note, !note.isEmpty {
            noteLabel.text = "Note: \(note)"
            noteLabel.isHidden = false
        } else {
            noteLabel.isHidden = true
        }
        
        dateLabel.text = DateFormatter.readable.string(from: highlight.dateCreated)
    }
}