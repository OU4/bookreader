//
//  NoteCell.swift
//  BookReader
//
//  Custom cell for displaying notes
//

import UIKit

class NoteCell: UITableViewCell {
    
    // MARK: - UI Components
    private let noteIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "note.text")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let tagsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
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
        contentView.addSubview(noteIcon)
        contentView.addSubview(titleLabel)
        contentView.addSubview(contentLabel)
        contentView.addSubview(tagsStackView)
        contentView.addSubview(dateLabel)
        
        NSLayoutConstraint.activate([
            noteIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            noteIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            noteIcon.widthAnchor.constraint(equalToConstant: 20),
            noteIcon.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: noteIcon.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            
            contentLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            tagsStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            tagsStackView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            tagsStackView.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 8),
            
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            dateLabel.topAnchor.constraint(equalTo: tagsStackView.bottomAnchor, constant: 8),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Configuration
    func configure(with note: Note) {
        titleLabel.text = note.title
        contentLabel.text = note.content
        dateLabel.text = DateFormatter.readable.string(from: note.dateCreated)
        
        // Clear existing tags
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add tag labels
        for tag in note.tags.prefix(3) { // Show max 3 tags
            let tagLabel = createTagLabel(text: tag)
            tagsStackView.addArrangedSubview(tagLabel)
        }
        
        if note.tags.count > 3 {
            let moreLabel = createTagLabel(text: "+\(note.tags.count - 3) more")
            moreLabel.backgroundColor = .systemGray5
            tagsStackView.addArrangedSubview(moreLabel)
        }
        
        tagsStackView.isHidden = note.tags.isEmpty
    }
    
    private func createTagLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = "#\(text)"
        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = .systemBlue
        label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Add padding
        label.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        
        return label
    }
}