import UIKit
import PDFKit

// MARK: - PDFHighlightHandlerDelegate
protocol PDFHighlightHandlerDelegate: AnyObject {
    func pdfHighlightHandler(_ handler: PDFHighlightHandler, didCreateHighlight highlight: Highlight)
    func pdfHighlightHandler(_ handler: PDFHighlightHandler, didFailWithError error: Error)
}

// MARK: - PDFHighlightHandler
class PDFHighlightHandler: NSObject {
    
    // MARK: - Properties
    weak var delegate: PDFHighlightHandlerDelegate?
    private weak var pdfView: PDFView?
    private var bookId: String?
    
    // Highlight colors
    private let highlightColors: [(name: String, color: UIColor)] = [
        ("Yellow", UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.5)),
        ("Green", UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 0.5)),
        ("Blue", UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.5)),
        ("Pink", UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 0.5))
    ]
    
    // MARK: - Initialization
    init(pdfView: PDFView, bookId: String) {
        self.pdfView = pdfView
        self.bookId = bookId
        super.init()
        setupGestureRecognizers()
    }
    
    // MARK: - Setup
    private func setupGestureRecognizers() {
        guard let pdfView = pdfView else { return }
        
        // Add long press gesture for text selection
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        pdfView.addGestureRecognizer(longPressGesture)
        
        // Enable text selection
        pdfView.isUserInteractionEnabled = true
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let pdfView = pdfView else { return }
        
        let location = gesture.location(in: pdfView)
        
        // Try to get selection at the gesture location
        if let selection = pdfView.currentSelection, !(selection.string?.isEmpty ?? true) {
            // There's already a selection
            showHighlightOptions(for: selection)
        } else {
            // Try to select text at the touch location
            if let page = pdfView.page(for: location, nearest: true) {
                let pageLocation = pdfView.convert(location, to: page)
                
                // Try to select a word at this location
                if let pageText = page.string {
                    // For now, show a hint that text needs to be selected first
                    showTextSelectionHint(at: location, in: pdfView)
                }
            }
        }
    }
    
    private func showTextSelectionHint(at location: CGPoint, in pdfView: PDFView) {
        // Create a temporary hint view
        let hintLabel = UILabel()
        hintLabel.text = "Select text first to highlight"
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        hintLabel.textColor = .white
        hintLabel.font = UIFont.systemFont(ofSize: 14)
        hintLabel.textAlignment = .center
        hintLabel.layer.cornerRadius = 8
        hintLabel.clipsToBounds = true
        hintLabel.alpha = 0
        
        pdfView.addSubview(hintLabel)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: pdfView.centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: pdfView.topAnchor, constant: location.y + 20),
            hintLabel.widthAnchor.constraint(equalToConstant: 200),
            hintLabel.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // Animate the hint
        UIView.animate(withDuration: 0.3, animations: {
            hintLabel.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, animations: {
                hintLabel.alpha = 0
            }) { _ in
                hintLabel.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Highlight UI
    func showHighlightOptions(for selection: PDFSelection) {
        guard let pdfView = pdfView,
              let viewController = pdfView.findViewController() else { return }
        
        let actionSheet = UIAlertController(title: "Highlight Options", message: nil, preferredStyle: .actionSheet)
        
        // Add color options
        for (colorName, color) in highlightColors {
            actionSheet.addAction(UIAlertAction(title: colorName, style: .default) { [weak self] _ in
                self?.createHighlight(from: selection, color: color, colorName: colorName)
            })
        }
        
        // Add cancel action
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.pdfView?.clearSelection()
        })
        
        // Configure for iPad
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = pdfView
            if let page = selection.pages.first {
                let bounds = selection.bounds(for: page)
                let convertedBounds = pdfView.convert(bounds, from: page)
                popover.sourceRect = convertedBounds
            }
        }
        
        viewController.present(actionSheet, animated: true)
    }
    
    // MARK: - Highlight Creation
    private func createHighlight(from selection: PDFSelection, color: UIColor, colorName: String) {
        guard let bookId = bookId,
              let pdfView = pdfView,
              let document = pdfView.document,
              let selectedText = selection.string,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Collect selection rects per page
        var selectionRects: [SelectionRect] = []
        for page in selection.pages {
            let bounds = selection.bounds(for: page)
            guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { continue }
            let pageIndex = document.index(for: page)
            selectionRects.append(SelectionRect(pageIndex: pageIndex, rect: bounds))

            // Apply visual highlight immediately
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = color
            annotation.contents = selectedText
            page.addAnnotation(annotation)
        }

        // Create highlight model with best-effort offsets
        let highlightColor: Highlight.HighlightColor
        switch colorName {
        case "Yellow": highlightColor = .yellow
        case "Green": highlightColor = .green
        case "Blue": highlightColor = .blue
        case "Pink": highlightColor = .pink
        default: highlightColor = .yellow
        }

        let firstPageIndex = selectionRects.first?.pageIndex ?? document.index(for: selection.pages.first ?? PDFPage())
        let pageNumber = max(firstPageIndex, 0) + 1

        var startOffset = 0
        var endOffset = selectedText.count

        if let firstPage = selection.pages.first,
           let pageText = firstPage.string,
           !pageText.isEmpty {
            let normalizedSelection = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedSelection.isEmpty {
                let candidates: [Range<String.Index>] = {
                    var ranges: [Range<String.Index>] = []
                    if let range = pageText.range(of: normalizedSelection) {
                        ranges.append(range)
                    }
                    if let range = pageText.range(of: normalizedSelection, options: [.caseInsensitive]) {
                        ranges.append(range)
                    }
                    if normalizedSelection.count > 8 {
                        let prefix = String(normalizedSelection.prefix(min(normalizedSelection.count, 32)))
                        if let range = pageText.range(of: prefix, options: [.caseInsensitive]) {
                            ranges.append(range)
                        }
                    }
                    return ranges
                }()

                if let match = candidates.first {
                    let nsRange = NSRange(match, in: pageText)
                    startOffset = nsRange.location
                    endOffset = nsRange.location + nsRange.length
                }
            }
        }

        let textPosition = TextPosition(
            startOffset: startOffset,
            endOffset: endOffset,
            chapter: nil,
            pageNumber: pageNumber
        )

        let highlight = Highlight(
            text: selectedText,
            color: highlightColor,
            position: textPosition,
            note: nil,
            selectionRects: selectionRects.isEmpty ? nil : selectionRects
        )

        UnifiedFirebaseStorage.shared.addHighlight(highlight, bookId: bookId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.delegate?.pdfHighlightHandler(self, didCreateHighlight: highlight)
                    self.pdfView?.clearSelection()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.delegate?.pdfHighlightHandler(self, didFailWithError: error)
                }
            }
        }
    }
    
    // MARK: - Load Existing Highlights
    func loadExistingHighlights() {
        guard let bookId = bookId else { return }
        
        
        // Load highlights asynchronously without artificial delay
        DispatchQueue.global(qos: .utility).async { [weak self] in
            UnifiedFirebaseStorage.shared.loadHighlights(bookId: bookId) { [weak self] highlights in
                DispatchQueue.main.async {
                    self?.applyHighlightsOptimized(highlights)
                }
            }
        }
    }
    
    // Method to manually refresh highlights
    func refreshHighlights() {
        loadExistingHighlights()
    }
    
    private func applyHighlightsOptimized(_ highlights: [Highlight]) {
        guard let pdfView = pdfView,
              let document = pdfView.document else { return }
        
        
        // Group highlights by page for efficient processing
        var highlightsByPage: [Int: [Highlight]] = [:]
        for highlight in highlights {
            let pageIndex: Int?
            if let pageNumber = highlight.position.pageNumber,
               pageNumber > 0,
               pageNumber <= document.pageCount {
                pageIndex = pageNumber - 1
            } else if let rectIndex = highlight.selectionRects?.first?.pageIndex,
                      rectIndex >= 0,
                      rectIndex < document.pageCount {
                pageIndex = rectIndex
            } else {
                pageIndex = nil
            }

            guard let pageIndex else { continue }
            if highlightsByPage[pageIndex] == nil {
                highlightsByPage[pageIndex] = []
            }
            highlightsByPage[pageIndex]?.append(highlight)
        }
        
        // Process each page only once in background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            for (pageIndex, pageHighlights) in highlightsByPage {
                autoreleasepool {
                    self?.processHighlightsForPage(pageIndex, highlights: pageHighlights, document: document)
                }
            }
            
            DispatchQueue.main.async {
                pdfView.layoutDocumentView()
            }
        }
    }
    
    private func processHighlightsForPage(_ pageIndex: Int, highlights: [Highlight], document: PDFDocument) {
        guard let page = document.page(at: pageIndex) else { return }

        let pageText = page.string ?? ""
        let searchOptions: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        var annotationsToAdd: [(CGRect, Highlight)] = []

        for highlight in highlights {
            autoreleasepool {
                if let rects = highlight.selectionRects?.filter({ $0.pageIndex == pageIndex }),
                   !rects.isEmpty {
                    rects.forEach { annotationsToAdd.append(($0.cgRect, highlight)) }
                } else if let rect = self.findHighlightRect(highlight, in: page, pageText: pageText, searchOptions: searchOptions) {
                    annotationsToAdd.append((rect, highlight))
                }
            }
        }

        DispatchQueue.main.async {
            for (bounds, highlight) in annotationsToAdd {
                let duplicates = page.annotations.filter { existing in
                    existing.bounds.equalTo(bounds) && (existing.contents == highlight.text || existing.contents == nil)
                }
                duplicates.forEach { page.removeAnnotation($0) }

                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = highlight.color.uiColor.withAlphaComponent(0.5)
                annotation.contents = highlight.text
                page.addAnnotation(annotation)
            }
        }
    }
    
    private func findHighlightRect(_ highlight: Highlight, in page: PDFPage, pageText: String, searchOptions: NSString.CompareOptions) -> CGRect? {
        // Fast text matching with fallback strategies
        var range: Range<String.Index>?
        
        // Strategy 1: Case-insensitive search
        range = pageText.range(of: highlight.text, options: searchOptions)
        
        // Strategy 2: Exact match
        if range == nil {
            range = pageText.range(of: highlight.text)
        }
        
        // Strategy 3: Fuzzy matching for longer text
        if range == nil && highlight.text.count > 15 {
            let cleanText = highlight.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchText = String(cleanText.prefix(min(cleanText.count - 3, 50))) // Limit search length
            range = pageText.range(of: searchText, options: searchOptions)
        }
        
        guard let textRange = range else { return nil }
        let nsRange = NSRange(textRange, in: pageText)
        guard let selection = page.selection(for: nsRange) else { return nil }
        return selection.bounds(for: page)
    }
    
    // Legacy method for backward compatibility
    private func applyHighlights(_ highlights: [Highlight]) {
        applyHighlightsOptimized(highlights)
    }
}

// MARK: - UIView Extension
