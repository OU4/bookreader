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
    
    private let maxUploadAttempts = 3
    
    private init() {}
    
    func uploadPDF(fileURL: URL, title: String, author: String, userId: String, completion: @escaping (Result<(url: String, fileName: String), Error>) -> Void) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            completion(.failure(UploadError.fileNotFound))
            return
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            if fileSize > 100 * 1024 * 1024 {
                completion(.failure(UploadError.fileTooLarge))
                return
            }
        } catch {
        }

        let safeTitle = createSafeFileName(from: title)
        let uniqueId = UUID().uuidString.prefix(8)
        let fileName = "\(safeTitle)_\(uniqueId).pdf"

        let storageRef = Storage.storage().reference()
        let bookRef = storageRef.child("books").child(userId).child(fileName)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            guard let fileData = try? Data(contentsOf: fileURL) else {
                DispatchQueue.main.async {
                    completion(.failure(UploadError.cannotReadFile))
                }
                return
            }

            let metadata = StorageMetadata()
            metadata.contentType = "application/pdf"
            metadata.customMetadata = [
                "title": title,
                "author": author,
                "originalFileName": fileURL.lastPathComponent
            ]

            self.performDataUpload(
                data: fileData,
                fileURL: fileURL,
                bookRef: bookRef,
                metadata: metadata,
                fileName: fileName,
                attempt: 1,
                completion: completion
            )
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

    private func performDataUpload(
        data: Data,
        fileURL: URL,
        bookRef: StorageReference,
        metadata: StorageMetadata,
        fileName: String,
        attempt: Int,
        completion: @escaping (Result<(url: String, fileName: String), Error>) -> Void
    ) {
        let uploadTask = bookRef.putData(data, metadata: metadata) { [weak self] _, error in
            guard let self = self else { return }

            if let error = error {
                if self.shouldFallbackToFile(error) {
                    self.performFileUpload(
                        fileURL: fileURL,
                        bookRef: bookRef,
                        metadata: metadata,
                        fileName: fileName,
                        attempt: attempt,
                        completion: completion
                    )
                    return
                }

                if self.shouldRetryUpload(error: error) && attempt < self.maxUploadAttempts {
                    self.scheduleRetry(after: self.retryDelay(for: attempt)) {
                        self.performDataUpload(
                            data: data,
                            fileURL: fileURL,
                            bookRef: bookRef,
                            metadata: metadata,
                            fileName: fileName,
                            attempt: attempt + 1,
                            completion: completion
                        )
                    }
                    return
                }

                if self.isPermissionError(error) {
                    self.finishOnMain(.failure(UploadError.permissionDenied), completion: completion)
                    return
                }

                self.finishOnMain(.failure(self.mapUploadError(error)), completion: completion)
                return
            }

            self.fetchDownloadURL(bookRef: bookRef, fileName: fileName, attempt: 1, completion: completion)
        }

        uploadTask.observe(.progress) { snapshot in
            _ = snapshot.progress
        }
    }

    private func performFileUpload(
        fileURL: URL,
        bookRef: StorageReference,
        metadata: StorageMetadata,
        fileName: String,
        attempt: Int,
        completion: @escaping (Result<(url: String, fileName: String), Error>) -> Void
    ) {
        let fileTask = bookRef.putFile(from: fileURL, metadata: metadata) { [weak self] _, error in
            guard let self = self else { return }

            if let error = error {
                if self.shouldRetryUpload(error: error) && attempt < self.maxUploadAttempts {
                    self.scheduleRetry(after: self.retryDelay(for: attempt)) {
                        self.performFileUpload(
                            fileURL: fileURL,
                            bookRef: bookRef,
                            metadata: metadata,
                            fileName: fileName,
                            attempt: attempt + 1,
                            completion: completion
                        )
                    }
                    return
                }

                if self.isPermissionError(error) {
                    self.finishOnMain(.failure(UploadError.permissionDenied), completion: completion)
                    return
                }

                self.finishOnMain(.failure(self.mapUploadError(error)), completion: completion)
                return
            }

            self.fetchDownloadURL(bookRef: bookRef, fileName: fileName, attempt: 1, completion: completion)
        }

        fileTask.observe(.progress) { snapshot in
            _ = snapshot.progress
        }
    }

    private func fetchDownloadURL(
        bookRef: StorageReference,
        fileName: String,
        attempt: Int,
        completion: @escaping (Result<(url: String, fileName: String), Error>) -> Void
    ) {
        bookRef.downloadURL { [weak self] url, error in
            guard let self = self else { return }

            if let error = error {
                if self.shouldRetryUpload(error: error) && attempt < self.maxUploadAttempts {
                    self.scheduleRetry(after: self.retryDelay(for: attempt)) {
                        self.fetchDownloadURL(
                            bookRef: bookRef,
                            fileName: fileName,
                            attempt: attempt + 1,
                            completion: completion
                        )
                    }
                    return
                }

                self.finishOnMain(.failure(self.mapUploadError(error)), completion: completion)
                return
            }

            guard let downloadURL = url else {
                self.finishOnMain(.failure(UploadError.noDownloadURL), completion: completion)
                return
            }

            self.finishOnMain(.success((url: downloadURL.absoluteString, fileName: fileName)), completion: completion)
        }
    }

    private func finishOnMain(
        _ result: Result<(url: String, fileName: String), Error>,
        completion: @escaping (Result<(url: String, fileName: String), Error>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func retryDelay(for attempt: Int) -> TimeInterval {
        return pow(2, Double(max(0, attempt - 1)))
    }

    private func scheduleRetry(after delay: TimeInterval, execute: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
            execute()
        }
    }

    private func shouldFallbackToFile(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain &&
            (nsError.code == NSURLErrorCannotParseResponse || nsError.code == NSURLErrorNetworkConnectionLost)
    }

    private func shouldRetryUpload(error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            let retryableCodes: Set<Int> = [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorResourceUnavailable,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorInternationalRoamingOff,
                NSURLErrorCallIsActive,
                NSURLErrorDataNotAllowed,
                NSURLErrorRequestBodyStreamExhausted,
                NSURLErrorCannotParseResponse
            ]
            return retryableCodes.contains(nsError.code)
        }

        if nsError.domain == StorageErrorDomain,
           let storageError = StorageErrorCode(rawValue: nsError.code) {
            switch storageError {
            case .unknown, .retryLimitExceeded, .nonMatchingChecksum:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.code == 403 { return true }

        if nsError.domain == StorageErrorDomain,
           let storageError = StorageErrorCode(rawValue: nsError.code) {
            return storageError == .unauthorized
        }

        return false
    }

    private func mapUploadError(_ error: Error) -> Error {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            return UploadError.networkError(nsError.localizedDescription)
        }

        if nsError.domain == StorageErrorDomain,
           let storageError = StorageErrorCode(rawValue: nsError.code) {
            switch storageError {
            case .objectNotFound:
                return UploadError.networkError("Uploaded object was not found")
            case .bucketNotFound:
                return UploadError.networkError("Storage bucket not found")
            case .projectNotFound:
                return UploadError.networkError("Firebase project not found")
            case .quotaExceeded:
                return UploadError.networkError("Storage quota exceeded")
            case .retryLimitExceeded:
                return UploadError.networkError("Upload retry limit exceeded")
            case .nonMatchingChecksum:
                return UploadError.networkError("Upload checksum mismatch")
            case .unauthenticated:
                return UploadError.networkError("User is not authenticated")
            case .unauthorized:
                return UploadError.permissionDenied
            case .downloadSizeExceeded:
                return UploadError.networkError("Download size exceeded")
            case .cancelled:
                return UploadError.networkError("Upload was cancelled")
            default:
                return error
            }
        }

        return error
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
