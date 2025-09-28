//
//  OrganizedNotesViewController.swift
//  BookReader
//
//  Enhanced notes view with search, filtering, and organization features
//

import UIKit

// MARK: - Models
enum NoteType {
    case main
    case highlight
    case note
}

enum NoteFilter: Int, CaseIterable {
    case notes
    case highlights

    static var allCases: [NoteFilter] { [.notes, .highlights] }

    var title: String {
        switch self {
        case .notes: return "Notes"
        case .highlights: return "Highlights"
        }
    }
}

enum SortCriteria {
    case date
    case title
}

struct NoteEntry {
    let id: String
    let type: NoteType
    let title: String
    let content: String
    let date: Date
    let tags: [String]
    var highlightColor: UIColor?
    
    var typeDescription: String {
        switch type {
        case .main: return "My Note"
        case .highlight: return "Highlight"
        case .note: return "Saved Note"
        }
    }
}

final class OrganizedNotesViewController: UIViewController {
    
    // MARK: - Properties
    private let bookId: String
    private var bookTitle: String
    private var allNotes: [NoteEntry] = []
    private var filteredNotes: [NoteEntry] = []
    private var currentFilter: NoteFilter = .notes
    private var searchQuery: String = ""
    
    // UI Components
    private let searchController = UISearchController(searchResultsController: nil)
    private let collectionView: UICollectionView
    private let filterBar = NoteFilterBar()
    private let emptyStateView = EmptyStateView()
    private let floatingActionButton = FloatingActionButton()
    
