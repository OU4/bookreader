//
//  BookCell.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//

import UIKit

class BookCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = .systemGray6
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.translatesAutoresizingMaskIntoConstraints = false
        return pv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.75),
            
            progressView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
    }
    
    func configure(with book: Book) {
        imageView.image = book.coverImage ?? generatePlaceholderCover(for: book.type)
        titleLabel.text = book.title
        progressView.progress = book.lastReadPosition
    }
    
    private func generatePlaceholderCover(for type: Book.BookType) -> UIImage? {
        let size = CGSize(width: 200, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        UIColor.systemGray5.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        let iconName: String
        switch type {
        case .pdf: iconName = "doc.text"
        case .text: iconName = "doc.plaintext"
        case .epub: iconName = "book"
        case .image: iconName = "photo"
        }
        
        if let icon = UIImage(systemName: iconName) {
            let iconSize = CGSize(width: 80, height: 80)
            let iconRect = CGRect(
                x: (size.width - iconSize.width) / 2,
                y: (size.height - iconSize.height) / 2,
                width: iconSize.width,
                height: iconSize.height
            )
            icon.withTintColor(.systemGray2).draw(in: iconRect)
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}
