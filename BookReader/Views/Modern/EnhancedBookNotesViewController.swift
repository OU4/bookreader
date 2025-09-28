//
//  EnhancedBookNotesViewController.swift
//  BookReader
//
//  Enhanced My Notes tab with improved UI/UX for better reading and editing experience
//

import UIKit

final class EnhancedBookNotesViewController: UIViewController {
    enum ViewMode {
        case reading
        case editing
    }
    
    private let bookId: String
    private var bookTitle: String
    private var record: BookNotesRecord
    private var originalNote: String
    private var noteDraft: String
    private var currentMode: ViewMode = .reading
    private var shouldPersistOnDismiss = true
    
    // UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let headerView = NoteHeaderView()
    private let noteContainerView = UIView()
    private let readingView = EnhancedReadingView()
    private let editingView = EnhancedEditingView()

    private lazy var editButton = UIBarButtonItem(title: "Edit",
                                                  style: .plain,
                                                  target: self,
                                                  action: #selector(editTapped))
    private lazy var doneButton = UIBarButtonItem(title: "Done",
                                                  style: .done,
                                                  target: self,
                                                  action: #selector(doneTapped))
    private lazy var deleteButton = UIBarButtonItem(barButtonSystemItem: .trash,
                                                     target: self,
                                                     action: #selector(deleteTapped))
    
    // Constraints
    private var readingViewConstraints: [NSLayoutConstraint] = []
    private var editingViewConstraints: [NSLayoutConstraint] = []
    private var noteContainerMaxHeightConstraint: NSLayoutConstraint?
    
    private let relativeFormatter = RelativeDateTimeFormatter()
    private var observers: [NSObjectProtocol] = []
    private var keyboardHeight: CGFloat = 0
    
    // MARK: - Init
    init(bookId: String, bookTitle: String, initialRecord: BookNotesRecord? = nil) {
        self.bookId = bookId
        self.bookTitle = bookTitle
        
        let snapshot = initialRecord ?? BookNotesManager.shared.snapshot(for: bookId, bookTitle: bookTitle)
        self.record = snapshot
        self.originalNote = snapshot.personalSummary
        self.noteDraft = snapshot.personalSummary
        self.currentMode = snapshot.personalSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .editing : .reading

        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init(book: Book) {
        let snapshot = BookNotesManager.shared.snapshot(for: book.id, bookTitle: book.title, fallbackBook: book)
        self.init(bookId: book.id, bookTitle: book.title, initialRecord: snapshot)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupUI()
        configureInitialState()
        registerObservers()
        
        // Start in reading mode unless note is empty
        if noteDraft.isEmpty {
            currentMode = .editing
        } else {
            currentMode = .reading
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateViewForMode(animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if currentMode == .editing && shouldPersistOnDismiss {
            saveNote()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let maxHeightConstraint = noteContainerMaxHeightConstraint else { return }
        let topInset = view.safeAreaInsets.top
        let bottomInset = view.safeAreaInsets.bottom + (currentMode == .editing ? keyboardHeight : 0)
        let totalPadding = topInset + bottomInset + 80
        let viewHeight = view.bounds.height
        let targetHeight = max(viewHeight - totalPadding, 320)
        maxHeightConstraint.constant = targetHeight - viewHeight
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "My Notes"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(closeTapped))
        deleteButton.tintColor = .systemRed
        
        // Scroll view setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Note container setup
        noteContainerView.translatesAutoresizingMaskIntoConstraints = false
        noteContainerView.backgroundColor = .secondarySystemBackground
        noteContainerView.layer.cornerRadius = 16
        noteContainerView.layer.cornerCurve = .continuous
        
        // Configure subviews
        headerView.translatesAutoresizingMaskIntoConstraints = false
        readingView.translatesAutoresizingMaskIntoConstraints = false
        editingView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headerView)
        contentView.addSubview(noteContainerView)
        noteContainerView.addSubview(readingView)
        noteContainerView.addSubview(editingView)

        // Layout constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            noteContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            noteContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            noteContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            noteContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])

        noteContainerMaxHeightConstraint = noteContainerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, constant: -80)
        noteContainerMaxHeightConstraint?.priority = .defaultHigh
        noteContainerMaxHeightConstraint?.isActive = true

        // Mode-specific constraints
        readingViewConstraints = [
            readingView.topAnchor.constraint(equalTo: noteContainerView.topAnchor),
            readingView.leadingAnchor.constraint(equalTo: noteContainerView.leadingAnchor),
            readingView.trailingAnchor.constraint(equalTo: noteContainerView.trailingAnchor),
            readingView.bottomAnchor.constraint(equalTo: noteContainerView.bottomAnchor)
        ]
        
        editingViewConstraints = [
            editingView.topAnchor.constraint(equalTo: noteContainerView.topAnchor),
            editingView.leadingAnchor.constraint(equalTo: noteContainerView.leadingAnchor),
            editingView.trailingAnchor.constraint(equalTo: noteContainerView.trailingAnchor),
            editingView.bottomAnchor.constraint(equalTo: noteContainerView.bottomAnchor),
            editingView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ]
        
        // Activate initial constraints based on mode
        if currentMode == .reading {
            NSLayoutConstraint.activate(readingViewConstraints)
            readingView.alpha = 1
            editingView.alpha = 0
        } else {
            NSLayoutConstraint.activate(editingViewConstraints)
            readingView.alpha = 0
            editingView.alpha = 1
        }
    }
    
    private func configureInitialState() {
        headerView.configure(title: bookTitle, subtitle: formatLastUpdated())
        readingView.configure(text: noteDraft)
        editingView.configure(text: noteDraft, placeholder: "Start writing your thoughts about this book...")
        
        readingView.onTap = { [weak self] in
            self?.switchToEditMode()
        }
        
        editingView.onTextChange = { [weak self] text in
            self?.noteDraft = text
            self?.headerView.updateSubtitle("Editing...")
            self?.updateNavigationButtons()
        }
        
        updateNavigationButtons()
    }
    
    // MARK: - Mode Management
    private func updateViewForMode(animated: Bool) {
        let updates = {
            switch self.currentMode {
            case .reading:
                self.readingView.alpha = 1
                self.editingView.alpha = 0
                NSLayoutConstraint.deactivate(self.editingViewConstraints)
                NSLayoutConstraint.activate(self.readingViewConstraints)
                self.editingView.resignFirstResponder()
                self.scrollView.isScrollEnabled = true
                self.noteContainerMaxHeightConstraint?.isActive = false

            case .editing:
                self.readingView.alpha = 0
                self.editingView.alpha = 1
                NSLayoutConstraint.deactivate(self.readingViewConstraints)
                NSLayoutConstraint.activate(self.editingViewConstraints)
                self.editingView.becomeFirstResponder()
                self.scrollView.isScrollEnabled = false
                self.noteContainerMaxHeightConstraint?.isActive = true
                DispatchQueue.main.async {
                    self.editingView.flashScrollIndicators()
                }
            }

            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: updates)
        } else {
            updates()
        }

        updateNavigationButtons()
    }

    private func updateNavigationButtons() {
        switch currentMode {
        case .reading:
            navigationItem.rightBarButtonItems = [editButton]

        case .editing:
            let isEmpty = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            deleteButton.isEnabled = !isEmpty
            if isEmpty {
                navigationItem.rightBarButtonItems = [doneButton]
            } else {
                navigationItem.rightBarButtonItems = [doneButton, deleteButton]
            }
        }
    }
    
    private func switchToEditMode() {
        currentMode = .editing
        updateViewForMode(animated: true)
    }
    
    private func switchToReadMode() {
        currentMode = .reading
        readingView.updateText(noteDraft)
        saveNote()
        updateViewForMode(animated: true)
        scrollView.isScrollEnabled = true
        DispatchQueue.main.async { [weak self] in
            self?.scrollView.flashScrollIndicators()
        }
    }
    
    // MARK: - Actions
    @objc private func doneTapped() {
        finishEditing()
    }

    @objc private func deleteTapped() {
        confirmDelete()
    }
    
    @objc private func editTapped() {
        switchToEditMode()
    }

    @objc private func closeTapped() {
        shouldPersistOnDismiss = false
        noteDraft = originalNote
        editingView.updateText(originalNote)
        readingView.updateText(originalNote)
        updateNavigationButtons()
        dismiss(animated: true)
    }

    private func finishEditing() {
        saveNote()
        shouldPersistOnDismiss = false
        dismiss(animated: true)
    }

    private func confirmDelete() {
        guard !noteDraft.isEmpty else { return }
        
        let alert = UIAlertController(
            title: "Delete Note?",
            message: "This will permanently delete your note for this book.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteNote()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteNote() {
        noteDraft = ""
        readingView.updateText("")
        editingView.updateText("")
        saveNote()
        headerView.updateSubtitle("Note deleted")
        updateNavigationButtons()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.headerView.updateSubtitle(self.formatLastUpdated())
        }
    }
    
    // MARK: - Data Management
    private func saveNote() {
        BookNotesManager.shared.updateNotes(
            for: bookId,
            bookTitle: bookTitle,
            summary: noteDraft,
            takeaways: "",
            actionItems: ""
        )
        
        record.personalSummary = noteDraft
        record.notesUpdatedAt = Date()
        headerView.updateSubtitle(formatLastUpdated())
        originalNote = noteDraft
    }
    
    private func formatLastUpdated() -> String {
        if let updated = record.notesUpdatedAt {
            return "Last updated " + relativeFormatter.localizedString(for: updated, relativeTo: Date())
        }
        return "Start writing to save"
    }
    
    // MARK: - Observers
    private func registerObservers() {
        let nc = NotificationCenter.default
        
        observers.append(nc.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboardShow(notification)
        })
        
        observers.append(nc.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleKeyboardHide()
        })
        
        observers.append(nc.addObserver(
            forName: .bookNotesUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let updatedBookId = notification.userInfo?["bookId"] as? String,
                updatedBookId == self.bookId,
                let updatedRecord = notification.userInfo?["record"] as? BookNotesRecord
            else { return }
            
            self.record = updatedRecord
            self.noteDraft = updatedRecord.personalSummary
            self.originalNote = updatedRecord.personalSummary
            self.readingView.updateText(self.noteDraft)
            self.headerView.updateSubtitle(self.formatLastUpdated())
            self.updateNavigationButtons()
        })
    }
    
    private func handleKeyboardShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let convertedFrame = view.convert(keyboardFrame, from: nil)
        keyboardHeight = max(0, view.bounds.height - convertedFrame.origin.y - view.safeAreaInsets.bottom)

        var textInset = editingView.contentInset
        textInset.bottom = keyboardHeight + 40 // Reasonable padding
        editingView.contentInset = textInset

        var indicatorInsets = editingView.scrollIndicatorInsets
        indicatorInsets.bottom = keyboardHeight
        editingView.scrollIndicatorInsets = indicatorInsets

        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // Scroll to show cursor if needed
        DispatchQueue.main.async {
            if let selectedRange = self.editingView.selectedTextRange {
                let caretRect = self.editingView.caretRect(for: selectedRange.end)
                self.editingView.scrollRectToVisible(caretRect, animated: true)
            }
        }
    }

