//
//  ThreadSafeReadingPositionManager.swift
//  BookReader
//
//  Thread-safe version of ReadingPositionManager with proper synchronization
//

import Foundation
import PDFKit

// MARK: - Thread-Safe Reading Position Manager
class ThreadSafeReadingPositionManager {
    static let shared = ThreadSafeReadingPositionManager()
    
    // Thread safety
    private let queue = DispatchQueue(label: "com.bookreader.positionmanager", attributes: .concurrent)
    
    // Storage
    private let userDefaults = UserDefaults.standard
    private let positionKey = "ReadingPositions"
    private let highlightKey = "PDFHighlights"
    
    // Position tracking with thread-safe access
    private var _lastSaveTime: [String: Date] = [:]
    private let minimumSaveInterval: TimeInterval = 2.0
    
    // Thread-safe accessors
    private var lastSaveTime: [String: Date] {
        get {
            queue.sync {
                return _lastSaveTime
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._lastSaveTime = newValue
            }
        }
    }
    
    private init() {}
    
    // MARK: - Thread-Safe Position Management
    
    func savePosition(for bookId: String, pdfView: PDFView) {
        guard let document = pdfView.document,
              let currentPage = pdfView.currentPage else { return }
        
        // Thread-safe throttle check
        let shouldSave = queue.sync(flags: .barrier) { () -> Bool in
            let now = Date()
            if let lastSave = _lastSaveTime[bookId],
               now.timeIntervalSince(lastSave) < minimumSaveInterval {
                return false
            }
            _lastSaveTime[bookId] = now
            return true
        }
        
        guard shouldSave else { return }
        
        // Gather position data (safe to do outside the queue)
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
        
        // Save position thread-safely
        savePositionThreadSafe(position)
        
    }
    
    /// Force save position (e.g., when app goes to background)
    func forceSavePosition(for bookId: String, pdfView: PDFView) {
        // Thread-safe removal of throttling
        queue.async(flags: .barrier) {
            self._lastSaveTime.removeValue(forKey: bookId)
        }
        savePosition(for: bookId, pdfView: pdfView)
    }
    
    func savePosition(for bookId: String, textView: UITextView, totalLength: Int) {
        // Thread-safe throttle check
        let shouldSave = queue.sync(flags: .barrier) { () -> Bool in
            let now = Date()
            if let lastSave = _lastSaveTime[bookId],
               now.timeIntervalSince(lastSave) < minimumSaveInterval {
                return false
            }
            _lastSaveTime[bookId] = now
            return true
        }
        
        guard shouldSave else { return }
        
        let offset = textView.contentOffset.y
        let contentHeight = textView.contentSize.height
        let frameHeight = textView.frame.height
        let scrollPercentage = Float(offset / max(contentHeight - frameHeight, 1))
        
        // Get visible range for text offset
        let visibleRect = CGRect(origin: textView.contentOffset, size: textView.bounds.size)
        let textRange = textView.layoutManager.characterRange(forGlyphRange: textView.layoutManager.glyphRange(forBoundingRect: visibleRect, in: textView.textContainer), actualGlyphRange: nil)
        
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
            textOffset: textRange.location,
            scrollPercentage: scrollPercentage,
            totalPages: nil,
            readingProgress: scrollPercentage,
            precisionLevel: 2
        )
        
        savePositionThreadSafe(position)
        
    }
    
    private func savePositionThreadSafe(_ position: ReadingPosition) {
        queue.async(flags: .barrier) {
            // Get existing positions
            var positions = self.loadPositionsThreadSafe()
            positions[position.bookId] = position
            
            // Save to UserDefaults
            if let encoded = try? JSONEncoder().encode(positions) {
                self.userDefaults.set(encoded, forKey: self.positionKey)
                
                // Also save to Firebase in background
                DispatchQueue.global(qos: .background).async {
                    UnifiedFirebaseStorage.shared.updateReadingProgress(
                        bookId: position.bookId,
                        position: position.readingProgress
                    ) { _ in }
                }
            }
        }
    }
    
    private func loadPositionsThreadSafe() -> [String: ReadingPosition] {
        guard let data = userDefaults.data(forKey: positionKey),
              let positions = try? JSONDecoder().decode([String: ReadingPosition].self, from: data) else {
            return [:]
        }
        return positions
    }
    
    func loadPosition(for bookId: String) -> ReadingPosition? {
        return queue.sync {
            return loadPositionsThreadSafe()[bookId]
        }
    }
    
    // MARK: - Thread-Safe Highlight Management
    
    private var _highlightCache: [String: [PDFHighlight]] = [:]
    
    func saveHighlight(_ highlight: PDFHighlight) {
        queue.async(flags: .barrier) {
            // Update cache
            if self._highlightCache[highlight.bookId] == nil {
                self._highlightCache[highlight.bookId] = []
            }
            self._highlightCache[highlight.bookId]?.append(highlight)
            
            // Save all highlights for this book
            self.saveHighlightsThreadSafe(for: highlight.bookId)
        }
    }
    
    func loadHighlights(for bookId: String) -> [PDFHighlight] {
        return queue.sync {
            // Check cache first
            if let cached = _highlightCache[bookId] {
                return cached
            }
            
            // Load from storage
            guard let data = userDefaults.data(forKey: "\(highlightKey)_\(bookId)"),
                  let highlights = try? JSONDecoder().decode([PDFHighlight].self, from: data) else {
                return []
            }
            
            // Update cache
            _highlightCache[bookId] = highlights
            return highlights
        }
    }
    
    func deleteHighlight(withId highlightId: String, bookId: String) {
        queue.async(flags: .barrier) {
            self._highlightCache[bookId]?.removeAll { $0.id == highlightId }
            self.saveHighlightsThreadSafe(for: bookId)
        }
    }
    
    private func saveHighlightsThreadSafe(for bookId: String) {
        guard let highlights = _highlightCache[bookId],
              let encoded = try? JSONEncoder().encode(highlights) else { return }
        
        userDefaults.set(encoded, forKey: "\(highlightKey)_\(bookId)")
    }
    
    // MARK: - Cleanup
    
    func clearAllData() {
        queue.async(flags: .barrier) {
            self._lastSaveTime.removeAll()
            self._highlightCache.removeAll()
            self.userDefaults.removeObject(forKey: self.positionKey)
            
            // Clear all highlight data
            if let bundleID = Bundle.main.bundleIdentifier {
                for key in self.userDefaults.dictionaryRepresentation().keys {
                    if key.starts(with: self.highlightKey) {
                        self.userDefaults.removeObject(forKey: key)
                    }
                }
            }
        }
    }
    
    func clearData(for bookId: String) {
        queue.async(flags: .barrier) {
            self._lastSaveTime.removeValue(forKey: bookId)
            self._highlightCache.removeValue(forKey: bookId)
            
            // Remove position
            var positions = self.loadPositionsThreadSafe()
            positions.removeValue(forKey: bookId)
            if let encoded = try? JSONEncoder().encode(positions) {
                self.userDefaults.set(encoded, forKey: self.positionKey)
            }
            
            // Remove highlights
            self.userDefaults.removeObject(forKey: "\(self.highlightKey)_\(bookId)")
        }
    }
}