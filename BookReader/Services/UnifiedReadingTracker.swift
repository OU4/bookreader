//
//  UnifiedReadingTracker.swift
//  BookReader
//
//  Consolidated reading tracker that combines position, session, and goal tracking
//

import Foundation
import PDFKit
import UIKit

// MARK: - Models
struct ReadingSession: Codable {
    let id: String = UUID().uuidString
    let bookId: String
    let bookTitle: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0
    let startPosition: Float
    var endPosition: Float = 0
    var pagesRead: Int = 0
    
    var isActive: Bool {
        return endTime == nil
    }
}

struct TrackerPosition: Codable {
    let bookId: String
    let timestamp: Date
    
    // For PDFs
    let pageIndex: Int?
    let viewportOffset: CGPoint?
    let scrollOffset: CGPoint?
    let zoomScale: CGFloat?
    
    // For text files
    let textOffset: Int?
    let scrollPercentage: Float?
    
    // Common
    let totalPages: Int?
    let readingProgress: Float
}

struct DailyGoal: Codable {
    var targetMinutes: Int = 30
    var isEnabled: Bool = true
}

struct TrackerStats: Codable {
    var totalReadingTime: TimeInterval = 0
    var sessionsCount: Int = 0
    var currentStreak: Int = 0
    var lastReadDate: Date?
    var todayReadingTime: TimeInterval = 0
}

// MARK: - Unified Reading Tracker
class UnifiedReadingTracker {
    static let shared = UnifiedReadingTracker()
    
    // MARK: - Properties
    private var currentSession: ReadingSession?
    private var sessionTimer: Timer?
    private let userDefaults = UserDefaults.standard
    
    // Storage keys
    private let positionsKey = "UnifiedTrackerPositions"
    private let sessionsKey = "UnifiedReadingSessions"
    private let statsKey = "UnifiedReadingStats"
    private let goalKey = "UnifiedDailyGoal"
    private let lastSaveTimeKey = "UnifiedLastSaveTime"
    
    // Prevent excessive saves
    private var lastSaveTime: [String: Date] = [:]
    private let minimumSaveInterval: TimeInterval = 2.0
    
    private init() {
        loadLastSaveTimes()
    }
    
    // MARK: - Session Management
    func startSession(for book: Book) {
        // End any existing session
        if let existingSession = currentSession {
            endSession()
        }
        
        // Create new session
        currentSession = ReadingSession(
            bookId: book.id,
            bookTitle: book.title,
            startTime: Date(),
            startPosition: book.lastReadPosition
        )
        
        // Start timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionDuration()
        }
        
        // Update last read date
        updateLastReadDate()
        
