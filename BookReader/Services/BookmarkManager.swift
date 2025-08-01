//
//  BookmarkManager.swift
//  BookReader
//
//  Comprehensive bookmark management system
//

import Foundation
import PDFKit
import UIKit

// MARK: - Enhanced Bookmark Model
struct BookmarkItem: Codable, Identifiable {
    let id: String
    let bookId: String
    let bookTitle: String
    let title: String
    let note: String?
    let dateCreated: Date
    let dateModified: Date
    
    // Position information
    let pageNumber: Int?       // For PDFs
    let textOffset: Int?       // For text files
    let scrollPercentage: Float // Universal position
    let readingProgress: Float  // Percentage through book
    
    // Visual context
    let contextText: String?    // Surrounding text for preview
    let chapterTitle: String?   // Chapter or section name
    
    // Bookmark type
    let type: BookmarkType
    
    enum BookmarkType: String, Codable, CaseIterable {
        case bookmark = "bookmark"      // Standard bookmark
        case important = "important"    // Important passage
        case question = "question"      // Question to revisit
        case favorite = "favorite"      // Favorite quote/passage
        
        var icon: String {
            switch self {
            case .bookmark: return "bookmark.fill"
            case .important: return "exclamationmark.triangle.fill"
            case .question: return "questionmark.circle.fill"
            case .favorite: return "heart.fill"
            }
        }
        
        var color: UIColor {
            switch self {
            case .bookmark: return .systemBlue
            case .important: return .systemRed
            case .question: return .systemOrange
            case .favorite: return .systemPink
            }
        }
        
        var displayName: String {
            switch self {
            case .bookmark: return "Bookmark"
            case .important: return "Important"
            case .question: return "Question"
            case .favorite: return "Favorite"
            }
        }
    }
    
    init(id: String = UUID().uuidString,
         bookId: String,
         bookTitle: String,
         title: String,
         note: String? = nil,
         pageNumber: Int? = nil,
         textOffset: Int? = nil,
         scrollPercentage: Float,
         readingProgress: Float,
         contextText: String? = nil,
         chapterTitle: String? = nil,
         type: BookmarkType = .bookmark) {
        self.id = id
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.title = title
        self.note = note
        self.dateCreated = Date()
        self.dateModified = Date()
        self.pageNumber = pageNumber
        self.textOffset = textOffset
        self.scrollPercentage = scrollPercentage
        self.readingProgress = readingProgress
        self.contextText = contextText
        self.chapterTitle = chapterTitle
        self.type = type
    }
}

// MARK: - Bookmark Manager
class BookmarkManager {
    static let shared = BookmarkManager()
    
    private let userDefaults = UserDefaults.standard
    private let bookmarksKey = "SavedBookmarks"
    
    private init() {}
    
    // MARK: - Bookmark Operations
    
    func addBookmark(
        bookId: String,
        bookTitle: String,
        title: String,
        note: String? = nil,
        pageNumber: Int? = nil,
        textOffset: Int? = nil,
        scrollPercentage: Float,
        readingProgress: Float,
        contextText: String? = nil,
        chapterTitle: String? = nil,
        type: BookmarkItem.BookmarkType = .bookmark
    ) -> BookmarkItem {
        
        let bookmark = BookmarkItem(
            bookId: bookId,
            bookTitle: bookTitle,
            title: title,
            note: note,
            pageNumber: pageNumber,
            textOffset: textOffset,
            scrollPercentage: scrollPercentage,
            readingProgress: readingProgress,
            contextText: contextText,
            chapterTitle: chapterTitle,
            type: type
        )
        
        var bookmarks = getAllBookmarks()
        bookmarks.append(bookmark)
        saveBookmarks(bookmarks)
        
        print("📑 Added bookmark: \(title) for \(bookTitle)")
        return bookmark
    }
    