    // Layout
    private var compositionalLayout: UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(200))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(200))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 80, trailing: 16)
        
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
    
    // MARK: - Initialization
    init(bookId: String, bookTitle: String) {
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init(book: Book) {
        self.init(bookId: book.id, bookTitle: book.title)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadNotes()
        registerObservers()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "My Notes"
        
        // Navigation
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(moreOptionsTapped)
        )
        
        // Search setup
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search notes..."
        navigationItem.searchController = searchController
        definesPresentationContext = true
        
        // Collection view setup
        collectionView.collectionViewLayout = compositionalLayout
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(NoteCard.self, forCellWithReuseIdentifier: "NoteCard")
        
        // Filter bar setup
        filterBar.delegate = self
        
        // Layout
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        filterBar.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        floatingActionButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(collectionView)
        view.addSubview(filterBar)
        view.addSubview(emptyStateView)
        view.addSubview(floatingActionButton)
        
        NSLayoutConstraint.activate([
            filterBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            filterBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterBar.heightAnchor.constraint(equalToConstant: 50),
            
            collectionView.topAnchor.constraint(equalTo: filterBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            floatingActionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            floatingActionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        // Configure empty state
        emptyStateView.configure(
            icon: "note.text",
            title: "No Notes Yet",
            subtitle: "Save notes or add highlights to see them here"
        )
        
        // Configure FAB
        floatingActionButton.addTarget(self, action: #selector(createNewNote), for: .touchUpInside)
    }
    
    // MARK: - Data Management
    private func loadNotes() {
        let snapshot = BookNotesManager.shared.snapshot(for: bookId, bookTitle: bookTitle)
        bookTitle = snapshot.bookTitle

        // Load highlights and saved notes
        var entries: [NoteEntry] = []

        // Primary "My Note" entry
        let personalSummary = snapshot.personalSummary
        entries.append(NoteEntry(
            id: "main",
            type: .main,
            title: "My Note",
            content: personalSummary,
            date: snapshot.notesUpdatedAt ?? Date.distantPast,
            tags: []
        ))

        // Load highlights
        let highlights = combinedHighlights(for: bookId)
        for highlight in highlights {
            entries.append(NoteEntry(
                id: highlight.id,
                type: .highlight,
                title: String(highlight.text.prefix(50)) + (highlight.text.count > 50 ? "..." : ""),
                content: highlight.text,
                date: highlight.dateCreated,
                tags: [],
                highlightColor: highlight.color.uiColor
            ))
        }

        // Load saved notes
        let notes = combinedNotes(for: bookId)
        for note in notes {
            entries.append(NoteEntry(
                id: note.id,
                type: .note,
                title: note.title,
                content: note.content,
                date: note.dateModified,
                tags: []
            ))
        }
        
        allNotes = entries.sorted { lhs, rhs in
            switch (lhs.type, rhs.type) {
            case (.main, .main):
                return lhs.date > rhs.date
            case (.main, _):
                return true
            case (_, .main):
                return false
            default:
                return lhs.date > rhs.date
            }
        }
        applyFilters()
    }
    
    private func applyFilters() {
        var filtered = allNotes
        
        // Apply type filter
        filtered = filtered.filter { note in
            switch currentFilter {
            case .notes:
                return note.type == .main || note.type == .note
            case .highlights:
                return note.type == .highlight
            }
        }
        
        // Apply search
        if !searchQuery.isEmpty {
            filtered = filtered.filter { note in
                note.title.localizedCaseInsensitiveContains(searchQuery) ||
                note.content.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        filteredNotes = filtered
        updateUI()
    }

    private func combinedHighlights(for bookId: String) -> [Highlight] {
        var map: [String: Highlight] = [:]
        NotesManager.shared.getHighlights(for: bookId).forEach { map[$0.id] = $0 }
        if let remote = UnifiedFirebaseStorage.shared.books.first(where: { $0.id == bookId }) {
            remote.highlights.forEach { map[$0.id] = $0 }
        }
        return map.values.sorted { $0.dateCreated > $1.dateCreated }
    }

    private func combinedNotes(for bookId: String) -> [Note] {
        var map: [String: Note] = [:]
        NotesManager.shared.getNotes(for: bookId).forEach { map[$0.id] = $0 }
        if let remote = UnifiedFirebaseStorage.shared.books.first(where: { $0.id == bookId }) {
            remote.notes.forEach { map[$0.id] = $0 }
        }
        return map.values.sorted { $0.dateModified > $1.dateModified }
    }
    
    private func updateUI() {
        if filteredNotes.isEmpty {
            switch currentFilter {
            case .notes:
                emptyStateView.configure(icon: "note.text",
                                         title: "No Notes Yet",
                                         subtitle: "Save notes or edit your My Note to see them here")
            case .highlights:
                emptyStateView.configure(icon: "highlighter",
                                         title: "No Highlights Yet",
                                         subtitle: "Add highlights in the reader to keep them together")
            }
            emptyStateView.isHidden = false
        } else {
            emptyStateView.isHidden = true
        }

        collectionView.reloadData()
    }
    
    // MARK: - Actions
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func moreOptionsTapped() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Export All Notes", style: .default) { _ in
            self.exportAllNotes()
        })
        
        alert.addAction(UIAlertAction(title: "Sort by Date", style: .default) { _ in
            self.sortNotes(by: .date)
        })
        
        alert.addAction(UIAlertAction(title: "Sort by Title", style: .default) { _ in
            self.sortNotes(by: .title)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    @objc private func createNewNote() {
        let alert = UIAlertController(title: "New Saved Note", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Title" }
        alert.addTextField { $0.placeholder = "Details" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard
                let self,
                let title = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
                let body = alert.textFields?.last?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty
            else { return }

            NotesManager.shared.addNote(to: self.bookId, title: title, content: body)
            self.loadNotes()
        })
        present(alert, animated: true)
    }
    
    private func exportAllNotes() {
        var exportText = "# \(bookTitle) - Notes Export\n\n"
        exportText += "Exported on: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))\n\n"
        exportText += "---\n\n"
        
        for note in filteredNotes {
            exportText += "## \(note.title)\n"
            let dateString: String
            if note.date == Date.distantPast {
                dateString = "Not saved yet"
            } else {
                dateString = DateFormatter.localizedString(from: note.date, dateStyle: .medium, timeStyle: .none)
            }
            exportText += "_\(note.typeDescription) • \(dateString)_\n\n"
            exportText += "\(note.content)\n\n"
            exportText += "---\n\n"
        }
        
        let activityVC = UIActivityViewController(activityItems: [exportText], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activityVC, animated: true)
    }
    
    private func sortNotes(by criteria: SortCriteria) {
        switch criteria {
        case .date:
            allNotes.sort { $0.date > $1.date }
        case .title:
            allNotes.sort { $0.title < $1.title }
        }
        applyFilters()
    }
    
    // MARK: - Observers
    private func registerObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(notesUpdated), name: .bookNotesUpdated, object: nil)

        let highlightEvents: [Notification.Name] = [.highlightAdded, .highlightUpdated, .highlightRemoved]
        highlightEvents.forEach { nc.addObserver(self, selector: #selector(notesUpdated), name: $0, object: nil) }

        let noteEvents: [Notification.Name] = [.noteAdded, .noteUpdated, .noteRemoved]
        noteEvents.forEach { nc.addObserver(self, selector: #selector(notesUpdated), name: $0, object: nil) }

        nc.addObserver(self, selector: #selector(notesUpdated), name: NSNotification.Name("FirebaseBooksUpdated"), object: nil)
    }
    
    @objc private func notesUpdated() {
        loadNotes()
    }
}

// MARK: - UICollectionView DataSource
extension OrganizedNotesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredNotes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCard", for: indexPath) as! NoteCard
        let note = filteredNotes[indexPath.item]
        cell.configure(with: note)
        return cell
    }
}

// MARK: - UICollectionView Delegate
extension OrganizedNotesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let note = filteredNotes[indexPath.item]
        
        switch note.type {
        case .main:
            presentMyNoteEditor()
        case .note:
            presentSavedNoteOptions(for: note, at: indexPath)
        case .highlight:
            showNoteDetail(note)
        }
    }

    private func showNoteDetail(_ note: NoteEntry) {
        let detailVC = NoteDetailViewController(note: note)
        detailVC.modalPresentationStyle = .pageSheet
        
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(detailVC, animated: true)
    }

    private func presentMyNoteEditor() {
        let editor = EnhancedBookNotesViewController(bookId: bookId, bookTitle: bookTitle)
        let nav = UINavigationController(rootViewController: editor)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func presentSavedNoteOptions(for entry: NoteEntry, at indexPath: IndexPath) {
        let sheet = UIAlertController(title: entry.title, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "View", style: .default) { [weak self] _ in
            self?.showNoteDetail(entry)
        })
        sheet.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.presentSavedNoteEditor(for: entry)
        })
        sheet.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.confirmDeleteSavedNote(for: entry)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = collectionView
            if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
                popover.sourceRect = attributes.frame
            } else {
                popover.sourceRect = collectionView.bounds
            }
        }

        present(sheet, animated: true)
    }

    private func presentSavedNoteEditor(for entry: NoteEntry) {
        guard let note = localNote(withId: entry.id) else {
            presentInfoAlert(title: "Read-only Note", message: "This note is synced from another device. Edit it there to make changes.")
            return
        }

        let alert = UIAlertController(title: "Edit Saved Note", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Title"
            textField.text = note.title
        }
        alert.addTextField { textField in
            textField.placeholder = "Details"
            textField.text = note.content
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard
                let self,
                let title = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
                let content = alert?.textFields?.last?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty
            else { return }

            NotesManager.shared.updateNote(id: note.id,
                                           in: self.bookId,
                                           title: title,
                                           content: content,
                                           tags: note.tags)
            self.loadNotes()
        })
        present(alert, animated: true)
    }

    private func confirmDeleteSavedNote(for entry: NoteEntry) {
        guard let note = localNote(withId: entry.id) else {
            presentInfoAlert(title: "Read-only Note", message: "This note is synced from another device. Delete it there to remove it.")
            return
        }

        let alert = UIAlertController(title: "Delete Note?",
                                      message: "This will permanently remove \(note.title).",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            NotesManager.shared.removeNote(id: note.id, from: self.bookId)
            self.loadNotes()
        })
        present(alert, animated: true)
    }
}

