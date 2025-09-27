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
    
    func downloadFile(
        from url: String,
        to localURL: URL,
        maxRetries: Int = 3,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        downloadWithRetry(
            from: url,
            to: localURL,
            currentAttempt: 1,
            maxRetries: maxRetries,
            completion: completion
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
            completion(.failure(DownloadError.invalidURL))
            return
        }
        
        // Create directory if needed
        let directory = localURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Use URLSession for more control over the download
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0 // 30 second timeout
        config.timeoutIntervalForResource = 300.0 // 5 minute timeout
        let session = URLSession(configuration: config)
        
        let task = session.downloadTask(with: storageURL) { [weak self] tempURL, response, error in
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
                    // Max retries reached or non-retryable error
                    completion(.failure(error))
                }
                return
            }
            
            guard let tempURL = tempURL else {
                completion(.failure(DownloadError.noTempFile))
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
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            let percentage = Int(progress.fractionCompleted * 100)
            if percentage % 25 == 0 { // Log every 25%
            }
        }
        
        task.resume()
        
        // Clean up observation when task completes
        DispatchQueue.global().asyncAfter(deadline: .now() + 300) {
            observation.invalidate()
        }
    }
    
    private func shouldRetryError(_ error: NSError) -> Bool {
        switch error.code {
        case -1017: // Cannot parse response
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
}

enum DownloadError: LocalizedError {
    case invalidURL
    case noTempFile
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .noTempFile:
            return "No temporary file received"
        case .maxRetriesExceeded:
            return "Download failed after multiple attempts"
        }
    }
}