//
//  NotesAndHighlightsViewController.swift
//  BookReader
//
//  View controller to display and manage notes and highlights
//

import UIKit

class NotesAndHighlightsViewController: UIViewController {
    
    // MARK: - Properties
    private let bookId: String
    private var highlights: [Highlight] = []
    private var notes: [Note] = []
    private var filteredHighlights: [Highlight] = []
    private var filteredNotes: [Note] = []
    private var currentSegment: Int = 0
    
    // MARK: - UI Components
    private lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Highlights", "Notes", "All"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search notes and highlights..."
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(HighlightCell.self, forCellReuseIdentifier: "HighlightCell")
        tableView.register(NoteCell.self, forCellReuseIdentifier: "NoteCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private lazy var exportButton: UIBarButtonItem = {
        return UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportNotesAndHighlights)
        )
    }()
    
    private lazy var addNoteButton: UIBarButtonItem = {
        return UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addNewNote)
        )
    }()
    
    // MARK: - Initialization
    init(bookId: String) {
        self.bookId = bookId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
        setupNotifications()
        setupFirebaseListener()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Notes & Highlights"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissViewController)
        )
        
        // Add refresh button
        let refreshButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshData)
        )
        
        navigationItem.rightBarButtonItems = [exportButton, addNoteButton, refreshButton]
        
        view.addSubview(segmentedControl)
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            searchBar.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(highlightAdded),
            name: .highlightAdded,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(noteAdded),
            name: .noteAdded,
            object: nil
        )
    }
    
    private func setupFirebaseListener() {
        // Listen for Firebase books updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(firebaseBooksUpdated),
            name: NSNotification.Name("FirebaseBooksUpdated"),
            object: nil
        )
    }
    
    @objc private func firebaseBooksUpdated() {
        print("🔄 Firebase books updated, reloading highlights...")
        loadData()
    }
    
    @objc private func refreshData() {
        print("🔄 Manual refresh triggered")
        loadData()
    }
    
    // MARK: - Data Loading
    private func loadData() {
        // Load highlights from Firebase first
        loadHighlightsFromFirebase()
        
        // Load notes from NotesManager (keeping this for now)
        notes = NotesManager.shared.getNotes(for: bookId)
        updateFilteredData()
    }
    
    private func loadHighlightsFromFirebase() {
        // Get highlights from UnifiedFirebaseStorage
        let firebaseBooks = UnifiedFirebaseStorage.shared.books
        print("🔍 Looking for book ID: \(bookId)")
        print("🔍 Available books in Firebase: \(firebaseBooks.map { $0.id })")
        
        if let book = firebaseBooks.first(where: { $0.id == bookId }) {
            highlights = book.highlights
            print("📚 Loaded \(highlights.count) highlights from Firebase for book \(bookId)")
        } else {
            highlights = []
            print("⚠️ No book found in Firebase with ID \(bookId)")
            print("⚠️ Available book IDs: \(firebaseBooks.map { $0.id })")
            
            // Try to find book with similar title as fallback
            if let currentBookTitle = getCurrentBookTitle() {
                print("🔍 Trying to match by title: \(currentBookTitle)")
                if let matchedBook = firebaseBooks.first(where: { $0.title == currentBookTitle }) {
                    highlights = matchedBook.highlights
                    print("📚 Found book by title match: \(matchedBook.id) with \(highlights.count) highlights")
                }
            }
        }
        
        // Also load highlights from local NotesManager for compatibility
        let localHighlights = NotesManager.shared.getHighlights(for: bookId)
        print("📚 Loaded \(localHighlights.count) local highlights from NotesManager")
        
        // Merge highlights (avoid duplicates by checking text and position)
        for localHighlight in localHighlights {
            let isDuplicate = highlights.contains { firebaseHighlight in
                firebaseHighlight.text == localHighlight.text &&
                firebaseHighlight.position.startOffset == localHighlight.position.startOffset
            }
            
            if !isDuplicate {
                highlights.append(localHighlight)
            }
        }
        
        print("📚 Total highlights after merging: \(highlights.count)")
    }
    
    private func getCurrentBookTitle() -> String? {
        // Try to get the current book title from various sources
        if let bookTitle = UserDefaults.standard.string(forKey: "currentBookTitle") {
            return bookTitle
        }
        
        // Could also try to extract from any other available source
        return nil
    }
    
    private func updateFilteredData() {
        let searchText = searchBar.text?.lowercased() ?? ""
        
        if searchText.isEmpty {
            filteredHighlights = highlights
            filteredNotes = notes
        } else {
            filteredHighlights = highlights.filter { highlight in
                highlight.text.lowercased().contains(searchText) ||
                highlight.note?.lowercased().contains(searchText) ?? false
            }
            
            filteredNotes = notes.filter { note in
                note.title.lowercased().contains(searchText) ||
                note.content.lowercased().contains(searchText) ||
                note.tags.contains { $0.lowercased().contains(searchText) }
            }
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Actions
    @objc private func dismissViewController() {
        dismiss(animated: true)
    }
    
    @objc private func segmentChanged() {
        currentSegment = segmentedControl.selectedSegmentIndex
        tableView.reloadData()
    }
    
    @objc private func exportNotesAndHighlights() {
        let alert = UIAlertController(title: "Export Format", message: nil, preferredStyle: .actionSheet)
        
        for format in ExportFormat.allCases {
            alert.addAction(UIAlertAction(title: format.displayName, style: .default) { [weak self] _ in
                self?.exportInFormat(format)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = exportButton
        }
        
        present(alert, animated: true)
    }
    
    @objc private func addNewNote() {
        let alert = UIAlertController(title: "New Note", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Note title"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Note content"
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let title = alert.textFields?[0].text, !title.isEmpty,
                  let content = alert.textFields?[1].text, !content.isEmpty else { return }
            
            NotesManager.shared.addNote(to: self.bookId, title: title, content: content)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func highlightAdded(_ notification: Notification) {
        if let bookId = notification.userInfo?["bookId"] as? String,
           bookId == self.bookId {
            loadData()
        }
    }
    
    @objc private func noteAdded(_ notification: Notification) {
        if let bookId = notification.userInfo?["bookId"] as? String,
           bookId == self.bookId {
            loadData()
        }
    }
    
    // MARK: - Export
    private func exportInFormat(_ format: ExportFormat) {
        let content = NotesManager.shared.exportNotesAndHighlights(for: bookId, format: format)
        
        let activityVC = UIActivityViewController(activityItems: [content], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = exportButton
        }
        
        present(activityVC, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate
extension NotesAndHighlightsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        switch currentSegment {
        case 0: return filteredHighlights.isEmpty ? 0 : 1 // Highlights only
        case 1: return filteredNotes.isEmpty ? 0 : 1 // Notes only
        case 2: return 2 // Both highlights and notes
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentSegment {
        case 0: return filteredHighlights.count
        case 1: return filteredNotes.count
        case 2:
            if section == 0 {
                return filteredHighlights.count
            } else {
                return filteredNotes.count
            }
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch currentSegment {
        case 0: 
            if filteredHighlights.isEmpty {
                return "No Highlights Found - Tap Refresh ↻"
            } else {
                return "Highlights (\(filteredHighlights.count))"
            }
        case 1: 
            return filteredNotes.isEmpty ? nil : "Notes (\(filteredNotes.count))"
        case 2:
            if section == 0 {
                if filteredHighlights.isEmpty {
                    return "No Highlights Found - Tap Refresh ↻"
                } else {
                    return "Highlights (\(filteredHighlights.count))"
                }
            } else {
                return filteredNotes.isEmpty ? nil : "Notes (\(filteredNotes.count))"
            }
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch currentSegment {
        case 0: // Highlights only
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "HighlightCell", for: indexPath) as? HighlightCell else {
                fatalError("Failed to dequeue HighlightCell")
            }
            cell.configure(with: filteredHighlights[indexPath.row])
            return cell
            
        case 1: // Notes only
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as? NoteCell else {
                fatalError("Failed to dequeue NoteCell")
            }
            cell.configure(with: filteredNotes[indexPath.row])
            return cell
            
        case 2: // Both
            if indexPath.section == 0 {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "HighlightCell", for: indexPath) as? HighlightCell else {
                fatalError("Failed to dequeue HighlightCell")
            }
                cell.configure(with: filteredHighlights[indexPath.row])
                return cell
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as? NoteCell else {
                fatalError("Failed to dequeue NoteCell")
            }
                cell.configure(with: filteredNotes[indexPath.row])
                return cell
            }
            
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Show detailed view or edit options
        switch currentSegment {
        case 0: // Highlight selected
            let highlight = filteredHighlights[indexPath.row]
            showHighlightOptions(for: highlight)
            
        case 1: // Note selected
            let note = filteredNotes[indexPath.row]
            showNoteOptions(for: note)
            
        case 2: // Both
            if indexPath.section == 0 {
                let highlight = filteredHighlights[indexPath.row]
                showHighlightOptions(for: highlight)
            } else {
                let note = filteredNotes[indexPath.row]
                showNoteOptions(for: note)
            }
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            switch currentSegment {
            case 0: // Delete highlight
                let highlight = filteredHighlights[indexPath.row]
                NotesManager.shared.removeHighlight(id: highlight.id, from: bookId)
                loadData()
                
            case 1: // Delete note
                let note = filteredNotes[indexPath.row]
                NotesManager.shared.removeNote(id: note.id, from: bookId)
                loadData()
                
            case 2: // Delete from either section
                if indexPath.section == 0 {
                    let highlight = filteredHighlights[indexPath.row]
                    NotesManager.shared.removeHighlight(id: highlight.id, from: bookId)
                } else {
                    let note = filteredNotes[indexPath.row]
                    NotesManager.shared.removeNote(id: note.id, from: bookId)
                }
                loadData()
            default:
                break
            }
        }
    }
    
    // MARK: - Options
    private func showHighlightOptions(for highlight: Highlight) {
        let alert = UIAlertController(title: "Highlight Options", message: highlight.text, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Add Note", style: .default) { [weak self] _ in
            self?.addNoteToHighlight(highlight)
        })
        
        alert.addAction(UIAlertAction(title: "Copy Text", style: .default) { _ in
            UIPasteboard.general.string = highlight.text
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            UnifiedFirebaseStorage.shared.removeHighlight(bookId: self.bookId, highlightId: highlight.id) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Highlight deleted successfully")
                        self.loadData()
                    case .failure(let error):
                        print("❌ Failed to delete highlight: \(error)")
                        let errorAlert = UIAlertController(title: "Error", message: "Failed to delete highlight: \(error.localizedDescription)", preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showNoteOptions(for note: Note) {
        let alert = UIAlertController(title: "Note Options", message: note.title, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.editNote(note)
        })
        
        alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = "\(note.title)\n\n\(note.content)"
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            NotesManager.shared.removeNote(id: note.id, from: self?.bookId ?? "")
            self?.loadData()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func addNoteToHighlight(_ highlight: Highlight) {
        let alert = UIAlertController(title: "Add Note to Highlight", message: highlight.text, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Your note..."
            textField.text = highlight.note
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let noteText = alert.textFields?.first?.text ?? ""
            
            // Create updated highlight with new note
            let updatedHighlight = Highlight(
                id: highlight.id,
                text: highlight.text,
                color: highlight.color,
                position: highlight.position,
                note: noteText.isEmpty ? nil : noteText,
                dateCreated: highlight.dateCreated
            )
            
            // Update in Firebase
            UnifiedFirebaseStorage.shared.updateHighlight(updatedHighlight, bookId: self.bookId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Note added to highlight successfully")
                        self.loadData()
                    case .failure(let error):
                        print("❌ Failed to add note: \(error)")
                        let errorAlert = UIAlertController(title: "Error", message: "Failed to save note: \(error.localizedDescription)", preferredStyle: .alert)
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func editNote(_ note: Note) {
        let alert = UIAlertController(title: "Edit Note", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Note title"
            textField.text = note.title
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Note content"
            textField.text = note.content
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let title = alert.textFields?[0].text, !title.isEmpty,
                  let content = alert.textFields?[1].text, !content.isEmpty else { return }
            
            NotesManager.shared.updateNote(id: note.id, in: self?.bookId ?? "", title: title, content: content, tags: note.tags)
            self?.loadData()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension NotesAndHighlightsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateFilteredData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}