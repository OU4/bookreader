//
//  BookNotesViewController.swift
//  BookReader
//
//  Unified notes surface bringing "My Note" and highlights together.
//

import UIKit

final class BookNotesViewController: UIViewController {
    enum Focus {
        case myNote
        case highlights
    }

    private let bookId: String
    private var bookTitle: String
    private let focus: Focus
    private let onHighlightSelected: ((Highlight) -> Void)?

    private var record: BookNotesRecord
    private var noteDraft: String
    private var highlights: [Highlight] = []
    private var textNotes: [Note] = []

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let noteDisplay = NoteDisplayView()
    private let statusLabel = UILabel()
    private let actionBar = NoteActionBar()
    private let entriesView = NoteEntriesListView()

    private let relativeFormatter = RelativeDateTimeFormatter()

    private var focusApplied = false
    private var observers: [NSObjectProtocol] = []

    // MARK: - Init
    init(bookId: String,
         bookTitle: String,
         initialRecord: BookNotesRecord? = nil,
         focus: Focus = .myNote,
         onHighlightSelected: ((Highlight) -> Void)? = nil) {
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.focus = focus
        self.onHighlightSelected = onHighlightSelected

        let snapshot = initialRecord ?? BookNotesManager.shared.snapshot(for: bookId, bookTitle: bookTitle)
        self.record = snapshot
        self.noteDraft = snapshot.personalSummary
        super.init(nibName: nil, bundle: nil)
    }

