//
//  MigrationViewController.swift
//  BookReader
//
//  Handles migration of local books to Firebase
//

import UIKit

class MigrationViewController: UIViewController {
    
    // MARK: - UI Elements
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 10)
        view.layer.shadowRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "icloud.and.arrow.up")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Migrate to Cloud"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "We found books in your local storage. Would you like to sync them to the cloud for access across all your devices?"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .bar)
        progress.progressTintColor = .systemBlue
        progress.trackTintColor = .systemGray5
        progress.isHidden = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let migrateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Migrate Books", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Skip for Now", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    private var localBooks: [Book] = []
    var completion: (() -> Void)?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        checkLocalBooks()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(progressView)
        containerView.addSubview(statusLabel)
        containerView.addSubview(migrateButton)
        containerView.addSubview(skipButton)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Progress
            progressView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 30),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Status
            statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Migrate button
            migrateButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            migrateButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            migrateButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            migrateButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Skip button
            skipButton.topAnchor.constraint(equalTo: migrateButton.bottomAnchor, constant: 12),
            skipButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupActions() {
        migrateButton.addTarget(self, action: #selector(migrateTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
    }
    
    // MARK: - Data
    private func checkLocalBooks() {
        localBooks = BookStorage.shared.loadBooks()
        
        if localBooks.isEmpty {
            // No books to migrate
            dismiss(animated: true)
            completion?()
        } else {
            let bookCount = localBooks.count
            descriptionLabel.text = "We found \(bookCount) book\(bookCount == 1 ? "" : "s") in your local storage. Would you like to sync them to the cloud for access across all your devices?"
        }
    }
    
    // MARK: - Actions
    @objc private func migrateTapped() {
        migrateButton.isEnabled = false
        skipButton.isEnabled = false
        progressView.isHidden = false
        statusLabel.isHidden = false
        progressView.progress = 0
        
        statusLabel.text = "Starting migration..."
        
        UnifiedFirebaseStorage.shared.migrateLocalBooks { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    self?.progressView.progress = 1.0
                    self?.statusLabel.text = "Successfully migrated \(count) book\(count == 1 ? "" : "s")"
                    
                    // Clear local storage after successful migration
                    UserDefaults.standard.set(true, forKey: "HasMigratedToFirebase")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.dismiss(animated: true)
                        self?.completion?()
                    }
                    
                case .failure(let error):
                    self?.statusLabel.text = "Migration failed: \(error.localizedDescription)"
                    self?.migrateButton.isEnabled = true
                    self?.skipButton.isEnabled = true
                }
            }
        }
    }
    
    @objc private func skipTapped() {
        UserDefaults.standard.set(true, forKey: "HasSkippedMigration")
        dismiss(animated: true)
        completion?()
    }
}