//
//  ModernLibraryViewController.swift
//  BookReader
//
//  Stunning library interface with beautiful book cards
//

import UIKit
import Combine
import FirebaseAuth
import FirebaseStorage

class ModernLibraryViewController: UIViewController {
    
    // MARK: - Properties
    private var books: [Book] = []
    private var filteredBooks: [Book] = []
    private var currentSearchText = ""
    private var cancellables = Set<AnyCancellable>()
    
    // Debouncing for stats refresh
    private var statsRefreshWorkItem: DispatchWorkItem?
    
    // Sorting and filtering
    private var currentSortType: SortType = .recent
    private var currentFilterType: FilterType = .all
    
    // Loading indicator properties
    private var loadingIndicator: UIView?
    private var loadingLabel: UILabel?
    
    enum SortType {
        case title, author, recent, progress
    }
    
    enum FilterType {
        case all, reading, completed
    }
    
    // MARK: - UI Components
    private lazy var gradientBackgroundLayer: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.systemBackground.cgColor,
            UIColor.systemBlue.withAlphaComponent(0.03).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.03).cgColor,
            UIColor.systemBackground.cgColor
        ]
        gradient.locations = [0, 0.3, 0.7, 1]
        gradient.type = .axial
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        return gradient
    }()
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var headerBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        view.layer.cornerRadius = 24
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 16
        view.layer.shadowOpacity = 0.08
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var quickActionsButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "line.3.horizontal.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.layer.cornerRadius = 18
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showQuickActions), for: .touchUpInside)
        return button
    }()
    
    private lazy var profileButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "person.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .systemPurple
        button.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        button.layer.cornerRadius = 18
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(userMenuTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = getDynamicGreeting()
        label.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = getDynamicSubtitle()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var searchContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 6
        view.layer.shadowOpacity = 0.06
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.2).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var searchBar: UISearchBar = {
        let search = UISearchBar()
        search.placeholder = "Search your books..."
        search.searchBarStyle = .minimal
        search.backgroundColor = .clear
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false
        return search
    }()
    
    private lazy var statsView: LibraryStatsView = {
        let view = LibraryStatsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add tap gesture to show detailed stats
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showDetailedStats))
        view.addGestureRecognizer(tapGesture)
        view.isUserInteractionEnabled = true
        
        return view
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = createLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.delegate = self
        collection.dataSource = self
        collection.showsVerticalScrollIndicator = false
        collection.translatesAutoresizingMaskIntoConstraints = false
        
        // Register cells
        collection.register(ModernBookCell.self, forCellWithReuseIdentifier: "ModernBookCell")
        collection.register(ModernSectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "SectionHeader")
        
        return collection
    }()
    
    private lazy var emptyStateView: ModernEmptyStateView = {
        let view = ModernEmptyStateView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var addBookButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.systemBlue.cgColor
        button.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        button.layer.shadowRadius = 12
        button.layer.shadowOpacity = 0.3
        
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        button.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.addTarget(self, action: #selector(addBookTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
        
        // Force initialize UnifiedFirebaseStorage
        _ = UnifiedFirebaseStorage.shared
        
        loadBooks()
        addAnimations()
        
        // Verify collection view setup
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshStats()
        animateHeaderEntrance()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientBackgroundLayer.frame = view.bounds
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.layer.insertSublayer(gradientBackgroundLayer, at: 0)
        
        // Add subviews
        view.addSubview(headerView)
        view.addSubview(searchContainer)
        view.addSubview(statsView)
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        view.addSubview(addBookButton)
        
        headerView.addSubview(headerBackgroundView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        headerView.addSubview(quickActionsButton)
        headerView.addSubview(profileButton)
        searchContainer.addSubview(searchBar)
        
        setupConstraints()
        setupNavigationBarAppearance()
        setupUserMenu()
    }
    
    private func setupUserMenu() {
        // Add user profile button
        let userButton = UIButton(type: .system)
        userButton.setImage(UIImage(systemName: "person.circle.fill"), for: .normal)
        userButton.tintColor = .label
        userButton.addTarget(self, action: #selector(showUserMenu), for: .touchUpInside)
        userButton.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(userButton)
        
        NSLayoutConstraint.activate([
            userButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            userButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            userButton.widthAnchor.constraint(equalToConstant: 40),
            userButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Header background
            headerBackgroundView.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerBackgroundView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerBackgroundView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            headerBackgroundView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            // Title with padding
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: quickActionsButton.leadingAnchor, constant: -12),
            
            // Quick actions button
            quickActionsButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            quickActionsButton.trailingAnchor.constraint(equalTo: profileButton.leadingAnchor, constant: -8),
            quickActionsButton.widthAnchor.constraint(equalToConstant: 36),
            quickActionsButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Profile button
            profileButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            profileButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            profileButton.widthAnchor.constraint(equalToConstant: 36),
            profileButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Subtitle with proper spacing
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            // Search
            searchContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: 52),
            
            searchBar.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -8),
            searchBar.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            
            // Stats
            statsView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 16),
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // Collection view
            collectionView.topAnchor.constraint(equalTo: statsView.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Empty state
            emptyStateView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor, constant: -40),
            
            // Add button
            addBookButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            addBookButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            addBookButton.widthAnchor.constraint(equalToConstant: 56),
            addBookButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupObservers() {
        // Observe changes to UnifiedFirebaseStorage books
        UnifiedFirebaseStorage.shared.$books
            .receive(on: DispatchQueue.main)
            .sink { [weak self] books in
                self?.books = books
                self?.updateDynamicContent()
                self?.applyFiltersAndSort()
                self?.refreshStats()
            }
            .store(in: &cancellables)
        
        // Observe authentication state changes
        FirebaseManager.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                if user != nil {
                    self?.loadBooks()
                } else {
                    self?.books = []
                    self?.filteredBooks = []
                    self?.updateEmptyState()
                    self?.collectionView.reloadData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            
            // Recently Read Section (Horizontal Scroll)
            if sectionIndex == 0 {
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(140),
                    heightDimension: .absolute(200)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(140),
                    heightDimension: .absolute(200)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .continuous
                section.interGroupSpacing = 16
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 32, trailing: 20)
                
                // Header
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(44)
                )
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
                
                return section
            }
            
            // All Books Section (Grid)
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.5),
                heightDimension: .absolute(220)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8)
            
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(220)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
            
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
            
            // Header
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(44)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            
            return section
        }
        
        return layout
    }
    
    private func addAnimations() {
        // Entrance animations
        headerView.alpha = 0
        headerView.transform = CGAffineTransform(translationX: -50, y: 0)
        
        searchContainer.alpha = 0
        searchContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        statsView.alpha = 0
        statsView.transform = CGAffineTransform(translationX: 0, y: 30)
        
        collectionView.alpha = 0
        collectionView.transform = CGAffineTransform(translationX: 0, y: 50)
        
        addBookButton.alpha = 0
        addBookButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        // Animate in sequence
        UIView.animate(withDuration: 0.8, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.headerView.alpha = 1
            self.headerView.transform = .identity
        }
        
        UIView.animate(withDuration: 0.6, delay: 0.2, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.searchContainer.alpha = 1
            self.searchContainer.transform = .identity
        }
        
        UIView.animate(withDuration: 0.7, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.statsView.alpha = 1
            self.statsView.transform = .identity
        }
        
        UIView.animate(withDuration: 0.8, delay: 0.4, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.collectionView.alpha = 1
            self.collectionView.transform = .identity
        }
        
        UIView.animate(withDuration: 0.6, delay: 0.8, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            self.addBookButton.alpha = 1
            self.addBookButton.transform = .identity
        }
    }
    
    private func animateHeaderEntrance() {
        // Prepare for animation
        headerBackgroundView.alpha = 0
        headerBackgroundView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: -20, y: 0)
        
        subtitleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: -20, y: 0)
        
        quickActionsButton.alpha = 0
        quickActionsButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        profileButton.alpha = 0
        profileButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Animate
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.headerBackgroundView.alpha = 1
            self.headerBackgroundView.transform = .identity
        }
        
        UIView.animate(withDuration: 0.6, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }
        
        UIView.animate(withDuration: 0.6, delay: 0.15, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.subtitleLabel.alpha = 1
            self.subtitleLabel.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.2, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.quickActionsButton.alpha = 1
            self.quickActionsButton.transform = .identity
        }
        
        UIView.animate(withDuration: 0.5, delay: 0.25, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            self.profileButton.alpha = 1
            self.profileButton.transform = .identity
        }
    }
    
    // MARK: - Data
    private func loadBooks() {
        
        // Check if user is authenticated
        guard FirebaseManager.shared.isAuthenticated else {
            books = BookStorage.shared.loadBooks()
            filteredBooks = books
            updateEmptyState()
            collectionView.reloadData()
            return
        }
        
        // Use Firebase storage
        books = UnifiedFirebaseStorage.shared.books
        for (index, book) in books.enumerated() {
        }
        filteredBooks = books
        updateEmptyState()
        collectionView.reloadData()
        
        // Observe changes
        UnifiedFirebaseStorage.shared.$books
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedBooks in
                self?.books = updatedBooks
                self?.filteredBooks = self?.currentSearchText.isEmpty ?? true ? updatedBooks : updatedBooks.filter { book in
                    book.title.localizedCaseInsensitiveContains(self?.currentSearchText ?? "") ||
                    book.author.localizedCaseInsensitiveContains(self?.currentSearchText ?? "")
                }
                self?.updateEmptyState()
                self?.collectionView.reloadData()
                self?.refreshStats()
            }
            .store(in: &cancellables)
    }
    
    private func refreshStats() {
        // Cancel previous work item to debounce multiple calls
        statsRefreshWorkItem?.cancel()
        
        // Create new work item
        statsRefreshWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            let totalBooks = self.books.count
            let booksCompleted = self.books.filter { $0.lastReadPosition >= 1.0 }.count
            
            // Get reading time from UnifiedReadingTracker
            let stats = UnifiedReadingTracker.shared.getTrackerStats()
            let totalReadingMinutes = Int(stats.totalReadingTime / 60)
            let currentStreak = self.calculateReadingStreak()
            
            DispatchQueue.main.async {
                self.statsView.updateStats(
                    totalBooks: totalBooks,
                    readingTime: totalReadingMinutes,
                    completedBooks: booksCompleted,
                    currentStreak: currentStreak
                )
            }
        }
        
        // Execute after a short delay to debounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: statsRefreshWorkItem!)
    }
    
    private func updateEmptyState() {
        let isEmpty = filteredBooks.isEmpty
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
        
        if isEmpty && !currentSearchText.isEmpty {
            emptyStateView.configure(
                title: "No Books Found",
                subtitle: "Try adjusting your search terms",
                imageName: "magnifyingglass"
            )
        } else if isEmpty {
            emptyStateView.configure(
                title: "Welcome to Your Library",
                subtitle: "Add your first book to get started",
                imageName: "books.vertical"
            )
        }
    }
    
    // MARK: - Actions
    @objc private func addBookTapped() {
        // Animate button
        UIView.animate(withDuration: 0.1, animations: {
            self.addBookButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.addBookButton.transform = .identity
            }
        }
        
        // Present document picker
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }
    
    @objc private func userMenuTapped() {
        showUserMenu()
    }
    
    @objc private func showUserMenu() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // User info
        if let user = FirebaseManager.shared.currentUser {
            let userInfo = user.isAnonymous ? "Anonymous User" : (user.displayName ?? user.email ?? "User")
            alertController.title = userInfo
        }
        
        // Test Firestore connection
        alertController.addAction(UIAlertAction(title: "Test Firebase", style: .default) { _ in
            FirestoreTest.testConnection()
        })
        
        // Test file upload
        alertController.addAction(UIAlertAction(title: "Test File Upload", style: .default) { _ in
            self.testFileUpload()
        })
        
        // Cleanup broken books
        alertController.addAction(UIAlertAction(title: "Clean Up Broken Books", style: .destructive) { _ in
            self.cleanupBrokenBooks()
        })
        
        // Stats & Goals action
        alertController.addAction(UIAlertAction(title: "Stats & Goals", style: .default) { _ in
            self.showDetailedStats()
        })
        
        // Settings action
        alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            // Navigate to settings
            let settingsVC = UIViewController()
            settingsVC.title = "Settings"
            let settingsPanel = ModernSettingsPanel()
            settingsVC.view.addSubview(settingsPanel)
            settingsPanel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                settingsPanel.topAnchor.constraint(equalTo: settingsVC.view.safeAreaLayoutGuide.topAnchor),
                settingsPanel.leadingAnchor.constraint(equalTo: settingsVC.view.leadingAnchor),
                settingsPanel.trailingAnchor.constraint(equalTo: settingsVC.view.trailingAnchor),
                settingsPanel.bottomAnchor.constraint(equalTo: settingsVC.view.bottomAnchor)
            ])
            let navController = UINavigationController(rootViewController: settingsVC)
            self.present(navController, animated: true)
        })
        
        // Sign Out action
        alertController.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { _ in
            self.signOut()
        })
        
        // Cancel action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.width - 50, y: 100, width: 1, height: 1)
        }
        
        present(alertController, animated: true)
    }
    
    @objc private func showDetailedStats() {
        // Stats view removed - using simplified tracking
        let alert = UIAlertController(title: "Reading Stats", message: "Check your reading progress in the stats card above.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func signOut() {
        AuthenticationManager.shared.signOut { [weak self] result in
            switch result {
            case .success:
                // Navigate to login screen
                let loginVC = LoginViewController()
                let navigationController = UINavigationController(rootViewController: loginVC)
                navigationController.isNavigationBarHidden = true
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = navigationController
                    UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
                }
                
            case .failure(let error):
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Dynamic Content
    private func getDynamicGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let userName = getUserDisplayName()
        
        switch hour {
        case 5..<12:
            return "Good Morning\(userName.isEmpty ? "" : ", \(userName)")"
        case 12..<17:
            return "Good Afternoon\(userName.isEmpty ? "" : ", \(userName)")"
        case 17..<21:
            return "Good Evening\(userName.isEmpty ? "" : ", \(userName)")"
        default:
            return "Happy Reading\(userName.isEmpty ? "" : ", \(userName)")"
        }
    }
    
    private func getDynamicSubtitle() -> String {
        let bookCount = books.count
        let completedCount = books.filter { $0.lastReadPosition >= 1.0 }.count
        let readingCount = books.filter { $0.lastReadPosition > 0 && $0.lastReadPosition < 1.0 }.count
        
        if bookCount == 0 {
            return "Start your reading journey by adding your first book"
        } else if readingCount > 0 {
            return "You have \(readingCount) book\(readingCount == 1 ? "" : "s") in progress • \(completedCount) completed"
        } else if completedCount > 0 {
            return "You've completed \(completedCount) book\(completedCount == 1 ? "" : "s") • Keep the momentum!"
        } else {
            return "You have \(bookCount) book\(bookCount == 1 ? "" : "s") ready to explore"
        }
    }
    
    private func getUserDisplayName() -> String {
        // Try to get user's first name from Firebase Auth
        if let user = FirebaseManager.shared.currentUser {
            if let displayName = user.displayName, !displayName.isEmpty {
                // Get first name only and limit length
                let firstName = displayName.components(separatedBy: " ").first ?? displayName
                // Limit to 15 characters to prevent overflow
                if firstName.count > 15 {
                    return String(firstName.prefix(12)) + "..."
                }
                return firstName
            } else if let email = user.email {
                // Use email username if no display name
                let username = email.components(separatedBy: "@").first ?? ""
                if username.count > 15 {
                    return String(username.prefix(12)) + "..."
                }
                return username
            }
        }
        return ""
    }
    
    private func updateDynamicContent() {
        titleLabel.text = getDynamicGreeting()
        subtitleLabel.text = getDynamicSubtitle()
    }
    
    @objc private func showQuickActions() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Sort options
        alertController.addAction(UIAlertAction(title: "Sort by Title", style: .default) { [weak self] _ in
            self?.sortBooks(by: .title)
        })
        
        alertController.addAction(UIAlertAction(title: "Sort by Author", style: .default) { [weak self] _ in
            self?.sortBooks(by: .author)
        })
        
        alertController.addAction(UIAlertAction(title: "Sort by Recent", style: .default) { [weak self] _ in
            self?.sortBooks(by: .recent)
        })
        
        alertController.addAction(UIAlertAction(title: "Sort by Progress", style: .default) { [weak self] _ in
            self?.sortBooks(by: .progress)
        })
        
        // Filter options
        alertController.addAction(UIAlertAction(title: "Show Only Reading", style: .default) { [weak self] _ in
            self?.filterBooks(by: .reading)
        })
        
        alertController.addAction(UIAlertAction(title: "Show Only Completed", style: .default) { [weak self] _ in
            self?.filterBooks(by: .completed)
        })
        
        alertController.addAction(UIAlertAction(title: "Show All Books", style: .default) { [weak self] _ in
            self?.filterBooks(by: .all)
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = quickActionsButton
            popover.sourceRect = quickActionsButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func sortBooks(by sortType: SortType) {
        currentSortType = sortType
        applyFiltersAndSort()
    }
    
    private func filterBooks(by filterType: FilterType) {
        currentFilterType = filterType
        applyFiltersAndSort()
    }
    
    private func applyFiltersAndSort() {
        var filtered = books
        
        // Apply search filter first
        if !currentSearchText.isEmpty {
            filtered = filtered.filter { book in
                book.title.localizedCaseInsensitiveContains(currentSearchText) ||
                book.author.localizedCaseInsensitiveContains(currentSearchText)
            }
        }
        
        // Apply status filter
        switch currentFilterType {
        case .reading:
            filtered = filtered.filter { $0.lastReadPosition > 0 && $0.lastReadPosition < 1.0 }
        case .completed:
            filtered = filtered.filter { $0.lastReadPosition >= 1.0 }
        case .all:
            break
        }
        
        // Apply sorting
        switch currentSortType {
        case .title:
            filtered.sort { (book1: Book, book2: Book) in
                book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
            }
        case .author:
            filtered.sort { (book1: Book, book2: Book) in
                book1.author.localizedCaseInsensitiveCompare(book2.author) == .orderedAscending
            }
        case .recent:
            filtered.sort { (book1: Book, book2: Book) in
                let date1 = book1.readingStats.lastReadDate ?? Date.distantPast
                let date2 = book2.readingStats.lastReadDate ?? Date.distantPast
                return date1 > date2
            }
        case .progress:
            filtered.sort { (book1: Book, book2: Book) in
                book1.lastReadPosition > book2.lastReadPosition
            }
        }
        
        filteredBooks = filtered
        updateEmptyState()
        collectionView.reloadData()
    }
    
    private func calculateReadingStreak() -> Int {
        // Get reading sessions from tracker
        let stats = UnifiedReadingTracker.shared.getTrackerStats()
        
        // Return the current streak from the tracker stats
        // The UnifiedReadingTracker already calculates and maintains the current streak
        return stats.currentStreak
    }
    
    // MARK: - Cleanup
    deinit {
        statsRefreshWorkItem?.cancel()
        statsRefreshWorkItem = nil
    }
}

// MARK: - UICollectionViewDataSource
extension ModernLibraryViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // Only show sections if we have books
        if filteredBooks.isEmpty {
            return 0
        }
        
        // Section 0: Continue Reading (only if we have recently read books)
        // Section 1: All Books
        let recentlyReadBooks = getRecentlyReadBooks()
        let sections = recentlyReadBooks.isEmpty ? 1 : 2
        return sections
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let count: Int
        if section == 0 && !getRecentlyReadBooks().isEmpty {
            // Continue Reading section
            count = min(5, getRecentlyReadBooks().count)
        } else {
            // All books section
            count = filteredBooks.count
        }
        return count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ModernBookCell", for: indexPath) as? ModernBookCell else {
            fatalError("Failed to dequeue ModernBookCell")
        }
        
        let book: Book
        if indexPath.section == 0 && !getRecentlyReadBooks().isEmpty {
            // Continue Reading section - show recently read books
            let recentBooks = getRecentlyReadBooks()
            book = recentBooks[indexPath.item]
        } else {
            // All books section
            book = filteredBooks[indexPath.item]
        }
        
        cell.configure(with: book, style: indexPath.section == 0 ? .compact : .detailed)
        cell.delegate = self
        
        // Add entrance animation for new cells
        cell.alpha = 0
        cell.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.5, delay: Double(indexPath.item) * 0.05, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            cell.alpha = 1
            cell.transform = .identity
        }
        
        return cell
    }
    
    // Helper method to get recently read books
    private func getRecentlyReadBooks() -> [Book] {
        return filteredBooks
            .filter { $0.readingStats.lastReadDate != nil }
            .sorted(by: { (book1, book2) in
                guard let date1 = book1.readingStats.lastReadDate,
                      let date2 = book2.readingStats.lastReadDate else {
                    return false
                }
                return date1 > date2
            })
            .prefix(5)
            .map { $0 }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeader", for: indexPath) as? ModernSectionHeader else {
            fatalError("Failed to dequeue ModernSectionHeader")
        }
        
        let recentlyReadBooks = getRecentlyReadBooks()
        
        if indexPath.section == 0 && !recentlyReadBooks.isEmpty {
            header.configure(title: "📖 Continue Reading", showSeeAll: false)
        } else {
            header.configure(title: "📚 All Books", showSeeAll: false)
        }
        
        return header
    }
}

