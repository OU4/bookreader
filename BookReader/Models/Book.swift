//
//  Book.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//

import UIKit

struct Book {
    enum BookType: String, Codable {
        case pdf, text, epub, image
    }
    
    let id: String
    let title: String
    let author: String
    var filePath: String
    let type: BookType
    let coverImage: UIImage?
    var lastReadPosition: Float = 0
    var bookmarks: [Bookmark] = []
    var highlights: [Highlight] = []
    var notes: [Note] = []
    var readingStats: ReadingStats = ReadingStats()
    
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
         readingStats: ReadingStats = ReadingStats()) {
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
    }
}

struct Bookmark: Codable {
    let id: String
    let position: Float
    let note: String?
    let dateCreated: Date
    
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
    let dateCreated: Date
    var note: String?
    
    init(id: String = UUID().uuidString,
         text: String,
         color: HighlightColor,
         position: TextPosition,
         note: String? = nil,
         dateCreated: Date = Date()) {
        self.id = id
        self.text = text
        self.color = color
        self.position = position
        self.note = note
        self.dateCreated = dateCreated
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
