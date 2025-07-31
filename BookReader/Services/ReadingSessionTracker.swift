//
//  ReadingSessionTracker.swift
//  BookReader
//
//  Track reading sessions, time, speed, and progress
//

import Foundation
import UIKit

class ReadingSessionTracker {
    static let shared = ReadingSessionTracker()
    private init() {}
    
    // MARK: - Properties
    private var currentSession: ReadingSession?
    private var sessionTimer: Timer?
    private var lastScrollPosition: CGFloat = 0
    private var wordsReadInSession: Int = 0
    
    // MARK: - Session Management
    func startSession(for book: Book) {
        endCurrentSession()
        
        currentSession = ReadingSession(
            bookId: book.id,
            bookTitle: book.title,
            startTime: Date(),
            startPosition: book.lastReadPosition
        )
        
        startTimer()
        updateDailyStreak(for: book)
    }
    
    func endCurrentSession() {
        guard let session = currentSession else { return }
        
        stopTimer()
        
        session.endTime = Date()
        session.wordsRead = wordsReadInSession
        session.duration = session.endTime!.timeIntervalSince(session.startTime)
        
        // Calculate reading speed
        if session.duration > 0 {
            session.readingSpeed = Double(session.wordsRead) / (session.duration / 60.0) // WPM
        }
        
        // Save session
        saveSession(session)
        
        // Update book stats
        updateBookStats(session)
        
        currentSession = nil
        wordsReadInSession = 0
    }
    
    func pauseSession() {
        stopTimer()
    }
    
    func resumeSession() {
        guard currentSession != nil else { return }
        startTimer()
    }
    
    // MARK: - Progress Tracking
    func updateReadingProgress(position: Float, wordsOnScreen: Int) {
        guard let session = currentSession else { return }
        
        session.endPosition = position
        
        // Estimate words read based on position change
        let positionDelta = position - session.startPosition
        if positionDelta > 0 {
            let estimatedWordsRead = Int(positionDelta * Float(wordsOnScreen))
            wordsReadInSession = max(wordsReadInSession, estimatedWordsRead)
        }
    }
    
    func trackPageTurn() {
        guard let session = currentSession else { return }
        session.pagesRead += 1
    }
    
    func trackWordLookup() {
        guard let session = currentSession else { return }
        session.wordLookupsCount += 1
    }
    
    // MARK: - Statistics
    func getReadingStats(for bookId: String) -> ReadingStats? {
        return loadBookStats(bookId: bookId)
    }
    
    func getTodayReadingTime() -> TimeInterval {
        let sessions = loadTodaySessions()
        return sessions.reduce(0) { $0 + $1.duration }
    }
    
    func getWeeklyReadingTime() -> TimeInterval {
        let sessions = loadWeeklySessions()
        return sessions.reduce(0) { $0 + $1.duration }
    }
    
    func getCurrentStreak() -> Int {
        return UserDefaults.standard.integer(forKey: "currentReadingStreak")
    }
    
    func getReadingGoal() -> ReadingGoal {
        if let data = UserDefaults.standard.data(forKey: "readingGoal"),
           let goal = try? JSONDecoder().decode(ReadingGoal.self, from: data) {
            return goal
        }
        
        // Default goal: 30 minutes per day
        return ReadingGoal(type: .time, target: 30 * 60, period: .daily)
    }
    
    func setReadingGoal(_ goal: ReadingGoal) {
        if let data = try? JSONEncoder().encode(goal) {
            UserDefaults.standard.set(data, forKey: "readingGoal")
        }
    }
    
    func getCurrentSessionBookId() -> String? {
        return currentSession?.bookId
    }
    