        print("📖 Started reading session for: \(book.title)")
    }
    
    func pauseSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        if let session = currentSession {
            updateSessionDuration()
            saveCurrentSession()
            print("⏸️ Paused reading session")
        }
    }
    
    func resumeSession() {
        guard currentSession != nil else { return }
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionDuration()
        }
        
        print("▶️ Resumed reading session")
    }
    
    func endSession() {
        guard let session = currentSession else { return }
        
        // Stop timer
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Update session
        var finalSession = session
        finalSession.endTime = Date()
        updateSessionDuration()
        
        // Save session
        saveSession(finalSession)
        
        // Update stats
        updateReadingStats(with: finalSession)
        
        // Clear current session
        currentSession = nil
        
        print("🏁 Ended reading session. Duration: \(Int(finalSession.duration / 60)) minutes")
    }
    
    private func updateSessionDuration() {
        guard var session = currentSession else { return }
        session.duration = Date().timeIntervalSince(session.startTime)
        currentSession = session
    }
    
    // MARK: - Position Management
    func savePosition(for bookId: String, pdfView: PDFView) {
        // Check minimum save interval
        if let lastSave = lastSaveTime[bookId],
           Date().timeIntervalSince(lastSave) < minimumSaveInterval {
            return
        }
        
        guard let currentPage = pdfView.currentPage,
              let document = pdfView.document else { return }
        
        let pageIndex = document.index(for: currentPage)
        let visibleRect = pdfView.convert(pdfView.bounds, to: currentPage)
        let scrollOffset = pdfView.documentView?.bounds.origin ?? .zero
        
        let position = TrackerPosition(
            bookId: bookId,
            timestamp: Date(),
            pageIndex: pageIndex,
            viewportOffset: visibleRect.origin,
            scrollOffset: scrollOffset,
            zoomScale: pdfView.scaleFactor,
            textOffset: nil,
            scrollPercentage: nil,
            totalPages: document.pageCount,
            readingProgress: Float(pageIndex + 1) / Float(document.pageCount)
        )
        
        savePosition(position)
        
        // Update session position if active
        if var session = currentSession, session.bookId == bookId {
            session.endPosition = position.readingProgress
            session.pagesRead = max(session.pagesRead, pageIndex + 1 - Int(session.startPosition * Float(document.pageCount)))
            currentSession = session
        }
        
        lastSaveTime[bookId] = Date()
    }
    
    func savePosition(for bookId: String, textView: UITextView, totalLength: Int) {
        // Check minimum save interval
        if let lastSave = lastSaveTime[bookId],
           Date().timeIntervalSince(lastSave) < minimumSaveInterval {
            return
        }
        
        // Simple position tracking based on scroll offset
        let scrollPercentage = Float(textView.contentOffset.y / max(1, textView.contentSize.height - textView.bounds.height))
        let estimatedPosition = Int(scrollPercentage * Float(totalLength))
        let readingProgress = scrollPercentage
        
        let position = TrackerPosition(
            bookId: bookId,
            timestamp: Date(),
            pageIndex: nil,
            viewportOffset: nil,
            scrollOffset: nil,
            zoomScale: nil,
            textOffset: estimatedPosition,
            scrollPercentage: scrollPercentage,
            totalPages: nil,
            readingProgress: readingProgress
        )
        
        savePosition(position)
        
        // Update session position if active
        if var session = currentSession, session.bookId == bookId {
            session.endPosition = position.readingProgress
            currentSession = session
        }
        
        lastSaveTime[bookId] = Date()
    }
    
    func loadPosition(for bookId: String) -> TrackerPosition? {
        let positions = loadAllPositions()
        return positions[bookId]
    }
    
    func restorePosition(for bookId: String, in pdfView: PDFView) {
        guard let position = loadPosition(for: bookId),
              let pageIndex = position.pageIndex,
              let document = pdfView.document,
              pageIndex < document.pageCount else { return }
        
        let page = document.page(at: pageIndex)
        pdfView.go(to: page!)
        
        if let zoomScale = position.zoomScale {
            pdfView.scaleFactor = zoomScale
        }
        
        print("📍 Restored PDF position: page \(pageIndex + 1)")
    }
    
    func restorePosition(for bookId: String, in textView: UITextView) {
        guard let position = loadPosition(for: bookId),
              let textOffset = position.textOffset else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if textOffset < textView.text.count {
                let nsRange = NSRange(location: textOffset, length: 0)
                textView.scrollRangeToVisible(nsRange)
            }
        }
        
        print("📍 Restored text position: offset \(textOffset)")
    }
    
    // MARK: - Goal Management
    func getDailyGoal() -> DailyGoal {
        if let data = userDefaults.data(forKey: goalKey),
           let goal = try? JSONDecoder().decode(DailyGoal.self, from: data) {
            return goal
        }
        return DailyGoal()
    }
    
    func updateDailyGoal(_ goal: DailyGoal) {
        if let data = try? JSONEncoder().encode(goal) {
            userDefaults.set(data, forKey: goalKey)
        }
    }
    
    func getTodayProgress() -> (minutes: Int, percentage: Double) {
        let stats = getTrackerStats()
        let todayMinutes = Int(stats.todayReadingTime / 60)
        let goal = getDailyGoal()
        let percentage = goal.isEnabled ? Double(todayMinutes) / Double(goal.targetMinutes) * 100 : 0
        return (todayMinutes, min(percentage, 100))
    }
    
    // MARK: - Statistics
    func getTrackerStats() -> TrackerStats {
        if let data = userDefaults.data(forKey: statsKey),
           let stats = try? JSONDecoder().decode(TrackerStats.self, from: data) {
            
            // Check if we need to reset today's reading time
            var updatedStats = stats
            if let lastRead = stats.lastReadDate,
               !Calendar.current.isDateInToday(lastRead) {
                updatedStats.todayReadingTime = 0
                saveStats(updatedStats)
            }
            
            return updatedStats
        }
        return TrackerStats()
    }
    
    func getCurrentStreak() -> Int {
        return getTrackerStats().currentStreak
    }
    
    // MARK: - Private Methods
    private func savePosition(_ position: TrackerPosition) {
        var positions = loadAllPositions()
        positions[position.bookId] = position
        
        if let data = try? JSONEncoder().encode(positions) {
            userDefaults.set(data, forKey: positionsKey)
        }
    }
    
    private func loadAllPositions() -> [String: TrackerPosition] {
        if let data = userDefaults.data(forKey: positionsKey),
           let positions = try? JSONDecoder().decode([String: TrackerPosition].self, from: data) {
            return positions
        }
        return [:]
    }
    
    private func saveSession(_ session: ReadingSession) {
        var sessions = loadAllSessions()
        sessions.append(session)
        
        // Keep only last 100 sessions
        if sessions.count > 100 {
            sessions = Array(sessions.suffix(100))
        }
        
        if let data = try? JSONEncoder().encode(sessions) {
            userDefaults.set(data, forKey: sessionsKey)
        }
    }
    
    private func saveCurrentSession() {
        guard let session = currentSession else { return }
        var tempSession = session
        tempSession.endTime = Date()
        saveSession(tempSession)
    }
    
    private func loadAllSessions() -> [ReadingSession] {
        if let data = userDefaults.data(forKey: sessionsKey),
           let sessions = try? JSONDecoder().decode([ReadingSession].self, from: data) {
            return sessions
        }
        return []
    }
    
    private func updateReadingStats(with session: ReadingSession) {
        var stats = getTrackerStats()
        
        stats.totalReadingTime += session.duration
        stats.sessionsCount += 1
        
        // Update today's reading time
        if Calendar.current.isDateInToday(session.startTime) {
            stats.todayReadingTime += session.duration
        }
        
        // Update streak
        if let lastRead = stats.lastReadDate {
            if Calendar.current.isDateInToday(lastRead) {
                // Already read today, no change
            } else if Calendar.current.isDateInYesterday(lastRead) {
                // Read yesterday, increment streak
                stats.currentStreak += 1
            } else {
                // Missed days, reset streak
                stats.currentStreak = 1
            }
        } else {
            // First time reading
            stats.currentStreak = 1
        }
        
        stats.lastReadDate = Date()
        saveStats(stats)
    }
    
    private func updateLastReadDate() {
        var stats = getTrackerStats()
        
        // Update streak if this is the first read today
        if let lastRead = stats.lastReadDate {
            if !Calendar.current.isDateInToday(lastRead) {
                if Calendar.current.isDateInYesterday(lastRead) {
                    stats.currentStreak += 1
                } else {
                    stats.currentStreak = 1
                }
            }
        } else {
            stats.currentStreak = 1
        }
        
        stats.lastReadDate = Date()
        saveStats(stats)
    }
    
    private func saveStats(_ stats: TrackerStats) {
        if let data = try? JSONEncoder().encode(stats) {
            userDefaults.set(data, forKey: statsKey)
        }
    }
    
    private func loadLastSaveTimes() {
        if let data = userDefaults.data(forKey: lastSaveTimeKey),
           let times = try? JSONDecoder().decode([String: Date].self, from: data) {
            lastSaveTime = times
        }
    }
    
    // MARK: - Bookmark Integration
    func addQuickBookmark(for bookId: String, bookTitle: String, pdfView: PDFView? = nil, textView: UITextView? = nil) {
        if let pdfView = pdfView {
            _ = BookmarkManager.shared.addBookmarkFromPDF(
                bookId: bookId,
                bookTitle: bookTitle,
                pdfView: pdfView,
                title: "Quick Bookmark"
            )
        } else if let textView = textView {
            _ = BookmarkManager.shared.addBookmarkFromText(
                bookId: bookId,
                bookTitle: bookTitle,
                textView: textView,
                title: "Quick Bookmark"
            )
        }
    }
    
    func getBookmarkCount(for bookId: String) -> Int {
        return BookmarkManager.shared.getBookmarkCount(for: bookId)
    }
    
    // MARK: - Cleanup
    deinit {
        sessionTimer?.invalidate()
    }
}