// MARK: - UICollectionViewDelegate
extension ModernLibraryViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let book: Book
        if indexPath.section == 0 && !getRecentlyReadBooks().isEmpty {
            // Continue Reading section - get from recently read books
            let recentBooks = getRecentlyReadBooks()
            book = recentBooks[indexPath.item]
        } else {
            // All books section
            book = filteredBooks[indexPath.item]
        }
        
        
        // Animate selection
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.1, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    cell.transform = .identity
                }
            }
        }
        
        // Check if book needs to be downloaded from Firebase
        if FirebaseManager.shared.isAuthenticated && book.filePath.isEmpty {
            // Show loading indicator
            let loadingAlert = UIAlertController(title: "Loading Book", message: "Downloading from cloud...", preferredStyle: .alert)
            present(loadingAlert, animated: true)
            
            UnifiedFirebaseStorage.shared.downloadBook(book) { [weak self] result in
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let fileURL):
                        // Update book with local path
                        var updatedBook = book
                        updatedBook.filePath = fileURL.path
                        
                        // Present modern book reader
                        let readerVC = ModernBookReaderViewController()
                        readerVC.loadBook(updatedBook)
                        self?.navigationController?.pushViewController(readerVC, animated: true)
                        
                    case .failure(let error):
                        let alert = UIAlertController(title: "Error", message: "Failed to download book: \(error.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(alert, animated: true)
                    }
                }
            }
        } else {
            // Book is available locally
            let readerVC = ModernBookReaderViewController()
            readerVC.loadBook(book)
            navigationController?.pushViewController(readerVC, animated: true)
        }
    }
}

