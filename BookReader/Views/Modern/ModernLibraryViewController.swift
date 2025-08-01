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
    
    // MARK: - UI Components
    private lazy var gradientBackgroundLayer: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.systemBackground.cgColor,
            UIColor.systemBlue.withAlphaComponent(0.05).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.05).cgColor
        ]
        gradient.locations = [0, 0.5, 1]
        gradient.type = .radial
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        return gradient
    }()
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "My Library"
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Your reading journey continues"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var searchContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
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
        print("DEBUG: ModernLibraryViewController viewDidLoad called")
        setupUI()
        setupObservers()
        
        // Force initialize FirebaseBookStorage
        _ = FirebaseBookStorage.shared
        
        loadBooks()
        addAnimations()
        
        // Verify collection view setup
        print("DEBUG: collectionView.dataSource = \(String(describing: collectionView.dataSource))")
        print("DEBUG: collectionView.delegate = \(String(describing: collectionView.delegate))")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshStats()
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
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
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
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            // Search
            searchContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            searchContainer.heightAnchor.constraint(equalToConstant: 50),
            
            searchBar.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -8),
            searchBar.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            
            // Stats
            statsView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 20),
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
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
        // Observe changes to FirebaseBookStorage books
        FirebaseBookStorage.shared.$books
            .receive(on: DispatchQueue.main)
            .sink { [weak self] books in
                print("📚 Firebase books updated: \(books.count) books")
                self?.books = books
                self?.filteredBooks = books
                self?.updateEmptyState()
                self?.collectionView.reloadData()
                self?.refreshStats()
            }
            .store(in: &cancellables)
        
        // Observe authentication state changes
        FirebaseManager.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                if user != nil {
                    print("🔥 User authenticated, refreshing books")
                    self?.loadBooks()
                } else {
                    print("🔥 User signed out, clearing books")
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
    
    // MARK: - Data
    private func loadBooks() {
        print("DEBUG: loadBooks() called")
        
        // Check if user is authenticated
        guard FirebaseManager.shared.isAuthenticated else {
            print("DEBUG: User not authenticated, using local storage")
            books = BookStorage.shared.loadBooks()
            filteredBooks = books
            updateEmptyState()
            collectionView.reloadData()
            return
        }
        
        // Use Firebase storage
        books = FirebaseBookStorage.shared.books
        print("DEBUG: Loaded \(books.count) books from Firebase")
        for (index, book) in books.enumerated() {
            print("DEBUG: Book \(index): \(book.title)")
        }
        filteredBooks = books
        print("DEBUG: filteredBooks count: \(filteredBooks.count)")
        updateEmptyState()
        collectionView.reloadData()
        print("DEBUG: Collection view reloaded")
        
        // Observe changes
        FirebaseBookStorage.shared.$books
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
        let totalBooks = books.count
        let booksCompleted = books.filter { $0.lastReadPosition >= 1.0 }.count
        
        // Get reading time from UnifiedReadingTracker
        let stats = UnifiedReadingTracker.shared.getTrackerStats()
        let totalReadingMinutes = Int(stats.totalReadingTime / 60)
        
        statsView.updateStats(
            totalBooks: totalBooks,
            readingTime: totalReadingMinutes,
            completedBooks: booksCompleted
        )
    }
    
    private func updateEmptyState() {
        let isEmpty = filteredBooks.isEmpty
        print("DEBUG: updateEmptyState - isEmpty: \(isEmpty), filteredBooks count: \(filteredBooks.count)")
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
        print("DEBUG: emptyStateView.isHidden = \(!isEmpty), collectionView.isHidden = \(isEmpty)")
        
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
        print("DEBUG: numberOfSections = \(sections), filteredBooks.count = \(filteredBooks.count), recentlyRead: \(recentlyReadBooks.count)")
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
        print("DEBUG: numberOfItemsInSection \(section) = \(count)")
        return count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("DEBUG: cellForItemAt called for section: \(indexPath.section), item: \(indexPath.item)")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ModernBookCell", for: indexPath) as! ModernBookCell
        
        let book: Book
        if indexPath.section == 0 && !getRecentlyReadBooks().isEmpty {
            // Continue Reading section - show recently read books
            let recentBooks = getRecentlyReadBooks()
            book = recentBooks[indexPath.item]
        } else {
            // All books section
            book = filteredBooks[indexPath.item]
        }
        
        print("DEBUG: Configuring cell with book: \(book.title)")
        cell.configure(with: book, style: indexPath.section == 0 ? .compact : .detailed)
        
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
            .sorted(by: { $0.readingStats.lastReadDate! > $1.readingStats.lastReadDate! })
            .prefix(5)
            .map { $0 }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "SectionHeader", for: indexPath) as! ModernSectionHeader
        
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
        
        print("📖 Selected book: \(book.title)")
        print("📂 File path: \(book.filePath)")
        print("📄 File exists: \(FileManager.default.fileExists(atPath: book.filePath))")
        
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
            
            FirebaseBookStorage.shared.downloadBook(book) { [weak self] result in
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
        
        if searchText.isEmpty {
            filteredBooks = books
        } else {
            filteredBooks = books.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.author.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        updateEmptyState()
        
        // Animate reload
        UIView.transition(with: collectionView, duration: 0.3, options: .transitionCrossDissolve) {
            self.collectionView.reloadData()
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
            print("❌ No URL selected")
            return 
        }
        
        print("📁 Selected file: \(url)")
        print("📁 File exists at source: \(FileManager.default.fileExists(atPath: url.path))")
        
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Failed to access security-scoped resource")
            return
        }
        
        // Verify file is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ File does not exist at path: \(url.path)")
            url.stopAccessingSecurityScopedResource()
            return
        }
        
        // Copy file to documents directory first
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = url.lastPathComponent
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        print("📁 Destination: \(destinationURL)")
        print("📁 Documents directory: \(documentsPath)")
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("🗑️ Removing existing file at destination")
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy file to app's documents directory
            print("📋 Copying file...")
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("✅ File copied successfully")
            
            // Verify the copy was successful
            guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                print("❌ File was not copied successfully")
                url.stopAccessingSecurityScopedResource()
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
            
            // Create new book with the copied file path
            let book = Book(
                title: url.deletingPathExtension().lastPathComponent,
                author: "Unknown Author",
                filePath: destinationURL.path, // Use copied file path
                type: bookType
            )
            
            // Now we can release the security scope since we have the file copied
            url.stopAccessingSecurityScopedResource()
            
            // Debug authentication state
            print("🔍 Authentication check:")
            print("   - FirebaseManager.shared.isAuthenticated: \(FirebaseManager.shared.isAuthenticated)")
            print("   - FirebaseManager.shared.currentUser: \(FirebaseManager.shared.currentUser?.uid ?? "nil")")
            print("   - Auth.auth().currentUser: \(Auth.auth().currentUser?.uid ?? "nil")")
            
            // Save book IMMEDIATELY while we have access to the file
            if FirebaseManager.shared.isAuthenticated {
                print("🚀 Attempting to save to Firebase...")
                
                // Double-check file exists before upload
                print("🔍 Final file check before Firebase:")
                print("   - File exists: \(FileManager.default.fileExists(atPath: destinationURL.path))")
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0
                print("   - File size: \(fileSize) bytes")
                
                if fileSize == 0 {
                    print("❌ File is empty after copy!")
                    let alert = UIAlertController(title: "File Error", message: "The copied file is empty", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                    return
                }
                
                // Create a strong reference to prevent cleanup
                let fileURLCopy = destinationURL
                let bookCopy = book
                
                // Use the copied file for Firebase upload
                FirebaseBookStorage.shared.addBook(bookCopy, fileURL: fileURLCopy) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let bookId):
                            print("✅ Book uploaded successfully with ID: \(bookId)")
                            // Show success animation
                            self?.showBookAddedAnimation()
                        case .failure(let error):
                            print("❌ Failed to save book to Firebase: \(error)")
                            // Show error alert
                            let alert = UIAlertController(title: "Upload Failed", message: error.localizedDescription, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            self?.present(alert, animated: true)
                        }
                    }
                }
            } else {
                print("❌ User not authenticated! Cannot save to Firebase")
                let alert = UIAlertController(title: "Not Authenticated", message: "Please sign in to add books", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
            
        } catch {
            print("❌ Error copying file: \(error)")
            url.stopAccessingSecurityScopedResource()
            let alert = UIAlertController(title: "File Copy Error", message: "Failed to copy file: \(error.localizedDescription)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
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
            print("❌ No user ID for test upload")
            return
        }
        
        print("🧪 Testing file upload...")
        
        // Create a test file in documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let testFileURL = documentsPath.appendingPathComponent("test.txt")
        let testContent = "Hello Firebase Storage Test!"
        
        do {
            try testContent.write(to: testFileURL, atomically: true, encoding: .utf8)
            print("✅ Test file created at: \(testFileURL)")
            
            // Test Firebase upload with this file
            let storage = Storage.storage()
            let storageRef = storage.reference().child("users/\(userId)/test/test.txt")
            
            storageRef.putFile(from: testFileURL, metadata: nil) { metadata, error in
                if let error = error {
                    print("❌ Test file upload failed: \(error)")
                } else {
                    print("✅ Test file upload successful!")
                    print("📄 Uploaded to: users/\(userId)/test/test.txt")
                }
            }
            
        } catch {
            print("❌ Failed to create test file: \(error)")
        }
    }
}
