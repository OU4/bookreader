//
//  BookSearchViewController.swift
//  BookReader
//
//  Search functionality within books
//

import UIKit

class BookSearchViewController: UIViewController {
    
    // MARK: - Properties
    private let book: Book
    private let bookText: String
    private var searchResults: [SearchResult] = []
    
    // MARK: - UI Components
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search in book..."
        searchBar.delegate = self
        searchBar.showsCancelButton = true
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private lazy var resultsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "magnifyingglass")
        imageView.tintColor = .systemGray3
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Search in Book"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Enter keywords to find content"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .tertiaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(imageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
            
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
        
        return view
    }()
    
    // MARK: - Initialization
    init(book: Book, text: String) {
        self.book = book
        self.bookText = text
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Search"
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissViewController)
        )
        
        view.addSubview(searchBar)
        view.addSubview(resultsLabel)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            resultsLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            resultsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: resultsLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.topAnchor.constraint(equalTo: resultsLabel.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        updateUI()
    }
    
    // MARK: - Actions
    @objc private func dismissViewController() {
        dismiss(animated: true)
    }
    
    // MARK: - Search
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            updateUI()
            return
        }
        
        searchResults = findMatches(for: query)
        updateUI()
    }
    
    private func findMatches(for query: String) -> [SearchResult] {
        let lowercaseQuery = query.lowercased()
        let words = bookText.components(separatedBy: .whitespacesAndNewlines)
        var results: [SearchResult] = []
        var currentPosition = 0
        
        for (index, word) in words.enumerated() {
            if word.lowercased().contains(lowercaseQuery) {
                // Find the context around this word
                let contextStart = max(0, index - 10)
                let contextEnd = min(words.count - 1, index + 10)
                let contextWords = Array(words[contextStart...contextEnd])
                let context = contextWords.joined(separator: " ")
                
                // Highlight the matching word
                let highlightedContext = highlightMatches(in: context, query: lowercaseQuery)
                
                let result = SearchResult(
                    text: highlightedContext,
                    position: currentPosition,
                    matchRange: NSRange(location: 0, length: query.count)
                )
                
                results.append(result)
            }
            
            currentPosition += word.count + 1 // +1 for space
        }
        
        return results
    }
    
    private func highlightMatches(in text: String, query: String) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: text)
        let lowercaseText = text.lowercased()
        let lowercaseQuery = query.lowercased()
        
        let range = NSRange(location: 0, length: text.count)
        
        do {
            let regex = try NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: lowercaseQuery), options: .caseInsensitive)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches.reversed() { // Reversed to avoid range shifting
                attributedText.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: match.range)
                attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: match.range)
            }
        } catch {
        }
        
        return attributedText
    }
    
    private func updateUI() {
        if searchResults.isEmpty {
            if searchBar.text?.isEmpty == false {
                resultsLabel.text = "No results found"
            } else {
                resultsLabel.text = ""
            }
            tableView.isHidden = true
            emptyStateView.isHidden = false
        } else {
            resultsLabel.text = "\(searchResults.count) result\(searchResults.count == 1 ? "" : "s") found"
            tableView.isHidden = false
            emptyStateView.isHidden = true
            tableView.reloadData()
        }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension BookSearchViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath) as! SearchResultCell
        cell.configure(with: searchResults[indexPath.row], resultNumber: indexPath.row + 1)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Return to book reader and navigate to this position
        let result = searchResults[indexPath.row]
        
        NotificationCenter.default.post(
            name: .searchResultSelected,
            object: nil,
            userInfo: ["position": result.position, "text": result.text.string]
        )
        
        dismissViewController()
    }
}

// MARK: - UISearchBarDelegate
extension BookSearchViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        performSearch(query: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        dismissViewController()
    }
}

// MARK: - Supporting Types
struct SearchResult {
    let text: NSAttributedString
    let position: Int
    let matchRange: NSRange
}

// MARK: - Search Result Cell
class SearchResultCell: UITableViewCell {
    
    private let resultNumberLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let contextLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 3
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(resultNumberLabel)
        contentView.addSubview(contextLabel)
        
        NSLayoutConstraint.activate([
            resultNumberLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            resultNumberLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            resultNumberLabel.widthAnchor.constraint(equalToConstant: 30),
            
            contextLabel.leadingAnchor.constraint(equalTo: resultNumberLabel.trailingAnchor, constant: 8),
            contextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            contextLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            contextLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with result: SearchResult, resultNumber: Int) {
        resultNumberLabel.text = "\(resultNumber)"
        contextLabel.attributedText = result.text
    }
}

// MARK: - Notification
extension Notification.Name {
    static let searchResultSelected = Notification.Name("searchResultSelected")
}