//
//  FirebaseBookStorage.swift
//  BookReader
//
//  Handles book storage in Firebase Firestore and Storage
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Combine

class FirebaseBookStorage: ObservableObject {
    
    // MARK: - Singleton
    static let shared = FirebaseBookStorage()
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()
    private var isListening = false
    
    // Cache for downloaded files
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let cacheDirectory: URL
    
    // MARK: - Init
    private init() {
        // Create cache directory
        cacheDirectory = documentsDirectory.appendingPathComponent("BookCache")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Listen for auth changes
        setupAuthListener()
    }
    
    // MARK: - Setup
    private func setupAuthListener() {
        // Start listening immediately if user is already authenticated
        if FirebaseManager.shared.currentUser != nil {
            print("🔥 User already authenticated, starting Firebase listener")
            startListening()
        }
        
        // Also listen for future auth changes
        FirebaseManager.shared.$currentUser
            .sink { [weak self] user in
                if let user = user {
                    print("🔥 User authenticated: \(user.uid), starting Firebase listener")
                    // Small delay to ensure Firebase is fully initialized
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.startListening()
                    }
                } else {
                    print("🔥 User signed out, stopping Firebase listener")
                    self?.stopListening()
                    DispatchQueue.main.async {
                        self?.books = []
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Real-time Listening
    private func startListening() {
        guard let userId = FirebaseManager.shared.userId else { 
            print("❌ Cannot start listening: No user ID")
            return 
        }
        
        // Check if we're already listening to prevent duplicates
        if isListening {
            print("ℹ️ Already listening for user \(userId), skipping...")
            return
        }
        
        // Don't add duplicate listeners
        if !listeners.isEmpty {
            print("⚠️ Listener already exists for user \(userId), removing old listeners first...")
            stopListening()
        }
        
        print("🎧 Starting Firestore listener for user: \(userId)")
        print("🔍 Listening to path: users/\(userId)/books")
        
        let listener = db.collection("users").document(userId).collection("books")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = error
                    print("❌ Error listening to books: \(error)")
                    return
                }
                
                print("🔄 Firestore snapshot received")
                self?.processBookSnapshot(snapshot)
            }
        
        listeners.append(listener)
        isListening = true
        print("✅ Firestore listener added. Total listeners: \(listeners.count)")
    }
    
    private func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        isListening = false
    }
    
    private func processBookSnapshot(_ snapshot: QuerySnapshot?) {
        guard let documents = snapshot?.documents else { return }
        
        print("📚 Processing \(documents.count) books from Firestore")
        
        let firebaseBooks = documents.compactMap { document -> FirebaseBook? in
            do {
                let book = try document.data(as: FirebaseBook.self)
                print("✅ Decoded book: \(book.title)")
                return book
            } catch {
                print("❌ Failed to decode book: \(error)")
                return nil
            }
        }
        
        // Convert to local Book models with cached file paths
        books = firebaseBooks.map { fbBook in
            let cachedPath = cacheDirectory.appendingPathComponent(fbBook.fileName).path
            
            // Check if file exists in cache
            if FileManager.default.fileExists(atPath: cachedPath) {
                print("📁 Book cached locally: \(fbBook.title) at \(cachedPath)")
                return fbBook.toBook(filePath: cachedPath)
            } else {
                // File not cached yet, but still show the book (will download on open)
                print("☁️ Book in cloud only: \(fbBook.title)")
                return fbBook.toBook(filePath: "")
            }
        }
        
        print("📚 Total books loaded: \(books.count)")
    }
    
    // MARK: - Add Book
    func addBook(_ book: Book, fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            print("❌ No user ID for upload")
            completion(.failure(FirebaseManager.FirebaseError.notAuthenticated))
            return
        }
        
        print("📤 Starting book upload: \(book.title)")
        print("📁 File URL: \(fileURL)")
        print("👤 User ID: \(userId)")
        
