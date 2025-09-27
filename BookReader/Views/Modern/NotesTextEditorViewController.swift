//
//  NotesTextEditorViewController.swift
//  BookReader
//
//  Lightweight editor for summary/takeaway/action items.
//

import UIKit

final class NotesTextEditorViewController: UIViewController {
    var onSave: ((String) -> Void)?

    private let initialText: String
    private let placeholder: String

    private let textView: UITextView = {
        let view = UITextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.alwaysBounceVertical = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        return view
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        return label
    }()

    init(title: String, initialText: String, placeholder: String) {
        self.initialText = initialText
        self.placeholder = placeholder
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveTapped))

        textView.delegate = self
        view.addSubview(textView)
        view.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 18),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 18),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -18)
        ])

        textView.text = initialText
        placeholderLabel.text = placeholder
        updatePlaceholderVisibility()

        DispatchQueue.main.async { [weak self] in
            self?.textView.becomeFirstResponder()
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        onSave?(textView.text ?? "")
        dismiss(animated: true)
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !(textView.text?.isEmpty ?? true)
    }
}

extension NotesTextEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
    }
}
