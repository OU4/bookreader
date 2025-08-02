//
//  BookmarkSidebarView.swift
//  BookReader
//
//  Enhanced bookmark sidebar with quick access and visual features
//

import UIKit

// MARK: - Bookmark Sidebar View
class BookmarkSidebarView: UIView {
    
    weak var delegate: BookmarkSidebarDelegate?
    
    private var bookmarks: [BookmarkItem] = []
    private var bookId: String = ""
    
    // UI Components
    private let blurBackground: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemChromeMaterial)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: -2, height: 0)
        view.layer.shadowRadius = 10
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Bookmarks"
        label.font = .boldSystemFont(ofSize: 20)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let bookmarkCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .tertiaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let segmentedControl: UISegmentedControl = {
        let items = ["All", "Important", "Questions", "Favorites"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No bookmarks yet"
        label.textColor = .tertiaryLabel
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let addBookmarkButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.layer.shadowColor = UIColor.systemBlue.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.3
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Pan gesture for swipe to close
    private var panGesture: UIPanGestureRecognizer!
    private var originalX: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupGestures()
    }
    
    private func setupUI() {
        alpha = 0
        
        addSubview(blurBackground)
        addSubview(containerView)
        
        containerView.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(bookmarkCountLabel)
        headerView.addSubview(closeButton)
        
        containerView.addSubview(segmentedControl)
        containerView.addSubview(tableView)
        containerView.addSubview(emptyStateLabel)
        containerView.addSubview(addBookmarkButton)
        
        NSLayoutConstraint.activate([
            blurBackground.topAnchor.constraint(equalTo: topAnchor),
            blurBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurBackground.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 320),
            
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: headerView.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            bookmarkCountLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bookmarkCountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -80),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            
            addBookmarkButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            addBookmarkButton.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addBookmarkButton.widthAnchor.constraint(equalToConstant: 50),
            addBookmarkButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(BookmarkSidebarCell.self, forCellReuseIdentifier: "BookmarkSidebarCell")
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addBookmarkButton.addTarget(self, action: #selector(addBookmarkTapped), for: .touchUpInside)
        segmentedControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        blurBackground.addGestureRecognizer(tapGesture)
    }
    
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        containerView.addGestureRecognizer(panGesture)
    }
    
    // MARK: - Public Methods
    
    func show(bookId: String, animated: Bool = true) {
        self.bookId = bookId
        loadBookmarks()
        
        if animated {
            containerView.transform = CGAffineTransform(translationX: 320, y: 0)
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.alpha = 1
                self.containerView.transform = .identity
            }
        } else {
            alpha = 1
        }
    }
    
    func hide(animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.alpha = 0
                self.containerView.transform = CGAffineTransform(translationX: 320, y: 0)
            } completion: { _ in
                self.removeFromSuperview()
            }
        } else {
            removeFromSuperview()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadBookmarks() {
        let allBookmarks = BookmarkManager.shared.getBookmarks(for: bookId)
        
        switch segmentedControl.selectedSegmentIndex {
        case 1:
            bookmarks = allBookmarks.filter { $0.type == .important }
        case 2:
            bookmarks = allBookmarks.filter { $0.type == .question }
        case 3:
            bookmarks = allBookmarks.filter { $0.type == .favorite }
        default:
            bookmarks = allBookmarks
        }
        
        bookmarkCountLabel.text = "\(bookmarks.count) bookmark\(bookmarks.count == 1 ? "" : "s")"
        emptyStateLabel.isHidden = !bookmarks.isEmpty
        tableView.reloadData()
    }
    
    @objc private func closeTapped() {
        hide()
    }
    
    @objc private func backgroundTapped() {
        hide()
    }
    
    @objc private func addBookmarkTapped() {
        delegate?.bookmarkSidebarDidRequestNewBookmark(self)
    }
    
    @objc private func filterChanged() {
        loadBookmarks()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .began:
            originalX = containerView.transform.tx
        case .changed:
            let newX = max(0, translation.x)
            containerView.transform = CGAffineTransform(translationX: newX, y: 0)
            let progress = 1 - (newX / 320)
            alpha = progress
        case .ended:
            if velocity.x > 500 || translation.x > 160 {
                hide()
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                    self.containerView.transform = .identity
                    self.alpha = 1
                }
            }
        default:
            break
        }
    }
}

// MARK: - TableView DataSource & Delegate
extension BookmarkSidebarView: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookmarkSidebarCell", for: indexPath) as! BookmarkSidebarCell
        cell.configure(with: bookmarks[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let bookmark = bookmarks[indexPath.row]
        delegate?.bookmarkSidebar(self, didSelectBookmark: bookmark)
        hide()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let bookmark = bookmarks[indexPath.row]
            BookmarkManager.shared.deleteBookmark(bookmark)
            loadBookmarks()
        }
    }
}

// MARK: - Bookmark Sidebar Cell
class BookmarkSidebarCell: UITableViewCell {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let typeIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressBar: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var progressBarWidthConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(typeIcon)
        containerView.addSubview(titleLabel)
        containerView.addSubview(pageLabel)
        containerView.addSubview(progressBar)
        
        progressBarWidthConstraint = progressBar.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            typeIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            typeIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            typeIcon.widthAnchor.constraint(equalToConstant: 24),
            typeIcon.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: typeIcon.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            pageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            
            progressBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            progressBarWidthConstraint
        ])
    }
    
    func configure(with bookmark: BookmarkItem) {
        titleLabel.text = bookmark.title
        
        if let pageNumber = bookmark.pageNumber {
            pageLabel.text = "Page \(pageNumber)"
        } else {
            pageLabel.text = "\(Int(bookmark.readingProgress * 100))% through"
        }
        
        typeIcon.image = UIImage(systemName: bookmark.type.icon)
        typeIcon.tintColor = bookmark.type.color
        
        // Update progress bar
        let progress = CGFloat(bookmark.readingProgress)
        progressBarWidthConstraint.constant = (contentView.bounds.width - 32) * progress
        progressBar.backgroundColor = bookmark.type.color.withAlphaComponent(0.3)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        UIView.animate(withDuration: 0.2) {
            self.containerView.transform = highlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            self.containerView.backgroundColor = highlighted ? .tertiarySystemBackground : .secondarySystemBackground
        }
    }
}

// MARK: - Delegate Protocol
protocol BookmarkSidebarDelegate: AnyObject {
    func bookmarkSidebar(_ sidebar: BookmarkSidebarView, didSelectBookmark bookmark: BookmarkItem)
    func bookmarkSidebarDidRequestNewBookmark(_ sidebar: BookmarkSidebarView)
}