    convenience init(book: Book,
                     focus: Focus = .myNote,
                     onHighlightSelected: ((Highlight) -> Void)? = nil) {
        let snapshot = BookNotesManager.shared.snapshot(for: book.id, bookTitle: book.title, fallbackBook: book)
        self.init(bookId: book.id,
                  bookTitle: book.title,
                  initialRecord: snapshot,
                  focus: focus,
                  onHighlightSelected: onHighlightSelected)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        configureNavigation()
        configureLayout()
        configureNoteDisplay()
        configureActionBar()
        configureEntriesView()
        updateStatusLabel()
        updateActionBar()

        loadEntryData()
        registerObservers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !focusApplied {
            focusApplied = true
            switch focus {
            case .myNote:
                break
            case .highlights:
                if entriesView.hasHighlights {
                    entriesView.focus(on: .highlights)
                    scrollToEntriesView()
                }
            }
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Setup
    private func configureNavigation() {
        title = "My Notes"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeTapped))

        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneTapped))
        let exportButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportEntries))
        let addNoteButton = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(addQuickNote))
        navigationItem.rightBarButtonItems = [doneButton, exportButton, addNoteButton]
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 28
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.layoutMargins = UIEdgeInsets(top: 36, left: 24, bottom: 52, right: 24)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        statusLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center

        contentStack.addArrangedSubview(noteDisplay)
        contentStack.addArrangedSubview(statusLabel)
        contentStack.addArrangedSubview(actionBar)
        contentStack.addArrangedSubview(entriesView)
    }

    private func configureNoteDisplay() {
        noteDisplay.configure(placeholder: "Tap to add your perspective on this book",
                              text: noteDraft) { [weak self] in
            self?.presentEditor()
        }
    }

    private func configureActionBar() {
        actionBar.configure(onEdit: { [weak self] in self?.presentEditor() },
                            onShare: { [weak self] in self?.shareNote() },
                            onCopy: { [weak self] in self?.copyNote() },
                            onClear: { [weak self] in self?.confirmClear() })
    }

    private func configureEntriesView() {
        entriesView.configure(onHighlightSelect: { [weak self] highlight in
            guard let self else { return }
            self.dismiss(animated: true) {
                self.onHighlightSelected?(highlight)
            }
        }, onNoteSelect: { [weak self] note in
            self?.presentTextNoteDetail(note)
        })
    }

    private func registerObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .bookNotesUpdated, object: nil, queue: .main) { [weak self] notification in
            guard
                let self,
                let updatedBookId = notification.userInfo?["bookId"] as? String,
                updatedBookId == self.bookId,
                let updatedRecord = notification.userInfo?["record"] as? BookNotesRecord
            else { return }

            self.applyUpdatedRecord(updatedRecord)
        })

        let highlightEvents: [Notification.Name] = [.highlightAdded, .highlightUpdated, .highlightRemoved]
        for name in highlightEvents {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let self, (notification.userInfo?["bookId"] as? String) == self.bookId else { return }
                self.loadEntryData()
            })
        }

        let noteEvents: [Notification.Name] = [.noteAdded, .noteUpdated, .noteRemoved]
        for name in noteEvents {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let self, (notification.userInfo?["bookId"] as? String) == self.bookId else { return }
                self.loadEntryData()
            })
        }

        observers.append(center.addObserver(forName: NSNotification.Name("FirebaseBooksUpdated"), object: nil, queue: .main) { [weak self] _ in
            self?.loadEntryData()
        })
    }

    // MARK: - Data
    private func loadEntryData() {
        highlights = combinedHighlights(for: bookId)
        textNotes = combinedNotes(for: bookId)
        entriesView.update(highlights: highlights, notes: textNotes)
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

    private func updateStatusLabel() {
        let subtitle: String
        if let updated = record.notesUpdatedAt {
            subtitle = "Last updated " + relativeFormatter.localizedString(for: updated, relativeTo: Date())
        } else {
            subtitle = "Nothing saved yet"
        }
        statusLabel.text = subtitle.uppercased()
    }

    private func updateActionBar() {
        let isEmpty = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        actionBar.update(isNoteEmpty: isEmpty)
    }

    private func applyUpdatedRecord(_ updated: BookNotesRecord) {
        record = updated
        bookTitle = updated.bookTitle
        noteDraft = updated.personalSummary
        noteDisplay.update(text: noteDraft)
        updateStatusLabel()
        updateActionBar()
    }

    // MARK: - Actions
    @objc private func doneTapped() {
        persistNotes()
        dismiss(animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func exportEntries() {
        let content = NotesManager.shared.exportNotesAndHighlights(for: bookId, format: .markdown)
        let activityVC = UIActivityViewController(activityItems: [content], applicationActivities: nil)
        present(activityVC, animated: true)
    }

    @objc private func addQuickNote() {
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
            self.loadEntryData()
        })
        present(alert, animated: true)
    }

    private func presentEditor() {
        let editor = NotesTextEditorViewController(title: "My Note",
                                                   initialText: noteDraft,
                                                   placeholder: "Write what stood out to you")
        editor.onSave = { [weak self] text in
            guard let self else { return }
            noteDraft = text
            noteDisplay.update(text: text)
            updateActionBar()
            persistNotes()
        }
        let nav = UINavigationController(rootViewController: editor)
        present(nav, animated: true)
    }

    private func shareNote() {
        let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            presentSimpleAlert(title: "Nothing to Share", message: "Add a note first, then try sharing again.")
            return
        }
        let text = "# \(bookTitle)\n\n\(trimmed)"
        present(UIActivityViewController(activityItems: [text], applicationActivities: nil), animated: true)
    }

    private func copyNote() {
        let trimmed = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            presentSimpleAlert(title: "Nothing to Copy", message: "Add a note first, then copy it.")
            return
        }
        UIPasteboard.general.string = trimmed
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        presentToast("Note copied to clipboard")
    }

    private func confirmClear() {
        guard !noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let alert = UIAlertController(title: "Clear My Note?",
                                      message: "This will remove the text you saved for this book.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.clearNote()
        })
        present(alert, animated: true)
    }

    private func clearNote() {
        noteDraft = ""
        noteDisplay.update(text: "")
        updateActionBar()
        persistNotes()
        presentToast("Cleared")
    }

    private func presentTextNoteDetail(_ note: Note) {
        let detail = UIAlertController(title: note.title, message: note.content, preferredStyle: .alert)
        detail.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(detail, animated: true)
    }

    private func persistNotes() {
        BookNotesManager.shared.updateNotes(for: bookId,
                                            bookTitle: bookTitle,
                                            summary: noteDraft,
                                            takeaways: "",
                                            actionItems: "")
    }

    private func scrollToEntriesView() {
        let targetFrame = scrollView.convert(entriesView.frame, from: entriesView.superview)
        scrollView.scrollRectToVisible(targetFrame.insetBy(dx: 0, dy: -32), animated: true)
    }
}

