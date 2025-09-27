//
//  EnhancedBookCell.swift
//  BookReader
//
//  Enhanced book cell with reading progress and stats
//

import UIKit

class EnhancedBookCell: UICollectionViewCell {
    
    // MARK: - UI Components
    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = .label
        label.numberOfLines = 2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.tintColor = .systemBlue
        progressView.translatesAutoresizingMaskIntoConstraints = false
        return progressView
    }()
    
    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let highlightsIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "highlighter")
        imageView.tintColor = .systemYellow
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let notesIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "note.text")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let bookmarkIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "bookmark.fill")
        imageView.tintColor = .systemRed
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 4
        contentView.layer.shadowOpacity = 0.1
        
        // Add icons to stack view
        statsStackView.addArrangedSubview(highlightsIcon)
        statsStackView.addArrangedSubview(notesIcon)
        statsStackView.addArrangedSubview(bookmarkIcon)
        
        contentView.addSubview(coverImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(authorLabel)
        contentView.addSubview(progressView)
        contentView.addSubview(progressLabel)
        contentView.addSubview(statsStackView)
        
        NSLayoutConstraint.activate([
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            coverImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            coverImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            coverImageView.heightAnchor.constraint(equalTo: coverImageView.widthAnchor, multiplier: 1.4),
            
            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            
            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            authorLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            authorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            
            progressView.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 2),
            progressLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            progressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            
            statsStackView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 8),
            statsStackView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            statsStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),
            
            highlightsIcon.widthAnchor.constraint(equalToConstant: 16),
            highlightsIcon.heightAnchor.constraint(equalToConstant: 16),
            
            notesIcon.widthAnchor.constraint(equalToConstant: 16),
            notesIcon.heightAnchor.constraint(equalToConstant: 16),
            
            bookmarkIcon.widthAnchor.constraint(equalToConstant: 16),
            bookmarkIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with book: Book) {
        titleLabel.text = book.title
        authorLabel.text = book.author
        
        // Set cover image
        if let coverImage = book.coverImage {
            coverImageView.image = coverImage
        } else {
            coverImageView.image = generatePlaceholderCover(for: book)
        }
        
        // Set progress
        progressView.progress = book.lastReadPosition
        
        if book.lastReadPosition > 0 {
            progressLabel.text = "\(Int(book.lastReadPosition))% complete"
        } else {
            progressLabel.text = "Not started"
        }
        
        // Show/hide icons based on content
        highlightsIcon.isHidden = book.highlights.isEmpty
        notesIcon.isHidden = book.notes.isEmpty
        bookmarkIcon.isHidden = book.bookmarks.isEmpty
        
        // If all icons are hidden, hide the stack view
        statsStackView.isHidden = book.highlights.isEmpty && book.notes.isEmpty && book.bookmarks.isEmpty
    }
    
    private func generatePlaceholderCover(for book: Book) -> UIImage? {
        let size = CGSize(width: 120, height: 160)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        // Background gradient
        let colors = [UIColor.systemBlue, UIColor.systemPurple, UIColor.systemGreen, UIColor.systemOrange]
        let color = colors[abs(book.title.hashValue) % colors.count]
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // Book icon
        if let icon = UIImage(systemName: "book.closed") {
            let iconSize = CGSize(width: 40, height: 40)
            let iconRect = CGRect(
                x: (size.width - iconSize.width) / 2,
                y: (size.height - iconSize.height) / 2,
                width: iconSize.width,
                height: iconSize.height
            )
            icon.withTintColor(.white).draw(in: iconRect)
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.image = nil
        titleLabel.text = nil
        authorLabel.text = nil
        progressView.progress = 0
        progressLabel.text = nil
        highlightsIcon.isHidden = true
        notesIcon.isHidden = true
        bookmarkIcon.isHidden = true
        statsStackView.isHidden = true
    }
}