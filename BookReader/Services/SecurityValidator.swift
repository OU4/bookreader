//
//  SecurityValidator.swift
//  BookReader
//
//  Security validation for file uploads and operations
//

import Foundation
import UIKit

enum SecurityError: LocalizedError {
    case invalidFileName
    case invalidFileExtension
    case fileSizeTooLarge
    case pathTraversalAttempt
    case invalidFileContent
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidFileName:
            return "The file name contains invalid characters"
        case .invalidFileExtension:
            return "This file type is not supported"
        case .fileSizeTooLarge:
            return "The file size exceeds the maximum allowed limit"
        case .pathTraversalAttempt:
            return "Invalid file path detected"
        case .invalidFileContent:
            return "The file content is invalid or corrupted"
        case .rateLimitExceeded:
            return "Too many requests. Please try again later"
        }
    }
}

class SecurityValidator {
    
    // MARK: - Constants
    static let maxFileSize: Int64 = 100 * 1024 * 1024 // 100 MB
    static let allowedExtensions = ["pdf", "txt", "epub"]
    static let maxFileNameLength = 255
    
    // Rate limiting
    private static var uploadTimestamps: [Date] = []
    private static let maxUploadsPerMinute = 10
    private static let rateLimitWindow: TimeInterval = 60 // 1 minute
    
    // MARK: - File Validation
    
    static func validateFileUpload(at url: URL) -> Result<Void, SecurityError> {
        // Check file extension
        let fileExtension = url.pathExtension.lowercased()
        guard allowedExtensions.contains(fileExtension) else {
            return .failure(.invalidFileExtension)
        }
        
        // Check file size
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
                if fileSize > maxFileSize {
                    return .failure(.fileSizeTooLarge)
                }
            }
        } catch {
            return .failure(.invalidFileContent)
        }
        
        // Validate file name
        let fileName = url.lastPathComponent
        if let validationError = validateFileName(fileName) {
            return .failure(validationError)
        }
        
        // Check rate limiting
        if isRateLimited() {
            return .failure(.rateLimitExceeded)
        }
        
        // Record upload timestamp
        recordUpload()
        
        return .success(())
    }
    
    static func validateFileName(_ fileName: String) -> SecurityError? {
        // Check length
        if fileName.count > maxFileNameLength {
            return .invalidFileName
        }
        
        // Check for path traversal attempts (only check for actual path traversal patterns)
        let pathTraversalPatterns = ["../", "~/../", "\\..\\"]
        for pattern in pathTraversalPatterns {
            if fileName.contains(pattern) {
                return .pathTraversalAttempt
            }
        }
        
        // Check for hidden files
        if fileName.hasPrefix(".") {
            return .invalidFileName
        }
        
        // Check for dangerous characters only (not restrictive on normal filename characters)
        let dangerousCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|\0")
        if fileName.rangeOfCharacter(from: dangerousCharacters) != nil {
            return .invalidFileName
        }
        
        return nil
    }
    
    static func sanitizeFileName(_ fileName: String) -> String {
        // Remove file extension
        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        let fileExtension = (fileName as NSString).pathExtension
        
        // Replace invalid characters with underscores
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var sanitized = nameWithoutExtension.components(separatedBy: invalidCharacters).joined(separator: "_")
        
        // Remove leading/trailing whitespace and dots
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        
        // Limit length
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
        }
        
        // If empty, use default name
        if sanitized.isEmpty {
            sanitized = "Untitled"
        }
        
        // Add back extension if valid
        if !fileExtension.isEmpty && allowedExtensions.contains(fileExtension.lowercased()) {
            sanitized += ".\(fileExtension)"
        }
        
        return sanitized
    }
    
    // MARK: - Authentication Validation
    
    static func requireAuthentication() -> Bool {
        return FirebaseManager.shared.isAuthenticated
    }
    
    static func validateUserPermission(for operation: String) -> Bool {
        guard requireAuthentication() else { return false }
        
        // Add specific permission checks here if needed
        // For now, authenticated users can perform all operations
        return true
    }
    
    // MARK: - Rate Limiting
    
    private static func isRateLimited() -> Bool {
        let now = Date()
        let recentTimestamps = uploadTimestamps.filter { now.timeIntervalSince($0) < rateLimitWindow }
        uploadTimestamps = recentTimestamps
        
        return recentTimestamps.count >= maxUploadsPerMinute
    }
    
    private static func recordUpload() {
        uploadTimestamps.append(Date())
    }
    
    // MARK: - File Content Validation
    
    static func validatePDFContent(at url: URL) -> Bool {
        // Check PDF header
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { fileHandle.closeFile() }
        
        let headerData = fileHandle.readData(ofLength: 5)
        let headerString = String(data: headerData, encoding: .ascii)
        
        return headerString == "%PDF-"
    }
    
    static func validateTextContent(at url: URL) -> Bool {
        // Try to read as UTF-8 text
        do {
            let _ = try String(contentsOf: url, encoding: .utf8)
            return true
        } catch {
            // Try other encodings
            if let _ = try? String(contentsOf: url, encoding: .utf16) {
                return true
            }
            if let _ = try? String(contentsOf: url, encoding: .ascii) {
                return true
            }
            return false
        }
    }
}