// MARK: - Helpers
private extension OrganizedNotesViewController {
    func localNote(withId id: String) -> Note? {
        return NotesManager.shared.getNotes(for: bookId).first(where: { $0.id == id })
    }

    func presentInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UISearchResultsUpdating
extension OrganizedNotesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchQuery = searchController.searchBar.text ?? ""
        applyFilters()
    }
}

// MARK: - NoteFilterBarDelegate
extension OrganizedNotesViewController: NoteFilterBarDelegate {
    func filterBar(_ filterBar: NoteFilterBar, didSelectFilter filter: NoteFilter) {
        currentFilter = filter
        applyFilters()
    }
}

// MARK: - Note Card Cell
final class NoteCard: UICollectionViewCell {
    private let containerView = UIView()
    private let typeIndicator = UIView()
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let dateLabel = UILabel()
    private let tagStackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.cornerCurve = .continuous
        
        typeIndicator.layer.cornerRadius = 2
        typeIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        
        contentLabel.font = .systemFont(ofSize: 15)
        contentLabel.textColor = .secondaryLabel
        contentLabel.numberOfLines = 3
        
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .tertiaryLabel
        
        tagStackView.axis = .horizontal
        tagStackView.spacing = 6
        tagStackView.distribution = .fillProportionally
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        tagStackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(containerView)
        containerView.addSubview(typeIndicator)
        containerView.addSubview(titleLabel)
        containerView.addSubview(contentLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(tagStackView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            typeIndicator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            typeIndicator.topAnchor.constraint(equalTo: containerView.topAnchor),
            typeIndicator.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            typeIndicator.widthAnchor.constraint(equalToConstant: 4),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 12),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            tagStackView.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            tagStackView.leadingAnchor.constraint(greaterThanOrEqualTo: dateLabel.trailingAnchor, constant: 12),
            tagStackView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
    }
    