    func addBookmarkFromPDF(
        bookId: String,
        bookTitle: String,
        pdfView: PDFView,
        title: String,
        note: String? = nil,
        type: BookmarkItem.BookmarkType = .bookmark
    ) -> BookmarkItem? {
        
        guard let currentPage = pdfView.currentPage,
              let document = pdfView.document else { return nil }
        
        let pageIndex = document.index(for: currentPage)
        let totalPages = document.pageCount
        let readingProgress = Float(pageIndex + 1) / Float(totalPages)
        let scrollPercentage = readingProgress
        
        // Extract context text from current page
        let contextText = currentPage.string?.prefix(200).description
        
        // Try to determine chapter title (simplified)
        let chapterTitle = "Page \(pageIndex + 1)"
        
        return addBookmark(
            bookId: bookId,
            bookTitle: bookTitle,
            title: title,
            note: note,
            pageNumber: pageIndex + 1,
            textOffset: nil,
            scrollPercentage: scrollPercentage,
            readingProgress: readingProgress,
            contextText: contextText,
            chapterTitle: chapterTitle,
            type: type
        )
    }
    
    func addBookmarkFromText(
        bookId: String,
        bookTitle: String,
        textView: UITextView,
        title: String,
        note: String? = nil,
        type: BookmarkItem.BookmarkType = .bookmark
    ) -> BookmarkItem? {
        
        let scrollPercentage = Float(textView.contentOffset.y / max(1, textView.contentSize.height - textView.bounds.height))
        let textLength = textView.text.count
        let estimatedOffset = Int(scrollPercentage * Float(textLength))
        
        // Extract context text around current position
        let contextText: String?
        if estimatedOffset < textLength {
            let start = max(0, estimatedOffset - 100)
            let end = min(textLength, estimatedOffset + 100)
            let startIndex = textView.text.index(textView.text.startIndex, offsetBy: start)
            let endIndex = textView.text.index(textView.text.startIndex, offsetBy: end)
            contextText = String(textView.text[startIndex..<endIndex])
        } else {
            contextText = nil
        }
        
        return addBookmark(
            bookId: bookId,
            bookTitle: bookTitle,
            title: title,
            note: note,
            pageNumber: nil,
            textOffset: estimatedOffset,
            scrollPercentage: scrollPercentage,
            readingProgress: scrollPercentage,
            contextText: contextText,
            chapterTitle: nil,
            type: type
        )
    }
    
