//
//  Book.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//

import UIKit

struct Book: Codable {
    enum BookType: String, Codable {
        case pdf, text, epub, image
    }
    
    let id: String
    let title: String
    let author: String
    var filePath: String
    var storageFileName: String?
    let type: BookType
    let coverImage: UIImage?
    var lastReadPosition: Float = 0
    var bookmarks: [Bookmark] = []
    var highlights: [Highlight] = []
    var notes: [Note] = []
    var readingStats: ReadingStats = ReadingStats()
    var personalSummary: String = ""
    var keyTakeaways: String = ""
    var actionItems: String = ""
    var sessionNotes: [BookSessionNote] = []
    var notesUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, author, filePath, storageFileName, type, lastReadPosition, bookmarks, highlights, notes, readingStats, personalSummary, keyTakeaways, actionItems, sessionNotes, notesUpdatedAt
        // Exclude coverImage from Codable
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath) ?? ""
        storageFileName = try container.decodeIfPresent(String.self, forKey: .storageFileName)
        type = try container.decode(BookType.self, forKey: .type)
        lastReadPosition = try container.decodeIfPresent(Float.self, forKey: .lastReadPosition) ?? 0.0
        bookmarks = try container.decodeIfPresent([Bookmark].self, forKey: .bookmarks) ?? []
        highlights = try container.decodeIfPresent([Highlight].self, forKey: .highlights) ?? []
        notes = try container.decodeIfPresent([Note].self, forKey: .notes) ?? []
        readingStats = try container.decodeIfPresent(ReadingStats.self, forKey: .readingStats) ?? ReadingStats()
        personalSummary = try container.decodeIfPresent(String.self, forKey: .personalSummary) ?? ""
        keyTakeaways = try container.decodeIfPresent(String.self, forKey: .keyTakeaways) ?? ""
        actionItems = try container.decodeIfPresent(String.self, forKey: .actionItems) ?? ""
        sessionNotes = try container.decodeIfPresent([BookSessionNote].self, forKey: .sessionNotes) ?? []
        if let notesUpdatedString = try container.decodeIfPresent(String.self, forKey: .notesUpdatedAt) {
            let formatter = ISO8601DateFormatter()
            notesUpdatedAt = formatter.date(from: notesUpdatedString)
        } else {
            notesUpdatedAt = nil
        }
        // coverImage is set to nil since it's not stored in Codable
        coverImage = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(filePath, forKey: .filePath)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(storageFileName, forKey: .storageFileName)
        try container.encode(lastReadPosition, forKey: .lastReadPosition)
        try container.encode(bookmarks, forKey: .bookmarks)
        try container.encode(highlights, forKey: .highlights)
        try container.encode(notes, forKey: .notes)
        try container.encode(readingStats, forKey: .readingStats)
        try container.encode(personalSummary, forKey: .personalSummary)
        try container.encode(keyTakeaways, forKey: .keyTakeaways)
        try container.encode(actionItems, forKey: .actionItems)
        try container.encode(sessionNotes, forKey: .sessionNotes)
        if let notesUpdatedAt {
            let formatter = ISO8601DateFormatter()
            try container.encode(formatter.string(from: notesUpdatedAt), forKey: .notesUpdatedAt)
        }
        // coverImage is not encoded since UIImage doesn't conform to Codable
    }
    
    init(id: String = UUID().uuidString,
         title: String,
         author: String = "Unknown",
         filePath: String,
         type: BookType,
         coverImage: UIImage? = nil,
         lastReadPosition: Float = 0,
         bookmarks: [Bookmark] = [],
         highlights: [Highlight] = [],
         notes: [Note] = [],
         readingStats: ReadingStats = ReadingStats(),
         personalSummary: String = "",
         keyTakeaways: String = "",
         actionItems: String = "",
         sessionNotes: [BookSessionNote] = [],
         notesUpdatedAt: Date? = nil,
         storageFileName: String? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.filePath = filePath
        self.type = type
        self.coverImage = coverImage
        self.lastReadPosition = lastReadPosition
        self.bookmarks = bookmarks
        self.highlights = highlights
        self.notes = notes
        self.readingStats = readingStats
        self.personalSummary = personalSummary
        self.keyTakeaways = keyTakeaways
        self.actionItems = actionItems
        self.sessionNotes = sessionNotes
        self.notesUpdatedAt = notesUpdatedAt
        self.storageFileName = storageFileName
    }
}

