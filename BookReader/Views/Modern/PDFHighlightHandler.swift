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
              let selectedText = selection.string,
              !selectedText.isEmpty else { return }
        
        // Apply visual highlight to PDF
        for page in selection.pages {
            let bounds = selection.bounds(for: page)
            
            let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            highlight.color = color
            page.addAnnotation(highlight)
        }
        
        // Create highlight model
        let highlightColor: Highlight.HighlightColor
        switch colorName {
        case "Yellow": highlightColor = .yellow
        case "Green": highlightColor = .green
        case "Blue": highlightColor = .blue
        case "Pink": highlightColor = .pink
        default: highlightColor = .yellow
        }
        
        // Get page number
        let pageNumber = pdfView?.document?.index(for: selection.pages.first ?? PDFPage()) ?? 0
        
        let highlight = Highlight(
            text: selectedText,
            color: highlightColor,
            position: TextPosition(
                startOffset: 0,
                endOffset: selectedText.count,
                pageNumber: pageNumber + 1
            )
        )
        
        // Save to storage
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
        
        print("🔄 Loading existing highlights for book: \(bookId)")
        
        // Add a small delay to ensure PDF is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UnifiedFirebaseStorage.shared.loadHighlights(bookId: bookId) { [weak self] highlights in
                DispatchQueue.main.async {
                    print("📥 Received \(highlights.count) highlights from storage")
                    self?.applyHighlights(highlights)
                }
            }
        }
    }
    
    // Method to manually refresh highlights
    func refreshHighlights() {
        loadExistingHighlights()
    }
    
    private func applyHighlights(_ highlights: [Highlight]) {
        guard let pdfView = pdfView,
              let document = pdfView.document else { return }
        
        print("📝 Applying \(highlights.count) highlights to PDF")
        
        for highlight in highlights {
            guard let pageNumber = highlight.position.pageNumber,
                  pageNumber > 0,
                  pageNumber <= document.pageCount,
                  let page = document.page(at: pageNumber - 1) else {
                print("❌ Invalid page number \(highlight.position.pageNumber ?? -1) for highlight: \(highlight.text)")
                continue
            }
            
            // Search for the highlight text on the page
            guard let pageText = page.string else {
                print("❌ No text found on page \(pageNumber)")
                continue
            }
            
            // Try to find the text case-insensitively first
            var range = pageText.range(of: highlight.text, options: .caseInsensitive)
            
            // If not found, try exact match
            if range == nil {
                range = pageText.range(of: highlight.text)
            }
            
            // If still not found, try finding a substring
            if range == nil {
                let cleanText = highlight.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanText.count > 10 { // Only try substring for longer text
                    let prefix = String(cleanText.prefix(cleanText.count - 5))
                    range = pageText.range(of: prefix, options: .caseInsensitive)
                }
            }
            
            if let range = range {
                let nsRange = NSRange(range, in: pageText)
                if let selection = page.selection(for: nsRange) {
                    let bounds = selection.bounds(for: page)
                    let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                    annotation.color = highlight.color.uiColor.withAlphaComponent(0.5)
                    annotation.contents = highlight.text // Store original text
                    page.addAnnotation(annotation)
                    print("✅ Applied highlight: \(highlight.text.prefix(50))...")
                } else {
                    print("❌ Could not create selection for range on page \(pageNumber)")
                }
            } else {
                print("❌ Text not found on page \(pageNumber): \(highlight.text.prefix(50))...")
            }
        }
        
        print("✅ Finished applying highlights")
    }
}

// MARK: - UIView Extension
