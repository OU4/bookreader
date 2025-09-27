//
//  FirebaseUploadHelper.swift
//  BookReader
//
//  Helper for robust Firebase Storage uploads
//

import Foundation
import Firebase
import FirebaseStorage

class FirebaseUploadHelper {
    
    static let shared = FirebaseUploadHelper()
    
    private init() {}
    
    func uploadPDF(fileURL: URL, title: String, author: String, userId: String, completion: @escaping (Result<(url: String, fileName: String), Error>) -> Void) {
        
        // Validate file
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            completion(.failure(UploadError.fileNotFound))
            return
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            if fileSize > 100 * 1024 * 1024 { // 100MB limit
                completion(.failure(UploadError.fileTooLarge))
                return
            }
            
        } catch {
        }
        
        // Create safe filename
        let safeTitle = createSafeFileName(from: title)
        let uniqueId = UUID().uuidString.prefix(8)
        let fileName = "\(safeTitle)_\(uniqueId).pdf"
        
        
        // Create storage reference with simple path
        let storageRef = Storage.storage().reference()
        let bookRef = storageRef.child("books").child(userId).child(fileName)
        
        // Read file data asynchronously to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async {
            guard let fileData = try? Data(contentsOf: fileURL) else {
                DispatchQueue.main.async {
                    completion(.failure(UploadError.cannotReadFile))
                }
                return
            }
            
            // Create metadata
            let metadata = StorageMetadata()
            metadata.contentType = "application/pdf"
            metadata.customMetadata = [
                "title": title,
                "author": author,
                "originalFileName": fileURL.lastPathComponent
            ]
            
            // Upload using data instead of file URL to avoid parsing issues
            let uploadTask = bookRef.putData(fileData, metadata: metadata) { metadata, error in
                if let error = error {
                    
                    // Check for specific error codes
                    let errorCode = (error as NSError).code
                    switch errorCode {
                    case -1017:
                        DispatchQueue.main.async {
                            completion(.failure(UploadError.networkError("Cannot parse response. Please check your internet connection.")))
                        }
                    case 403:
                        DispatchQueue.main.async {
                            completion(.failure(UploadError.permissionDenied))
                        }
                    default:
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                    return
                }
                
                // Get download URL
                bookRef.downloadURL { url, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                        return
                    }
                    
                    guard let downloadURL = url else {
                        DispatchQueue.main.async {
                            completion(.failure(UploadError.noDownloadURL))
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success((url: downloadURL.absoluteString, fileName: fileName)))
                    }
                }
            }
            
            // Monitor upload progress
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                }
            }
        }
    }
    
    private func createSafeFileName(from title: String) -> String {
        // Remove all special characters and spaces
        let allowedCharacters = CharacterSet.alphanumerics
        let cleanedTitle = title.components(separatedBy: allowedCharacters.inverted).joined(separator: "")
        
        // Limit length
        let maxLength = 50
        let truncatedTitle = String(cleanedTitle.prefix(maxLength))
        
        // Ensure non-empty
        return truncatedTitle.isEmpty ? "Book" : truncatedTitle
    }
}

enum UploadError: LocalizedError {
    case fileNotFound
    case fileTooLarge
    case cannotReadFile
    case networkError(String)
    case permissionDenied
    case noDownloadURL
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .fileTooLarge:
            return "File is too large. Maximum size is 100MB."
        case .cannotReadFile:
            return "Cannot read file data"
        case .networkError(let message):
            return message
        case .permissionDenied:
            return "Permission denied. Please check Firebase Storage rules."
        case .noDownloadURL:
            return "Failed to get download URL"
        }
    }
}