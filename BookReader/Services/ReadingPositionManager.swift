//
//  ReadingPositionManager.swift
//  BookReader
//
//  Professional-grade reading position and highlight management
//

import Foundation
import PDFKit

// MARK: - Reading Position Model
struct ReadingPosition: Codable {
    let bookId: String
    let timestamp: Date
    
    // For PDFs - Enhanced precision
    let pageIndex: Int?
    let viewportOffset: CGPoint?  // Point in page coordinates
    let scrollOffset: CGPoint?    // Scroll view content offset
    let zoomScale: CGFloat?
    let pageBounds: CGRect?       // Page bounds at save time
    let viewBounds: CGRect?       // View bounds at save time
    let displayMode: String?      // Single page, continuous, etc.
    
    // For text files
    let textOffset: Int?
    let scrollPercentage: Float?
    
    // Common
    let totalPages: Int?
    let readingProgress: Float
    let precisionLevel: Int       // Version for future compatibility
}

// MARK: - PDF Highlight Model
struct PDFHighlight: Codable {
    let id: String
    let bookId: String
    let pageIndex: Int
    let quadPoints: [[CGFloat]] // Array of quad points for exact text location
    let text: String
    let color: String
    let dateCreated: Date
    let note: String?
    
    init(id: String = UUID().uuidString,
         bookId: String,
         pageIndex: Int,
         quadPoints: [[CGFloat]],
         text: String,
         color: String,
         dateCreated: Date = Date(),
         note: String? = nil) {
        self.id = id
        self.bookId = bookId
        self.pageIndex = pageIndex
        self.quadPoints = quadPoints
        self.text = text
        self.color = color
        self.dateCreated = dateCreated
        self.note = note
    }
}

// MARK: - Reading Position Manager
class ReadingPositionManager {
    static let shared = ReadingPositionManager()
    private let userDefaults = UserDefaults.standard
    private let positionKey = "ReadingPositions"
    private let highlightKey = "PDFHighlights"
    
    // Enhanced position tracking
    private var lastSaveTime: [String: Date] = [:]
    private let minimumSaveInterval: TimeInterval = 2.0 // Prevent excessive saves
    
    private init() {}
    
    // MARK: - Position Management
    
    func savePosition(for bookId: String, pdfView: PDFView) {
        guard let document = pdfView.document,
              let currentPage = pdfView.currentPage else { return }
        
        // Throttle saves to prevent excessive disk writes
        let now = Date()
        if let lastSave = lastSaveTime[bookId],
           now.timeIntervalSince(lastSave) < minimumSaveInterval {
            return
        }
        lastSaveTime[bookId] = now
        
        let pageIndex = document.index(for: currentPage)
        let zoomScale = pdfView.scaleFactor
        
        // Get multiple reference points for better precision
        let viewBounds = pdfView.bounds
        let pageBounds = currentPage.bounds(for: .mediaBox)
        
        // Use reading-optimized point (upper third of view rather than center)
        let readingPoint = CGPoint(
            x: viewBounds.midX,
            y: viewBounds.minY + (viewBounds.height * 0.3) // 30% from top
        )
        let pagePoint = pdfView.convert(readingPoint, to: currentPage)
        
        // Get scroll view offset with validation
        var scrollOffset: CGPoint = .zero
        if let scrollView = pdfView.documentView?.superview as? UIScrollView {
            scrollOffset = scrollView.contentOffset
        }
        
        // Enhanced progress calculation with page geometry
        let normalizedPageY = max(0, min(1, pagePoint.y / pageBounds.height))
        let baseProgress = Float(pageIndex) / Float(max(document.pageCount, 1))
        let pageProgressIncrement = 1.0 / Float(max(document.pageCount, 1))
        let preciseProgress = baseProgress + (Float(normalizedPageY) * pageProgressIncrement)
        
        // Determine display mode for restoration context
        let displayMode: String
        switch pdfView.displayMode {
        case .singlePage:
            displayMode = "singlePage"
        case .singlePageContinuous:
            displayMode = "singlePageContinuous"
        case .twoUp:
            displayMode = "twoUp"
        case .twoUpContinuous:
            displayMode = "twoUpContinuous"
        @unknown default:
            displayMode = "unknown"
        }
        
        let position = ReadingPosition(
            bookId: bookId,
            timestamp: Date(),
            pageIndex: pageIndex,
            viewportOffset: pagePoint,
            scrollOffset: scrollOffset,
            zoomScale: zoomScale,
            pageBounds: pageBounds,
            viewBounds: viewBounds,
            displayMode: displayMode,
            textOffset: nil,
            scrollPercentage: Float(preciseProgress),
            totalPages: document.pageCount,
            readingProgress: preciseProgress,
            precisionLevel: 2
        )
        
        savePosition(position)
        print("📍 Enhanced PDF position saved: Page \(pageIndex + 1)/\(document.pageCount), point: \(pagePoint), scroll: \(scrollOffset), zoom: \(zoomScale)x, mode: \(displayMode)")
    }
    