    private func handleKeyboardHide() {
        keyboardHeight = 0

        var textInset = editingView.contentInset
        textInset.bottom = 24
        editingView.contentInset = textInset
        editingView.scrollIndicatorInsets = .zero

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    // MARK: - Helpers
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Header View
private final class NoteHeaderView: UIView {
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
        // Title - simple and clean
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        
        // Subtitle - helpful status
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
    
    func updateSubtitle(_ subtitle: String) {
        UIView.transition(with: subtitleLabel, duration: 0.2, options: .transitionCrossDissolve) {
            self.subtitleLabel.text = subtitle
        }
    }
}

// MARK: - Enhanced Reading View
private final class EnhancedReadingView: UIView {
    private let textView = UITextView()
    private let emptyStateView = UIView()
    private let emptyStateLabel = UILabel()
    
    private var fontSize: CGFloat = 17
    
    var onTap: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Text view setup - properly sized within the container
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = .label
        textView.isScrollEnabled = false
        textView.showsVerticalScrollIndicator = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        // Empty state - friendly and simple
        emptyStateView.backgroundColor = .systemGray6
        emptyStateView.layer.cornerRadius = 12
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        emptyStateLabel.text = "✏️ Tap here to write your note"
        emptyStateLabel.font = .systemFont(ofSize: 16, weight: .medium)
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        addSubview(textView)
        emptyStateView.addSubview(emptyStateLabel)
        addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            // Text view fills the container with proper sizing
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Empty state centered
            emptyStateView.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalToConstant: 280),
            emptyStateView.heightAnchor.constraint(equalToConstant: 100),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 20),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -20)
        ])
        
        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        // Make empty state interactive
        emptyStateView.isUserInteractionEnabled = true
        let emptyTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        emptyStateView.addGestureRecognizer(emptyTapGesture)
    }
    
    func configure(text: String) {
        updateText(text)
    }
    
    func updateText(_ text: String) {
        // Simple line height for readability
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.3
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        
        textView.attributedText = NSAttributedString(string: text, attributes: attributes)
        
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        emptyStateView.isHidden = hasText
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    func adjustFontSize(increase: Bool) {
        fontSize = increase ? min(fontSize + 2, 28) : max(fontSize - 2, 14)
        if let text = textView.text {
            updateText(text)
        }
    }
    
    @objc private func handleTap() {
        // Simple animation for feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.alpha = 0.9
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.alpha = 1.0
            }
        }
        onTap?()
    }
}