    func updateBookmark(_ bookmark: BookmarkItem, title: String? = nil, note: String? = nil, type: BookmarkItem.BookmarkType? = nil) {
        var bookmarks = getAllBookmarks()
        
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            var updatedBookmark = bookmarks[index]
            
            if let title = title {
                updatedBookmark = BookmarkItem(
                    id: updatedBookmark.id,
                    bookId: updatedBookmark.bookId,
                    bookTitle: updatedBookmark.bookTitle,
                    title: title,
                    note: note ?? updatedBookmark.note,
                    pageNumber: updatedBookmark.pageNumber,
                    textOffset: updatedBookmark.textOffset,
                    scrollPercentage: updatedBookmark.scrollPercentage,
                    readingProgress: updatedBookmark.readingProgress,
                    contextText: updatedBookmark.contextText,
                    chapterTitle: updatedBookmark.chapterTitle,
                    type: type ?? updatedBookmark.type
                )
            }
            
            bookmarks[index] = updatedBookmark
            saveBookmarks(bookmarks)
            
            print("📝 Updated bookmark: \(updatedBookmark.title)")
        }
    }
    
    func deleteBookmark(_ bookmark: BookmarkItem) {
        var bookmarks = getAllBookmarks()
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks(bookmarks)
        
        print("🗑️ Deleted bookmark: \(bookmark.title)")
    }
    
    func deleteBookmark(withId id: String) {
        var bookmarks = getAllBookmarks()
        bookmarks.removeAll { $0.id == id }
        saveBookmarks(bookmarks)
        
        print("🗑️ Deleted bookmark with ID: \(id)")
    }
    
    // MARK: - Retrieval Methods
    
    func getAllBookmarks() -> [BookmarkItem] {
        if let data = userDefaults.data(forKey: bookmarksKey),
           let bookmarks = try? JSONDecoder().decode([BookmarkItem].self, from: data) {
            return bookmarks.sorted { $0.dateCreated > $1.dateCreated }
        }
        return []
    }
    
    func getBookmarks(for bookId: String) -> [BookmarkItem] {
        return getAllBookmarks().filter { $0.bookId == bookId }
    }
    
    func getBookmarks(ofType type: BookmarkItem.BookmarkType) -> [BookmarkItem] {
        return getAllBookmarks().filter { $0.type == type }
    }
    
    func getBookmark(withId id: String) -> BookmarkItem? {
        return getAllBookmarks().first { $0.id == id }
    }
    
    func getRecentBookmarks(limit: Int = 10) -> [BookmarkItem] {
        return Array(getAllBookmarks().prefix(limit))
    }
    
    // MARK: - Navigation
    
    func navigateToBookmark(_ bookmark: BookmarkItem, in pdfView: PDFView) -> Bool {
        guard let pageNumber = bookmark.pageNumber,
              let document = pdfView.document,
              pageNumber > 0 && pageNumber <= document.pageCount,
              let page = document.page(at: pageNumber - 1) else { return false }
        
        DispatchQueue.main.async {
            pdfView.go(to: page)
        }
        
        print("📍 Navigated to bookmark: \(bookmark.title) - Page \(pageNumber)")
        return true
    }
    
    func navigateToBookmark(_ bookmark: BookmarkItem, in textView: UITextView) -> Bool {
        guard let textOffset = bookmark.textOffset,
              textOffset >= 0 && textOffset < textView.text.count else { return false }
        
        DispatchQueue.main.async {
            let nsRange = NSRange(location: textOffset, length: 0)
            textView.scrollRangeToVisible(nsRange)
        }
        
        print("📍 Navigated to bookmark: \(bookmark.title) - Offset \(textOffset)")
        return true
    }
    
    // MARK: - Statistics
    
    func getBookmarkCount(for bookId: String) -> Int {
        return getBookmarks(for: bookId).count
    }
    
    func getTotalBookmarkCount() -> Int {
        return getAllBookmarks().count
    }
    
    func getBookmarkStats() -> (total: Int, byType: [BookmarkItem.BookmarkType: Int]) {
        let bookmarks = getAllBookmarks()
        let total = bookmarks.count
        
        var byType: [BookmarkItem.BookmarkType: Int] = [:]
        for type in BookmarkItem.BookmarkType.allCases {
            byType[type] = bookmarks.filter { $0.type == type }.count
        }
        
        return (total, byType)
    }
    
    // MARK: - Search
    
    func searchBookmarks(_ query: String) -> [BookmarkItem] {
        let bookmarks = getAllBookmarks()
        let lowercaseQuery = query.lowercased()
        
        return bookmarks.filter { bookmark in
            bookmark.title.lowercased().contains(lowercaseQuery) ||
            bookmark.bookTitle.lowercased().contains(lowercaseQuery) ||
            bookmark.note?.lowercased().contains(lowercaseQuery) == true ||
            bookmark.contextText?.lowercased().contains(lowercaseQuery) == true
        }
    }
    
    // MARK: - Export
    
    func exportBookmarks(for bookId: String? = nil) -> String {
        let bookmarks = bookId != nil ? getBookmarks(for: bookId!) : getAllBookmarks()
        
        var exportText = "📚 BookReader Bookmarks Export\n"
        exportText += "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))\n\n"
        
        let groupedBookmarks = Dictionary(grouping: bookmarks) { $0.bookTitle }
        
        for (bookTitle, bookBookmarks) in groupedBookmarks.sorted(by: { $0.key < $1.key }) {
            exportText += "📖 \(bookTitle)\n"
            exportText += String(repeating: "=", count: bookTitle.count + 3) + "\n\n"
            
            for bookmark in bookBookmarks.sorted(by: { $0.readingProgress < $1.readingProgress }) {
                exportText += "📑 \(bookmark.title)\n"
                exportText += "   Type: \(bookmark.type.displayName)\n"
                
                if let pageNumber = bookmark.pageNumber {
                    exportText += "   Page: \(pageNumber)\n"
                }
                
                exportText += "   Progress: \(Int(bookmark.readingProgress * 100))%\n"
                
                if let note = bookmark.note, !note.isEmpty {
                    exportText += "   Note: \(note)\n"
                }
                
                if let context = bookmark.contextText, !context.isEmpty {
                    exportText += "   Context: \(context.prefix(100))...\n"
                }
                
                exportText += "   Created: \(DateFormatter.localizedString(from: bookmark.dateCreated, dateStyle: .short, timeStyle: .short))\n\n"
            }
        }
        
        return exportText
    }
    
    // MARK: - Private Methods
    
    private func saveBookmarks(_ bookmarks: [BookmarkItem]) {
        if let data = try? JSONEncoder().encode(bookmarks) {
            userDefaults.set(data, forKey: bookmarksKey)
        }
    }
}