    /// Force save position (e.g., when app goes to background)
    func forceSavePosition(for bookId: String, pdfView: PDFView) {
        lastSaveTime.removeValue(forKey: bookId) // Remove throttling
        savePosition(for: bookId, pdfView: pdfView)
    }
    
    func savePosition(for bookId: String, textView: UITextView) {
        // Throttle saves for text view as well
        let now = Date()
        if let lastSave = lastSaveTime[bookId],
           now.timeIntervalSince(lastSave) < minimumSaveInterval {
            return
        }
        lastSaveTime[bookId] = now
        
        // Calculate visible character position based on scroll position
        let visiblePoint = CGPoint(x: 0, y: textView.contentOffset.y)
        let visibleCharacterIndex = textView.characterRange(at: visiblePoint)?.start ?? textView.beginningOfDocument
        let visibleLocation = textView.offset(from: textView.beginningOfDocument, to: visibleCharacterIndex)
        let scrollPercentage = Float(textView.contentOffset.y / max(textView.contentSize.height - textView.bounds.height, 1))
        
        let position = ReadingPosition(
            bookId: bookId,
            timestamp: Date(),
            pageIndex: nil,
            viewportOffset: nil,
            scrollOffset: nil,
            zoomScale: nil,
            pageBounds: nil,
            viewBounds: nil,
            displayMode: nil,
            textOffset: visibleLocation,
            scrollPercentage: scrollPercentage,
            totalPages: nil,
            readingProgress: scrollPercentage,
            precisionLevel: 2
        )
        
        savePosition(position)
    }
    
    /// Force save text position (e.g., when app goes to background)
    func forceSavePosition(for bookId: String, textView: UITextView) {
        lastSaveTime.removeValue(forKey: bookId) // Remove throttling
        savePosition(for: bookId, textView: textView)
    }
    
    /// Get reading statistics for position validation
    func getPositionAccuracy(for bookId: String, pdfView: PDFView) -> (isAccurate: Bool, details: String) {
        guard let position = loadPosition(for: bookId),
              let savedPageIndex = position.pageIndex,
              let document = pdfView.document,
              let currentPage = pdfView.currentPage else {
            return (false, "No saved position or current state")
        }
        
        let currentPageIndex = document.index(for: currentPage)
        let pageAccurate = currentPageIndex == savedPageIndex
        
        var zoomAccurate = true
        if let savedZoom = position.zoomScale {
            zoomAccurate = abs(pdfView.scaleFactor - savedZoom) < 0.01
        }
        
        let details = "Page: \(pageAccurate ? "✓" : "✗") (\(currentPageIndex + 1) vs \(savedPageIndex + 1)), Zoom: \(zoomAccurate ? "✓" : "✗")"
        
        return (pageAccurate && zoomAccurate, details)
    }
    
