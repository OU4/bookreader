//
//  BookmarksViewController.swift
//  BookReader
//
//  Complete bookmarks management interface
//

import UIKit

class BookmarksViewController: UIViewController {
    
    // MARK: - Properties
    private var bookmarks: [BookmarkItem] = []
    private var filteredBookmarks: [BookmarkItem] = []
    private var currentBookId: String?
    private var selectedFilterType: BookmarkItem.BookmarkType?
    
    // MARK: - UI Components
    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.searchResultsUpdater = self
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchBar.placeholder = "Search bookmarks..."
        return controller
    }()
    
    private lazy var filterSegmentedControl: UISegmentedControl = {
        var items = ["All"]
        items.append(contentsOf: BookmarkItem.BookmarkType.allCases.map { $0.displayName })
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(BookmarkCell.self, forCellReuseIdentifier: "BookmarkCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView(image: UIImage(systemName: "bookmark.slash"))
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "No Bookmarks"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .systemGray
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Start reading and bookmark your favorite passages"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = .systemGray2
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(imageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        view.isHidden = true
        return view
    }()
    
    // MARK: - Initializers
    init(bookId: String? = nil) {
        self.currentBookId = bookId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadBookmarks()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadBookmarks() // Refresh bookmarks when view appears
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = currentBookId != nil ? "Book Bookmarks" : "All Bookmarks"
        view.backgroundColor = .systemBackground
        
        // Navigation items
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        if currentBookId == nil {
            // Add export button for all bookmarks
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.up"),
                style: .plain,
                target: self,
                action: #selector(exportBookmarks)
            )
        }
        
        // Add close button if presented modally
        if presentingViewController != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeButtonTapped)
            )
        }
        
        // Setup views
        view.addSubview(filterSegmentedControl)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            filterSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            filterSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: filterSegmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.topAnchor.constraint(equalTo: filterSegmentedControl.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        definesPresentationContext = true
    }
    
    // MARK: - Data Loading
    private func loadBookmarks() {
        if let bookId = currentBookId {
            bookmarks = BookmarkManager.shared.getBookmarks(for: bookId)
        } else {
            bookmarks = BookmarkManager.shared.getAllBookmarks()
        }
        
        applyFilter()
        updateEmptyState()
    }
    
    private func applyFilter() {
        var filtered = bookmarks
        
        // Apply type filter
        if let filterType = selectedFilterType {
            filtered = filtered.filter { $0.type == filterType }
        }
        
        // Apply search filter
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            filtered = BookmarkManager.shared.searchBookmarks(searchText)
            if let bookId = currentBookId {
                filtered = filtered.filter { $0.bookId == bookId }
            }
            if let filterType = selectedFilterType {
                filtered = filtered.filter { $0.type == filterType }
            }
        }
        
        filteredBookmarks = filtered
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        let isEmpty = filteredBookmarks.isEmpty
        emptyStateView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }
    
    // MARK: - Actions
    @objc private func filterChanged() {
        if filterSegmentedControl.selectedSegmentIndex == 0 {
            selectedFilterType = nil
        } else {
            selectedFilterType = BookmarkItem.BookmarkType.allCases[filterSegmentedControl.selectedSegmentIndex - 1]
        }
        applyFilter()
    }
    
    @objc private func exportBookmarks() {
        let exportText = BookmarkManager.shared.exportBookmarks(for: currentBookId)
        
        let activityController = UIActivityViewController(
            activityItems: [exportText],
            applicationActivities: nil
        )
        
        if let popover = activityController.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(activityController, animated: true)
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    private func navigateToBookmark(_ bookmark: BookmarkItem) {
        // This would typically navigate back to the reader and jump to the bookmark
        // For now, we'll just dismiss this view
        dismiss(animated: true) {
            // Post notification that bookmark was selected
            NotificationCenter.default.post(
                name: NSNotification.Name("BookmarkSelected"),
                object: bookmark
            )
        }
    }
    
    private func editBookmark(_ bookmark: BookmarkItem) {
        let alert = UIAlertController(title: "Edit Bookmark", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Title"
            textField.text = bookmark.title
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Note (optional)"
            textField.text = bookmark.note
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let titleField = alert.textFields?[0],
                  let noteField = alert.textFields?[1],
                  let title = titleField.text, !title.isEmpty else { return }
            
            let note = noteField.text?.isEmpty == true ? nil : noteField.text
            BookmarkManager.shared.updateBookmark(bookmark, title: title, note: note)
            self?.loadBookmarks()
        }
        
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func deleteBookmark(_ bookmark: BookmarkItem) {
        let alert = UIAlertController(
            title: "Delete Bookmark",
            message: "Are you sure you want to delete \"\(bookmark.title)\"?",
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            BookmarkManager.shared.deleteBookmark(bookmark)
            self?.loadBookmarks()
        }
        
        alert.addAction(deleteAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension BookmarksViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredBookmarks.isEmpty ? 0 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredBookmarks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookmarkCell", for: indexPath) as! BookmarkCell
        let bookmark = filteredBookmarks[indexPath.row]
        cell.configure(with: bookmark)
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if currentBookId != nil {
            return nil // No section header for single book
        }
        
        let count = filteredBookmarks.count
        return "\(count) Bookmark\(count == 1 ? "" : "s")"
    }
}

// MARK: - UITableViewDelegate
extension BookmarksViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let bookmark = filteredBookmarks[indexPath.row]
        navigateToBookmark(bookmark)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let bookmark = filteredBookmarks[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.deleteBookmark(bookmark)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, completion in
            self?.editBookmark(bookmark)
            completion(true)
        }
        editAction.image = UIImage(systemName: "pencil")
        editAction.backgroundColor = .systemBlue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let bookmark = filteredBookmarks[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let goToAction = UIAction(title: "Go to Bookmark", image: UIImage(systemName: "arrow.right")) { [weak self] _ in
                self?.navigateToBookmark(bookmark)
            }
            
            let editAction = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.editBookmark(bookmark)
            }
            
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteBookmark(bookmark)
            }
            
            return UIMenu(title: bookmark.title, children: [goToAction, editAction, deleteAction])
        }
    }
}

// MARK: - UISearchResultsUpdating
extension BookmarksViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        applyFilter()
    }
}