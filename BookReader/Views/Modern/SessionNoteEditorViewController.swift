//
//  SessionNoteEditorViewController.swift
//  BookReader
//
//  Lightweight editor for a single journal entry.
//

import UIKit

final class SessionNoteEditorViewController: UIViewController {
    var onSave: ((String, [String], Int?) -> Void)?
    var onDelete: (() -> Void)?

    private let textView: UITextView = {
        let view = UITextView()
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tagsField: UITextField = {
        let field = UITextField()
        field.placeholder = "Tags (comma separated)"
        field.borderStyle = .roundedRect
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let pageField: UITextField = {
        let field = UITextField()
        field.placeholder = "Page"
        field.keyboardType = .numberPad
        field.borderStyle = .roundedRect
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = "Journal Entry"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))
        if onDelete != nil {
            navigationItem.rightBarButtonItems = [navigationItem.rightBarButtonItem!, UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deleteTapped))]
        }

        view.addSubview(tagsField)
        view.addSubview(pageField)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            tagsField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            tagsField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tagsField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            pageField.topAnchor.constraint(equalTo: tagsField.bottomAnchor, constant: 8),
            pageField.leadingAnchor.constraint(equalTo: tagsField.leadingAnchor),
            pageField.widthAnchor.constraint(equalToConstant: 120),

            textView.topAnchor.constraint(equalTo: pageField.bottomAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    func configure(initialText: String, initialTags: [String], pageHint: Int?) {
        _ = view // force load
        textView.text = initialText
        tagsField.text = initialTags.joined(separator: ", ")
        if let pageHint {
            pageField.text = String(pageHint)
        }
    }

    @objc private func saveTapped() {
        let tags = tagsField.text?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        let pageHint = Int(pageField.text ?? "")
        onSave?(textView.text, tags, pageHint)
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func deleteTapped() {
        onDelete?()
        dismiss(animated: true)
    }
}
