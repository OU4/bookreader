//
//  LibraryViewController.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//

import UIKit
import UniformTypeIdentifiers
import MobileCoreServices
import Combine

protocol LibraryViewControllerDelegate: AnyObject {
    func didSelectBook(_ book: Book)
}

class LibraryViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: LibraryViewControllerDelegate?
    private var books: [Book] = []
    private var filteredBooks: [Book] = []
    private var currentSortOption: SortOption = .title
    private var isSearching: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UI Components
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search books..."
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["All", "Recently Read", "Favorites"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemBackground
        cv.delegate = self
        cv.dataSource = self
        cv.register(EnhancedBookCell.self, forCellWithReuseIdentifier: "EnhancedBookCell")
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private lazy var statsView: LibraryStatsView = {
        let view = LibraryStatsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
        loadBooks()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "My Library"
        view.backgroundColor = .systemBackground
        
        // Navigation items
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissLibrary)
        )
        
        let sortButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(showSortOptions)
        )
        
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addBook)
        )
        
        navigationItem.rightBarButtonItems = [addButton, sortButton]
        
        // Add views
        view.addSubview(searchBar)
        view.addSubview(segmentedControl)
        view.addSubview(statsView)
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            segmentedControl.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            statsView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statsView.heightAnchor.constraint(equalToConstant: 80),
            
            collectionView.topAnchor.constraint(equalTo: statsView.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func dismissLibrary() {
        dismiss(animated: true)
    }
    
    @objc private func addBook() {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                UTType.pdf,
                UTType.text,
                UTType.epub,
                UTType.image
            ]
        )
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        present(documentPicker, animated: true)
    }
    
    @objc private func showSortOptions() {
        let alert = UIAlertController(title: "Sort Books", message: nil, preferredStyle: .actionSheet)
        
        for option in SortOption.allCases {
            let action = UIAlertAction(title: option.displayName, style: .default) { [weak self] _ in
                self?.currentSortOption = option
                self?.updateFilteredBooks()
            }
            
            if option == currentSortOption {
                action.setValue(true, forKey: "checked")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        
        present(alert, animated: true)
    }
    
    @objc private func segmentChanged() {
        updateFilteredBooks()
    }
    
    // MARK: - Data Management
    private func setupObservers() {
        // Observe changes to FirebaseBookStorage books
        FirebaseBookStorage.shared.$books
            .receive(on: DispatchQueue.main)
            .sink { [weak self] books in
                print("📚 LibraryViewController: Firebase books updated: \(books.count) books")
                self?.books = books
                self?.updateFilteredBooks()
                self?.updateStatsView()
            }
            .store(in: &cancellables)
    }
    
    private func loadBooks() {
        print("DEBUG LibraryViewController: loadBooks() called")
        
        // Check if user is authenticated
        if FirebaseManager.shared.currentUser != nil {
            // Use Firebase storage for authenticated users
            books = FirebaseBookStorage.shared.books
            print("DEBUG LibraryViewController: Loaded \(books.count) books from Firebase")
        } else {
            // Fall back to local storage for unauthenticated users
            books = BookStorage.shared.loadBooks()
            print("DEBUG LibraryViewController: Loaded \(books.count) books from local storage")
        }
        
        updateFilteredBooks()
        updateStatsView()
    }
    
    private func updateFilteredBooks() {
        print("DEBUG LibraryViewController: updateFilteredBooks called with \(books.count) total books")
        var filtered = books
        
        // Apply search filter
        if let searchText = searchBar.text, !searchText.isEmpty {
            isSearching = true
            filtered = filtered.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.author.localizedCaseInsensitiveContains(searchText)
            }
        } else {
            isSearching = false
        }
        
        // Apply segment filter
        switch segmentedControl.selectedSegmentIndex {
        case 1: // Recently Read
            filtered = filtered.filter { book in
                book.readingStats.lastReadDate != nil
            }.sorted { first, second in
                guard let firstDate = first.readingStats.lastReadDate,
                      let secondDate = second.readingStats.lastReadDate else {
                    return false
                }
                return firstDate > secondDate
            }
            
        case 2: // Favorites (books with highlights/notes)
            filtered = filtered.filter { book in
                !book.highlights.isEmpty || !book.notes.isEmpty
            }
            
        default: // All books
            break
        }
        
        // Apply sort
        filtered = sortBooks(filtered, by: currentSortOption)
        
        filteredBooks = filtered
        print("DEBUG LibraryViewController: Final filteredBooks count: \(filteredBooks.count)")
        collectionView.reloadData()
        print("DEBUG LibraryViewController: Collection view reloaded")
    }
    
    private func sortBooks(_ books: [Book], by option: SortOption) -> [Book] {
        switch option {
        case .title:
            return books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            return books.sorted { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
        case .recentlyAdded:
            return books.sorted { $0.id > $1.id } // Assuming newer IDs are larger
        case .readingProgress:
            return books.sorted { $0.lastReadPosition > $1.lastReadPosition }
        }
    }
    
    private func updateStatsView() {
        let totalBooks = books.count
        let booksRead = books.filter { $0.lastReadPosition > 0 }.count
        let totalReadingTime = books.reduce(0) { $0 + $1.readingStats.totalReadingTime }
        
        let readingTimeMinutes = Int(totalReadingTime / 60)
        let completedBooks = books.filter { $0.lastReadPosition >= 1.0 }.count
        
        statsView.updateStats(
            totalBooks: totalBooks,
            readingTime: readingTimeMinutes,
            completedBooks: completedBooks
        )
    }
    
    
    private func saveBook(_ book: Book) {
        // Check for duplicates by title and file path
        let isDuplicate = books.contains { existingBook in
            existingBook.title == book.title || existingBook.filePath == book.filePath
        }
        
        if isDuplicate {
            showDuplicateBookAlert(bookTitle: book.title)
            return
        }
        
        books.append(book)
        BookStorage.shared.saveBook(book)
        updateFilteredBooks() // Fix: Update filtered books
        collectionView.reloadData()
    }
    
    private func showDuplicateBookAlert(bookTitle: String) {
        let alert = UIAlertController(
            title: "Duplicate Book",
            message: "'\(bookTitle)' already exists in your library.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func deleteBook(at indexPath: IndexPath) {
        let book = filteredBooks[indexPath.item]
        
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Delete Book",
            message: "Are you sure you want to delete '\(book.title)'? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performBookDeletion(book: book, at: indexPath)
        })
        
        present(alert, animated: true)
    }
    
    private func performBookDeletion(book: Book, at indexPath: IndexPath) {
        // Remove from both arrays
        if let mainIndex = books.firstIndex(where: { $0.id == book.id }) {
            books.remove(at: mainIndex)
        }
        filteredBooks.remove(at: indexPath.item)
        
        // Remove from storage
        // Note: BookStorage needs a deleteBook method - this is a missing feature
        // BookStorage.shared.deleteBook(book.id)
        
        // Update UI
        collectionView.deleteItems(at: [indexPath])
        
        // Show feedback
        let message = "'\(book.title)' has been deleted"
        let alert = UIAlertController(title: "Book Deleted", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension LibraryViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("DEBUG LibraryViewController: numberOfItemsInSection = \(filteredBooks.count)")
        return filteredBooks.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("DEBUG LibraryViewController: cellForItemAt called for item: \(indexPath.item)")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EnhancedBookCell", for: indexPath) as! EnhancedBookCell
        let book = filteredBooks[indexPath.item]
        print("DEBUG LibraryViewController: Configuring cell with book: \(book.title)")
        cell.configure(with: book)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let book = filteredBooks[indexPath.item]
        delegate?.didSelectBook(book)
        dismiss(animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 48) / 3 // 3 columns
        return CGSize(width: width, height: width * 1.5)
    }
    
    // Add context menu for book actions
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let book = filteredBooks[indexPath.item]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let deleteAction = UIAction(
                title: "Delete Book",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                self?.deleteBook(at: indexPath)
            }
            
            return UIMenu(title: book.title, children: [deleteAction])
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension LibraryViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            processDocument(at: url)
        }
    }
    
    private func processDocument(at url: URL) {
        print("Processing document from URL: \(url)")
        
        guard url.startAccessingSecurityScopedResource() else { 
            print("Failed to access security scoped resource")
            showErrorAlert(message: "Cannot access the selected file. Please try again.")
            return 
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            // Copy file to app's documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = url.lastPathComponent
            let destinationURL = documentsPath.appendingPathComponent(fileName)
            
            print("Copying file to: \(destinationURL.path)")
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                print("Removed existing file")
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("File copied successfully")
            
            // Verify the file was copied and is accessible
            guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                print("File was not copied successfully")
                showErrorAlert(message: "Failed to import file. Please try again.")
                return
            }
            
            // Create book object
            let book = createBook(from: destinationURL)
            saveBook(book)
            print("Book created and saved: \(book.title)")
            
        } catch {
            print("Error processing document: \(error)")
            showErrorAlert(message: "Failed to import file: \(error.localizedDescription)")
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Import Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func createBook(from url: URL) -> Book {
        let fileExtension = url.pathExtension.lowercased()
        let bookType: Book.BookType
        
        switch fileExtension {
        case "pdf":
            bookType = .pdf
        case "txt":
            bookType = .text
        case "epub":
            bookType = .epub
        case "jpg", "jpeg", "png":
            bookType = .image
        default:
            bookType = .text
        }
        
        return Book(
            id: UUID().uuidString,
            title: url.deletingPathExtension().lastPathComponent,
            author: "Unknown",
            filePath: url.path,
            type: bookType,
            coverImage: generateCoverImage(for: bookType)
        )
    }
    
    private func generateCoverImage(for type: Book.BookType) -> UIImage? {
        // Generate a placeholder cover image
        let size = CGSize(width: 200, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        // Background
        UIColor.systemGray5.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        // Icon
        let iconName: String
        switch type {
        case .pdf:
            iconName = "doc.text"
        case .text:
            iconName = "doc.plaintext"
        case .epub:
            iconName = "book"
        case .image:
            iconName = "photo"
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

// MARK: - UISearchBarDelegate
extension LibraryViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateFilteredBooks()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        updateFilteredBooks()
    }
}

// MARK: - Supporting Types
enum SortOption: CaseIterable {
    case title
    case author
    case recentlyAdded
    case readingProgress
    
    var displayName: String {
        switch self {
        case .title: return "Title"
        case .author: return "Author"
        case .recentlyAdded: return "Recently Added"
        case .readingProgress: return "Reading Progress"
        }
    }
}

