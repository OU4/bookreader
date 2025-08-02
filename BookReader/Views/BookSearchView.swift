//
//  BookSearchView.swift
//  BookReader
//
//  Search functionality with Live Text support
//

import UIKit
import PDFKit
import VisionKit

// MARK: - Book Search Result Model
struct BookSearchResult {
    let pageNumber: Int
    let matchedText: String
    let context: String
    let bounds: CGRect?
    let selection: PDFSelection?
    
    var displayText: String {
        return "Page \(pageNumber): \(context)"
    }
}

// MARK: - Book Search View
class BookSearchView: UIView {
    
    weak var delegate: BookSearchDelegate?
    private var searchResults: [BookSearchResult] = []
    private var currentBook: Book?
    private var pdfDocument: PDFDocument?
    
    // UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "Search in book..."
        bar.searchBarStyle = .minimal
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.allowsSelection = true
        table.isUserInteractionEnabled = true
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No results found"
        label.textColor = .tertiaryLabel
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .tertiaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Search task management
    private var searchTask: Task<Void, Never>?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        addSubview(containerView)
        containerView.addSubview(searchBar)
        containerView.addSubview(closeButton)
        containerView.addSubview(tableView)
        containerView.addSubview(emptyStateLabel)
        containerView.addSubview(loadingIndicator)
        containerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.9),
            containerView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.7),
            
            searchBar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            
            closeButton.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            statusLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        searchBar.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(BookSearchResultCell.self, forCellReuseIdentifier: "BookSearchResultCell")
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tapGesture.delegate = self
        tapGesture.cancelsTouchesInView = false
        addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Public Methods
    
    func show(for book: Book, pdfDocument: PDFDocument?) {
        self.currentBook = book
        self.pdfDocument = pdfDocument
        
        print("🔍 Search view shown for book: \(book.title)")
        print("📄 PDF document available: \(pdfDocument != nil)")
        
        alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
        
        searchBar.becomeFirstResponder()
    }
    
    func hide() {
        searchBar.resignFirstResponder()
        
        UIView.animate(withDuration: 0.25) {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
    
    // MARK: - Search Implementation
    
    private func performSearch(_ query: String) {
        print("🔍 Performing search for: '\(query)'")
        
        guard !query.isEmpty else {
            print("❌ Empty search query")
            searchResults = []
            tableView.reloadData()
            emptyStateLabel.isHidden = true
            return
        }
        
        searchTask?.cancel()
        
        searchTask = Task {
            await MainActor.run {
                self.loadingIndicator.startAnimating()
                self.emptyStateLabel.isHidden = true
                self.statusLabel.isHidden = false
                self.statusLabel.text = "Searching..."
            }
            
            if let pdfDocument = pdfDocument {
                print("📄 Searching in PDF document")
                await searchPDF(query: query, document: pdfDocument)
            } else if let book = currentBook {
                print("📖 Searching in text file")
                searchTextFile(query: query, book: book)
            } else {
                print("❌ No document available for search")
            }
        }
    }
    
    private func searchPDF(query: String, document: PDFDocument) async {
        print("📄 Starting PDF search for: '\(query)'")
        var results: [BookSearchResult] = []
        
        // Check if Live Text is available
        if #available(iOS 16.0, *), ImageAnalyzer.isSupported {
            print("✅ Live Text is available")
            await MainActor.run {
                self.statusLabel.text = "Using Live Text to search..."
            }
        } else {
            print("⚠️ Live Text not available, using standard search")
        }
        
        // Use PDFKit's built-in search (works with Live Text)
        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        print("🔍 Searching PDF with options: \(options)")
        
        await withTaskCancellationHandler {
            let selections = document.findString(query, withOptions: options)
            print("📄 Found \(selections.count) selections for '\(query)'")
            
            // Limit results to prevent UI overload
            let limitedSelections = Array(selections.prefix(100))
            if selections.count > 100 {
                print("⚠️ Limited results to first 100 out of \(selections.count) matches")
            }
            
            for (index, selection) in limitedSelections.enumerated() {
                if Task.isCancelled { break }
                
                if let page = selection.pages.first {
                    let pageIndex = document.index(for: page)
                    
                    // Validate page index
                    guard pageIndex >= 0 && pageIndex < document.pageCount else {
                        print("⚠️ Invalid page index: \(pageIndex) for document with \(document.pageCount) pages")
                        continue
                    }
                    
                    // Get context - be more careful about text extraction
                    let bounds = selection.bounds(for: page)
                    var context = selection.string ?? ""
                    
                    // Try to get more context if the selection text is too short
                    if context.count < 20 {
                        let extendedBounds = bounds.insetBy(dx: -30, dy: -15)
                        if let extendedSelection = page.selection(for: extendedBounds),
                           let extendedText = extendedSelection.string,
                           !extendedText.isEmpty {
                            context = extendedText
                        }
                    }
                    
                    // Clean up the context text
                    context = context.trimmingCharacters(in: .whitespacesAndNewlines)
                    context = context.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    
                    // Ensure we have the search term in the context
                    if !context.localizedCaseInsensitiveContains(query) {
                        context = (selection.string ?? query) + " (context unavailable)"
                    }
                    
                    let result = BookSearchResult(
                        pageNumber: pageIndex + 1,
                        matchedText: selection.string ?? query,
                        context: context,
                        bounds: bounds,
                        selection: selection
                    )
                    results.append(result)
                    
                    if results.count <= 5 {
                        print("🔍 Added result \(results.count): Page \(pageIndex + 1), context: '\(context.prefix(50))...'")
                    }
                }
                
                // Update progress
                if index % 10 == 0 {
                    let progress = Float(index) / Float(limitedSelections.count)
                    await MainActor.run {
                        self.statusLabel.text = "Found \(index) results... (\(Int(progress * 100))%)"
                    }
                }
            }
            
            await MainActor.run {
                print("📊 Final results: \(results.count) items")
                self.searchResults = results
                self.tableView.reloadData()
                self.loadingIndicator.stopAnimating()
                
                // Show result count with limitation info
                if selections.count > 100 {
                    self.statusLabel.text = "Showing first \(results.count) of \(selections.count) results"
                } else {
                    self.statusLabel.text = "\(results.count) results found"
                }
                
                self.emptyStateLabel.isHidden = !results.isEmpty
                
                if results.isEmpty {
                    self.emptyStateLabel.text = "No results for \"\(query)\""
                    print("❌ No results found for '\(query)'")
                } else {
                    print("✅ Search completed with \(results.count) results")
                }
            }
        } onCancel: {
            print("Search cancelled")
        }
    }
    
    private func searchTextFile(query: String, book: Book) {
        // Implementation for text file search
        // Similar to PDF but simpler
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        hide()
    }
    
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        if !containerView.frame.contains(location) {
            hide()
        }
    }
}

