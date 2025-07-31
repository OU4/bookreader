//
//  FirebaseManager.swift
//  BookReader
//
//  Centralized Firebase configuration and management
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

class FirebaseManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = FirebaseManager()
    
    // MARK: - Properties
    let auth = Auth.auth()
    let db = Firestore.firestore()
    let storage = Storage.storage()
    
    // User state
    @Published var currentUser: User? = nil
    
    var isAuthenticated: Bool {
        return currentUser != nil
    }
    
    var userId: String? {
        return currentUser?.uid
    }
    
    // MARK: - Collections
    enum Collection {
        static let users = "users"
        static let books = "books"
        static let notes = "notes"
        static let highlights = "highlights"
        static let studyGroups = "studyGroups"
        static let sharedBooks = "sharedBooks"
    }
    
    // MARK: - Storage Paths
    enum StoragePath {
        static func userBooks(userId: String) -> String {
            return "users/\(userId)/books"
        }
        
        static func bookFile(userId: String, bookId: String) -> String {
            return "users/\(userId)/books/\(bookId)/original.pdf"
        }
        
        static func bookThumbnail(userId: String, bookId: String) -> String {
            return "users/\(userId)/books/\(bookId)/thumbnail.jpg"
        }
        
        static func userExports(userId: String) -> String {
            return "users/\(userId)/exports"
        }
    }
    
    // MARK: - Private Init
    private init() {
        setupFirestore()
    }
    
    // MARK: - Setup
    private func setupFirestore() {
        // Enable offline persistence (already done in AppDelegate, but good to ensure)
        db.settings.isPersistenceEnabled = true
        db.settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        
        // Set initial user state
        currentUser = auth.currentUser
        if let user = currentUser {
            print("🔐 Initial user state: \(user.uid)")
        }
        
        // Add auth state listener
        auth.addStateDidChangeListener { [weak self] (auth, user) in
            print("🔄 Auth state changed: \(user?.uid ?? "nil")")
            self?.currentUser = user
            if let user = user {
                print("🔐 User authenticated: \(user.uid)")
                self?.updateUserProfile()
            } else {
                print("🔓 User not authenticated")
            }
        }
    }
    
    // MARK: - User Profile Management
    private func updateUserProfile() {
        guard let user = currentUser else { return }
        
        let userRef = db.collection(Collection.users).document(user.uid)
        
        let profileData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "Reader",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "lastActive": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // Merge to avoid overwriting existing data
        userRef.setData(profileData, merge: true) { error in
            if let error = error {
                print("❌ Error updating user profile: \(error)")
            } else {
                print("✅ User profile updated")
            }
        }
    }
    
    // MARK: - User Document References
    func userDocument() -> DocumentReference? {
        guard let userId = userId else { return nil }
        return db.collection(Collection.users).document(userId)
    }
    
    func userBooksCollection() -> CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection(Collection.users).document(userId).collection(Collection.books)
    }
    
    func userNotesCollection() -> CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection(Collection.users).document(userId).collection(Collection.notes)
    }
    
    func userHighlightsCollection() -> CollectionReference? {
        guard let userId = userId else { return nil }
        return db.collection(Collection.users).document(userId).collection(Collection.highlights)
    }
    
    // MARK: - Storage References
    func bookStorageRef(bookId: String) -> StorageReference? {
        guard let userId = userId else { return nil }
        return storage.reference().child(StoragePath.bookFile(userId: userId, bookId: bookId))
    }
    
    func thumbnailStorageRef(bookId: String) -> StorageReference? {
        guard let userId = userId else { return nil }
        return storage.reference().child(StoragePath.bookThumbnail(userId: userId, bookId: bookId))
    }
    
    // MARK: - Error Handling
    enum FirebaseError: LocalizedError {
        case notAuthenticated
        case missingData
        case uploadFailed
        case downloadFailed
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "User not authenticated. Please sign in."
            case .missingData:
                return "Required data is missing."
            case .uploadFailed:
                return "Failed to upload file."
            case .downloadFailed:
                return "Failed to download file."
            }
        }
    }
}

// MARK: - Firestore Timestamp Extension
extension Timestamp {
    var dateValue: Date {
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}