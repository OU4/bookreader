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
    
    // Retry configuration
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    
    // Network monitoring
    private var networkCancellable: AnyCancellable?
    
    // MARK: - Init
    private init() {
        setupFirestore()
        setupAuthListener()
        setupNetworkMonitoring()
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
                    self?.startListening()
                    self?.processOfflineOperations()
                } else {
                    self?.stopListening()
                    DispatchQueue.main.async {
                        self?.books = []
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupNetworkMonitoring() {
        networkCancellable = NetworkMonitor.shared.$isConnected
            .sink { [weak self] isConnected in
                if isConnected {
                    self?.processOfflineOperations()
                } else {
                }
            }
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
                    // Server version is newer, use enhanced conflict resolution
                    let mergedData = self.resolveConflict(local: bookData, remote: existingData)
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
            
            if NetworkMonitor.shared.isConnected {
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
                return nil
            }
            
            // Get existing bookmarks or create empty array if none exist
            var bookmarks = data["bookmarks"] as? [[String: Any]] ?? []
            
            switch operation {
            case .addBookmark(let bookmark):
                guard let bookmarkData = try? JSONEncoder().encode(bookmark).toDictionary() else {
                    return nil
                }
                bookmarks.append(bookmarkData)
            case .removeBookmark(let bookmarkId):
                let countBefore = bookmarks.count
                bookmarks.removeAll { bookmarkDict in
                    bookmarkDict["id"] as? String == bookmarkId
                }
            }
            
            data["bookmarks"] = bookmarks
            data["lastModified"] = Timestamp(date: Date())
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
            
            var data: [String: Any]
            
            if document.exists, let existingData = document.data() {
                // Document exists, use existing data
                data = existingData
            } else {
                // Document doesn't exist, create minimal book document
                data = [
                    "id": bookId,
                    "highlights": [],
                    "bookmarks": [],
                    "notes": [],
                    "lastModified": Timestamp(date: Date())
                ]
            }
            
            // Get existing highlights or create empty array if none exist
            var highlights = data["highlights"] as? [[String: Any]] ?? []
            
            switch operation {
            case .addHighlight(let highlight):
                guard let highlightData = try? JSONEncoder().encode(highlight).toDictionary() else {
                    return nil
                }
                highlights.append(highlightData)
            case .updateHighlight(let highlight):
                // Find and update existing highlight
                guard let highlightData = try? JSONEncoder().encode(highlight).toDictionary() else {
                    return nil
                }
                for (index, existingHighlight) in highlights.enumerated() {
                    if existingHighlight["id"] as? String == highlight.id {
                        highlights[index] = highlightData
                        break
                    }
                }
            case .removeHighlight(let highlightId):
                let countBefore = highlights.count
                highlights.removeAll { highlightDict in
                    highlightDict["id"] as? String == highlightId
                }
            }
            
            data["highlights"] = highlights
            data["lastModified"] = Timestamp(date: Date())
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
        
        // Only process if network is available
        guard NetworkMonitor.shared.isConnected else {
            return
        }
        
        operationQueue.async { [weak self] in
            guard let self = self else { return }
            
            let operations = self.pendingOperations
            self.pendingOperations.removeAll()
            
            
            for operation in operations {
                // Use retry logic for offline operations
                self.retryOperation(maxAttempts: self.maxRetryAttempts) { attemptCompletion in
                    self.executeOperation(operation, userId: userId, completion: attemptCompletion)
                } finalCompletion: { result in
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        // Re-queue failed operations with exponential backoff
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 5...15)) {
                            self.pendingOperations.append(operation)
                        }
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
        
        retryOperation(maxAttempts: maxRetryAttempts) { [weak self] attemptCompletion in
            self?.performUploadAttempt(fileURL: fileURL, title: title, author: author, userId: userId, completion: attemptCompletion)
        } finalCompletion: { result in
            completion(result)
        }
    }
    
    private func performUploadAttempt(
        fileURL: URL,
        title: String,
        author: String,
        userId: String,
        completion: @escaping (Result<Book, Error>) -> Void
    ) {
        // Use the new upload helper for more robust uploads
        FirebaseUploadHelper.shared.uploadPDF(
            fileURL: fileURL,
            title: title,
            author: author,
            userId: userId
        ) { [weak self] result in
            switch result {
            case .success(let uploadResult):
                // Create book object
                let book = Book(
                    title: title,
                    author: author,
                    filePath: uploadResult.url,
                    type: .pdf
                )
                
                // Save to Firestore with retry
                self?.addBookWithRetry(book) { saveResult in
                    switch saveResult {
                    case .success:
                        completion(.success(book))
                    case .failure(let error):
                        // If metadata save fails, try to delete uploaded file
                        let storageRef = Storage.storage().reference().child("books/\(userId)/\(uploadResult.fileName)")
                        storageRef.delete { _ in }
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func downloadBook(_ book: Book, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !book.filePath.isEmpty else {
            completion(.failure(StorageError.networkUnavailable))
            return
        }
        
        // Check local cache first
        let localURL = getLocalFileURL(for: book)
        if FileManager.default.fileExists(atPath: localURL.path) {
            completion(.success(localURL))
            return
        }
        
        // Use robust download helper
        FirebaseDownloadHelper.shared.downloadFile(
            from: book.filePath,
            to: localURL,
            maxRetries: 3
        ) { result in
            completion(result)
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
                case .failure(let error):
                    errors.append(error)
                    uploadedCount += 1
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
                }
            }
            
            if brokenBooks.isEmpty {
                completion(.success(0))
                return
            }
            
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
                completion(.failure(error))
            } else {
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
        
        // First get the book data to find the storage file
        docRef.getDocument { [weak self] document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Delete from Firestore first
            docRef.delete { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                // If Firestore deletion succeeded, try to delete from Storage
                if let document = document, document.exists,
                   let data = document.data(),
                   let fileName = data["fileName"] as? String {
                    
                    let storageRef = Storage.storage().reference()
                    let fileRef = storageRef.child("users/\(userId)/books/\(fileName)")
                    
                    fileRef.delete { storageError in
                        if let storageError = storageError {
                            // Log storage deletion error but don't fail the operation
                            // since Firestore deletion already succeeded
                            print("Failed to delete file from Storage: \(storageError.localizedDescription)")
                        } else {
                            print("Successfully deleted file from Storage: \(fileName)")
                        }
                        
                        // Complete successfully regardless of storage deletion result
                        completion(.success(()))
                    }
                } else {
                    // No storage file to delete or couldn't find it
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Retry Logic
    
    private func retryOperation<T>(
        maxAttempts: Int,
        attempt: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        finalCompletion: @escaping (Result<T, Error>) -> Void
    ) {
        func performAttempt(attemptNumber: Int) {
            attempt { result in
                switch result {
                case .success(let value):
                    finalCompletion(.success(value))
                case .failure(let error):
                    if attemptNumber < maxAttempts && self.shouldRetry(error: error) {
                        DispatchQueue.global().asyncAfter(deadline: .now() + self.retryDelay * Double(attemptNumber)) {
                            performAttempt(attemptNumber: attemptNumber + 1)
                        }
                    } else {
                        finalCompletion(.failure(error))
                    }
                }
            }
        }
        
        performAttempt(attemptNumber: 1)
    }
    
    private func shouldRetry(error: Error) -> Bool {
        // Check if error is retryable
        if let nsError = error as NSError? {
            // Network errors
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorTimedOut,
                     NSURLErrorCannotConnectToHost,
                     NSURLErrorNetworkConnectionLost,
                     NSURLErrorNotConnectedToInternet:
                    return true
                default:
                    return false
                }
            }
            
            // Firebase errors
            if nsError.domain.contains("FIRStorage") {
                switch nsError.code {
                case 408, // Request timeout
                     429, // Too many requests
                     503, // Service unavailable
                     504: // Gateway timeout
                    return true
                default:
                    return false
                }
            }
        }
        
        return false
    }
    
    private func addBookWithRetry(_ book: Book, completion: @escaping (Result<Void, Error>) -> Void) {
        retryOperation(maxAttempts: maxRetryAttempts) { [weak self] attemptCompletion in
            self?.addBook(book, completion: attemptCompletion)
        } finalCompletion: { result in
            completion(result)
        }
    }
    
    // MARK: - Enhanced Conflict Resolution
    
    private func resolveConflict(local: [String: Any], remote: [String: Any]) -> [String: Any] {
        var resolved = remote
        
        // Use latest timestamp for basic fields
        let localTimestamp = (local["lastModified"] as? Timestamp)?.dateValue() ?? Date.distantPast
        let remoteTimestamp = (remote["lastModified"] as? Timestamp)?.dateValue() ?? Date.distantPast
        
        if localTimestamp > remoteTimestamp {
            // Local is newer, use local version for basic fields
            resolved["lastReadPosition"] = local["lastReadPosition"]
            resolved["lastModified"] = local["lastModified"]
            resolved["personalSummary"] = local["personalSummary"]
            resolved["keyTakeaways"] = local["keyTakeaways"]
            resolved["actionItems"] = local["actionItems"]
            resolved["notesUpdatedAt"] = local["notesUpdatedAt"]
        }

        // Merge arrays (bookmarks, highlights) by combining unique items
        resolved["bookmarks"] = mergeUniqueArrays(
            local: local["bookmarks"] as? [[String: Any]] ?? [],
            remote: remote["bookmarks"] as? [[String: Any]] ?? []
        )
        
        resolved["highlights"] = mergeUniqueArrays(
            local: local["highlights"] as? [[String: Any]] ?? [],
            remote: remote["highlights"] as? [[String: Any]] ?? []
        )

        resolved["notes"] = mergeUniqueArrays(
            local: local["notes"] as? [[String: Any]] ?? [],
            remote: remote["notes"] as? [[String: Any]] ?? []
        )

        resolved["sessionNotes"] = mergeUniqueArrays(
            local: local["sessionNotes"] as? [[String: Any]] ?? [],
            remote: remote["sessionNotes"] as? [[String: Any]] ?? []
        )

        return resolved
    }
    
    private func mergeUniqueArrays(local: [[String: Any]], remote: [[String: Any]]) -> [[String: Any]] {
        var merged = remote
        
        for localItem in local {
            if let id = localItem["id"] as? String {
                // Check if item already exists in remote
                let existsInRemote = remote.contains { remoteItem in
                    remoteItem["id"] as? String == id
                }
                
                if !existsInRemote {
                    merged.append(localItem)
                }
            }
        }
        
        return merged
    }
    
    // MARK: - Cleanup
    deinit {
        stopListening()
        cancellables.removeAll()
        networkCancellable?.cancel()
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
    case fileTooLarge
    case invalidFileName
    
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
        case .fileTooLarge:
            return "File is too large. Maximum size is 100MB."
        case .invalidFileName:
            return "File name contains invalid characters."
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

// MARK: - String Extension for Filename Sanitization
extension String {
    func sanitizedFileName() -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return self.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