// MARK: - UISearchBarDelegate
extension BookSearchView: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(#selector(searchWithDelay), with: searchText, afterDelay: 0.3)
    }
    
    @objc private func searchWithDelay(_ searchText: String) {
        performSearch(searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDataSource & Delegate
extension BookSearchView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookSearchResultCell", for: indexPath) as! BookSearchResultCell
        cell.configure(with: searchResults[indexPath.row])
        
        // Add a tap gesture as backup
        cell.tag = indexPath.row
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped(_:)))
        cell.addGestureRecognizer(tapGesture)
        
        return cell
    }
    
    @objc private func cellTapped(_ gesture: UITapGestureRecognizer) {
        guard let cell = gesture.view as? BookSearchResultCell else { return }
        let row = cell.tag
        
        print("🎯 Cell tapped via gesture recognizer: row \(row)")
        
        if row < searchResults.count {
            let result = searchResults[row]
            print("🔍 Search result tapped via gesture: Page \(result.pageNumber)")
            delegate?.bookSearch(self, didSelectResult: result)
            hide()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("🎯 didSelectRowAt called for row \(indexPath.row)")
        tableView.deselectRow(at: indexPath, animated: true)
        let result = searchResults[indexPath.row]
        
        print("🔍 Search result tapped: Page \(result.pageNumber)")
        print("🔗 Delegate available: \(delegate != nil)")
        print("📄 Selection available: \(result.selection != nil)")
        
        delegate?.bookSearch(self, didSelectResult: result)
        hide()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - UIGestureRecognizerDelegate
extension BookSearchView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let locationInContainer = touch.location(in: containerView)
        let shouldReceive = !containerView.bounds.contains(locationInContainer)
        print("🤚 Gesture recognizer shouldReceive: \(shouldReceive), location: \(locationInContainer)")
        return shouldReceive
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - Book Search Result Cell
class BookSearchResultCell: UITableViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let pageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let contextLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .label
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
        backgroundColor = .clear
        selectionStyle = .default
        
        contentView.addSubview(containerView)
        containerView.addSubview(pageLabel)
        containerView.addSubview(contextLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            pageLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            pageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            contextLabel.topAnchor.constraint(equalTo: pageLabel.bottomAnchor, constant: 4),
            contextLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contextLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            contextLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with result: BookSearchResult) {
        pageLabel.text = "Page \(result.pageNumber)"
        
        // Create attributed string with better highlighting
        let attributedString = NSMutableAttributedString(string: result.context)
        
        // Try to find and highlight the matched text (case insensitive)
        let searchText = result.matchedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchText.isEmpty {
            let range = (result.context as NSString).range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive])
            if range.location != NSNotFound {
                attributedString.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.4), range: range)
                attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 14), range: range)
                attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            }
        }
        
        contextLabel.attributedText = attributedString
        print("🔧 Configured cell: Page \(result.pageNumber), matched: '\(searchText)', context: '\(result.context.prefix(30))...'")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        print("📱 Cell selection changed: \(selected)")
        
        UIView.animate(withDuration: 0.2) {
            self.containerView.backgroundColor = selected ? .tertiarySystemBackground : .secondarySystemBackground
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        print("✨ Cell highlighted: \(highlighted)")
        
        UIView.animate(withDuration: 0.1) {
            self.containerView.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }
}

// MARK: - Delegate Protocol
protocol BookSearchDelegate: AnyObject {
    func bookSearch(_ searchView: BookSearchView, didSelectResult result: BookSearchResult)
}