// MARK: - UISearchBarDelegate
extension ModernLibraryViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentSearchText = searchText
        
        // Animate reload with filters and sorting applied
        UIView.transition(with: collectionView, duration: 0.3, options: .transitionCrossDissolve) {
            self.applyFiltersAndSort()
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UIDocumentPickerDelegate
extension ModernLibraryViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { 
            return 
        }
        
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            showAlert(title: "Error", message: "Could not access selected file")
            return
        }
        
        // Show loading indicator immediately
        showLoadingIndicator(message: "Processing file...")
        
        // Move all file operations to background queue to prevent UI freeze
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer { url.stopAccessingSecurityScopedResource() }
            
            guard let self = self else { return }
            
            // Verify file is accessible
            guard FileManager.default.fileExists(atPath: url.path) else {
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                    self.showAlert(title: "Error", message: "Selected file is not accessible")
                }
                return
            }
            
            // Get documents directory
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                    self.showAlert(title: "Error", message: "Could not access documents directory")
                }
                return
            }
            
            // Validate file before processing (now on background thread)
            switch SecurityValidator.validateFileUpload(at: url) {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                    self.showAlert(title: "Invalid File", message: error.localizedDescription)
                }
                return
            case .success:
                break
            }
            
            // Sanitize file name to prevent security issues
            let originalFileName = url.lastPathComponent
            let sanitizedFileName = SecurityValidator.sanitizeFileName(originalFileName)
            let destinationURL = documentsPath.appendingPathComponent(sanitizedFileName)
            
            // Continue with file operations on background thread
            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy file to app's documents directory
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                // Verify the copy was successful
                guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                    DispatchQueue.main.async {
                        self.hideLoadingIndicator()
                        self.showAlert(title: "Error", message: "Failed to copy file to app directory")
                    }
                    return
                }
                
                // Determine book type based on extension
                let fileExtension = url.pathExtension.lowercased()
                let bookType: Book.BookType = {
                    switch fileExtension {
                    case "pdf": return .pdf
                    case "txt": return .text
                    case "epub": return .epub
                    default: return .pdf
                    }
                }()
                
                // Validate file content based on type
                switch bookType {
                case .pdf:
                    if !SecurityValidator.validatePDFContent(at: destinationURL) {
                        try? FileManager.default.removeItem(at: destinationURL)
                        DispatchQueue.main.async {
                            self.hideLoadingIndicator()
                            self.showAlert(title: "Invalid File", message: "The PDF file appears to be corrupted")
                        }
                        return
                    }
                case .text:
                    if !SecurityValidator.validateTextContent(at: destinationURL) {
                        try? FileManager.default.removeItem(at: destinationURL)
                        DispatchQueue.main.async {
                            self.hideLoadingIndicator()
                            self.showAlert(title: "Invalid File", message: "The text file could not be read")
                        }
                        return
                    }
                default:
                    break
                }
                
                // Verify authentication before sensitive operations
                guard SecurityValidator.requireAuthentication() else {
                    DispatchQueue.main.async {
                        self.hideLoadingIndicator()
                        self.showAlert(title: "Authentication Required", message: "Please sign in to upload books")
                    }
                    return
                }
                
                // Verify user has permission for upload operation
                guard SecurityValidator.validateUserPermission(for: "upload_book") else {
                    DispatchQueue.main.async {
                        self.hideLoadingIndicator()
                        self.showAlert(title: "Permission Denied", message: "You don't have permission to upload books")
                    }
                    return
                }
                
                // Create new book with the copied file path
                let book = Book(
                    title: url.deletingPathExtension().lastPathComponent,
                    author: "Unknown Author",
                    filePath: destinationURL.path, // Use copied file path
                    type: bookType
                )
                
                // Update loading message for upload phase
                DispatchQueue.main.async {
                    self.updateLoadingIndicator(message: "Uploading to cloud...")
                }
                
                // Save book IMMEDIATELY while we have access to the file
                if FirebaseManager.shared.isAuthenticated {
                    
                    // Double-check file exists before upload
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0
                    
                    if fileSize == 0 {
                        DispatchQueue.main.async {
                            self.hideLoadingIndicator()
                            self.showAlert(title: "File Error", message: "The copied file is empty")
                        }
                        return
                    }
                    
                    // Use the copied file for Firebase upload
                    UnifiedFirebaseStorage.shared.uploadBook(fileURL: destinationURL, title: book.title, author: book.author) { [weak self] result in
                        DispatchQueue.main.async {
                            self?.hideLoadingIndicator()
                            
                            switch result {
                            case .success(let uploadedBook):
                                // Show success animation
                                self?.showBookAddedAnimation()
                                
                                // Refresh the library
                                self?.loadBooks()
                                
                            case .failure(let error):
                                // Show error alert
                                self?.showAlert(title: "Upload Failed", message: error.localizedDescription)
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.hideLoadingIndicator()
                        self.showAlert(title: "Not Authenticated", message: "Please sign in to add books")
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                    self.showAlert(title: "File Copy Error", message: "Failed to copy file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Loading Indicator Methods
    
    private func showLoadingIndicator(message: String) {
        // Remove existing loading indicator if any
        hideLoadingIndicator()
        
        let containerView = UIView()
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let contentView = UIView()
        contentView.backgroundColor = UIColor.systemBackground
        contentView.layer.cornerRadius = 16
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor.label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(activityIndicator)
        contentView.addSubview(label)
        containerView.addSubview(contentView)
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            contentView.widthAnchor.constraint(equalToConstant: 200),
            contentView.heightAnchor.constraint(equalToConstant: 120),
            
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16)
        ])
        
        loadingIndicator = containerView
        loadingLabel = label
    }
    
    private func updateLoadingIndicator(message: String) {
        loadingLabel?.text = message
    }
    
    private func hideLoadingIndicator() {
        loadingIndicator?.removeFromSuperview()
        loadingIndicator = nil
        loadingLabel = nil
    }
    
    private func showBookAddedAnimation() {
        let successView = UIView()
        successView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        successView.layer.cornerRadius = 25
        successView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        iconImageView.image = UIImage(systemName: "checkmark", withConfiguration: config)
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Book Added!"
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        
        successView.addSubview(iconImageView)
        successView.addSubview(label)
        view.addSubview(successView)
        
        NSLayoutConstraint.activate([
            successView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            successView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            successView.widthAnchor.constraint(equalToConstant: 200),
            successView.heightAnchor.constraint(equalToConstant: 100),
            
            iconImageView.centerXAnchor.constraint(equalTo: successView.centerXAnchor),
            iconImageView.topAnchor.constraint(equalTo: successView.topAnchor, constant: 20),
            
            label.centerXAnchor.constraint(equalTo: successView.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: successView.bottomAnchor, constant: -20)
        ])
        
        // Animation
        successView.alpha = 0
        successView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8) {
            successView.alpha = 1
            successView.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5) {
                successView.alpha = 0
                successView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            } completion: { _ in
                successView.removeFromSuperview()
            }
        }
    }
    
    private func testFileUpload() {
        guard let userId = FirebaseManager.shared.userId else {
            return
        }
        
        
        // Create a test file in documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showAlert(title: "Error", message: "Could not access documents directory")
            return
        }
        let testFileURL = documentsPath.appendingPathComponent("test.txt")
        let testContent = "Hello Firebase Storage Test!"
        
        do {
            try testContent.write(to: testFileURL, atomically: true, encoding: .utf8)
            
            // Test Firebase upload with this file
            let storage = Storage.storage()
            let storageRef = storage.reference().child("users/\(userId)/test/test.txt")
            
            storageRef.putFile(from: testFileURL, metadata: nil) { metadata, error in
                if let error = error {
                } else {
                }
            }
            
        } catch {
        }
    }
    
    private func cleanupBrokenBooks() {
        let alert = UIAlertController(title: "Clean Up Broken Books", 
                                    message: "This will remove all books with missing or invalid files. This action cannot be undone.", 
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clean Up", style: .destructive) { _ in
            UnifiedFirebaseStorage.shared.cleanupBrokenBooks { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let count):
                        if count > 0 {
                            self.showAlert(title: "Cleanup Complete", message: "Removed \(count) broken books from your library.")
                        } else {
                            self.showAlert(title: "No Issues Found", message: "All your books are working properly!")
                        }
                    case .failure(let error):
                        self.showAlert(title: "Cleanup Failed", message: error.localizedDescription)
                    }
                }
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - ModernBookCellDelegate
extension ModernLibraryViewController: ModernBookCellDelegate {
    
