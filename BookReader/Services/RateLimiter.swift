//
//  RateLimiter.swift
//  BookReader
//
//  Rate limiting for Firebase operations
//

import Foundation

class RateLimiter {
    
    // MARK: - Singleton
    static let shared = RateLimiter()
    
    // MARK: - Properties
    private var operationTimestamps: [String: [Date]] = [:] // Operation type -> timestamps
    private let queue = DispatchQueue(label: "com.bookreader.ratelimiter", attributes: .concurrent)
    
    // MARK: - Configuration
    struct Limits {
        static let bookUpload = RateLimit(maxRequests: 5, perTimeInterval: 60) // 5 uploads per minute
        static let bookUpdate = RateLimit(maxRequests: 20, perTimeInterval: 60) // 20 updates per minute
        static let highlightOperation = RateLimit(maxRequests: 30, perTimeInterval: 60) // 30 highlight ops per minute
        static let generalFirebase = RateLimit(maxRequests: 100, perTimeInterval: 60) // 100 general ops per minute
    }
    
    struct RateLimit {
        let maxRequests: Int
        let perTimeInterval: TimeInterval
    }
    
    // MARK: - Public Methods
    
    func checkLimit(for operation: OperationType) -> Bool {
        return queue.sync(flags: .barrier) {
            let limit = getRateLimit(for: operation)
            let key = operation.rawValue
            let now = Date()
            
            // Clean old timestamps
            var timestamps = operationTimestamps[key] ?? []
            timestamps = timestamps.filter { now.timeIntervalSince($0) < limit.perTimeInterval }
            
            // Check if limit exceeded
            if timestamps.count >= limit.maxRequests {
                return false
            }
            
            // Record new operation
            timestamps.append(now)
            operationTimestamps[key] = timestamps
            
            return true
        }
    }
    
    func recordOperation(_ operation: OperationType) {
        queue.async(flags: .barrier) {
            let key = operation.rawValue
            var timestamps = self.operationTimestamps[key] ?? []
            timestamps.append(Date())
            self.operationTimestamps[key] = timestamps
        }
    }
    
    func getRemainingRequests(for operation: OperationType) -> Int {
        return queue.sync {
            let limit = getRateLimit(for: operation)
            let key = operation.rawValue
            let now = Date()
            
            let timestamps = (operationTimestamps[key] ?? [])
                .filter { now.timeIntervalSince($0) < limit.perTimeInterval }
            
            return max(0, limit.maxRequests - timestamps.count)
        }
    }
    
    func getResetTime(for operation: OperationType) -> Date? {
        return queue.sync {
            let limit = getRateLimit(for: operation)
            let key = operation.rawValue
            
            guard let oldestTimestamp = operationTimestamps[key]?.first else {
                return nil
            }
            
            return oldestTimestamp.addingTimeInterval(limit.perTimeInterval)
        }
    }
    
    // MARK: - Private Methods
    
    private func getRateLimit(for operation: OperationType) -> RateLimit {
        switch operation {
        case .uploadBook:
            return Limits.bookUpload
        case .updateBook:
            return Limits.bookUpdate
        case .addHighlight, .updateHighlight, .removeHighlight:
            return Limits.highlightOperation
        case .general:
            return Limits.generalFirebase
        }
    }
    
    // MARK: - Operation Types
    
    enum OperationType: String {
        case uploadBook = "upload_book"
        case updateBook = "update_book"
        case addHighlight = "add_highlight"
        case updateHighlight = "update_highlight"
        case removeHighlight = "remove_highlight"
        case general = "general_firebase"
    }
}