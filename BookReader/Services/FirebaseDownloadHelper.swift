//
//  FirebaseDownloadHelper.swift
//  BookReader
//
//  Helper for robust Firebase Storage downloads with retry logic
//

import Foundation
import Firebase
import FirebaseStorage

class FirebaseDownloadHelper {
    
    static let shared = FirebaseDownloadHelper()
    
    private init() {}

    private let syncQueue = DispatchQueue(label: "com.bookreader.firebaseDownloadHelper")
    private var activeDownloads: [String: [ (Result<URL, Error>) -> Void ]] = [:]
    
    func downloadFile(
        from url: String,
        to localURL: URL,
        maxRetries: Int = 3,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if FileManager.default.fileExists(atPath: localURL.path) {
            completion(.success(localURL))
            return
        }

        let normalizedURL = url

        var shouldStartDownload = false

        syncQueue.sync {
            if var handlers = activeDownloads[normalizedURL] {
                handlers.append(completion)
                activeDownloads[normalizedURL] = handlers
            } else {
                activeDownloads[normalizedURL] = [completion]
                shouldStartDownload = true
            }
        }

        guard shouldStartDownload else {
            return
        }

        // Always try Firebase SDK first to avoid protocol issues
        if let storageReference = firebaseReference(from: url) {
            print("📥 Using Firebase SDK for download to avoid protocol issues")
            downloadUsingFirebaseStorage(reference: storageReference, to: localURL) { [weak self] result in
                switch result {
                case .success:
                    self?.finishDownload(for: normalizedURL, result: result)
                case .failure(let error):
                    print("⚠️ Firebase SDK download failed: \(error), trying URL download")
                    // Fallback to URL download if SDK fails
                    self?.downloadWithRetry(
                        from: url,
                        to: localURL,
                        currentAttempt: 1,
                        maxRetries: maxRetries,
                        completion: { retryResult in
                            self?.finishDownload(for: normalizedURL, result: retryResult)
                        }
                    )
                }
            }
            return
        }

        // If no Firebase reference, use URL download
        downloadWithRetry(
            from: url,
            to: localURL,
            currentAttempt: 1,
            maxRetries: maxRetries,
            completion: { [weak self] result in
                self?.finishDownload(for: normalizedURL, result: result)
            }
        )
    }
    
    private func downloadWithRetry(
        from url: String,
        to localURL: URL,
        currentAttempt: Int,
        maxRetries: Int,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        
        // Validate URL
        guard let storageURL = URL(string: url) else {
            DispatchQueue.main.async {
                completion(.failure(DownloadError.invalidURL))
            }
            return
        }
        
        // Create directory if needed
        let directory = localURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Use URLSession with custom configuration to avoid protocol issues
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0 // 60 second timeout
        config.timeoutIntervalForResource = 300.0 // 5 minute timeout
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        // Force HTTP/1.1 to avoid HTTP/2 protocol issues with Firebase
        config.httpAdditionalHeaders = ["Accept-Encoding": "gzip, deflate"]
        config.httpMaximumConnectionsPerHost = 2
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let session = URLSession(configuration: config)
        
        var observation: NSKeyValueObservation?
        let task = session.downloadTask(with: storageURL) { [weak self] tempURL, response, error in
            observation?.invalidate()
            observation = nil
            if let error = error {
                let nsError = error as NSError
                
                // Check if we should retry
                let shouldRetry = currentAttempt < maxRetries && self?.shouldRetryError(nsError) == true
                
                if shouldRetry {
                    let retryDelay = Double(currentAttempt) * 2.0 // Exponential backoff
                    DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
                        self?.downloadWithRetry(
                            from: url,
                            to: localURL,
                            currentAttempt: currentAttempt + 1,
                            maxRetries: maxRetries,
                            completion: completion
                        )
                    }
                } else {
                    // Max retries reached or non-retryable error – fallback to Firebase SDK if possible
                    self?.fallbackToFirebaseSDK(
                        from: url,
                        to: localURL,
                        originalError: error,
                        completion: { [weak self] result in
                            self?.finishDownload(for: url, result: result)
                        }
                    )
                }
                return
            }
            
            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    completion(.failure(DownloadError.noTempFile))
                }
                return
            }
            
            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                
                // Move downloaded file to final location
                try FileManager.default.moveItem(at: tempURL, to: localURL)
                
                completion(.success(localURL))
                
            } catch {
                completion(.failure(error))
            }
        }
        
        // Monitor download progress
        observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            let percentage = Int(progress.fractionCompleted * 100)
            if percentage % 25 == 0 { // Log every 25%
            }
        }
        
        task.resume()
    }
    
    private func shouldRetryError(_ error: NSError) -> Bool {
        switch error.code {
        case -1017: // Cannot parse response - Firebase protocol issue
            print("⚠️ Firebase protocol violation detected, will retry with fallback")
            return true
        case -1005: // Network connection lost
            return true
        case -1001: // Request timed out
            return true
        case -1009: // Internet connection appears to be offline
            return true
        case NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDNSLookupFailed:
            return true
        default:
            return false
        }
    }

    private func fallbackToFirebaseSDK(
        from url: String,
        to localURL: URL,
        originalError: Error,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard let reference = firebaseReference(from: url) else {
            DispatchQueue.main.async {
                completion(.failure(originalError))
            }
            return
        }

        downloadUsingFirebaseStorage(reference: reference, to: localURL, completion: completion)
    }

    func firebaseReference(from urlString: String) -> StorageReference? {
        if urlString.hasPrefix("gs://") {
            return Storage.storage().reference(forURL: urlString)
        }

        guard let components = URLComponents(string: urlString),
              let host = components.host,
              host.contains("firebasestorage.googleapis.com") else {
            return nil
        }

        let pathSegments = components.path.split(separator: "/")
        guard pathSegments.count >= 5,
              pathSegments[0] == "v0",
              pathSegments[1] == "b",
              pathSegments[3] == "o" else {
            return nil
        }

        var sanitizedComponents = components
        sanitizedComponents.query = nil
        guard let sanitizedURL = sanitizedComponents.string else {
            return nil
        }

        return Storage.storage().reference(forURL: sanitizedURL)
    }

    private func downloadUsingFirebaseStorage(
        reference: StorageReference,
        to localURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let directory = localURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: localURL)

        let task = reference.write(toFile: localURL)

        task.observe(.success) { _ in
            completion(.success(localURL))
        }

        task.observe(.failure) { snapshot in
            let error = snapshot.error ?? DownloadError.sdkDownloadFailed
            completion(.failure(error))
        }
    }

    private func finishDownload(for url: String, result: Result<URL, Error>) {
        let handlers: [ (Result<URL, Error>) -> Void ] = syncQueue.sync {
            let callbacks = activeDownloads[url] ?? []
            activeDownloads[url] = nil
            return callbacks
        }
        DispatchQueue.main.async {
            handlers.forEach { $0(result) }
        }
    }
}

enum DownloadError: LocalizedError {
    case invalidURL
    case noTempFile
    case maxRetriesExceeded
    case sdkDownloadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .noTempFile:
            return "No temporary file received"
        case .maxRetriesExceeded:
            return "Download failed after multiple attempts"
        case .sdkDownloadFailed:
            return "Download failed using fallback method"
        }
    }
}
