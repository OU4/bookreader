//
//  UnifiedFirebaseStorage.swift
//  BookReader
//
//  Unified Firebase storage with conflict resolution and offline sync
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Combine

class UnifiedFirebaseStorage: ObservableObject {
    
    // MARK: - Singleton
    static let shared = UnifiedFirebaseStorage()
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()
    private var isListening = false
    
    // Offline support
    private var pendingOperations: [PendingOperation] = []
    private let operationQueue = DispatchQueue(label: "firebase.operations", qos: .utility)
    
    // MARK: - Init
    private init() {
        setupFirestore()
        setupAuthListener()
    }
    
    private func setupFirestore() {
        // Enable offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }
    
    private func setupAuthListener() {
        FirebaseManager.shared.$currentUser
            .sink { [weak self] user in
                if let user = user {
                    print("🔥 User authenticated: \(user.uid), starting unified storage")
                    self?.startListening()
                    self?.processOfflineOperations()
                } else {
                    print("🔥 User signed out, stopping unified storage")
                    self?.stopListening()
                    DispatchQueue.main.async {
                        self?.books = []
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Listening
    private func startListening() {
        guard let userId = FirebaseManager.shared.userId else { return }
        
        if isListening {
            return
        }
        
        stopListening()
        
        let listener = db.collection("users").document(userId).collection("books")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = error
                    print("❌ Error listening to books: \(error)")
                    return
                }
                
                self?.processBookSnapshot(snapshot)
            }
        
        listeners.append(listener)
        isListening = true
    }
    
    private func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        isListening = false
    }
    
    private func processBookSnapshot(_ snapshot: QuerySnapshot?) {
        guard let documents = snapshot?.documents else { return }
        
        let firebaseBooks = documents.compactMap { document -> Book? in
            do {
                var data = document.data()
                data["id"] = document.documentID
                
                // Convert ALL Firebase Timestamp objects to Date objects for JSON serialization
                data = convertTimestampsToDate(in: data)
                
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                return try JSONDecoder().decode(Book.self, from: jsonData)
            } catch {
                print("❌ Failed to decode book: \(error)")
                return nil
            }
        }
        
        DispatchQueue.main.async {
            self.books = firebaseBooks
            // Post notification for UI updates
            NotificationCenter.default.post(name: NSNotification.Name("FirebaseBooksUpdated"), object: nil)
        }
    }
    
    // MARK: - Book Operations with Conflict Resolution
    func addBook(_ book: Book, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        // Check rate limit
        guard RateLimiter.shared.checkLimit(for: .updateBook) else {
            completion(.failure(StorageError.rateLimitExceeded))
            return
        }
        
        let operation = PendingOperation(
            type: .addBook,
            bookId: book.id,
            data: try? JSONEncoder().encode(book),
            timestamp: Date()
        )
        
        performOperation(operation, userId: userId, completion: completion)
    }
    
    func updateBook(_ book: Book, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        // Use Firestore transaction for atomic updates with conflict resolution
        db.runTransaction({ [weak self] (transaction, errorPointer) -> Any? in
            guard let self = self else { return nil }
            
            let docRef = self.db.collection("users").document(userId).collection("books").document(book.id)
            
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // Conflict resolution: merge by timestamp
            if document.exists,
               let existingData = document.data(),
               let existingTimestamp = existingData["lastModified"] as? Timestamp {
                
                guard let bookData = try? JSONEncoder().encode(book).toDictionary() else {
                    errorPointer?.pointee = NSError(domain: "UnifiedFirebaseStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode book data"])
                    return nil
                }
                let bookTimestamp = Timestamp(date: Date())
                
                if existingTimestamp.dateValue() > bookTimestamp.dateValue() {
                    // Server version is newer, merge changes
                    let mergedData = self.mergeBookData(existing: existingData, new: bookData)
                    transaction.setData(mergedData, forDocument: docRef)
                } else {
                    // Our version is newer or same, update normally
                    var bookDataWithTimestamp = bookData
                    bookDataWithTimestamp["lastModified"] = bookTimestamp
                    transaction.setData(bookDataWithTimestamp, forDocument: docRef)
                }
            } else {
                // Document doesn't exist, create it
                guard let bookData = try? JSONEncoder().encode(book).toDictionary() else {
                    errorPointer?.pointee = NSError(domain: "UnifiedFirebaseStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode book data"])
                    return nil
                }
                var bookDataWithTimestamp = bookData
                bookDataWithTimestamp["lastModified"] = Timestamp(date: Date())
                transaction.setData(bookDataWithTimestamp, forDocument: docRef)
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Bookmark Operations with Atomic Updates
    func addBookmark(_ bookmark: BookmarkItem, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        performAtomicBookmarkOperation(
            bookId: bookmark.bookId,
            operation: .addBookmark(bookmark),
            completion: completion
        )
    }
    
    func removeBookmark(bookId: String, bookmarkId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        performAtomicBookmarkOperation(
            bookId: bookId,
            operation: .removeBookmark(bookmarkId),
            completion: completion
        )
    }
    
    // MARK: - Highlight Operations with Atomic Updates
    func addHighlight(_ highlight: Highlight, bookId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        // Check rate limit
        guard RateLimiter.shared.checkLimit(for: .addHighlight) else {
            completion(.failure(StorageError.rateLimitExceeded))
            return
        }
        
        performAtomicHighlightOperation(
            bookId: bookId,
            operation: .addHighlight(highlight),
            completion: completion
        )
    }
    
    func updateHighlight(_ highlight: Highlight, bookId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        performAtomicHighlightOperation(
            bookId: bookId,
            operation: .updateHighlight(highlight),
            completion: completion
        )
    }
    
    func removeHighlight(bookId: String, highlightId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        performAtomicHighlightOperation(
            bookId: bookId,
            operation: .removeHighlight(highlightId),
            completion: completion
        )
    }
    
    
    func loadHighlights(bookId: String, completion: @escaping ([Highlight]) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion([])
            return
        }
        
        let docRef = db.collection("users").document(userId).collection("books").document(bookId)
        
        docRef.getDocument { snapshot, error in
            guard let document = snapshot, document.exists,
                  let data = document.data(),
                  let highlightsData = data["highlights"] as? [[String: Any]] else {
                completion([])
                return
            }
            
            let highlights = highlightsData.compactMap { dict -> Highlight? in
                var mutableDict = dict
                // Convert timestamp if needed
                if let timestamp = dict["dateCreated"] as? Timestamp {
                    let formatter = ISO8601DateFormatter()
                    mutableDict["dateCreated"] = formatter.string(from: timestamp.dateValue())
                }
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: mutableDict) else { return nil }
                return try? JSONDecoder().decode(Highlight.self, from: jsonData)
            }
            
            completion(highlights)
        }
    }
    
    // MARK: - Reading Progress
    func updateReadingProgress(bookId: String, position: Float, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        let docRef = db.collection("users").document(userId).collection("books").document(bookId)
        
        db.runTransaction({ [weak self] (transaction, errorPointer) -> Any? in
            guard self != nil else { return nil }
            
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            if document.exists {
                transaction.updateData([
                    "lastReadPosition": position,
                    "lastModified": Timestamp(date: Date())
                ], forDocument: docRef)
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Private Helpers
    private func performOperation(_ operation: PendingOperation, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        operationQueue.async { [weak self] in
            guard let self = self else { return }
            
            if Reachability.isConnectedToNetwork() {
                self.executeOperation(operation, userId: userId, completion: completion)
            } else {
                self.pendingOperations.append(operation)
                completion(.success(())) // Success for offline queuing
            }
        }
    }
    
    private func executeOperation(_ operation: PendingOperation, userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        switch operation.type {
        case .addBook:
            if let data = operation.data,
               let book = try? JSONDecoder().decode(Book.self, from: data) {
                let docRef = db.collection("users").document(userId).collection("books").document(book.id)
                guard let bookData = try? JSONEncoder().encode(book).toDictionary() else {
                    completion(.failure(NSError(domain: "UnifiedFirebaseStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode book data"])))
                    return
                }
                var bookDataWithTimestamp = bookData
                bookDataWithTimestamp["lastModified"] = Timestamp(date: operation.timestamp)
                
                docRef.setData(bookDataWithTimestamp) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        case .updateBook:
            // Handle update operations
            break
        }
    }
    
    private func performAtomicBookmarkOperation(bookId: String, operation: BookmarkOperation, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        let docRef = db.collection("users").document(userId).collection("books").document(bookId)
        
        db.runTransaction({ [weak self] (transaction, errorPointer) -> Any? in
            guard self != nil else { return nil }
            
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard document.exists,
                  var data = document.data() else {
                print("❌ Document doesn't exist or has no data for bookId: \(bookId)")
                return nil
            }
            
            // Get existing bookmarks or create empty array if none exist
            var bookmarks = data["bookmarks"] as? [[String: Any]] ?? []
            print("📚 Found \(bookmarks.count) existing bookmarks in document")
            
            switch operation {
            case .addBookmark(let bookmark):
                guard let bookmarkData = try? JSONEncoder().encode(bookmark).toDictionary() else {
                    print("❌ Failed to encode bookmark data")
                    return nil
                }
                bookmarks.append(bookmarkData)
                print("📝 Added bookmark. Total bookmarks now: \(bookmarks.count)")
            case .removeBookmark(let bookmarkId):
                let countBefore = bookmarks.count
                bookmarks.removeAll { bookmarkDict in
                    bookmarkDict["id"] as? String == bookmarkId
                }
                print("🗑️ Removed bookmark. Count before: \(countBefore), after: \(bookmarks.count)")
            }
            
            data["bookmarks"] = bookmarks
            data["lastModified"] = Timestamp(date: Date())
            print("💾 Updating document with \(bookmarks.count) bookmarks")
            transaction.setData(data, forDocument: docRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    private func performAtomicHighlightOperation(bookId: String, operation: HighlightOperation, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        let docRef = db.collection("users").document(userId).collection("books").document(bookId)
        
        db.runTransaction({ [weak self] (transaction, errorPointer) -> Any? in
            guard self != nil else { return nil }
            
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard document.exists,
                  var data = document.data() else {
                print("❌ Document doesn't exist or has no data for bookId: \(bookId)")
                return nil
            }
            
            // Get existing highlights or create empty array if none exist
            var highlights = data["highlights"] as? [[String: Any]] ?? []
            print("📚 Found \(highlights.count) existing highlights in document")
            
            switch operation {
            case .addHighlight(let highlight):
                guard let highlightData = try? JSONEncoder().encode(highlight).toDictionary() else {
                    print("❌ Failed to encode highlight data")
                    return nil
                }
                highlights.append(highlightData)
                print("📝 Added highlight. Total highlights now: \(highlights.count)")
            case .updateHighlight(let highlight):
                // Find and update existing highlight
                guard let highlightData = try? JSONEncoder().encode(highlight).toDictionary() else {
                    print("❌ Failed to encode highlight data")
                    return nil
                }
                for (index, existingHighlight) in highlights.enumerated() {
                    if existingHighlight["id"] as? String == highlight.id {
                        highlights[index] = highlightData
                        print("✏️ Updated highlight: \(highlight.text.prefix(30))...")
                        break
                    }
                }
            case .removeHighlight(let highlightId):
                let countBefore = highlights.count
                highlights.removeAll { highlightDict in
                    highlightDict["id"] as? String == highlightId
                }
                print("🗑️ Removed highlight. Count before: \(countBefore), after: \(highlights.count)")
            }
            
            data["highlights"] = highlights
            data["lastModified"] = Timestamp(date: Date())
            print("💾 Updating document with \(highlights.count) highlights")
            transaction.setData(data, forDocument: docRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    private func processOfflineOperations() {
        guard !pendingOperations.isEmpty,
              let userId = FirebaseManager.shared.userId else { return }
        
        operationQueue.async { [weak self] in
            guard let self = self else { return }
            
            let operations = self.pendingOperations
            self.pendingOperations.removeAll()
            
            for operation in operations {
                self.executeOperation(operation, userId: userId) { result in
                    if case .failure(let error) = result {
                        print("❌ Failed to execute offline operation: \(error)")
                        // Re-queue failed operations
                        self.pendingOperations.append(operation)
                    }
                }
            }
        }
    }
    
    private func mergeBookData(existing: [String: Any], new: [String: Any]) -> [String: Any] {
        var merged = existing
        
        // Merge reading position (keep latest)
        if let newPosition = new["lastReadPosition"] as? Float,
           let existingPosition = existing["lastReadPosition"] as? Float {
            merged["lastReadPosition"] = max(newPosition, existingPosition)
        }
        
        // Merge bookmarks (union)
        var allBookmarks: [[String: Any]] = []
        if let existingBookmarks = existing["bookmarks"] as? [[String: Any]] {
            allBookmarks.append(contentsOf: existingBookmarks)
        }
        if let newBookmarks = new["bookmarks"] as? [[String: Any]] {
            for newBookmark in newBookmarks {
                if let bookmarkId = newBookmark["id"] as? String,
                   !allBookmarks.contains(where: { $0["id"] as? String == bookmarkId }) {
                    allBookmarks.append(newBookmark)
                }
            }
        }
        merged["bookmarks"] = allBookmarks
        
        // Merge highlights (union)
        var allHighlights: [[String: Any]] = []
        if let existingHighlights = existing["highlights"] as? [[String: Any]] {
            allHighlights.append(contentsOf: existingHighlights)
        }
        if let newHighlights = new["highlights"] as? [[String: Any]] {
            for newHighlight in newHighlights {
                if let highlightId = newHighlight["id"] as? String,
                   !allHighlights.contains(where: { $0["id"] as? String == highlightId }) {
                    allHighlights.append(newHighlight)
                }
            }
        }
        merged["highlights"] = allHighlights
        
        merged["lastModified"] = Timestamp(date: Date())
        return merged
    }
    
    // MARK: - Helper function to convert Timestamps and Dates for JSON
    private func convertTimestampsToDate(in data: [String: Any]) -> [String: Any] {
        var convertedData = data
        let dateFormatter = ISO8601DateFormatter()
        
        for (key, value) in data {
            if let timestamp = value as? Timestamp {
                // Convert Firebase Timestamp to ISO8601 string
                convertedData[key] = dateFormatter.string(from: timestamp.dateValue())
            } else if let date = value as? Date {
                // Convert Date to ISO8601 string 
                convertedData[key] = dateFormatter.string(from: date)
            } else if let array = value as? [[String: Any]] {
                // Handle arrays of dictionaries (like bookmarks, highlights)
                convertedData[key] = array.map { convertTimestampsToDate(in: $0) }
            } else if let dict = value as? [String: Any] {
                // Handle nested dictionaries
                convertedData[key] = convertTimestampsToDate(in: dict)
            }
        }
        
        return convertedData
    }
    
    // MARK: - File Storage Operations
    func uploadBook(fileURL: URL, title: String, author: String, completion: @escaping (Result<Book, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        // Check rate limit for uploads
        guard RateLimiter.shared.checkLimit(for: .uploadBook) else {
            completion(.failure(StorageError.rateLimitExceeded))
            return
        }
        
        let fileName = "\(title.sanitizedFileName())_\(UUID().uuidString.prefix(8)).pdf"
        let storageRef = Storage.storage().reference().child("books/\(userId)/\(fileName)")
        
        // Upload file
        storageRef.putFile(from: fileURL, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Get download URL
            storageRef.downloadURL { [weak self] url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let downloadURL = url else {
                    completion(.failure(StorageError.networkUnavailable))
                    return
                }
                
                // Create book object
                let book = Book(
                    title: title,
                    author: author,
                    filePath: downloadURL.absoluteString,
                    type: .pdf
                )
                
                // Save to Firestore
                self?.addBook(book) { result in
                    completion(result.map { _ in book })
                }
            }
        }
    }
    
    func downloadBook(_ book: Book, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !book.filePath.isEmpty,
              let fileURL = URL(string: book.filePath) else {
            completion(.failure(StorageError.networkUnavailable))
            return
        }
        
        // Check local cache first
        let localURL = getLocalFileURL(for: book)
        if FileManager.default.fileExists(atPath: localURL.path) {
            completion(.success(localURL))
            return
        }
        
        // Download from Firebase Storage
        let storageRef = Storage.storage().reference(forURL: book.filePath)
        storageRef.write(toFile: localURL) { url, error in
            if let error = error {
                completion(.failure(error))
            } else if let url = url {
                completion(.success(url))
            }
        }
    }
    
    private func getLocalFileURL(for book: Book) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDir = documentsPath.appendingPathComponent("BookCache")
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        let fileName = "\(book.title.sanitizedFileName())_\(book.id.prefix(8)).pdf"
        return cacheDir.appendingPathComponent(fileName)
    }
    
    // MARK: - Migration
    func migrateLocalBooks(completion: @escaping (Result<Int, Error>) -> Void) {
        // Load local books and upload them to Firebase
        let localBooks = BookStorage.shared.loadBooks()
        
        guard !localBooks.isEmpty else {
            completion(.success(0))
            return
        }
        
        var uploadedCount = 0
        var successfulMigrations = 0
        var errors: [Error] = []
        
        for book in localBooks {
            // Skip if already has Firebase path
            if book.filePath.starts(with: "https://") {
                uploadedCount += 1
                successfulMigrations += 1
                checkMigrationComplete()
                continue
            }
            
            // Upload local file to Firebase
            guard !book.filePath.isEmpty,
                  FileManager.default.fileExists(atPath: book.filePath) else {
                uploadedCount += 1
                checkMigrationComplete()
                continue
            }
            
            let localURL = URL(fileURLWithPath: book.filePath)
            uploadBook(fileURL: localURL, title: book.title, author: book.author) { [weak self] result in
                guard self != nil else { return }
                
                switch result {
                case .success:
                    uploadedCount += 1
                    successfulMigrations += 1
                    print("✅ Migrated book: \(book.title)")
                case .failure(let error):
                    errors.append(error)
                    uploadedCount += 1
                    print("❌ Failed to migrate book: \(book.title) - \(error)")
                }
                checkMigrationComplete()
            }
        }
        
        func checkMigrationComplete() {
            if uploadedCount >= localBooks.count {
                if errors.isEmpty {
                    completion(.success(successfulMigrations))
                } else {
                    completion(.failure(errors.first!))
                }
            }
        }
    }
    
    // MARK: - Cleanup Operations
    func cleanupBrokenBooks(completion: @escaping (Result<Int, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        let userBooksRef = db.collection("users").document(userId).collection("books")
        
        userBooksRef.getDocuments { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success(0))
                return
            }
            
            var brokenBooks: [String] = []
            
            for document in documents {
                let data = document.data()
                let filePath = data["filePath"] as? String ?? ""
                
                // Check if book is broken (empty file path or invalid URL)
                if filePath.isEmpty || (!filePath.starts(with: "https://") && !FileManager.default.fileExists(atPath: filePath)) {
                    brokenBooks.append(document.documentID)
                    print("🗑️ Found broken book: \(data["title"] as? String ?? "Unknown") - Empty or invalid file path")
                }
            }
            
            if brokenBooks.isEmpty {
                print("✅ No broken books found")
                completion(.success(0))
                return
            }
            
            print("🗑️ Found \(brokenBooks.count) broken books to remove")
            self?.deleteBrokenBooks(bookIds: brokenBooks, completion: completion)
        }
    }
    
    private func deleteBrokenBooks(bookIds: [String], completion: @escaping (Result<Int, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        let userBooksRef = db.collection("users").document(userId).collection("books")
        let batch = db.batch()
        
        for bookId in bookIds {
            let docRef = userBooksRef.document(bookId)
            batch.deleteDocument(docRef)
        }
        
        batch.commit { error in
            if let error = error {
                print("❌ Failed to delete broken books: \(error)")
                completion(.failure(error))
            } else {
                print("✅ Successfully deleted \(bookIds.count) broken books")
                completion(.success(bookIds.count))
            }
        }
    }
    
    func removeBook(bookId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(StorageError.notAuthenticated))
            return
        }
        
        let docRef = db.collection("users").document(userId).collection("books").document(bookId)
        
        docRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ Successfully removed book: \(bookId)")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        stopListening()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types
private struct PendingOperation {
    let type: OperationType
    let bookId: String
    let data: Data?
    let timestamp: Date
}

private enum OperationType {
    case addBook
    case updateBook
}

private enum BookmarkOperation {
    case addBookmark(BookmarkItem)
    case removeBookmark(String)
}

private enum HighlightOperation {
    case addHighlight(Highlight)
    case updateHighlight(Highlight)
    case removeHighlight(String)
}

enum StorageError: LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case conflictResolutionFailed
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .networkUnavailable:
            return "Network connection is unavailable"
        case .conflictResolutionFailed:
            return "Failed to resolve data conflict"
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again"
        }
    }
}

// MARK: - Extensions
extension Data {
    func toDictionary() -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: self) as? [String: Any]
    }
}

extension Encodable {
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.toDictionary()
    }
}

// Simple reachability check
class Reachability {
    static func isConnectedToNetwork() -> Bool {
        // Simplified network check - in production use proper reachability framework
        return true
    }
}

// MARK: - String Extension for Filename Sanitization
extension String {
    func sanitizedFileName() -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return self.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}