        // First ensure user document exists
        ensureUserDocumentExists(userId: userId) { [weak self] result in
            switch result {
            case .success:
                self?.uploadBookToFirebase(book: book, fileURL: fileURL, userId: userId, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func ensureUserDocumentExists(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("❌ Error checking user document: \(error)")
                completion(.failure(error))
                return
            }
            
            if document?.exists == true {
                print("✅ User document exists")
                completion(.success(()))
            } else {
                print("📝 Creating user document...")
                // Create user document
                let userData: [String: Any] = [
                    "uid": userId,
                    "createdAt": FieldValue.serverTimestamp(),
                    "bookCount": 0
                ]
                
                userRef.setData(userData) { error in
                    if let error = error {
                        print("❌ Failed to create user document: \(error)")
                        completion(.failure(error))
                    } else {
                        print("✅ User document created")
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    private func uploadBookToFirebase(book: Book, fileURL: URL, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        
        // Verify file exists before uploading
        print("🔍 Checking file before upload...")
        print("📁 File URL: \(fileURL)")
        print("📁 File path: \(fileURL.path)")
        print("📁 File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ File does not exist at upload time!")
            isLoading = false
            completion(.failure(NSError(domain: "FileError", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found at path: \(fileURL.path)"])))
            return
        }
        
        // Get file info
        let fileName = fileURL.lastPathComponent
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        
        print("📄 File name: \(fileName)")
        print("📏 File size: \(fileSize) bytes")
        
        // Verify file has content
        guard fileSize > 0 else {
            print("❌ File is empty!")
            isLoading = false
            completion(.failure(NSError(domain: "FileError", code: 400, userInfo: [NSLocalizedDescriptionKey: "File is empty"])))
            return
        }
        
        // Upload file to Firebase Storage
        let storageRef = storage.reference().child("users/\(userId)/books/\(book.id)/\(fileName)")
        print("☁️ Storage path: users/\(userId)/books/\(book.id)/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"
        
        let uploadTask = storageRef.putFile(from: fileURL, metadata: metadata) { [weak self] metadata, error in
            if let error = error {
                print("❌ Storage upload failed: \(error)")
                self?.isLoading = false
                completion(.failure(error))
                return
            }
            
            print("✅ File uploaded to Storage successfully")
            
            // Create Firestore document
            let firebaseBook = FirebaseBook.fromBook(book, userId: userId, fileName: fileName, fileSize: fileSize)
            
            print("📝 Creating Firestore document...")
            
            do {
                try self?.db.collection("users").document(userId).collection("books")
                    .document(book.id).setData(from: firebaseBook) { error in
                        self?.isLoading = false
                        
                        if let error = error {
                            print("❌ Firestore save failed: \(error)")
                            completion(.failure(error))
                        } else {
                            print("✅ Book saved to Firestore successfully")
                            
                            // Copy file to cache
                            let cachedPath = self?.cacheDirectory.appendingPathComponent(fileName)
                            if let cachedPath = cachedPath {
                                do {
                                    try FileManager.default.copyItem(at: fileURL, to: cachedPath)
                                    print("✅ File cached locally at: \(cachedPath)")
                                } catch {
                                    print("⚠️ Failed to cache file: \(error)")
                                }
                            }
                            
                            completion(.success(book.id))
                        }
                    }
            } catch {
                print("❌ Failed to encode FirebaseBook: \(error)")
                self?.isLoading = false
                completion(.failure(error))
            }
        }
        
        // Observe upload progress
        uploadTask.observe(.progress) { snapshot in
            let percentComplete = 100.0 * Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
            print("📤 Upload progress: \(percentComplete)%")
        }
    }
    
    // MARK: - Update Book
    func updateBook(_ book: Book, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(FirebaseManager.FirebaseError.notAuthenticated))
            return
        }
        
        let bookRef = db.collection("users").document(userId).collection("books").document(book.id)
        
        bookRef.updateData([
            "lastReadPosition": book.lastReadPosition,
            "lastReadDate": book.readingStats.lastReadDate != nil ? Timestamp(date: book.readingStats.lastReadDate!) : NSNull(),
            "totalReadingTime": book.readingStats.totalReadingTime,
            "readingProgress": book.lastReadPosition,
            "isFinished": book.lastReadPosition >= 0.95,
            "highlightsCount": book.highlights.count,
            "notesCount": book.notes.count,
            "bookmarksCount": book.bookmarks.count
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Delete Book
    func deleteBook(_ book: Book, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(FirebaseManager.FirebaseError.notAuthenticated))
            return
        }
        
        // Delete from Firestore
        let bookRef = db.collection("users").document(userId).collection("books").document(book.id)
        
        bookRef.getDocument { [weak self] document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let firebaseBook = try? document?.data(as: FirebaseBook.self) else {
                completion(.failure(FirebaseManager.FirebaseError.missingData))
                return
            }
            
            // Delete from Storage
            let storageRef = self?.storage.reference().child("users/\(userId)/books/\(book.id)/\(firebaseBook.fileName)")
            
            storageRef?.delete { error in
                if let error = error {
                    print("⚠️ Error deleting file from storage: \(error)")
                }
                
                // Delete from Firestore
                bookRef.delete { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        // Delete from cache
                        let cachedPath = self?.cacheDirectory.appendingPathComponent(firebaseBook.fileName)
                        try? FileManager.default.removeItem(at: cachedPath!)
                        
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    // MARK: - Download Book
    func downloadBook(_ book: Book, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let userId = FirebaseManager.shared.userId else {
            completion(.failure(FirebaseManager.FirebaseError.notAuthenticated))
            return
        }
        
        // Get book info from Firestore
        let bookRef = db.collection("users").document(userId).collection("books").document(book.id)
        
        bookRef.getDocument { [weak self] document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let firebaseBook = try? document?.data(as: FirebaseBook.self) else {
                completion(.failure(FirebaseManager.FirebaseError.missingData))
                return
            }
            
            // Check cache first
            let cachedPath = self?.cacheDirectory.appendingPathComponent(firebaseBook.fileName)
            if let cachedPath = cachedPath, FileManager.default.fileExists(atPath: cachedPath.path) {
                completion(.success(cachedPath))
                return
            }
            
            // Download from Storage
            let storageRef = self?.storage.reference().child("users/\(userId)/books/\(book.id)/\(firebaseBook.fileName)")
            
            storageRef?.write(toFile: cachedPath!) { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    completion(.success(url))
                } else {
                    completion(.failure(FirebaseManager.FirebaseError.downloadFailed))
                }
            }
        }
    }
    
    // MARK: - Migration
    func migrateLocalBooks(completion: @escaping (Result<Int, Error>) -> Void) {
        let localBooks = BookStorage.shared.loadBooks()
        var migrated = 0
        let group = DispatchGroup()
        
        for book in localBooks {
            group.enter()
            
            let fileURL = URL(fileURLWithPath: book.filePath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                addBook(book, fileURL: fileURL) { result in
                    switch result {
                    case .success:
                        migrated += 1
                    case .failure(let error):
                        print("❌ Failed to migrate book \(book.title): \(error)")
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(.success(migrated))
        }
    }
}
