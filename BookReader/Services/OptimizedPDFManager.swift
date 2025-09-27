//
//  OptimizedPDFManager.swift
//  BookReader
//
//  High-performance PDF management with lazy loading and memory optimization
//

import Foundation
import PDFKit
import UIKit

class OptimizedPDFManager: NSObject {
    
    // MARK: - Properties
    private weak var pdfView: PDFView?
    private var document: PDFDocument?
    private let maxCachedPages = 10
    private var pageCache: [Int: PDFPage] = [:]
    private var thumbnailCache: [Int: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "pdf.cache", qos: .utility)
    
    // Memory management
    private var lastAccessedPages: [Int] = []
    private let memoryPressureThreshold = 50 * 1024 * 1024 // 50MB
    
    // Performance tracking
    private var isLargeDocument: Bool = false
    private var documentSize: Int64 = 0
    
    // MARK: - Initialization
    
    init(pdfView: PDFView) {
        self.pdfView = pdfView
        super.init()
        setupMemoryWarningObserver()
    }
    
    deinit {
        // Synchronously clear cache to avoid crashes
        pageCache.removeAll()
        thumbnailCache.removeAll()
        lastAccessedPages.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    func loadDocument(from url: URL, completion: @escaping (Result<PDFDocument, Error>) -> Void) {
        cacheQueue.async { [weak self] in
            do {
                // Check document size first
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                DispatchQueue.main.async {
                    self?.documentSize = fileSize
                    self?.isLargeDocument = fileSize > 10 * 1024 * 1024 // 10MB threshold
                    
                    if self?.isLargeDocument == true {
                        self?.loadLargeDocument(from: url, completion: completion)
                    } else {
                        self?.loadStandardDocument(from: url, completion: completion)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func preloadPages(around currentPage: Int, radius: Int = 2) {
        guard let document = document else { return }
        
        let startPage = max(0, currentPage - radius)
        let endPage = min(document.pageCount - 1, currentPage + radius)
        
        cacheQueue.async { [weak self] in
            for pageIndex in startPage...endPage {
                self?.cachePageIfNeeded(at: pageIndex)
            }
        }
    }
    
    func generateThumbnail(for pageIndex: Int, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        cacheQueue.async { [weak self] in
            // Check cache first
            if let cachedThumbnail = self?.thumbnailCache[pageIndex] {
                DispatchQueue.main.async {
                    completion(cachedThumbnail)
                }
                return
            }
            
            // Generate new thumbnail
            guard let document = self?.document,
                  pageIndex < document.pageCount,
                  let page = document.page(at: pageIndex) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let thumbnail = page.thumbnail(of: size, for: .mediaBox)
            
            // Cache if not too large
            if self?.thumbnailCache.count ?? 0 < self?.maxCachedPages ?? 0 {
                self?.thumbnailCache[pageIndex] = thumbnail
            }
            
            DispatchQueue.main.async {
                completion(thumbnail)
            }
        }
    }
    
    func clearCache() {
        cacheQueue.sync {
            pageCache.removeAll()
            thumbnailCache.removeAll()
            lastAccessedPages.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadStandardDocument(from url: URL, completion: @escaping (Result<PDFDocument, Error>) -> Void) {
        cacheQueue.async { [weak self] in
            guard let document = PDFDocument(url: url) else {
                DispatchQueue.main.async {
                    completion(.failure(PDFError.loadFailed))
                }
                return
            }
            
            self?.document = document
            self?.configurePDFViewForStandardDocument()
            
            DispatchQueue.main.async {
                completion(.success(document))
            }
        }
    }
    
    private func loadLargeDocument(from url: URL, completion: @escaping (Result<PDFDocument, Error>) -> Void) {
        cacheQueue.async { [weak self] in
            guard let document = PDFDocument(url: url) else {
                DispatchQueue.main.async {
                    completion(.failure(PDFError.loadFailed))
                }
                return
            }
            
            self?.document = document
            self?.configurePDFViewForLargeDocument()
            
            // For large documents, only keep first few pages in memory initially
            self?.preloadInitialPages()
            
            DispatchQueue.main.async {
                completion(.success(document))
            }
        }
    }
    
    private func configurePDFViewForStandardDocument() {
        DispatchQueue.main.async { [weak self] in
            guard let pdfView = self?.pdfView else { return }
            
            // Standard quality settings
            pdfView.interpolationQuality = .high
            pdfView.displayMode = .singlePageContinuous
            pdfView.autoScales = true
        }
    }
    
    private func configurePDFViewForLargeDocument() {
        DispatchQueue.main.async { [weak self] in
            guard let pdfView = self?.pdfView else { return }
            
            // Optimized settings for large documents
            pdfView.interpolationQuality = .low // Better performance for large docs
            pdfView.displayMode = .singlePage // Reduce memory usage
            pdfView.autoScales = true
        }
    }
    
    private func preloadInitialPages() {
        guard let document = document else { return }
        
        let pagesToPreload = min(5, document.pageCount)
        
        cacheQueue.async { [weak self] in
            for i in 0..<pagesToPreload {
                self?.cachePageIfNeeded(at: i)
            }
        }
    }
    
    private func cachePageIfNeeded(at index: Int) {
        guard pageCache[index] == nil,
              let document = document,
              index < document.pageCount else { return }
        
        let page = document.page(at: index)
        pageCache[index] = page
        
        // Update access tracking
        if let pageIndex = lastAccessedPages.firstIndex(of: index) {
            lastAccessedPages.remove(at: pageIndex)
        }
        lastAccessedPages.append(index)
        
        // Manage memory
        managePageCacheMemory()
    }
    
    private func managePageCacheMemory() {
        // Remove oldest pages if cache is too large
        while pageCache.count > maxCachedPages && !lastAccessedPages.isEmpty {
            let oldestPage = lastAccessedPages.removeFirst()
            pageCache.removeValue(forKey: oldestPage)
            thumbnailCache.removeValue(forKey: oldestPage)
        }
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        clearCache()
        
        // Force garbage collection by nil'ing the document temporarily
        if isLargeDocument {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                // Re-cache only current page
                if let pdfView = self?.pdfView,
                   let currentPage = pdfView.currentPage,
                   let document = self?.document {
                    let pageIndex = document.index(for: currentPage)
                    self?.preloadPages(around: pageIndex, radius: 1)
                }
            }
        }
    }
}

// MARK: - PDFError

enum PDFError: Error {
    case loadFailed
    case memoryExhausted
    case invalidDocument
}

extension PDFError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Failed to load PDF document"
        case .memoryExhausted:
            return "Not enough memory to load PDF"
        case .invalidDocument:
            return "Invalid PDF document"
        }
    }
}