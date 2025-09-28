//
//  BookStorage.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//

import UIKit
import Foundation

class BookStorage {
    static let shared = BookStorage()
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let booksFile = "books.json"
    private let backupFile = "books.json.backup"
    
    // File operation queue for thread safety
    private let fileQueue = DispatchQueue(label: "com.bookreader.filestorage", qos: .userInitiated)
    
    private init() {
        // Don't clear books automatically
        // clearAllBooks()
        
        // Create backup if main file exists but backup doesn't
        createInitialBackupIfNeeded()
        
        // Perform startup integrity check and repair if needed
        performStartupIntegrityCheck()
        
        // Schedule periodic integrity checks
        schedulePeriodicIntegrityChecks()
    }
    
    private func clearAllBooks() {
        let url = documentsDirectory.appendingPathComponent(booksFile)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func saveBook(_ book: Book) {
        // Create backup before making changes
        createBackupBeforeOperation()
        
        var books = loadBooks()
        books.append(book)
        saveBooks(books)
    }
    
    func updateBook(_ updatedBook: Book) {
        // Create backup before making changes
        createBackupBeforeOperation()
        
        var books = loadBooks()
        
        // Find and replace the book with the same ID
        if let index = books.firstIndex(where: { $0.id == updatedBook.id }) {
            books[index] = updatedBook
            saveBooks(books)
            
            // Also sync to Firebase if available
            UnifiedFirebaseStorage.shared.updateBook(updatedBook) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    break
                }
            }
        } else {
            saveBook(updatedBook)
        }
    }
    
    func deleteBook(_ bookId: String) {
        // Create backup before making changes
        createBackupBeforeOperation()
        
        var books = loadBooks()
        
        // Find the book to get its file path before deletion
        if let bookToDelete = books.first(where: { $0.id == bookId }) {
            // Remove from books array
            books.removeAll { $0.id == bookId }
            
            // Save updated books list
            saveBooks(books)
            
            // Clean up the actual file
            cleanupBookFile(at: bookToDelete.filePath)
            
            // Also try to delete from Firebase if authenticated
            if FirebaseManager.shared.isAuthenticated {
                UnifiedFirebaseStorage.shared.removeBook(bookId: bookId) { result in
                    switch result {
                    case .success:
                        print("Book deleted from Firebase successfully")
                    case .failure(let error):
                        print("Failed to delete book from Firebase: \(error.localizedDescription)")
                    }
                }
            }
            
            // Notify observers
            NotificationCenter.default.post(
                name: .bookDeleted,
                object: nil,
                userInfo: ["bookId": bookId, "filePath": bookToDelete.filePath]
            )
        }
    }
    
    func deleteBook(_ book: Book) {
        deleteBook(book.id)
    }
    
    func deleteBooks(_ bookIds: [String]) {
        // Create backup before making changes
        createBackupBeforeOperation()
        
        var books = loadBooks()
        var deletedBooks: [Book] = []
        
        // Collect books to delete for cleanup
        for bookId in bookIds {
            if let bookToDelete = books.first(where: { $0.id == bookId }) {
                deletedBooks.append(bookToDelete)
            }
        }
        
        // Remove from books array
        books.removeAll { bookIds.contains($0.id) }
        
        // Save updated books list
        saveBooks(books)
        
        // Clean up files
        for deletedBook in deletedBooks {
            cleanupBookFile(at: deletedBook.filePath)
        }
        
        // Delete from Firebase if authenticated
        if FirebaseManager.shared.isAuthenticated {
            for bookId in bookIds {
                UnifiedFirebaseStorage.shared.removeBook(bookId: bookId) { result in
                    switch result {
                    case .success:
                        print("Book \(bookId) deleted from Firebase successfully")
                    case .failure(let error):
                        print("Failed to delete book \(bookId) from Firebase: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Notify observers
        NotificationCenter.default.post(
            name: .booksDeleted,
            object: nil,
            userInfo: ["bookIds": bookIds, "deletedBooks": deletedBooks]
        )
    }
    
    func deleteAllBooks() {
        // Create backup before making changes
        createBackupBeforeOperation()
        
        let books = loadBooks()
        let bookIds = books.map { $0.id }
        
        // Clean up all book files
        for book in books {
            cleanupBookFile(at: book.filePath)
        }
        
        // Clear the books array and save
        saveBooks([])
        
        // Delete all from Firebase if authenticated
        if FirebaseManager.shared.isAuthenticated {
            for bookId in bookIds {
                UnifiedFirebaseStorage.shared.removeBook(bookId: bookId) { result in
                    switch result {
                    case .success:
                        print("Book \(bookId) deleted from Firebase successfully")
                    case .failure(let error):
                        print("Failed to delete book \(bookId) from Firebase: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Notify observers
        NotificationCenter.default.post(
            name: .allBooksDeleted,
            object: nil,
            userInfo: ["deletedCount": books.count]
        )
    }
    
    private func cleanupBookFile(at filePath: String) {
        // Only delete if file exists and is within our documents directory
        guard FileManager.default.fileExists(atPath: filePath),
              filePath.hasPrefix(documentsDirectory.path) else {
            return
        }
        
        do {
            try FileManager.default.removeItem(atPath: filePath)
            print("Successfully deleted book file: \(filePath)")
        } catch {
            print("Failed to delete book file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Safe Deletion Methods
    
    func safeDeleteBook(_ bookId: String, completion: @escaping (Bool) -> Void) {
        // Perform deletion on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Check if book exists
            let books = self.loadBooks()
            guard books.contains(where: { $0.id == bookId }) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // Perform deletion
            self.deleteBook(bookId)
            
            // Verify deletion was successful
            let updatedBooks = self.loadBooks()
            let deletionSuccessful = !updatedBooks.contains(where: { $0.id == bookId })
            
            DispatchQueue.main.async {
                completion(deletionSuccessful)
            }
        }
    }
    
    func canDeleteBook(_ bookId: String) -> Bool {
        let books = loadBooks()
        return books.contains(where: { $0.id == bookId })
    }
    
    func getBookToDelete(_ bookId: String) -> Book? {
        let books = loadBooks()
        return books.first(where: { $0.id == bookId })
    }
    
    func getDeletionConfirmationInfo(for bookId: String) -> (title: String, fileSize: String)? {
        guard let book = getBookToDelete(bookId) else { return nil }
        
        let fileSize: String
        if FileManager.default.fileExists(atPath: book.filePath) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: book.filePath)
                let size = attributes[.size] as? Int64 ?? 0
                fileSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            } catch {
                fileSize = "Unknown size"
            }
        } else {
            fileSize = "File not found"
        }
        
        return (title: book.title, fileSize: fileSize)
    }
    
    func loadBooks() -> [Book] {
        // Use async for non-blocking operation, but return synchronously for compatibility
        var result: [Book] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        fileQueue.async { [weak self] in
            defer { semaphore.signal() }
            guard let self = self else { return }
            result = self.loadBooksInternal()
        }
        
        semaphore.wait()
        return result
    }
    
    func loadBooksAsync(completion: @escaping ([Book]) -> Void) {
        fileQueue.async { [weak self] in
            guard let self = self else { 
                DispatchQueue.main.async { completion([]) }
                return 
            }
            
            let books = self.loadBooksInternal()
            DispatchQueue.main.async {
                completion(books)
            }
        }
    }
    
    private func loadBooksInternal() -> [Book] {
        let url = documentsDirectory.appendingPathComponent(booksFile)
        
        // Try to load main file first
        if let books = tryLoadBooks(from: url) {
            return books
        }
        
        // Main file failed, try backup
        let backupURL = documentsDirectory.appendingPathComponent(backupFile)
        if let books = tryLoadBooks(from: backupURL) {
            // Restore main file from backup
            do {
                try FileManager.default.copyItem(at: backupURL, to: url)
                NotificationCenter.default.post(
                    name: .bookDataRestored,
                    object: nil,
                    userInfo: ["source": "backup", "automatic": true]
                )
            } catch {
                // Log error but continue with backup data
            }
            return books
        }
        
        // Both files failed, return empty array
        return []
    }
    
    private func tryLoadBooks(from url: URL) -> [Book]? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let bookData = try JSONDecoder().decode([BookData].self, from: data)
            
            // Validate loaded data
            guard !data.isEmpty && validateBookData(bookData) else {
                return nil
            }
            
            return bookData.compactMap { data in
                // Convert relative path to absolute path
                let absolutePath = getAbsolutePath(from: data.filePath)
                
                // Check if file exists before creating book
                guard FileManager.default.fileExists(atPath: absolutePath) else {
                    return nil
                }
                
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
                    readingStats: data.readingStats ?? ReadingStats(),
                    personalSummary: data.personalSummary ?? "",
                    keyTakeaways: data.keyTakeaways ?? "",
                    actionItems: data.actionItems ?? "",
                    sessionNotes: data.sessionNotes ?? [],
                    notesUpdatedAt: data.notesUpdatedAt,
                    storageFileName: data.storageFileName
                )
            }
        } catch {
            return nil
        }
    }
    
    private func validateBookData(_ bookData: [BookData]) -> Bool {
        return bookData.allSatisfy { book in
            !book.id.isEmpty && 
            !book.title.isEmpty && 
            !book.filePath.isEmpty &&
            book.lastReadPosition >= 0
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
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            
            let bookData = books.map { book in
                // Store only the filename, not the full path
                let fileName = URL(fileURLWithPath: book.filePath).lastPathComponent
                return BookData(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    filePath: fileName, // Store relative path (just filename)
                    type: book.type.rawValue,
                    storageFileName: book.storageFileName,
                    lastReadPosition: book.lastReadPosition,
                    highlights: book.highlights,
                    notes: book.notes,
                    readingStats: book.readingStats,
                    personalSummary: book.personalSummary,
                    keyTakeaways: book.keyTakeaways,
                    actionItems: book.actionItems,
                    sessionNotes: book.sessionNotes,
                    notesUpdatedAt: book.notesUpdatedAt
                )
            }
            
            do {
                try self.saveDataAtomically(bookData)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .bookDataSaved, object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .bookDataSaveError, 
                        object: nil, 
                        userInfo: ["error": error]
                    )
                }
                
                // Attempt to restore from backup if save failed
                do {
                    try self.restoreFromBackup()
                } catch {
                    // Critical error - notify user
                    DispatchQueue.main.async {
                        self.notifyUserOfCriticalError(error)
                    }
                }
            }
        }
    }
    
    // MARK: - Atomic File Operations
    
    private func saveDataAtomically(_ bookData: [BookData]) throws {
        let data = try JSONEncoder().encode(bookData)
        
        // Validate data before saving
        guard !data.isEmpty else {
            throw BookStorageError.emptyData
        }
        
        // Create temporary file for atomic write
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        let tempURL = documentsDirectory.appendingPathComponent("\(booksFile).tmp")
        let backupURL = documentsDirectory.appendingPathComponent(backupFile)
        
        // Step 1: Create backup of current file if it exists
        if FileManager.default.fileExists(atPath: mainURL.path) {
            try createBackup(from: mainURL, to: backupURL)
        }
        
        // Step 2: Write to temporary file
        try data.write(to: tempURL)
        
        // Step 3: Validate the written data
        guard validateSavedData(at: tempURL) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw BookStorageError.dataValidationFailed
        }
        
        // Step 4: Atomically move temp file to main file
        if FileManager.default.fileExists(atPath: mainURL.path) {
            try FileManager.default.removeItem(at: mainURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: mainURL)
        
        // Step 5: Verify final file integrity
        guard validateSavedData(at: mainURL) else {
            // Restore from backup if final validation fails
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.copyItem(at: backupURL, to: mainURL)
            }
            throw BookStorageError.finalValidationFailed
        }
    }
    
    private func createBackup(from source: URL, to backup: URL) throws {
        // Remove old backup first
        if FileManager.default.fileExists(atPath: backup.path) {
            try FileManager.default.removeItem(at: backup)
        }
        
        // Create new backup
        try FileManager.default.copyItem(at: source, to: backup)
    }
    
    private func validateSavedData(at url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let bookData = try JSONDecoder().decode([BookData].self, from: data)
            
            // Basic validation - ensure we can decode and it's not empty
            return !data.isEmpty && bookData.allSatisfy { book in
                !book.id.isEmpty && !book.title.isEmpty && !book.filePath.isEmpty
            }
        } catch {
            return false
        }
    }
    
    private func createInitialBackupIfNeeded() {
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        let backupURL = documentsDirectory.appendingPathComponent(backupFile)
        
        if FileManager.default.fileExists(atPath: mainURL.path) && 
           !FileManager.default.fileExists(atPath: backupURL.path) {
            try? FileManager.default.copyItem(at: mainURL, to: backupURL)
        }
    }
    
    private func createBackupBeforeOperation() {
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        
        // Only create backup if main file exists and is valid
        if FileManager.default.fileExists(atPath: mainURL.path) && 
           validateSavedData(at: mainURL) {
            // Create backup asynchronously to avoid blocking
            DispatchQueue.global(qos: .utility).async { [weak self] in
                try? self?.createManualBackup()
            }
        }
    }
    
    private func restoreFromBackup() throws {
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        let backupURL = documentsDirectory.appendingPathComponent(backupFile)
        
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw BookStorageError.noBackupAvailable
        }
        
        // Validate backup before restoring
        guard validateSavedData(at: backupURL) else {
            throw BookStorageError.corruptedBackup
        }
        
        // Remove corrupted main file
        if FileManager.default.fileExists(atPath: mainURL.path) {
            try FileManager.default.removeItem(at: mainURL)
        }
        
        // Restore from backup
        try FileManager.default.copyItem(at: backupURL, to: mainURL)
    }
    
    private func notifyUserOfCriticalError(_ error: Error) {
        // This would typically show an alert to the user
        // For now, we'll post a notification that the UI can observe
        NotificationCenter.default.post(
            name: .criticalDataError,
            object: nil,
            userInfo: ["error": error, "message": "Critical data error occurred. Please restart the app."]
        )
    }
    
    // MARK: - Public Recovery Methods
    
    func hasBackup() -> Bool {
        let backupURL = documentsDirectory.appendingPathComponent(backupFile)
        return FileManager.default.fileExists(atPath: backupURL.path) && validateSavedData(at: backupURL)
    }
    
    func restoreFromBackupManually() throws {
        try restoreFromBackup()
        NotificationCenter.default.post(name: .bookDataRestored, object: nil)
    }
    
    func createManualBackup() throws {
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        let backupURL = documentsDirectory.appendingPathComponent(backupFile)
        
        guard FileManager.default.fileExists(atPath: mainURL.path) else {
            throw BookStorageError.noDataToBackup
        }
        
        try createBackup(from: mainURL, to: backupURL)
    }
    
    // MARK: - Enhanced Backup System
    
    func createTimestampedBackup() throws -> URL {
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        
        guard FileManager.default.fileExists(atPath: mainURL.path) else {
            throw BookStorageError.noDataToBackup
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let timestampedBackupFile = "books_backup_\(timestamp).json"
        let timestampedBackupURL = documentsDirectory.appendingPathComponent(timestampedBackupFile)
        
        try createBackup(from: mainURL, to: timestampedBackupURL)
        
        // Clean up old backups (keep only last 5)
        cleanupOldBackups()
        
        return timestampedBackupURL
    }
    
    func getAllBackups() -> [BackupInfo] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
            
            return contents.compactMap { url -> BackupInfo? in
                guard url.lastPathComponent.hasPrefix("books_backup_") || url.lastPathComponent == backupFile else {
                    return nil
                }
                
                guard validateSavedData(at: url) else {
                    return nil
                }
                
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let size = attributes?[.size] as? Int64 ?? 0
                let modificationDate = attributes?[.modificationDate] as? Date ?? Date()
                
                return BackupInfo(
                    url: url,
                    fileName: url.lastPathComponent,
                    size: size,
                    modificationDate: modificationDate,
                    isMainBackup: url.lastPathComponent == backupFile
                )
            }.sorted { $0.modificationDate > $1.modificationDate }
        } catch {
            return []
        }
    }
    
    func restoreFromSpecificBackup(_ backupInfo: BackupInfo) throws {
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        
        // Validate backup before restoring
        guard validateSavedData(at: backupInfo.url) else {
            throw BookStorageError.corruptedBackup
        }
        
        // Create a backup of current state before restoring
        if FileManager.default.fileExists(atPath: mainURL.path) {
            let emergencyBackupURL = documentsDirectory.appendingPathComponent("books_emergency_backup.json")
            try? createBackup(from: mainURL, to: emergencyBackupURL)
        }
        
        // Remove corrupted main file
        if FileManager.default.fileExists(atPath: mainURL.path) {
            try FileManager.default.removeItem(at: mainURL)
        }
        
        // Restore from selected backup
        try FileManager.default.copyItem(at: backupInfo.url, to: mainURL)
        
        // Verify restoration
        guard validateSavedData(at: mainURL) else {
            throw BookStorageError.finalValidationFailed
        }
        
        NotificationCenter.default.post(
            name: .bookDataRestored,
            object: nil,
            userInfo: ["source": backupInfo.fileName, "manual": true]
        )
    }
    
    private func cleanupOldBackups() {
        let allBackups = getAllBackups().filter { !$0.isMainBackup }
        
        // Keep only the 5 most recent timestamped backups
        if allBackups.count > 5 {
            let backupsToDelete = Array(allBackups.dropFirst(5))
            
            for backup in backupsToDelete {
                try? FileManager.default.removeItem(at: backup.url)
            }
        }
    }
    
    func exportBackupToUserDocuments() throws -> URL {
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        
        guard FileManager.default.fileExists(atPath: mainURL.path) else {
            throw BookStorageError.noDataToBackup
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let exportFileName = "BookReader_Export_\(timestamp).json"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportURL = documentsPath.appendingPathComponent(exportFileName)
        
        try FileManager.default.copyItem(at: mainURL, to: exportURL)
        
        return exportURL
    }
    
    func importBackupFromURL(_ url: URL) throws {
        // Validate the import file
        guard validateSavedData(at: url) else {
            throw BookStorageError.dataValidationFailed
        }
        
        // Create backup of current data before importing
        try createTimestampedBackup()
        
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        
        // Remove current file
        if FileManager.default.fileExists(atPath: mainURL.path) {
            try FileManager.default.removeItem(at: mainURL)
        }
        
        // Import new data
        try FileManager.default.copyItem(at: url, to: mainURL)
        
        // Verify import
        guard validateSavedData(at: mainURL) else {
            // Restore from backup if import validation fails
            try restoreFromBackup()
            throw BookStorageError.finalValidationFailed
        }
        
        // Update backup
        try createManualBackup()
        
        NotificationCenter.default.post(
            name: .bookDataImported,
            object: nil,
            userInfo: ["source": url.lastPathComponent]
        )
    }
    
    // MARK: - Data Integrity Methods
    
    func checkDataIntegrity() -> DataIntegrityResult {
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        let backupURL = documentsDirectory.appendingPathComponent(backupFile)
        
        let mainFileExists = FileManager.default.fileExists(atPath: mainURL.path)
        let backupFileExists = FileManager.default.fileExists(atPath: backupURL.path)
        
        let mainFileValid = mainFileExists ? validateSavedData(at: mainURL) : false
        let backupFileValid = backupFileExists ? validateSavedData(at: backupURL) : false
        
        return DataIntegrityResult(
            mainFileExists: mainFileExists,
            mainFileValid: mainFileValid,
            backupFileExists: backupFileExists,
            backupFileValid: backupFileValid
        )
    }
    
    func repairDataIfNeeded() -> Bool {
        let integrity = checkDataIntegrity()
        
        // If main file is corrupted but backup is valid, restore from backup
        if !integrity.mainFileValid && integrity.backupFileValid {
            do {
                try restoreFromBackup()
                return true
            } catch {
                return false
            }
        }
        
        // If main file is valid but backup is corrupted, recreate backup
        if integrity.mainFileValid && !integrity.backupFileValid {
            do {
                try createManualBackup()
                return true
            } catch {
                return false
            }
        }
        
        return integrity.mainFileValid
    }
    
    func getStorageInfo() -> StorageInfo {
        let mainURL = documentsDirectory.appendingPathComponent(booksFile)
        let backupURL = documentsDirectory.appendingPathComponent(backupFile)
        
        var mainFileSize: Int64 = 0
        var backupFileSize: Int64 = 0
        var mainFileModified: Date?
        var backupFileModified: Date?
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: mainURL.path) {
            mainFileSize = attributes[.size] as? Int64 ?? 0
            mainFileModified = attributes[.modificationDate] as? Date
        }
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: backupURL.path) {
            backupFileSize = attributes[.size] as? Int64 ?? 0
            backupFileModified = attributes[.modificationDate] as? Date
        }
        
        return StorageInfo(
            mainFileSize: mainFileSize,
            backupFileSize: backupFileSize,
            mainFileModified: mainFileModified,
            backupFileModified: backupFileModified
        )
    }
    
    // MARK: - Integrity Monitoring
    
    private func performStartupIntegrityCheck() {
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            
            let integrity = self.checkDataIntegrity()
            
            if integrity.needsRepair {
                let repairSuccessful = self.repairDataIfNeeded()
                
                DispatchQueue.main.async {
                    if repairSuccessful {
                        NotificationCenter.default.post(
                            name: .dataRepairedAtStartup,
                            object: nil,
                            userInfo: ["integrity": integrity]
                        )
                    } else {
                        NotificationCenter.default.post(
                            name: .criticalDataError,
                            object: nil,
                            userInfo: [
                                "error": BookStorageError.finalValidationFailed,
                                "message": "Failed to repair corrupted data at startup"
                            ]
                        )
                    }
                }
            }
        }
    }
    
    private func schedulePeriodicIntegrityChecks() {
        // Check integrity every 5 minutes when app is active
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performPeriodicIntegrityCheck()
        }
    }
    
    private func performPeriodicIntegrityCheck() {
        fileQueue.async { [weak self] in
            guard let self = self else { return }
            
            let integrity = self.checkDataIntegrity()
            
            if !integrity.isHealthy && integrity.needsRepair {
                let repairSuccessful = self.repairDataIfNeeded()
                
                if !repairSuccessful {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .dataIntegrityWarning,
                            object: nil,
                            userInfo: ["integrity": integrity]
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Error Types

enum BookStorageError: LocalizedError {
    case emptyData
    case dataValidationFailed
    case finalValidationFailed
    case noBackupAvailable
    case corruptedBackup
    case noDataToBackup
    case fileSystemError(Error)
    
    var errorDescription: String? {
        switch self {
        case .emptyData:
            return "Cannot save empty book data"
        case .dataValidationFailed:
            return "Book data validation failed during save"
        case .finalValidationFailed:
            return "Final validation failed after save - data may be corrupted"
        case .noBackupAvailable:
            return "No backup file available for restoration"
        case .corruptedBackup:
            return "Backup file is corrupted and cannot be restored"
        case .noDataToBackup:
            return "No book data exists to create backup"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyData:
            return "Ensure you have books to save before attempting to save data"
        case .dataValidationFailed, .finalValidationFailed:
            return "Try restarting the app. If the problem persists, restore from backup"
        case .noBackupAvailable:
            return "No backup is available. You may need to re-add your books"
        case .corruptedBackup:
            return "Both main data and backup are corrupted. You may need to re-add your books"
        case .noDataToBackup:
            return "Add some books first, then try creating a backup"
        case .fileSystemError:
            return "Check available storage space and app permissions"
        }
    }
}

// MARK: - Supporting Data Structures

struct DataIntegrityResult {
    let mainFileExists: Bool
    let mainFileValid: Bool
    let backupFileExists: Bool
    let backupFileValid: Bool
    
    var isHealthy: Bool {
        return mainFileValid && backupFileExists && backupFileValid
    }
    
    var needsRepair: Bool {
        return !mainFileValid || (mainFileExists && !backupFileExists)
    }
    
    var description: String {
        switch (mainFileValid, backupFileValid) {
        case (true, true):
            return "Data integrity is healthy"
        case (true, false):
            return "Main file is valid, backup needs repair"
        case (false, true):
            return "Main file corrupted, backup available for restore"
        case (false, false):
            return "Critical: Both main and backup files are corrupted"
        }
    }
}

struct StorageInfo {
    let mainFileSize: Int64
    let backupFileSize: Int64
    let mainFileModified: Date?
    let backupFileModified: Date?
    
    var totalStorageUsed: Int64 {
        return mainFileSize + backupFileSize
    }
    
    var formattedMainSize: String {
        return ByteCountFormatter.string(fromByteCount: mainFileSize, countStyle: .file)
    }
    
    var formattedBackupSize: String {
        return ByteCountFormatter.string(fromByteCount: backupFileSize, countStyle: .file)
    }
    
    var formattedTotalSize: String {
        return ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }
}

struct BackupInfo {
    let url: URL
    let fileName: String
    let size: Int64
    let modificationDate: Date
    let isMainBackup: Bool
    
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
    
    var displayName: String {
        if isMainBackup {
            return "Main Backup"
        } else if fileName.hasPrefix("books_backup_") {
            return "Auto Backup - \(formattedDate)"
        } else if fileName.hasPrefix("BookReader_Export_") {
            return "Export - \(formattedDate)"
        } else {
            return fileName
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let bookDataSaved = Notification.Name("BookDataSaved")
    static let bookDataSaveError = Notification.Name("BookDataSaveError")
    static let bookDataRestored = Notification.Name("BookDataRestored")
    static let bookDataImported = Notification.Name("BookDataImported")
    static let criticalDataError = Notification.Name("CriticalDataError")
    static let dataRepairedAtStartup = Notification.Name("DataRepairedAtStartup")
    static let dataIntegrityWarning = Notification.Name("DataIntegrityWarning")
    
    // Book deletion notifications
    static let bookDeleted = Notification.Name("BookDeleted")
    static let booksDeleted = Notification.Name("BooksDeleted")
    static let allBooksDeleted = Notification.Name("AllBooksDeleted")
    static let bookNotesUpdated = Notification.Name("BookNotesUpdated")
}

struct BookData: Codable {
    let id: String
    let title: String
    let author: String
    let filePath: String
    let type: String
    let storageFileName: String?
    let lastReadPosition: Float
    let highlights: [Highlight]?
    let notes: [Note]?
    let readingStats: ReadingStats?
    let personalSummary: String?
    let keyTakeaways: String?
    let actionItems: String?
    let sessionNotes: [BookSessionNote]?
    let notesUpdatedAt: Date?
    
    // Legacy initializer for backward compatibility
    init(id: String, title: String, author: String, filePath: String, type: String, storageFileName: String? = nil, lastReadPosition: Float, highlights: [Highlight]? = nil, notes: [Note]? = nil, readingStats: ReadingStats? = nil, personalSummary: String? = nil, keyTakeaways: String? = nil, actionItems: String? = nil, sessionNotes: [BookSessionNote]? = nil, notesUpdatedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.filePath = filePath
        self.type = type
        self.storageFileName = storageFileName
        self.lastReadPosition = lastReadPosition
        self.highlights = highlights
        self.notes = notes
        self.readingStats = readingStats
        self.personalSummary = personalSummary
        self.keyTakeaways = keyTakeaways
        self.actionItems = actionItems
        self.sessionNotes = sessionNotes
        self.notesUpdatedAt = notesUpdatedAt
    }
}
