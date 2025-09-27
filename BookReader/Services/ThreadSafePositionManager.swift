//
//  ThreadSafePositionManager.swift
//  BookReader
//
//  Thread-safe position management with actor isolation
//

import Foundation
import PDFKit
import UIKit

// MARK: - Actor for thread-safe position management
@available(iOS 13.0, *)
actor PositionManager {
    
    // MARK: - Properties
    private var positions: [String: TrackerPosition] = [:]
    private var pendingSaves: [String: TrackerPosition] = [:]
    private var saveTimestamps: [String: Date] = [:]
    
    // Debouncing configuration
    private let saveDelay: TimeInterval = 1.0 // Wait 1 second before saving
    private let maxPendingTime: TimeInterval = 5.0 // Force save after 5 seconds
    
    // MARK: - Public Methods
    
    func updatePosition(_ position: TrackerPosition) async {
        let bookId = position.bookId
        
        // Update in-memory position immediately
        positions[bookId] = position
        pendingSaves[bookId] = position
        saveTimestamps[bookId] = Date()
        
        // Schedule debounced save
        await scheduleDebouncedSave(for: bookId)
    }
    
    func getPosition(for bookId: String) async -> TrackerPosition? {
        return positions[bookId]
    }
    
    func getAllPositions() async -> [String: TrackerPosition] {
        return positions
    }
    
    func forceSaveAll() async {
        for (bookId, position) in pendingSaves {
            await savePositionToStorage(position)
        }
        pendingSaves.removeAll()
        saveTimestamps.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func scheduleDebouncedSave(for bookId: String) async {
        // Wait for debounce delay
        try? await Task.sleep(nanoseconds: UInt64(saveDelay * 1_000_000_000))
        
        // Check if position is still pending and not too old
        guard let position = pendingSaves[bookId],
              let timestamp = saveTimestamps[bookId] else { return }
        
        let elapsed = Date().timeIntervalSince(timestamp)
        
        // Save if enough time has passed or if it's been too long
        if elapsed >= saveDelay || elapsed >= maxPendingTime {
            await savePositionToStorage(position)
            pendingSaves.removeValue(forKey: bookId)
            saveTimestamps.removeValue(forKey: bookId)
        }
    }
    
    private func savePositionToStorage(_ position: TrackerPosition) async {
        // Save to UnifiedFirebaseStorage on background queue
        await withCheckedContinuation { continuation in
            UnifiedFirebaseStorage.shared.updateReadingProgress(
                bookId: position.bookId,
                position: position.readingProgress
            ) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    break
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - Thread-safe wrapper for older iOS versions
class ThreadSafePositionManager {
    
    // MARK: - Singleton
    static let shared = ThreadSafePositionManager()
    
    // MARK: - Properties
    private let queue = DispatchQueue(label: "com.bookreader.position", qos: .utility)
    private var positions: [String: TrackerPosition] = [:]
    private var saveTimers: [String: Timer] = [:]
    private let saveDelay: TimeInterval = 2.0
    
    // MARK: - Public Methods
    
    func updatePosition(_ position: TrackerPosition) {
        queue.async { [weak self] in
            self?.positions[position.bookId] = position
            self?.debouncedSave(for: position.bookId, position: position)
        }
    }
    
    func getPosition(for bookId: String, completion: @escaping (TrackerPosition?) -> Void) {
        queue.async { [weak self] in
            let position = self?.positions[bookId]
            DispatchQueue.main.async {
                completion(position)
            }
        }
    }
    
    func saveAllPendingPositions() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            for (bookId, position) in self.positions {
                self.savePositionToStorage(position)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func debouncedSave(for bookId: String, position: TrackerPosition) {
        queue.async { [weak self] in
            guard let self = self else { return }

            if let existingTimer = self.saveTimers[bookId] {
                DispatchQueue.main.async {
                    existingTimer.invalidate()
                }
                self.saveTimers.removeValue(forKey: bookId)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let timer = Timer(timeInterval: self.saveDelay, repeats: false) { [weak self] _ in
                    self?.queue.async {
                        self?.savePositionToStorage(position)
                        self?.saveTimers.removeValue(forKey: bookId)
                    }
                }

                RunLoop.main.add(timer, forMode: .common)

                self.queue.async { [weak self] in
                    self?.saveTimers[bookId] = timer
                }
            }
        }
    }
    
    private func savePositionToStorage(_ position: TrackerPosition) {
        UnifiedFirebaseStorage.shared.updateReadingProgress(
            bookId: position.bookId,
            position: position.readingProgress
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                break
            }
        }
    }
    
    deinit {
        // Clean up timers
        queue.sync {
            for timer in saveTimers.values {
                DispatchQueue.main.async {
                    timer.invalidate()
                }
            }
            saveTimers.removeAll()
        }
    }
}

// MARK: - Position Helper Extensions
extension TrackerPosition {
    
    static func fromPDFView(_ pdfView: PDFView, bookId: String) -> TrackerPosition {
        let pageIndex = pdfView.currentPage.flatMap { pdfView.document?.index(for: $0) } ?? 0
        let totalPages = pdfView.document?.pageCount ?? 1
        let progress = Float(pageIndex) / Float(max(totalPages - 1, 1))
        
        return TrackerPosition(
            bookId: bookId,
            timestamp: Date(),
            pageIndex: pageIndex,
            viewportOffset: nil,
            scrollOffset: pdfView.documentView?.bounds.origin,
            zoomScale: pdfView.scaleFactor,
            textOffset: nil,
            scrollPercentage: nil,
            totalPages: totalPages,
            readingProgress: progress
        )
    }
    
    static func fromTextView(_ textView: UITextView, bookId: String, totalLength: Int) -> TrackerPosition {
        let contentHeight = textView.contentSize.height
        let offset = textView.contentOffset.y
        let progress = Float(offset / max(contentHeight - textView.bounds.height, 1))
        
        // Calculate approximate text offset based on scroll position
        let visibleRange = textView.range(from: textView.contentOffset)
        let textOffset = visibleRange?.location ?? 0
        
        return TrackerPosition(
            bookId: bookId,
            timestamp: Date(),
            pageIndex: nil,
            viewportOffset: textView.contentOffset,
            scrollOffset: nil,
            zoomScale: nil,
            textOffset: textOffset,
            scrollPercentage: progress,
            totalPages: nil,
            readingProgress: progress
        )
    }
}

extension UITextView {
    func range(from point: CGPoint) -> NSRange? {
        guard let textPosition = closestPosition(to: point) else { return nil }
        let location = offset(from: beginningOfDocument, to: textPosition)
        return NSRange(location: location, length: 0)
    }
}