struct BookSessionNote: Codable, Identifiable {
    let id: String
    var text: String
    var tags: [String]
    var pageHint: Int?
    var createdAt: Date
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, text, tags, pageHint, createdAt, updatedAt
    }

    init(id: String = UUID().uuidString,
         text: String,
         tags: [String] = [],
         pageHint: Int? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.tags = tags
        self.pageHint = pageHint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        pageHint = try container.decodeIfPresent(Int.self, forKey: .pageHint)

        let formatter = ISO8601DateFormatter()
        if let createdString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = formatter.date(from: createdString) ?? Date()
        } else if let createdDate = try container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = createdDate
        } else {
            createdAt = Date()
        }

        if let updatedString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt = formatter.date(from: updatedString) ?? createdAt
        } else if let updatedDate = try container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            updatedAt = updatedDate
        } else {
            updatedAt = createdAt
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(pageHint, forKey: .pageHint)

        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(formatter.string(from: updatedAt), forKey: .updatedAt)
    }
}

struct Bookmark: Codable {
    let id: String
    let position: Float
    let note: String?
    let dateCreated: Date
    
    enum CodingKeys: String, CodingKey {
        case id, position, note, dateCreated
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        position = try container.decode(Float.self, forKey: .position)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        
        // Handle date string conversion
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dateCreated) {
            let formatter = ISO8601DateFormatter()
            dateCreated = formatter.date(from: dateString) ?? Date()
        } else {
            dateCreated = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(position, forKey: .position)
        try container.encodeIfPresent(note, forKey: .note)
        
        // Convert date to string
        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: dateCreated), forKey: .dateCreated)
    }
    
    init(id: String = UUID().uuidString,
         position: Float,
         note: String? = nil,
         dateCreated: Date = Date()) {
        self.id = id
        self.position = position
        self.note = note
        self.dateCreated = dateCreated
    }
}

struct Highlight: Codable {
    enum HighlightColor: String, CaseIterable, Codable {
        case yellow = "#FFFF00"
        case green = "#00FF00"
        case pink = "#FF69B4"
        case blue = "#00BFFF"
        case orange = "#FFA500"
        
        var uiColor: UIColor {
            return UIColor(hex: self.rawValue) ?? .yellow
        }
        
        var displayName: String {
            switch self {
            case .yellow: return "Yellow"
            case .green: return "Green"
            case .pink: return "Pink"
            case .blue: return "Blue"
            case .orange: return "Orange"
            }
        }
    }
    
    let id: String
    let text: String
    let color: HighlightColor
    let position: TextPosition
    let selectionRects: [SelectionRect]?
    let dateCreated: Date
    var note: String?
    
    enum CodingKeys: String, CodingKey {
        case id, text, color, position, selectionRects, dateCreated, note
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        color = try container.decode(HighlightColor.self, forKey: .color)
        position = try container.decode(TextPosition.self, forKey: .position)
        selectionRects = try container.decodeIfPresent([SelectionRect].self, forKey: .selectionRects)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        
        // Handle date string conversion
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dateCreated) {
            let formatter = ISO8601DateFormatter()
            dateCreated = formatter.date(from: dateString) ?? Date()
        } else {
            dateCreated = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(color, forKey: .color)
        try container.encode(position, forKey: .position)
        try container.encodeIfPresent(selectionRects, forKey: .selectionRects)
        try container.encodeIfPresent(note, forKey: .note)
        
        // Convert date to string
        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: dateCreated), forKey: .dateCreated)
    }
    
    init(id: String = UUID().uuidString,
         text: String,
         color: HighlightColor,
         position: TextPosition,
         note: String? = nil,
         selectionRects: [SelectionRect]? = nil,
         dateCreated: Date = Date()) {
        self.id = id
        self.text = text
        self.color = color
        self.position = position
        self.note = note
        self.selectionRects = selectionRects
        self.dateCreated = dateCreated
    }
}