    func didTapDeleteButton(for book: Book, in cell: ModernBookCell) {
        showDeleteConfirmation(for: book)
    }
    
    private func showDeleteConfirmation(for book: Book) {
        // Get file size directly from the book's file path
        let fileSize: String
        if FileManager.default.fileExists(atPath: book.filePath) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: book.filePath)
                let size = attributes[.size] as? Int64 ?? 0
                fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            } catch {
                fileSize = "Unknown size"
            }
        } else {
            fileSize = "File not found"
        }
        
        let alert = UIAlertController(
            title: "Delete Book",
            message: "Are you sure you want to delete '\(book.title)' (\(fileSize))?\n\nThis will permanently remove the book from your library and cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performBookDeletion(book: book)
        })
        
        present(alert, animated: true)
    }
    
    private func performBookDeletion(book: Book) {
        // Show loading indicator
        showLoadingIndicator(message: "Deleting book...")
        
        // Check if we're using Firebase or local storage
        if FirebaseManager.shared.isAuthenticated {
            // Delete from Firebase
            UnifiedFirebaseStorage.shared.removeBook(bookId: book.id) { [weak self] result in
                DispatchQueue.main.async {
                    self?.hideLoadingIndicator()
                    
                    switch result {
                    case .success:
                        // Also try to delete local file if it exists
                        self?.deleteLocalFile(at: book.filePath)
                        
                        // Show success message with animation
                        self?.showDeleteSuccessMessage(bookTitle: book.title)
                        
                        // Refresh the library
                        self?.loadBooks()
                        
                        // Animate collection view update
                        self?.animateBookRemoval()
                        
                    case .failure(let error):
                        self?.showAlert(title: "Delete Failed", message: "Could not delete the book: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Delete from local storage
            BookStorage.shared.safeDeleteBook(book.id) { [weak self] success in
                DispatchQueue.main.async {
                    self?.hideLoadingIndicator()
                    
                    if success {
                        // Show success message with animation
                        self?.showDeleteSuccessMessage(bookTitle: book.title)
                        
                        // Refresh the library
                        self?.loadBooks()
                        
                        // Animate collection view update
                        self?.animateBookRemoval()
                        
                    } else {
                        self?.showAlert(title: "Delete Failed", message: "Could not delete the book. Please try again.")
                    }
                }
            }
        }
    }
    
    private func deleteLocalFile(at filePath: String) {
        // Only delete if file exists and is within our documents directory
        guard FileManager.default.fileExists(atPath: filePath) else { return }
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        // Ensure file is within our app's directory
        guard filePath.hasPrefix(documentsPath.path) else { return }
        
        do {
            try FileManager.default.removeItem(atPath: filePath)
            print("Successfully deleted local file: \(filePath)")
        } catch {
            print("Failed to delete local file: \(error.localizedDescription)")
        }
    }
    
    private func showDeleteSuccessMessage(bookTitle: String) {
        let successView = UIView()
        successView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        successView.layer.cornerRadius = 25
        successView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        iconImageView.image = UIImage(systemName: "trash", withConfiguration: config)
        iconImageView.tintColor = .white
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = "Book Deleted"
        messageLabel.font = UIFont.boldSystemFont(ofSize: 16)
        messageLabel.textColor = .white
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [iconImageView, messageLabel])
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        successView.addSubview(stackView)
        view.addSubview(successView)
        
        NSLayoutConstraint.activate([
            successView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            successView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            successView.heightAnchor.constraint(equalToConstant: 50),
            successView.widthAnchor.constraint(equalToConstant: 160),
            
            stackView.centerXAnchor.constraint(equalTo: successView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: successView.centerYAnchor)
        ])
        
        // Animate appearance
        successView.alpha = 0
        successView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            successView.alpha = 1
            successView.transform = .identity
        }
        
        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.3) {
                successView.alpha = 0
                successView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            } completion: { _ in
                successView.removeFromSuperview()
            }
        }
    }
    
    private func animateBookRemoval() {
        UIView.animate(withDuration: 0.3, delay: 0.1, options: [.curveEaseInOut]) {
            self.collectionView.performBatchUpdates({
                // The collection view will automatically animate the changes
                // when we reload the data after calling loadBooks()
            })
        }
    }
}
