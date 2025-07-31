//
//  BookStorage.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//

import UIKit

class BookStorage {
    static let shared = BookStorage()
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let booksFile = "books.json"
    
    private init() {
        // Don't clear books automatically
        // clearAllBooks()
    }
    
    private func clearAllBooks() {
        let url = documentsDirectory.appendingPathComponent(booksFile)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
            print("Cleared all books from storage to start fresh")
        }
    }
    
    func saveBook(_ book: Book) {
        var books = loadBooks()
        books.append(book)
        saveBooks(books)
    }
    
    func updateBook(_ updatedBook: Book) {
        var books = loadBooks()
        
        print("🔍 Attempting to update book ID: '\(updatedBook.id)' Title: '\(updatedBook.title)'")
        print("🔍 Available book IDs in storage: \(books.map { "'\($0.id)'" }.joined(separator: ", "))")
        
        // Find and replace the book with the same ID
        if let index = books.firstIndex(where: { $0.id == updatedBook.id }) {
            books[index] = updatedBook
            saveBooks(books)
            print("📚 Updated book: \(updatedBook.title) with \(updatedBook.highlights.count) highlights and \(updatedBook.notes.count) notes")
            
            // Also sync to Firebase if available
            FirebaseBookStorage.shared.updateBook(updatedBook) { result in
                switch result {
                case .success:
                    print("✅ Book synced to Firebase successfully")
                case .failure(let error):
                    print("❌ Failed to sync book to Firebase: \(error.localizedDescription)")
                }
            }
        } else {
            print("⚠️ Book not found for update: \(updatedBook.title)")
            print("⚠️ This might be a new book - adding it instead")
            saveBook(updatedBook)
        }
    }
    
    func loadBooks() -> [Book] {
        let url = documentsDirectory.appendingPathComponent(booksFile)
        print("DEBUG BookStorage: Loading books from: \(url.path)")
        
        guard let data = try? Data(contentsOf: url) else {
            print("DEBUG BookStorage: No books.json file found or unable to read")
            return []
        }
        
        guard let bookData = try? JSONDecoder().decode([BookData].self, from: data) else {
            print("DEBUG BookStorage: Failed to decode books data")
            return []
        }
        
        print("DEBUG BookStorage: Found \(bookData.count) book entries in storage")
        
        return bookData.compactMap { data in
            // Convert relative path to absolute path
            let absolutePath = getAbsolutePath(from: data.filePath)
            
            // Check if file exists before creating book
            guard FileManager.default.fileExists(atPath: absolutePath) else {
                print("File not found, skipping: \(data.title) at \(absolutePath)")
                return nil
            }
            
            print("DEBUG BookStorage: Successfully loaded book: \(data.title)")
            
            return Book(
                id: data.id,
                title: data.title,
                author: data.author,
                filePath: absolutePath,
                type: Book.BookType(rawValue: data.type) ?? .text,
                coverImage: nil,
                lastReadPosition: data.lastReadPosition,
                bookmarks: [],
                highlights: data.highlights ?? [],
                notes: data.notes ?? [],
                readingStats: data.readingStats ?? ReadingStats()
            )
        }
    }
    
    private func getAbsolutePath(from storedPath: String) -> String {
        // If it's already a relative path (just filename), create absolute path
        if !storedPath.contains("/") {
            return documentsDirectory.appendingPathComponent(storedPath).path
        }
        
        // If it's an absolute path, extract filename and create new absolute path
        let fileName = URL(fileURLWithPath: storedPath).lastPathComponent
        return documentsDirectory.appendingPathComponent(fileName).path
    }
    
    private func saveBooks(_ books: [Book]) {
        let bookData = books.map { book in
            // Store only the filename, not the full path
            let fileName = URL(fileURLWithPath: book.filePath).lastPathComponent
            return BookData(
                id: book.id,
                title: book.title,
                author: book.author,
                filePath: fileName, // Store relative path (just filename)
                type: book.type.rawValue,
                lastReadPosition: book.lastReadPosition,
                highlights: book.highlights,
                notes: book.notes,
                readingStats: book.readingStats
            )
        }
        
        let url = documentsDirectory.appendingPathComponent(booksFile)
        do {
            let data = try JSONEncoder().encode(bookData)
            try data.write(to: url)
            print("Successfully saved \(bookData.count) books")
        } catch {
            print("Failed to save books: \(error)")
        }
    }
}

struct BookData: Codable {
    let id: String
    let title: String
    let author: String
    let filePath: String
    let type: String
    let lastReadPosition: Float
    let highlights: [Highlight]?
    let notes: [Note]?
    let readingStats: ReadingStats?
    
    // Legacy initializer for backward compatibility
    init(id: String, title: String, author: String, filePath: String, type: String, lastReadPosition: Float, highlights: [Highlight]? = nil, notes: [Note]? = nil, readingStats: ReadingStats? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.filePath = filePath
        self.type = type
        self.lastReadPosition = lastReadPosition
        self.highlights = highlights
        self.notes = notes
        self.readingStats = readingStats
    }
}