// MARK: - Enhanced Editing View
private final class EnhancedEditingView: UITextView {
    private let placeholderLabel = UILabel()
    var onTextChange: ((String) -> Void)?
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        delegate = self
        backgroundColor = .clear
        font = .systemFont(ofSize: 17)
        textColor = .label
        textContainerInset = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        isScrollEnabled = true
        alwaysBounceVertical = true
        showsVerticalScrollIndicator = true
        showsHorizontalScrollIndicator = false
        isDirectionalLockEnabled = true

        placeholderLabel.font = .systemFont(ofSize: 17)
        placeholderLabel.textColor = .tertiaryLabel
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24)
        ])
    }
    
    func configure(text: String, placeholder: String) {
        self.text = text
        placeholderLabel.text = placeholder
        updatePlaceholderVisibility()
    }
    
    func updateText(_ text: String) {
        self.text = text
        updatePlaceholderVisibility()
    }
    
    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !text.isEmpty
    }
    
    func toggleBold() {
        // Implement bold formatting
    }
    
    func toggleItalic() {
        // Implement italic formatting
    }
    
    func insertBulletPoint() {
        insertText("• ")
    }
    
    func adjustIndent(increase: Bool) {
        // Implement indent adjustment
    }
}

extension EnhancedEditingView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
        onTextChange?(textView.text)
    }
}
