//
//  FirebaseBook.swift
//  BookReader
//
//  Firebase-compatible book model for Firestore
//

import Foundation
import FirebaseFirestore
import Firebase

struct FirebaseBook: Codable {
    @DocumentID var id: String?
    let title: String
    let author: String
    let fileName: String
    let fileSize: Int64
    let type: String // "pdf", "text", "epub", "image"
    let uploadedAt: Timestamp
    let lastReadPosition: Float
    let totalPages: Int?
    let currentPage: Int?
    let coverImageURL: String?
    
    // Reading stats
    let totalReadingTime: TimeInterval
    let lastReadDate: Timestamp?
    let readingProgress: Float // 0.0 to 1.0
    
    // User metadata
    let userId: String
    let isFinished: Bool
    let isFavorite: Bool
    let rating: Int?
    
    // Study features
    let highlightsCount: Int
    let notesCount: Int
    let bookmarksCount: Int
    
    // Computed property for Book.BookType
    var bookType: Book.BookType {
        return Book.BookType(rawValue: type) ?? .pdf
    }
    
    // Convert to local Book model
    func toBook(filePath: String) -> Book {
        return Book(
            id: id ?? UUID().uuidString,
            title: title,
            author: author,
            filePath: filePath,
            type: bookType,
            coverImage: nil,
            lastReadPosition: lastReadPosition,
            bookmarks: [],
            highlights: [],
            notes: [],
            readingStats: ReadingStats(
                totalReadingTime: totalReadingTime,
                sessionsCount: 0,
                averageReadingSpeed: 0,
                lastReadDate: lastReadDate?.dateValue,
                currentStreak: 0,
                longestStreak: 0,
                wordsRead: 0,
                pagesRead: currentPage ?? 0
            )
        )
    }
    
    // Create from local Book model
    static func fromBook(_ book: Book, userId: String, fileName: String, fileSize: Int64) -> FirebaseBook {
        return FirebaseBook(
            id: book.id,
            title: book.title,
            author: book.author,
            fileName: fileName,
            fileSize: fileSize,
            type: book.type.rawValue,
            uploadedAt: Timestamp(date: Date()),
            lastReadPosition: book.lastReadPosition,
            totalPages: nil,
            currentPage: nil,
            coverImageURL: nil,
            totalReadingTime: book.readingStats.totalReadingTime,
            lastReadDate: book.readingStats.lastReadDate.map { Timestamp(date: $0) },
            readingProgress: book.lastReadPosition,
            userId: userId,
            isFinished: book.lastReadPosition >= 0.95,
            isFavorite: false,
            rating: nil,
            highlightsCount: book.highlights.count,
            notesCount: book.notes.count,
            bookmarksCount: book.bookmarks.count
        )
    }
}

// MARK: - Firestore Queries
extension FirebaseBook {
    static func fetchUserBooks(userId: String, completion: @escaping (Result<[FirebaseBook], Error>) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).collection("books")
            .order(by: "uploadedAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let books = snapshot?.documents.compactMap { document -> FirebaseBook? in
                    try? document.data(as: FirebaseBook.self)
                } ?? []
                
                completion(.success(books))
            }
    }
    
    static func fetchRecentBooks(userId: String, limit: Int = 5, completion: @escaping (Result<[FirebaseBook], Error>) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).collection("books")
            .whereField("lastReadDate", isNotEqualTo: NSNull())
            .order(by: "lastReadDate", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let books = snapshot?.documents.compactMap { document -> FirebaseBook? in
                    try? document.data(as: FirebaseBook.self)
                } ?? []
                
                completion(.success(books))
            }
    }
}