    func restorePosition(for bookId: String, pdfView: PDFView) {
        guard let position = loadPosition(for: bookId),
              let pageIndex = position.pageIndex,
              let document = pdfView.document,
              pageIndex < document.pageCount,
              let page = document.page(at: pageIndex) else { return }
        
        print("📍 Starting enhanced PDF position restoration: Page \(pageIndex + 1), precision level: \(position.precisionLevel)")
        
        // Set display mode first if available
        if let displayModeString = position.displayMode {
            switch displayModeString {
            case "singlePage":
                pdfView.displayMode = .singlePage
            case "singlePageContinuous":
                pdfView.displayMode = .singlePageContinuous
            case "twoUp":
                pdfView.displayMode = .twoUp
            case "twoUpContinuous":
                pdfView.displayMode = .twoUpContinuous
            default:
                break
            }
        }
        
        // Navigate to page first
        pdfView.go(to: page)
        
        // Use enhanced restoration with validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performEnhancedRestore(pdfView: pdfView, position: position, page: page, attempt: 1)
        }
    }
    
    private func performEnhancedRestore(pdfView: PDFView, position: ReadingPosition, page: PDFPage, attempt: Int) {
        let maxAttempts = 5
        
        // Step 1: Validate and apply zoom with better precision
        if let targetZoom = position.zoomScale {
            let currentZoom = pdfView.scaleFactor
            let zoomTolerance: CGFloat = 0.005 // More precise tolerance
            
            if abs(currentZoom - targetZoom) > zoomTolerance {
                pdfView.scaleFactor = targetZoom
                
                // Wait for zoom to stabilize before position restoration
                if attempt == 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.performEnhancedRestore(pdfView: pdfView, position: position, page: page, attempt: 2)
                    }
                    return
                }
            }
        }
        
        // Step 2: Enhanced position restoration with multiple methods
        if let savedPoint = position.viewportOffset {
            let currentPageBounds = page.bounds(for: .mediaBox)
            
            // Validate saved point is still within page bounds
            guard currentPageBounds.contains(savedPoint) || attempt <= 2 else {
                print("⚠️ Saved point \(savedPoint) outside page bounds \(currentPageBounds), using fallback")
                self.performFallbackRestore(pdfView: pdfView, position: position, page: page)
                return
            }
            
            // Method 1: Use PDFDestination for precise positioning
            let destination = PDFDestination(page: page, at: savedPoint)
            pdfView.go(to: destination)
            
            // Method 2: For continuous modes, also restore scroll offset
            if let scrollOffset = position.scrollOffset,
               (pdfView.displayMode == .singlePageContinuous || pdfView.displayMode == .twoUpContinuous),
               let scrollView = pdfView.documentView?.superview as? UIScrollView {
                
                // Validate scroll offset is reasonable
                let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
                let validatedOffset = CGPoint(
                    x: min(max(0, scrollOffset.x), scrollView.contentSize.width - scrollView.bounds.width),
                    y: min(max(0, scrollOffset.y), maxOffset)
                )
                
                scrollView.setContentOffset(validatedOffset, animated: false)
            }
            
            print("📍 Attempt \(attempt): Applied destination and scroll restoration")
        }
        
        // Step 3: Validation and retry logic
        let validationDelay: TimeInterval = attempt == 1 ? 0.2 : 0.1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + validationDelay) {
            let isAccurate = self.validateRestoration(pdfView: pdfView, position: position, page: page)
            
            if !isAccurate && attempt < maxAttempts {
                print("🔄 Position not accurate, retrying... (\(attempt)/\(maxAttempts))")
                self.performEnhancedRestore(pdfView: pdfView, position: position, page: page, attempt: attempt + 1)
            } else {
                let status = isAccurate ? "✅ Precise" : "⚠️ Best effort"
                print("\(status) position restoration completed after \(attempt) attempts")
            }
        }
    }
    
    private func validateRestoration(pdfView: PDFView, position: ReadingPosition, page: PDFPage) -> Bool {
        guard let savedPoint = position.viewportOffset else { return true }
        
        // Check zoom accuracy
        if let targetZoom = position.zoomScale {
            let zoomDiff = abs(pdfView.scaleFactor - targetZoom)
            if zoomDiff > 0.01 { return false }
        }
        
        // Check position accuracy by reverse-calculating the reading point
        let currentViewBounds = pdfView.bounds
        let readingPoint = CGPoint(
            x: currentViewBounds.midX,
            y: currentViewBounds.minY + (currentViewBounds.height * 0.3)
        )
        let currentPagePoint = pdfView.convert(readingPoint, to: page)
        
        // Allow for reasonable tolerance based on zoom level
        let tolerance: CGFloat = max(10.0, 20.0 / pdfView.scaleFactor)
        let distance = sqrt(pow(currentPagePoint.x - savedPoint.x, 2) + pow(currentPagePoint.y - savedPoint.y, 2))
        
        return distance <= tolerance
    }
    
    private func performFallbackRestore(pdfView: PDFView, position: ReadingPosition, page: PDFPage) {
        // Fallback to progress-based restoration
        if let scrollPercentage = position.scrollPercentage {
            let pageHeight = page.bounds(for: .mediaBox).height
            let targetY = CGFloat(scrollPercentage) * pageHeight
            let fallbackPoint = CGPoint(x: page.bounds(for: .mediaBox).midX, y: targetY)
            
            let destination = PDFDestination(page: page, at: fallbackPoint)
            pdfView.go(to: destination)
            
            print("📍 Used fallback restoration with \(Int(scrollPercentage * 100))% progress")
        }
    }
    
    func restorePosition(for bookId: String, textView: UITextView) {
        guard let position = loadPosition(for: bookId) else { return }
        
        // Wait for text layout to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let textOffset = position.textOffset, textOffset < textView.text.count {
                // Use precise character-based restoration
                let range = NSRange(location: textOffset, length: 0)
                textView.scrollRangeToVisible(range)
                
                // Fine-tune the position
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let rect = textView.layoutManager.boundingRect(forGlyphRange: range, in: textView.textContainer)
                    let targetPoint = CGPoint(x: 0, y: rect.origin.y - textView.bounds.height / 3)
                    textView.setContentOffset(targetPoint, animated: true)
                }
                
                print("📍 Restored text to character \(textOffset)")
            } else if let scrollPercentage = position.scrollPercentage {
                // Fallback to percentage-based scrolling with better precision
                let contentHeight = textView.contentSize.height
                let viewHeight = textView.bounds.height
                let maxOffset = max(0, contentHeight - viewHeight)
                let targetOffset = CGFloat(scrollPercentage) * maxOffset
                
                textView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
                print("📍 Restored text to \(Int(scrollPercentage * 100))% position")
            }
        }
    }
    
    private func savePosition(_ position: ReadingPosition) {
        var positions = loadAllPositions()
        positions[position.bookId] = position
        
        if let data = try? JSONEncoder().encode(positions) {
            userDefaults.set(data, forKey: positionKey)
        }
    }
    
    private func loadPosition(for bookId: String) -> ReadingPosition? {
        let positions = loadAllPositions()
        return positions[bookId]
    }
    
    private func loadAllPositions() -> [String: ReadingPosition] {
        guard let data = userDefaults.data(forKey: positionKey),
              let positions = try? JSONDecoder().decode([String: ReadingPosition].self, from: data) else {
            return [:]
        }
        return positions
    }
    
    // MARK: - Highlight Management
    
    func saveHighlight(for bookId: String, selection: PDFSelection, color: UIColor) -> PDFHighlight? {
        guard let page = selection.pages.first,
              let document = page.document else { return nil }
        
        let pageIndex = document.index(for: page)
        
        // Get quad points for exact text location
        var quadPoints: [[CGFloat]] = []
        
        // Get bounds for each line of the selection
        let lineSelections = selection.selectionsByLine()
        for lineSelection in lineSelections {
            if lineSelection.pages.contains(page) {
                let bounds = lineSelection.bounds(for: page)
                // Convert bounds to quad points (4 corners of the rectangle)
                let quad = [
                    bounds.minX, bounds.minY,  // Bottom-left
                    bounds.maxX, bounds.minY,  // Bottom-right
                    bounds.maxX, bounds.maxY,  // Top-right
                    bounds.minX, bounds.maxY   // Top-left
                ]
                quadPoints.append(quad)
            }
        }
        
        let highlight = PDFHighlight(
            bookId: bookId,
            pageIndex: pageIndex,
            quadPoints: quadPoints,
            text: selection.string ?? "",
            color: color.hexString
        )
        
        saveHighlight(highlight)
        return highlight
    }
    
    func loadHighlights(for bookId: String) -> [PDFHighlight] {
        let allHighlights = loadAllHighlights()
        return allHighlights.filter { $0.bookId == bookId }
    }
    
    func applyHighlights(to pdfView: PDFView, bookId: String) {
        guard let document = pdfView.document else { return }
        
        let highlights = loadHighlights(for: bookId)
        
        for highlight in highlights {
            guard highlight.pageIndex < document.pageCount,
                  let page = document.page(at: highlight.pageIndex) else { continue }
            
            // Create annotation for each quad
            for quad in highlight.quadPoints {
                if quad.count >= 8 {
                    // Create bounds from quad points
                    let minX = min(quad[0], quad[2], quad[4], quad[6])
                    let maxX = max(quad[0], quad[2], quad[4], quad[6])
                    let minY = min(quad[1], quad[3], quad[5], quad[7])
                    let maxY = max(quad[1], quad[3], quad[5], quad[7])
                    
                    let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                    
                    let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                    annotation.color = UIColor(hex: highlight.color) ?? .systemYellow
                    annotation.contents = highlight.text
                    
                    page.addAnnotation(annotation)
                }
            }
        }
        
        print("✅ Applied \(highlights.count) highlights to PDF")
    }
    
    private func saveHighlight(_ highlight: PDFHighlight) {
        var highlights = loadAllHighlights()
        highlights.append(highlight)
        
        if let data = try? JSONEncoder().encode(highlights) {
            userDefaults.set(data, forKey: highlightKey)
        }
    }
    
    private func loadAllHighlights() -> [PDFHighlight] {
        guard let data = userDefaults.data(forKey: highlightKey),
              let highlights = try? JSONDecoder().decode([PDFHighlight].self, from: data) else {
            return []
        }
        return highlights
    }
    
    func deleteHighlight(id: String) {
        var highlights = loadAllHighlights()
        highlights.removeAll { $0.id == id }
        
        if let data = try? JSONEncoder().encode(highlights) {
            userDefaults.set(data, forKey: highlightKey)
        }
    }
}

// MARK: - Helper Extensions

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return String(format: "#%06x", rgb)
    }
}