    // MARK: - Private Methods
    private func startTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionTime()
        }
    }
    
    private func stopTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    private func updateSessionTime() {
        guard let session = currentSession else { return }
        session.duration = Date().timeIntervalSince(session.startTime)
    }
    
    private func saveSession(_ session: ReadingSession) {
        var sessions = loadAllSessions()
        sessions.append(session)
        
        // Keep only last 1000 sessions to avoid storage bloat
        if sessions.count > 1000 {
            sessions = Array(sessions.suffix(1000))
        }
        
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "readingSessions")
        }
    }
    
    private func loadAllSessions() -> [ReadingSession] {
        guard let data = UserDefaults.standard.data(forKey: "readingSessions"),
              let sessions = try? JSONDecoder().decode([ReadingSession].self, from: data) else {
            return []
        }
        return sessions
    }
    
    private func loadTodaySessions() -> [ReadingSession] {
        let sessions = loadAllSessions()
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return sessions.filter { session in
            session.startTime >= today && session.startTime < tomorrow
        }
    }
    
    private func loadWeeklySessions() -> [ReadingSession] {
        let sessions = loadAllSessions()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        return sessions.filter { session in
            session.startTime >= weekAgo
        }
    }
    
    private func updateBookStats(_ session: ReadingSession) {
        var stats = loadBookStats(bookId: session.bookId) ?? ReadingStats()
        
        stats.totalReadingTime += session.duration
        stats.sessionsCount += 1
        stats.wordsRead += session.wordsRead
        stats.pagesRead += session.pagesRead
        stats.lastReadDate = session.endTime
        
        // Update average reading speed
        let totalSessions = Double(stats.sessionsCount)
        stats.averageReadingSpeed = (stats.averageReadingSpeed * (totalSessions - 1) + session.readingSpeed) / totalSessions
        
        saveBookStats(bookId: session.bookId, stats: stats)
    }
    
    private func loadBookStats(bookId: String) -> ReadingStats? {
        let key = "bookStats_\(bookId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(ReadingStats.self, from: data) else {
            return nil
        }
        return stats
    }
    
    private func saveBookStats(bookId: String, stats: ReadingStats) {
        let key = "bookStats_\(bookId)"
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func updateDailyStreak(for book: Book) {
        let lastReadKey = "lastReadDate"
        let streakKey = "currentReadingStreak"
        let longestStreakKey = "longestReadingStreak"
        
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastReadData = UserDefaults.standard.object(forKey: lastReadKey) as? Date {
            let lastReadDay = Calendar.current.startOfDay(for: lastReadData)
            let daysDifference = Calendar.current.dateComponents([.day], from: lastReadDay, to: today).day ?? 0
            
            var currentStreak = UserDefaults.standard.integer(forKey: streakKey)
            
            if daysDifference == 1 {
                // Consecutive day
                currentStreak += 1
            } else if daysDifference > 1 {
                // Streak broken
                currentStreak = 1
            }
            // Same day reading doesn't change streak
            
            UserDefaults.standard.set(currentStreak, forKey: streakKey)
            
            // Update longest streak
            let longestStreak = UserDefaults.standard.integer(forKey: longestStreakKey)
            if currentStreak > longestStreak {
                UserDefaults.standard.set(currentStreak, forKey: longestStreakKey)
            }
        } else {
            // First time reading
            UserDefaults.standard.set(1, forKey: streakKey)
            UserDefaults.standard.set(1, forKey: longestStreakKey)
        }
        
        UserDefaults.standard.set(Date(), forKey: lastReadKey)
    }
    
    deinit {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
}

// MARK: - Models
class ReadingSession: Codable {
    let id: String
    let bookId: String
    let bookTitle: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval = 0
    let startPosition: Float
    var endPosition: Float = 0
    var wordsRead: Int = 0
    var pagesRead: Int = 0
    var readingSpeed: Double = 0 // Words per minute
    var wordLookupsCount: Int = 0
    
    init(bookId: String, bookTitle: String, startTime: Date, startPosition: Float) {
        self.id = UUID().uuidString
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.startTime = startTime
        self.startPosition = startPosition
    }
}

struct ReadingGoal: Codable {
    enum GoalType: String, Codable, CaseIterable {
        case time = "time"
        case pages = "pages"
        case books = "books"
        
        var displayName: String {
            switch self {
            case .time: return "Reading Time"
            case .pages: return "Pages"
            case .books: return "Books"
            }
        }
        
        var unit: String {
            switch self {
            case .time: return "minutes"
            case .pages: return "pages"
            case .books: return "books"
            }
        }
    }
    
    enum GoalPeriod: String, Codable, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        
        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }
    }
    
    let type: GoalType
    let target: Double // Target value (minutes, pages, or books)
    let period: GoalPeriod
    let createdDate: Date
    
    init(type: GoalType, target: Double, period: GoalPeriod, createdDate: Date = Date()) {
        self.type = type
        self.target = target
        self.period = period
        self.createdDate = createdDate
    }
}