// MARK: - View Components
private final class NoteDisplayView: UIControl {
    private let badgeLabel = UILabel()
    private let bodyLabel = UILabel()
    private let placeholderLabel = UILabel()
    private let hintStack = UIStackView()

    private var tapHandler: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous

        badgeLabel.text = "MY NOTE"
        badgeLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        badgeLabel.textColor = .systemBlue

        bodyLabel.font = UIFont.preferredFont(forTextStyle: .title3)
        bodyLabel.textColor = .label
        bodyLabel.numberOfLines = 0

        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .title3)
        placeholderLabel.textColor = .tertiaryLabel
        placeholderLabel.numberOfLines = 0

        let icon = UIImageView(image: UIImage(systemName: "square.and.pencil"))
        icon.tintColor = .tertiaryLabel
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let hintLabel = UILabel()
        hintLabel.text = "Tap to edit"
        hintLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        hintLabel.textColor = .tertiaryLabel

        hintStack.axis = .horizontal
        hintStack.alignment = .center
        hintStack.spacing = 6
        hintStack.addArrangedSubview(icon)
        hintStack.addArrangedSubview(hintLabel)

        let stack = UIStackView(arrangedSubviews: [badgeLabel, bodyLabel, placeholderLabel, hintStack])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28)
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(placeholder: String, text: String, onTap: @escaping () -> Void) {
        placeholderLabel.text = placeholder
        update(text: text)
        tapHandler = onTap
        accessibilityTraits = .button
        accessibilityLabel = "My Note"
    }

    func update(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmed.isEmpty
        bodyLabel.text = hasText ? trimmed : nil
        bodyLabel.isHidden = !hasText
        placeholderLabel.isHidden = hasText
        accessibilityValue = trimmed
    }

    @objc private func handleTap() {
        tapHandler?()
    }
}

private final class NoteActionBar: UIView {
    var onEdit: (() -> Void)?
    var onShare: (() -> Void)?
    var onCopy: (() -> Void)?
    var onClear: (() -> Void)?

    private let editButton = ActionButton(title: "Edit", imageName: "square.and.pencil")
    private let shareButton = ActionButton(title: "Share", imageName: "square.and.arrow.up")
    private let copyButton = ActionButton(title: "Copy", imageName: "doc.on.doc")
    private let clearButton = ActionButton(title: "Clear", imageName: "trash")

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        shareButton.configuration?.baseForegroundColor = .systemBlue
        copyButton.configuration?.baseForegroundColor = .systemTeal
        clearButton.configuration?.baseForegroundColor = .systemRed

        let stack = UIStackView(arrangedSubviews: [editButton, shareButton, copyButton, clearButton])
        stack.axis = .horizontal
        stack.spacing = 16
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(onEdit: @escaping () -> Void,
                   onShare: @escaping () -> Void,
                   onCopy: @escaping () -> Void,
                   onClear: @escaping () -> Void) {
        self.onEdit = onEdit
        self.onShare = onShare
        self.onCopy = onCopy
        self.onClear = onClear
    }

    func update(isNoteEmpty: Bool) {
        shareButton.isEnabled = !isNoteEmpty
        copyButton.isEnabled = !isNoteEmpty
        clearButton.isEnabled = !isNoteEmpty
        let alpha: CGFloat = isNoteEmpty ? 0.35 : 1
        shareButton.alpha = alpha
        copyButton.alpha = alpha
        clearButton.alpha = alpha
    }

    @objc private func editTapped() { onEdit?() }
    @objc private func shareTapped() { onShare?() }
    @objc private func copyTapped() { onCopy?() }
    @objc private func clearTapped() { onClear?() }

    private final class ActionButton: UIButton {
        init(title: String, imageName: String) {
            super.init(frame: .zero)
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: imageName)
            config.title = title
            config.imagePlacement = .top
            config.imagePadding = 6
            config.baseForegroundColor = .label
            configuration = config
            translatesAutoresizingMaskIntoConstraints = false
            heightAnchor.constraint(equalToConstant: 64).isActive = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

private final class NoteEntriesListView: UIView, UITableViewDataSource, UITableViewDelegate {
    enum Segment: Int {
        case highlights
        case notes
    }

