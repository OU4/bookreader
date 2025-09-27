//
//  ModernBookCell.swift
//  BookReader
//
//  Beautiful book card with glassmorphism and animations
//

import UIKit
import PDFKit

enum BookCellStyle {
    case compact
    case detailed
}

protocol ModernBookCellDelegate: AnyObject {
    func didTapDeleteButton(for book: Book, in cell: ModernBookCell)
}

class ModernBookCell: UICollectionViewCell {
    
    // MARK: - Properties
    private var book: Book?
    private var style: BookCellStyle = .detailed
    private var currentLoadingTask: DispatchWorkItem?
    
    // Static cache for PDF previews
    private static let previewCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50 // Limit cache size
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB limit
        return cache
    }()
    
    // MARK: - UI Components
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var gradientOverlay: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.3).cgColor
        ]
        gradient.locations = [0.6, 1.0]
        gradient.cornerRadius = 16
        return gradient
    }()
    
    private lazy var coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.backgroundColor = UIColor.systemGray5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var placeholderBookIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .light)
        imageView.image = UIImage(systemName: "book.closed", withConfiguration: config)
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .label
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var authorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var progressContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var progressBar: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var statusBadge: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var recentBadge: UIView = {
        let view = UIView()
        view.backgroundColor = .systemOrange
        view.layer.cornerRadius = 6
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .systemRed
        button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        button.layer.cornerRadius = 15
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Hidden by default, show on hover/long press
        return button
    }()
    
    private var progressWidthConstraint: NSLayoutConstraint!
    
    // Delegate for delete action
    weak var delegate: ModernBookCellDelegate?
    
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
        
        contentView.addSubview(containerView)
        containerView.addSubview(coverImageView)
        containerView.addSubview(placeholderBookIcon)
        containerView.addSubview(titleLabel)
        containerView.addSubview(authorLabel)
        containerView.addSubview(progressContainer)
        containerView.addSubview(progressLabel)
        containerView.addSubview(statusBadge)
        containerView.addSubview(recentBadge)
        containerView.addSubview(deleteButton)
        
        progressContainer.addSubview(progressBar)
        statusBadge.addSubview(statusLabel)
        
        // Add gradient overlay to cover image
        coverImageView.layer.addSublayer(gradientOverlay)
        
        setupConstraints()
        addInteractionEffects()
    }
    
    private func setupConstraints() {
        progressWidthConstraint = progressBar.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Cover image
            coverImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.6),
            
            // Placeholder icon
            placeholderBookIcon.centerXAnchor.constraint(equalTo: coverImageView.centerXAnchor),
            placeholderBookIcon.centerYAnchor.constraint(equalTo: coverImageView.centerYAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // Author
            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // Progress container
            progressContainer.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 8),
            progressContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            progressContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            progressContainer.heightAnchor.constraint(equalToConstant: 4),
            
            // Progress bar
            progressBar.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            progressWidthConstraint,
            
            // Progress label
            progressLabel.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: 4),
            progressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            progressLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8),
            
            // Status badge
            statusBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            statusBadge.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            statusBadge.heightAnchor.constraint(equalToConstant: 16),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
            
            statusLabel.centerXAnchor.constraint(equalTo: statusBadge.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: 6),
            statusLabel.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: -6),
            
            // Recent badge
            recentBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            recentBadge.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            recentBadge.widthAnchor.constraint(equalToConstant: 12),
            recentBadge.heightAnchor.constraint(equalToConstant: 12),
            
            // Delete button
            deleteButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            deleteButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            deleteButton.widthAnchor.constraint(equalToConstant: 30),
            deleteButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func addInteractionEffects() {
        let tapGesture = UITapGestureRecognizer()
        tapGesture.cancelsTouchesInView = false
        containerView.addGestureRecognizer(tapGesture)
        
        // Add hover effect for larger screens
        let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(hoverGestureChanged(_:)))
        containerView.addGestureRecognizer(hoverGesture)
        
        // Add long press gesture for mobile devices
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureChanged(_:)))
        longPressGesture.minimumPressDuration = 0.5
        containerView.addGestureRecognizer(longPressGesture)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientOverlay.frame = coverImageView.bounds
    }
    
    // MARK: - Configuration
    func configure(with book: Book, style: BookCellStyle = .detailed) {
        self.book = book
        self.style = style
        
        
        titleLabel.text = book.title
        authorLabel.text = book.author
        
        // Configure based on style
        if style == .compact {
            titleLabel.font = UIFont.boldSystemFont(ofSize: 14)
            authorLabel.font = UIFont.systemFont(ofSize: 12)
        } else {
            titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
            authorLabel.font = UIFont.systemFont(ofSize: 14)
        }
        
        // Load cover image
        if let coverImage = book.coverImage {
            coverImageView.image = coverImage
            placeholderBookIcon.isHidden = true
        } else {
            loadCoverImage(from: nil)
        }
        
        // Update progress
        updateProgress(book.lastReadPosition)
        
        // Update status
        updateStatus(book.readingStats)
        
        // Show recent badge if read recently
        showRecentBadgeIfNeeded(book.readingStats.lastReadDate)
        
        // Add entrance animation
        addEntranceAnimation()
    }
    
    private func loadCoverImage(from path: String?) {
        // Try to generate preview for PDF
        if let book = book, book.type == .pdf {
            generatePDFPreview(from: book.filePath)
        } else {
            coverImageView.image = nil
            placeholderBookIcon.isHidden = false
            
            // Generate gradient background
            let colors = generateBookColors()
            let gradient = CAGradientLayer()
            gradient.colors = colors.map { $0.cgColor }
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            gradient.frame = coverImageView.bounds
            gradient.cornerRadius = 16
            
            coverImageView.layer.sublayers?.removeAll { $0 is CAGradientLayer }
            coverImageView.layer.insertSublayer(gradient, at: 0)
        }
    }
    
    private func generatePDFPreview(from filePath: String) {
        // Cancel any existing loading task
        currentLoadingTask?.cancel()
        
        // Store the current book ID to check later
        let currentBookId = book?.id
        
        // Check cache first
        let cacheKey = filePath as NSString
        if let cachedImage = ModernBookCell.previewCache.object(forKey: cacheKey) {
            self.coverImageView.image = cachedImage
            self.placeholderBookIcon.isHidden = true
            return
        }
        
        let loadingTask = DispatchWorkItem { [weak self] in
            guard let pdfDocument = PDFDocument(url: URL(fileURLWithPath: filePath)),
                  let firstPage = pdfDocument.page(at: 0) else {
                DispatchQueue.main.async {
                    // Check if this cell is still showing the same book
                    if self?.book?.id == currentBookId {
                        self?.loadCoverImage(from: nil)
                    }
                }
                return
            }
            
            let pageRect = firstPage.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
            
            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(CGRect(origin: .zero, size: scaledSize))
                
                context.cgContext.translateBy(x: 0, y: scaledSize.height)
                context.cgContext.scaleBy(x: scale, y: -scale)
                
                firstPage.draw(with: .mediaBox, to: context.cgContext)
            }
            
            DispatchQueue.main.async {
                // Only set the image if this cell is still showing the same book
                if self?.book?.id == currentBookId {
                    self?.coverImageView.image = image
                    self?.placeholderBookIcon.isHidden = true
                    
                    // Cache the image
                    ModernBookCell.previewCache.setObject(image, forKey: cacheKey)
                }
            }
        }
        
        currentLoadingTask = loadingTask
        DispatchQueue.global(qos: .background).async(execute: loadingTask)
    }
    
    private func generateBookColors() -> [UIColor] {
        guard let book = book else {
            return [.systemBlue, .systemPurple]
        }
        
        let hash = book.title.hash
        let colors: [[UIColor]] = [
            [.systemBlue, .systemPurple],
            [.systemGreen, .systemTeal],
            [.systemOrange, .systemRed],
            [.systemPink, .systemPurple],
            [.systemIndigo, .systemBlue],
            [.systemTeal, .systemGreen]
        ]
        
        return colors[abs(hash) % colors.count]
    }
    
    private func updateProgress(_ progress: Float) {
        let percentage = Int(progress * 100)
        progressLabel.text = "\(percentage)%"
        
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.progressWidthConstraint.constant = self.progressContainer.frame.width * CGFloat(progress)
            self.layoutIfNeeded()
        }
    }
    
    private func updateStatus(_ stats: ReadingStats) {
        if book?.lastReadPosition ?? 0 >= 1.0 {
            statusBadge.backgroundColor = .systemGreen
            statusLabel.text = "✓ DONE"
        } else if book?.lastReadPosition ?? 0 > 0 {
            statusBadge.backgroundColor = .systemOrange
            statusLabel.text = "READING"
        } else {
            statusBadge.backgroundColor = .systemGray
            statusLabel.text = "NEW"
        }
        
        statusBadge.isHidden = false
    }
    
    private func showRecentBadgeIfNeeded(_ lastReadDate: Date?) {
        guard let lastReadDate = lastReadDate else {
            recentBadge.isHidden = true
            return
        }
        
        let daysSinceRead = Calendar.current.dateComponents([.day], from: lastReadDate, to: Date()).day ?? 0
        recentBadge.isHidden = daysSinceRead > 3
    }
    
    private func addEntranceAnimation() {
        transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        alpha = 0.8
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.transform = .identity
            self.alpha = 1.0
        }
    }
    
    // MARK: - Interaction Effects
    @objc private func hoverGestureChanged(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            UIView.animate(withDuration: 0.2) {
                self.containerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.containerView.layer.shadowOpacity = 0.2
                self.containerView.layer.shadowRadius = 16
            }
            showDeleteButton()
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.2) {
                self.containerView.transform = .identity
                self.containerView.layer.shadowOpacity = 0.1
                self.containerView.layer.shadowRadius = 12
            }
            hideDeleteButton()
        default:
            break
        }
    }
    
    @objc private func deleteButtonTapped() {
        guard let book = book else { return }
        delegate?.didTapDeleteButton(for: book, in: self)
    }
    
    private func showDeleteButton() {
        deleteButton.isHidden = false
        UIView.animate(withDuration: 0.2, delay: 0.1, options: [.curveEaseOut]) {
            self.deleteButton.alpha = 1.0
            self.deleteButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        }
    }
    
    private func hideDeleteButton() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            self.deleteButton.alpha = 0.0
            self.deleteButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            self.deleteButton.isHidden = true
        }
    }
    
    @objc private func longPressGestureChanged(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            // Provide haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            showDeleteButton()
            
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.hideDeleteButton()
            }
            
        default:
            break
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.containerView.transform = .identity
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.1) {
            self.containerView.transform = .identity
        }
    }
    
    // MARK: - Reuse
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Cancel any ongoing image loading to prevent wrong images
        currentLoadingTask?.cancel()
        currentLoadingTask = nil
        
        // Reset book reference
        book = nil
        
        // Reset image
        coverImageView.image = nil
        coverImageView.layer.sublayers?.removeAll { $0 is CAGradientLayer }
        placeholderBookIcon.isHidden = false
        
        // Reset other UI elements
        recentBadge.isHidden = true
        statusBadge.isHidden = true
        progressWidthConstraint.constant = 0
    }
}