    func configure(with note: NoteEntry) {
        titleLabel.text = note.title

        switch note.type {
        case .main:
            typeIndicator.backgroundColor = .systemBlue
            contentLabel.text = note.content.isEmpty ? "Tap to capture your note" : note.content
            if note.date == Date.distantPast {
                dateLabel.text = "Not saved yet"
            } else {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                dateLabel.text = formatter.localizedString(for: note.date, relativeTo: Date())
            }
        case .highlight:
            typeIndicator.backgroundColor = note.highlightColor ?? .systemYellow
            contentLabel.text = note.content
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            dateLabel.text = formatter.localizedString(for: note.date, relativeTo: Date())
        case .note:
            typeIndicator.backgroundColor = .systemOrange
            contentLabel.text = note.content
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            dateLabel.text = formatter.localizedString(for: note.date, relativeTo: Date())
        }

        // Add subtle animation on configuration (skip for read-only placeholder state)
        containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.containerView.transform = .identity
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        tagStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}

// MARK: - Filter Bar
protocol NoteFilterBarDelegate: AnyObject {
    func filterBar(_ filterBar: NoteFilterBar, didSelectFilter filter: NoteFilter)
}

final class NoteFilterBar: UIView {
    weak var delegate: NoteFilterBarDelegate?
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var filterButtons: [UIButton] = []
    private var selectedFilter: NoteFilter = .notes
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillProportionally
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(scrollView)
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -16)
        ])
        
        // Create filter buttons
        for filter in NoteFilter.allCases {
            let button = createFilterButton(for: filter)
            filterButtons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        // Select initial filter
        selectFilter(.notes)
    }
    
    private func createFilterButton(for filter: NoteFilter) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(filter.title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.tag = filter.rawValue
        button.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)
        return button
    }
    
    @objc private func filterButtonTapped(_ sender: UIButton) {
        guard let filter = NoteFilter(rawValue: sender.tag) else { return }
        selectFilter(filter)
        delegate?.filterBar(self, didSelectFilter: filter)
    }
    
    private func selectFilter(_ filter: NoteFilter) {
        selectedFilter = filter
        
        for button in filterButtons {
            let isSelected = button.tag == filter.rawValue
            UIView.animate(withDuration: 0.3) {
                button.backgroundColor = isSelected ? .label : .secondarySystemBackground
                button.tintColor = isSelected ? .systemBackground : .label
            }
        }
    }
}

// MARK: - Empty State View
final class EmptyStateView: UIView {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .tertiaryLabel
        
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .tertiaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        let stack = UIStackView(arrangedSubviews: [iconImageView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    func configure(icon: String, title: String, subtitle: String) {
        iconImageView.image = UIImage(systemName: icon)
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}

// MARK: - Floating Action Button
final class FloatingActionButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .label
        tintColor = .systemBackground
        setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)), for: .normal)
        
        layer.cornerRadius = 28
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 8
        
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 56),
            heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
            }
        }
    }
}

// MARK: - Note Detail View Controller
final class NoteDetailViewController: UIViewController {
    private let note: NoteEntry
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let typeLabel = UILabel()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let contentTextView = UITextView()
    
    init(note: NoteEntry) {
        self.note = note
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        configure()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        typeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        typeLabel.textColor = .secondaryLabel
        
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        
        dateLabel.font = .systemFont(ofSize: 14)
        dateLabel.textColor = .tertiaryLabel
        
        contentTextView.font = .systemFont(ofSize: 17)
        contentTextView.textColor = .label
        contentTextView.isEditable = false
        contentTextView.isScrollEnabled = false
        contentTextView.backgroundColor = .clear
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        [typeLabel, titleLabel, dateLabel, contentTextView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            typeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            typeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: typeLabel.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: typeLabel.trailingAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: typeLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: typeLabel.trailingAnchor),
            
            contentTextView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 24),
            contentTextView.leadingAnchor.constraint(equalTo: typeLabel.leadingAnchor),
            contentTextView.trailingAnchor.constraint(equalTo: typeLabel.trailingAnchor),
            contentTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    private func configure() {
        typeLabel.text = note.typeDescription.uppercased()
        titleLabel.text = note.title
        contentTextView.text = note.content
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        dateLabel.text = formatter.string(from: note.date)
    }
}