    private var highlights: [Highlight] = []
    private var notes: [Note] = []

    private let headerLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["Highlights", "Saved Notes"])
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var tableHeightConstraint: NSLayoutConstraint?

    private var onHighlightSelect: ((Highlight) -> Void)?
    private var onNoteSelect: ((Note) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        headerLabel.text = "Notebook"
        headerLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        headerLabel.textColor = .label

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false
        tableView.backgroundColor = .clear
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.register(EntryCell.self, forCellReuseIdentifier: "EntryCell")

        let stack = UIStackView(arrangedSubviews: [headerLabel, segmentedControl, tableView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        tableHeightConstraint?.isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(onHighlightSelect: @escaping (Highlight) -> Void,
                   onNoteSelect: @escaping (Note) -> Void) {
        self.onHighlightSelect = onHighlightSelect
        self.onNoteSelect = onNoteSelect
    }

    func update(highlights: [Highlight], notes: [Note]) {
        self.highlights = highlights
        self.notes = notes
        tableView.reloadData()
        tableView.layoutIfNeeded()
        tableHeightConstraint?.constant = tableView.contentSize.height
    }

    func focus(on segment: Segment) {
        segmentedControl.selectedSegmentIndex = segment.rawValue
        segmentChanged()
    }

    var hasHighlights: Bool { !highlights.isEmpty }
    var hasNotes: Bool { !notes.isEmpty }

    @objc private func segmentChanged() {
        tableView.reloadData()
        tableView.layoutIfNeeded()
        tableHeightConstraint?.constant = tableView.contentSize.height
    }

    private var currentSegment: Segment {
        Segment(rawValue: segmentedControl.selectedSegmentIndex) ?? .highlights
    }

    private var entries: [Any] {
        switch currentSegment {
        case .highlights:
            return highlights
        case .notes:
            return notes
        }
    }

    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = entries.count
        return count == 0 ? 1 : count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "EntryCell", for: indexPath) as? EntryCell else {
            return UITableViewCell()
        }

        if entries.isEmpty {
            cell.textLabel?.text = currentSegment == .highlights ? "No highlights yet" : "No saved notes yet"
            cell.textLabel?.textColor = .secondaryLabel
            cell.detailTextLabel?.text = nil
            cell.selectionStyle = .none
            return cell
        }

        switch currentSegment {
        case .highlights:
            guard let highlight = entries[indexPath.row] as? Highlight else { return cell }
            cell.textLabel?.text = highlight.text
            cell.textLabel?.textColor = .label
            let formatted = DateFormatter.shortDateFormatter.string(from: highlight.dateCreated)
            cell.detailTextLabel?.text = formatted
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.imageView?.image = UIImage(systemName: "highlighter")?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = highlight.color.uiColor
        case .notes:
            guard let note = entries[indexPath.row] as? Note else { return cell }
            cell.textLabel?.text = note.title
            cell.textLabel?.textColor = .label
            cell.detailTextLabel?.text = note.content
            cell.detailTextLabel?.textColor = .secondaryLabel
            cell.imageView?.image = UIImage(systemName: "note.text")?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = .systemOrange
        }

        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !entries.isEmpty else { return }
        switch currentSegment {
        case .highlights:
            if let highlight = entries[indexPath.row] as? Highlight {
                onHighlightSelect?(highlight)
            }
        case .notes:
            if let note = entries[indexPath.row] as? Note {
                onNoteSelect?(note)
            }
        }
    }
}

// MARK: - Helpers
private extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private final class EntryCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        textLabel?.numberOfLines = 0
        textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        detailTextLabel?.numberOfLines = 0
        detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        backgroundColor = .clear
        selectionStyle = .default
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Alert & Toast Helpers
private extension BookNotesViewController {
    func presentSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func presentToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        toast.font = UIFont.preferredFont(forTextStyle: .caption1)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 12
        toast.layer.masksToBounds = true
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24)
        ])

        toast.layoutIfNeeded()

        UIView.animate(withDuration: 0.2, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.2, options: .curveEaseInOut, animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}
