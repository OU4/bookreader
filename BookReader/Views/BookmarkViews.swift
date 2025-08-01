//
//  BookmarkViews.swift
//  BookReader
//
//  UI components for bookmark system
//

import UIKit

// MARK: - Add Bookmark View
class AddBookmarkView: UIView {
    
    weak var delegate: AddBookmarkViewDelegate?
    
    private let titleTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Bookmark title"
        textField.borderStyle = .roundedRect
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let noteTextView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.borderWidth = 1
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private let notePlaceholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Add a note (optional)"
        label.textColor = .placeholderText
        label.font = UIFont.systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let typeSegmentedControl: UISegmentedControl = {
        let items = BookmarkItem.BookmarkType.allCases.map { $0.displayName }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Add Bookmark", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.1
        
        addSubview(titleTextField)
        addSubview(noteTextView)
        noteTextView.addSubview(notePlaceholderLabel)
        addSubview(typeSegmentedControl)
        addSubview(addButton)
        addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            titleTextField.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            titleTextField.heightAnchor.constraint(equalToConstant: 44),
            
            noteTextView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 16),
            noteTextView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            noteTextView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            noteTextView.heightAnchor.constraint(equalToConstant: 80),
            
            notePlaceholderLabel.topAnchor.constraint(equalTo: noteTextView.topAnchor, constant: 8),
            notePlaceholderLabel.leadingAnchor.constraint(equalTo: noteTextView.leadingAnchor, constant: 8),
            
            typeSegmentedControl.topAnchor.constraint(equalTo: noteTextView.bottomAnchor, constant: 16),
            typeSegmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            typeSegmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            typeSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            cancelButton.topAnchor.constraint(equalTo: typeSegmentedControl.bottomAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            cancelButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            cancelButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.4),
            
            addButton.topAnchor.constraint(equalTo: cancelButton.topAnchor),
            addButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.4),
            addButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        noteTextView.delegate = self
        
        // Set default title
        titleTextField.text = "Page Bookmark"
    }
    
    @objc private func addButtonTapped() {
        let title = titleTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Bookmark"
        let note = noteTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteToSave = note.isEmpty ? nil : note
        let selectedType = BookmarkItem.BookmarkType.allCases[typeSegmentedControl.selectedSegmentIndex]
        
        delegate?.addBookmarkView(self, didCreateBookmarkWithTitle: title, note: noteToSave, type: selectedType)
    }
    
    @objc private func cancelButtonTapped() {
        delegate?.addBookmarkViewDidCancel(self)
    }
    
    func prepopulate(title: String? = nil, note: String? = nil, type: BookmarkItem.BookmarkType = .bookmark) {
        if let title = title {
            titleTextField.text = title
        }
        if let note = note {
            noteTextView.text = note
            notePlaceholderLabel.isHidden = true
        }
        if let index = BookmarkItem.BookmarkType.allCases.firstIndex(of: type) {
            typeSegmentedControl.selectedSegmentIndex = index
        }
    }
}

// MARK: - Add Bookmark View Delegate
protocol AddBookmarkViewDelegate: AnyObject {
    func addBookmarkView(_ view: AddBookmarkView, didCreateBookmarkWithTitle title: String, note: String?, type: BookmarkItem.BookmarkType)
    func addBookmarkViewDidCancel(_ view: AddBookmarkView)
}

// MARK: - TextView Delegate
extension AddBookmarkView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        notePlaceholderLabel.isHidden = !textView.text.isEmpty
    }
}

// MARK: - Bookmark Cell
class BookmarkCell: UITableViewCell {
    