struct SelectionRect: Codable {
    let pageIndex: Int
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    init(pageIndex: Int, rect: CGRect) {
        self.pageIndex = pageIndex
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.width
        self.height = rect.height
    }
    
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct Note: Codable {
    let id: String
    let title: String
    let content: String
    let position: TextPosition?
    let dateCreated: Date
    let dateModified: Date
    var tags: [String] = []
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, position, dateCreated, dateModified, tags
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        position = try container.decodeIfPresent(TextPosition.self, forKey: .position)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        
        let formatter = ISO8601DateFormatter()
        
        // Handle dateCreated string conversion
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dateCreated) {
            dateCreated = formatter.date(from: dateString) ?? Date()
        } else {
            dateCreated = Date()
        }
        
        // Handle dateModified string conversion
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dateModified) {
            dateModified = formatter.date(from: dateString) ?? Date()
        } else {
            dateModified = Date()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encode(tags, forKey: .tags)
        
        // Convert dates to strings
        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: dateCreated), forKey: .dateCreated)
        try container.encode(formatter.string(from: dateModified), forKey: .dateModified)
    }
    
    init(id: String = UUID().uuidString,
         title: String,
         content: String,
         position: TextPosition? = nil,
         tags: [String] = [],
         dateCreated: Date = Date(),
         dateModified: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.position = position
        self.tags = tags
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }
}

struct TextPosition: Codable {
    let startOffset: Int
    let endOffset: Int
    let chapter: String?
    let pageNumber: Int?
    
    init(startOffset: Int, endOffset: Int, chapter: String? = nil, pageNumber: Int? = nil) {
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.chapter = chapter
        self.pageNumber = pageNumber
    }
}

struct ReadingStats: Codable {
    var totalReadingTime: TimeInterval = 0
    var sessionsCount: Int = 0
    var averageReadingSpeed: Double = 0 // Words per minute
    var lastReadDate: Date?
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var wordsRead: Int = 0
    var pagesRead: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case totalReadingTime, sessionsCount, averageReadingSpeed, lastReadDate
        case currentStreak, longestStreak, wordsRead, pagesRead
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalReadingTime = try container.decodeIfPresent(TimeInterval.self, forKey: .totalReadingTime) ?? 0
        sessionsCount = try container.decodeIfPresent(Int.self, forKey: .sessionsCount) ?? 0
        averageReadingSpeed = try container.decodeIfPresent(Double.self, forKey: .averageReadingSpeed) ?? 0
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        wordsRead = try container.decodeIfPresent(Int.self, forKey: .wordsRead) ?? 0
        pagesRead = try container.decodeIfPresent(Int.self, forKey: .pagesRead) ?? 0
        
        // Handle date string conversion
        if let dateString = try container.decodeIfPresent(String.self, forKey: .lastReadDate) {
            let formatter = ISO8601DateFormatter()
            lastReadDate = formatter.date(from: dateString)
        } else {
            lastReadDate = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalReadingTime, forKey: .totalReadingTime)
        try container.encode(sessionsCount, forKey: .sessionsCount)
        try container.encode(averageReadingSpeed, forKey: .averageReadingSpeed)
        try container.encode(currentStreak, forKey: .currentStreak)
        try container.encode(longestStreak, forKey: .longestStreak)
        try container.encode(wordsRead, forKey: .wordsRead)
        try container.encode(pagesRead, forKey: .pagesRead)
        
        // Convert date to string
        if let lastReadDate = lastReadDate {
            let formatter = ISO8601DateFormatter()
            try container.encode(formatter.string(from: lastReadDate), forKey: .lastReadDate)
        }
    }
    
    init(totalReadingTime: TimeInterval = 0,
         sessionsCount: Int = 0,
         averageReadingSpeed: Double = 0,
         lastReadDate: Date? = nil,
         currentStreak: Int = 0,
         longestStreak: Int = 0,
         wordsRead: Int = 0,
         pagesRead: Int = 0) {
        self.totalReadingTime = totalReadingTime
        self.sessionsCount = sessionsCount
        self.averageReadingSpeed = averageReadingSpeed
        self.lastReadDate = lastReadDate
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.wordsRead = wordsRead
        self.pagesRead = pagesRead
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1.0
                    
                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }
        
        return nil
    }
}