    // Constraint properties for dynamic layout
    private var positionTopToNoteConstraint: NSLayoutConstraint!
    private var positionTopToTitleConstraint: NSLayoutConstraint!
    private var contextTopToPositionConstraint: NSLayoutConstraint!
    private var contextBottomConstraint: NSLayoutConstraint!
    private var positionBottomConstraint: NSLayoutConstraint!
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let noteLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let positionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let contextLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.italicSystemFont(ofSize: 12)
        label.textColor = .quaternaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(noteLabel)
        contentView.addSubview(positionLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(contextLabel)
        
        // Create constraint references
        positionTopToNoteConstraint = positionLabel.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 4)
        positionTopToTitleConstraint = positionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
        contextTopToPositionConstraint = contextLabel.topAnchor.constraint(equalTo: positionLabel.bottomAnchor, constant: 4)
        contextBottomConstraint = contextLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        positionBottomConstraint = positionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: dateLabel.leadingAnchor, constant: -8),
            
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            dateLabel.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            dateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            noteLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            noteLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            noteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            positionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            positionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            contextLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            contextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Default constraints - will be managed dynamically
            positionTopToNoteConstraint,
            contextTopToPositionConstraint,
            contextBottomConstraint
        ])
    }
    
    func configure(with bookmark: BookmarkItem) {
        // Icon and color
        iconImageView.image = UIImage(systemName: bookmark.type.icon)
        iconImageView.tintColor = bookmark.type.color
        
        // Title
        titleLabel.text = bookmark.title
        
        // Note
        if let note = bookmark.note, !note.isEmpty {
            noteLabel.text = note
            noteLabel.isHidden = false
        } else {
            noteLabel.isHidden = true
        }
        
        // Position
        if let pageNumber = bookmark.pageNumber {
            positionLabel.text = "Page \(pageNumber) • \(Int(bookmark.readingProgress * 100))%"
        } else {
            positionLabel.text = "\(Int(bookmark.readingProgress * 100))% through book"
        }
        
        // Date
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        dateLabel.text = formatter.string(from: bookmark.dateCreated)
        
        // Context
        if let context = bookmark.contextText, !context.isEmpty {
            contextLabel.text = "\"\(context.prefix(100))...\""
            contextLabel.isHidden = false
        } else {
            contextLabel.isHidden = true
        }
        
        // Update constraints based on visible elements
        updateConstraintsForVisibleElements()
    }
    
    private func updateConstraintsForVisibleElements() {
        let hasNote = !noteLabel.isHidden
        let hasContext = !contextLabel.isHidden
        
        // Deactivate all dynamic constraints first
        NSLayoutConstraint.deactivate([
            positionTopToNoteConstraint,
            positionTopToTitleConstraint,
            contextTopToPositionConstraint,
            contextBottomConstraint,
            positionBottomConstraint
        ])
        
        // Activate appropriate constraints based on visible elements
        if hasNote && hasContext {
            // All elements visible: note -> position -> context -> bottom
            NSLayoutConstraint.activate([
                positionTopToNoteConstraint,
                contextTopToPositionConstraint,
                contextBottomConstraint
            ])
        } else if hasNote && !hasContext {
            // Only note visible: note -> position -> bottom
            NSLayoutConstraint.activate([
                positionTopToNoteConstraint,
                positionBottomConstraint
            ])
        } else if !hasNote && hasContext {
            // Only context visible: title -> position -> context -> bottom
            NSLayoutConstraint.activate([
                positionTopToTitleConstraint,
                contextTopToPositionConstraint,
                contextBottomConstraint
            ])
        } else {
            // Neither visible: title -> position -> bottom
            NSLayoutConstraint.activate([
                positionTopToTitleConstraint,
                positionBottomConstraint
            ])
        }
    }
}

// MARK: - Quick Bookmark Button
class QuickBookmarkButton: UIButton {
    
    private var isBookmarked = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        setImage(UIImage(systemName: "bookmark"), for: .normal)
        setImage(UIImage(systemName: "bookmark.fill"), for: .selected)
        tintColor = .systemBlue
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        layer.cornerRadius = 20
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }
    
    @objc private func buttonTapped() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate button
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = .identity
            }
        }
    }
    
    func setBookmarked(_ bookmarked: Bool, animated: Bool = true) {
        isBookmarked = bookmarked
        
        if animated {
            UIView.transition(with: self, duration: 0.2, options: .transitionCrossDissolve) {
                self.isSelected = bookmarked
                self.tintColor = bookmarked ? .systemYellow : .systemBlue
            }
        } else {
            isSelected = bookmarked
            tintColor = bookmarked ? .systemYellow : .systemBlue
        }
    }
}