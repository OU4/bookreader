//
//  ModernBookReaderViewController.swift
//  BookReader
//
//  Beautiful, modern book reader interface
//

import UIKit
import PDFKit
import AVFoundation

class ModernBookReaderViewController: UIViewController {
    
    // MARK: - Properties
    private var currentBook: Book?
    private var extractedText: String = ""
    private var currentTheme: ReadingTheme = .light
    private var isToolbarVisible = true
    
    // Reading session tracking
    private var sessionStartTime: Date?
    private var sessionTimer: Timer?
    private var currentSessionDuration: TimeInterval = 0
    
    // Position tracking
    private var lastSavedPosition: Float = 0
    private var positionSaveTimer: Timer?
    
    // MARK: - Beautiful UI Components
    private lazy var gradientBackground: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.systemBackground.cgColor,
            UIColor.systemGray6.cgColor
        ]
        gradient.locations = [0.0, 1.0]
        return gradient
    }()
    
    private lazy var textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.backgroundColor = .clear
        tv.font = UIFont(name: "Charter", size: 18) ?? UIFont.systemFont(ofSize: 18)
        tv.textColor = .label
        tv.textAlignment = .justified
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.showsVerticalScrollIndicator = false
        tv.showsHorizontalScrollIndicator = false
        tv.contentInsetAdjustmentBehavior = .never
        tv.textContainerInset = UIEdgeInsets(top: 40, left: 32, bottom: 120, right: 32)
        tv.textContainer.lineFragmentPadding = 0
        tv.isSelectable = true
        tv.delegate = self
        return tv
    }()
    
    private lazy var floatingToolbar: ModernFloatingToolbar = {
        let toolbar = ModernFloatingToolbar()
        toolbar.delegate = self
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        return toolbar
    }()
    
    private lazy var readingProgressView: ReadingProgressView = {
        let view = ReadingProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var navigationHeader: ModernNavigationHeader = {
        let header = ModernNavigationHeader()
        header.delegate = self
        header.translatesAutoresizingMaskIntoConstraints = false
        return header
    }()
    
    private lazy var settingsPanel: ModernSettingsPanel = {
        let panel = ModernSettingsPanel()
        panel.delegate = self
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.alpha = 0
        return panel
    }()
    
    // Reading timer widget
    private var readingTimerWidget: ReadingTimerWidget?
    
    // Constraints for animations
    private var toolbarBottomConstraint: NSLayoutConstraint!
    private var headerTopConstraint: NSLayoutConstraint!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupModernUI()
        setupGestures()
        loadTheme()
        showWelcomeAnimation()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientBackground.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Don't start session here - wait for content to load
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start reading session only when view is visible and has content
        if currentBook != nil && (!textView.isHidden || (pdfView?.isHidden == false)) {
            startReadingSession()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Save position and end reading session
        saveCurrentPosition()
        endReadingSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Make sure session is ended
        if sessionTimer != nil {
            endReadingSession()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return !isToolbarVisible
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    // MARK: - Cleanup
    deinit {
        // Clean up reading timer widget
        hideReadingTimerWidget()
        
        // Clean up timers in proper order to prevent memory leaks
        if let timer = sessionTimer {
            timer.invalidate()
            sessionTimer = nil
        }
        
        if let timer = positionSaveTimer {
            timer.invalidate()
            positionSaveTimer = nil
        }
        
        // Clean up any animation timers
        view.layer.removeAllAnimations()
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        print("🗑️ ModernBookReaderViewController deinitialized")
    }
    
    // MARK: - Modern UI Setup
    private func setupModernUI() {
        view.backgroundColor = .systemBackground
        
        // Add gradient background
        view.layer.insertSublayer(gradientBackground, at: 0)
        
        // Add components
        view.addSubview(textView)
        view.addSubview(readingProgressView)
        view.addSubview(navigationHeader)
        view.addSubview(floatingToolbar)
        view.addSubview(settingsPanel)
        
        // Setup constraints
        setupConstraints()
        
        // Apply smooth animations
        applyInitialAnimations()
    }
    
    private func setupConstraints() {
        // Header
        headerTopConstraint = navigationHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        
        NSLayoutConstraint.activate([
            headerTopConstraint,
            navigationHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationHeader.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Text View
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Reading Progress
        NSLayoutConstraint.activate([
            readingProgressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            readingProgressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            readingProgressView.bottomAnchor.constraint(equalTo: floatingToolbar.topAnchor, constant: -16),
            readingProgressView.heightAnchor.constraint(equalToConstant: 4)
        ])
        
        // Floating Toolbar
        toolbarBottomConstraint = floatingToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            floatingToolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toolbarBottomConstraint,
            floatingToolbar.heightAnchor.constraint(equalToConstant: 60),
            floatingToolbar.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])
        
        // Settings Panel
        NSLayoutConstraint.activate([
            settingsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            settingsPanel.topAnchor.constraint(equalTo: navigationHeader.bottomAnchor, constant: 16),
            settingsPanel.widthAnchor.constraint(equalToConstant: 280),
            settingsPanel.heightAnchor.constraint(equalToConstant: 400)
        ])
    }
    
    private func applyInitialAnimations() {
        // Start with toolbar hidden
        toolbarBottomConstraint.constant = 100
        headerTopConstraint.constant = -80
        
        // Animate in
        UIView.animate(withDuration: 0.8, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.toolbarBottomConstraint.constant = -16
            self.headerTopConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }
    
    private func setupGestures() {
        // Tap gesture to toggle UI
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        // Pan gesture for page turning
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        view.addGestureRecognizer(panGesture)
        
        // Long press for text selection
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        textView.addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        
        // Don't toggle if tapping on toolbar or header
        if floatingToolbar.frame.contains(location) || navigationHeader.frame.contains(location) {
            return
        }
        
        // Don't interfere with PDF view gestures if PDF is showing
        if let pdfView = pdfView, !pdfView.isHidden, pdfView.frame.contains(location) {
            // Let PDF view handle its own gestures, just toggle UI
            toggleUI()
            return
        }
        
        toggleUI()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // Don't interfere with PDF view gestures if PDF is showing
        if let pdfView = pdfView, !pdfView.isHidden {
            return
        }
        
        // Add page turning animation for text view only
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .changed:
            // Add subtle parallax effect
            let progress = abs(translation.x) / view.bounds.width
            textView.transform = CGAffineTransform(translationX: translation.x * 0.1, y: 0)
            textView.alpha = 1 - (progress * 0.2)
            
        case .ended:
            // Animate back
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.textView.transform = .identity
                self.textView.alpha = 1
            }
            
        default:
            break
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: textView)
        
        if let textPosition = textView.closestPosition(to: location),
           let range = textView.tokenizer.rangeEnclosingPosition(textPosition, with: .word, inDirection: .layout(.left)) {
            
            let selectedText = textView.text(in: range) ?? ""
            showModernTextMenu(for: selectedText, at: location)
        }
    }
    
    // MARK: - UI Animations
    private func toggleUI() {
        isToolbarVisible.toggle()
        
        let targetConstantToolbar: CGFloat = isToolbarVisible ? -16 : 100
        let targetConstantHeader: CGFloat = isToolbarVisible ? 0 : -80
        let targetAlphaProgress: CGFloat = isToolbarVisible ? 1 : 0
        
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.toolbarBottomConstraint.constant = targetConstantToolbar
            self.headerTopConstraint.constant = targetConstantHeader
            self.readingProgressView.alpha = targetAlphaProgress
            self.view.layoutIfNeeded()
        }
        
        // Update status bar
        UIView.animate(withDuration: 0.3) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    private func showWelcomeAnimation() {
        // Only show welcome if no book is loaded
        guard currentBook == nil else { return }
        
        let welcomeText = """
        ✨ Welcome to Your Beautiful Book Reader
        
        🎨 Experience reading like never before with:
        • Stunning typography and themes
        • Smooth animations and gestures  
        • Intelligent text selection
        • Beautiful floating controls
        
        📚 Tap the library icon to add your first book
        🎛️ Tap anywhere to show/hide controls
        ✏️ Long press text for instant actions
        
        Happy Reading! 📖
        """
        
        displayTextWithAnimation(welcomeText)
    }
    
    private func displayTextWithAnimation(_ text: String) {
        textView.alpha = 0
        textView.text = text
        
        // Beautiful text appearance animation
        UIView.animate(withDuration: 1.0, delay: 0.5, options: [.curveEaseOut]) {
            self.textView.alpha = 1
        }
        
        // Animate text typing effect
        animateTextTyping(text)
    }
    
    private func animateTextTyping(_ fullText: String) {
        textView.text = ""
        
        var currentIndex = 0
        let characters = Array(fullText)
        
        // Ensure timer runs on main thread for UI updates
        let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                if currentIndex < characters.count {
                    self.textView.text += String(characters[currentIndex])
                    currentIndex += 1
                } else {
                    timer.invalidate()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func showModernTextMenu(for text: String, at location: CGPoint) {
        let menuVC = ModernTextMenuViewController(selectedText: text)
        menuVC.delegate = self
        menuVC.modalPresentationStyle = .popover
        
        if let popover = menuVC.popoverPresentationController {
            popover.sourceView = textView
            popover.sourceRect = CGRect(origin: location, size: CGSize(width: 1, height: 1))
            popover.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        }
        
        present(menuVC, animated: true)
    }
    
    // MARK: - Theme Management
    private func loadTheme() {
        applyTheme(currentTheme)
    }
    
    private func applyTheme(_ theme: ReadingTheme) {
        currentTheme = theme
        
        UIView.animate(withDuration: 0.5) {
            self.view.backgroundColor = theme.backgroundColor
            self.textView.textColor = theme.textColor
            
            // Update gradient
            self.gradientBackground.colors = [
                theme.backgroundColor.cgColor,
                theme.backgroundColor.withAlphaComponent(0.8).cgColor
            ]
        }
        
        // Update UI components
        navigationHeader.updateTheme(theme)
        floatingToolbar.updateTheme(theme)
        readingProgressView.updateTheme(theme)
    }
    
    // MARK: - Book Loading
    func loadBook(_ book: Book) {
        currentBook = book
        navigationHeader.setBookTitle(book.title, author: book.author)
        
        // Start reading session tracking
        ReadingSessionTracker.shared.startSession(for: book)
        
        // Load book content with beautiful animation
        loadBookContent(book)
        
        // Position restoration now happens inside loadPDFContent when PDF is fully loaded
    }
    
    private func loadBookContent(_ book: Book) {
        // Show loading animation
        showLoadingAnimation()
        
        // Load content based on book type
        switch book.type {
        case .pdf:
            loadPDFContent(from: book.filePath)
        case .text, .epub:
            loadTextContent(from: book.filePath)
        case .image:
            showImageNotSupported()
        }
    }
    
    private func showLoadingAnimation() {
        let loadingView = ModernLoadingView()
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingView)
        
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 100),
            loadingView.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        loadingView.startAnimating()
        
        // Remove after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            loadingView.stopAnimating()
            loadingView.removeFromSuperview()
        }
    }
    
    private func loadTextContent(from path: String) {
        print("📄 Loading text content from: \(path)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                
                DispatchQueue.main.async {
                    // Hide PDF view and show text view
                    self.pdfView?.isHidden = true
                    self.liveTextSelectionView.isHidden = true
                    self.liveTextSelectionView.isUserInteractionEnabled = false
                    self.textView.isHidden = false
                    
                    // Load content
                    self.displayTextWithAnimation(content)
                    self.extractedText = content
                    self.updateReadingProgress()
                    self.hideLoadingAnimation()
                    
                    // Restore reading position for text content
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.restoreLastPosition()
                    }
                    
                    print("✅ Text content loaded successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorMessage("Failed to load book content: \(error.localizedDescription)")
                    self.hideLoadingAnimation()
                }
            }
        }
    }
    
    private func loadPDFContent(from path: String) {
        print("📄 Loading PDF from: \(path)")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ PDF file not found at path: \(path)")
            showErrorMessage("File not found: \(path)")
            return
        }
        
        // Show loading animation
        showLoadingAnimation()
        
        // Load PDF on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: path)
            
            // Try to load PDF document
            guard let pdfDocument = PDFDocument(url: url) else {
                DispatchQueue.main.async {
                    print("❌ Failed to load PDF document")
                    self.showErrorMessage("Failed to load PDF document. The file may be corrupted or not a valid PDF.")
                    self.hideLoadingAnimation()
                }
                return
            }
            
            print("✅ PDF document loaded with \(pdfDocument.pageCount) pages")
            
            // Configure PDF on main thread
            DispatchQueue.main.async {
                // Hide text view and welcome content
                self.textView.isHidden = true
                self.textView.text = ""
                
                // Create PDF view if it doesn't exist
                if self.pdfView == nil {
                    self.setupPDFView()
                }
                
                // Configure PDF view step by step to avoid scale issues
                self.pdfView?.isHidden = false
                self.pdfView?.backgroundColor = .systemBackground
                
                // Set document first
                self.pdfView?.document = pdfDocument
                
                // Configure display settings for better navigation
                self.pdfView?.displayMode = .singlePageContinuous
                self.pdfView?.displayDirection = .vertical
                
                // Wait for view to layout properly, then configure scaling
                DispatchQueue.main.async {
                    self.configurePDFScalingSafely()
                }
                
                // Go to first page
                if let firstPage = pdfDocument.page(at: 0) {
                    self.pdfView?.go(to: firstPage)
                }
                
                // Setup LiveText selection for PDFs
                self.setupLiveTextForPDF()
                
                // Load existing highlights
                self.loadExistingHighlights()
                
                // Hide loading animation
                self.hideLoadingAnimation()
                
                // Update reading progress
                self.updateReadingProgress()
                
                // Restore last reading position now that PDF is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.restoreLastPosition()
                }
                
                print("✅ PDF view configured and displayed successfully")
            }
        }
    }
    
    private var pdfView: PDFView?
    
    // Live text selection overlay
    private lazy var liveTextSelectionView: LiveTextSelectionView = {
        let view = LiveTextSelectionView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private func setupPDFView() {
        let pdfV = PDFView()
        pdfV.translatesAutoresizingMaskIntoConstraints = false
        pdfV.backgroundColor = .systemBackground
        
        // Safe initial configuration for proper PDF navigation
        pdfV.displayMode = .singlePageContinuous
        pdfV.displayDirection = .vertical
        pdfV.autoScales = false // Start with manual scaling
        pdfV.interpolationQuality = .low // Use low for better performance
        
        // Enable page navigation
        pdfV.pageShadowsEnabled = true
        pdfV.pageBreakMargins = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        
        // Insert behind other UI elements but above background
        view.insertSubview(pdfV, belowSubview: navigationHeader)
        
        NSLayoutConstraint.activate([
            pdfV.topAnchor.constraint(equalTo: view.topAnchor),
            pdfV.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfV.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfV.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Set delegate for position tracking
        pdfV.delegate = self
        
        self.pdfView = pdfV
        
        // Temporarily disable LiveText overlay - it's blocking UI interactions
        // Will re-enable after fixing gesture handling
        liveTextSelectionView.isHidden = true
        liveTextSelectionView.isUserInteractionEnabled = false
        
        print("✅ PDF view and LiveText overlay setup completed")
    }
    
    private func configurePDFScalingSafely(retryCount: Int = 0) {
        guard let pdfView = self.pdfView,
              pdfView.bounds.width > 0,
              pdfView.bounds.height > 0,
              pdfView.document != nil else {
            // Retry after a short delay if view isn't ready (max 10 retries)
            if retryCount < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.configurePDFScalingSafely(retryCount: retryCount + 1)
                }
            } else {
                print("⚠️ Failed to configure PDF scaling after 10 retries")
            }
            return
        }
        
        // Configure scaling with safe values
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 4.0
        
        // Calculate appropriate scale to fit page
        if let currentPage = pdfView.currentPage {
            let pageRect = currentPage.bounds(for: .mediaBox)
            let viewRect = pdfView.bounds
            
            if pageRect.width > 0 && pageRect.height > 0 && viewRect.width > 0 && viewRect.height > 0 {
                // Calculate scale to fit
                let scaleX = viewRect.width / pageRect.width
                let scaleY = viewRect.height / pageRect.height
                let fitScale = min(scaleX, scaleY)
                
                // Set a safe initial scale
                let initialScale = min(max(fitScale, pdfView.minScaleFactor), pdfView.maxScaleFactor)
                pdfView.scaleFactor = initialScale
                
                print("✅ PDF scaling configured: \(initialScale), page: \(pageRect), view: \(viewRect)")
            }
        }
        
        // Enable auto-scaling after manual scale is set
        pdfView.autoScales = true
        
        // Force layout
        pdfView.layoutIfNeeded()
        
        print("✅ PDF scaling configured safely")
    }
    
    private func setupLiveTextForPDF() {
        // Temporarily disabled LiveText to fix UI blocking issues
        print("📝 LiveText temporarily disabled to fix UI interactions")
        return
        
        /*
        // Enable Live Text selection for PDFs, but keep it non-intrusive
        liveTextSelectionView.isHidden = false
        liveTextSelectionView.isUserInteractionEnabled = true
        
        // Delay LiveText attachment to avoid conflicts
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.liveTextSelectionView.attachToPDFView(self?.pdfView)
            print("✅ LiveText selection enabled for PDF")
        }
        */
    }
    
    private func loadExistingHighlights() {
        guard let book = currentBook,
              let pdfView = pdfView else { return }
        
        // Use professional highlight manager to load and apply highlights
        ReadingPositionManager.shared.applyHighlights(to: pdfView, bookId: book.id)
        
        // Force PDF view to refresh
        pdfView.layoutDocumentView()
    }
    
    private func hideLoadingAnimation() {
        // Hide loading animation
        DispatchQueue.main.async {
            // Find and remove any loading views
            for subview in self.view.subviews {
                if subview is ModernLoadingView {
                    (subview as? ModernLoadingView)?.stopAnimating()
                    subview.removeFromSuperview()
                }
            }
        }
    }
    
    private func showImageNotSupported() {
        let message = """
        📷 Image Support Coming Soon
        
        Beautiful image-based book reading with:
        • Live text recognition
        • Smooth page animations
        • Enhanced zoom controls
        
        For now, please use PDF or text formats.
        """
        
        displayTextWithAnimation(message)
    }
    
    private func updateReadingProgress() {
        // Calculate and update reading progress based on actual position
        var progress: Float = 0
        
        if !textView.isHidden {
            // For text view
            let contentHeight = textView.contentSize.height
            let offset = textView.contentOffset.y
            progress = Float(offset / max(contentHeight - textView.bounds.height, 1))
        } else if let pdfView = pdfView, !pdfView.isHidden {
            // For PDF view
            if let currentPage = pdfView.currentPage,
               let document = pdfView.document {
                let pageIndex = document.index(for: currentPage)
                let totalPages = document.pageCount
                progress = Float(pageIndex) / Float(max(totalPages - 1, 1))
            }
        }
        
        readingProgressView.setProgress(progress, animated: true)
    }
    
    private func showErrorMessage(_ message: String) {
        let alert = UIAlertController(title: "📚 Book Reader", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Gesture Recognizer Delegate
extension ModernBookReaderViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: view)
        
        // Don't interfere with navigation header
        if navigationHeader.frame.contains(location) {
            return false
        }
        
        // Don't interfere with floating toolbar
        if floatingToolbar.frame.contains(location) {
            return false
        }
        
        // Don't interfere with settings panel if visible
        if settingsPanel.alpha > 0 && settingsPanel.frame.contains(location) {
            return false
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow PDF view gestures to work simultaneously
        if let pdfView = pdfView, otherGestureRecognizer.view == pdfView {
            return true
        }
        return false
    }
}

// MARK: - Text View Delegate
extension ModernBookReaderViewController: UITextViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update reading progress based on scroll
        updateReadingProgress()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Save position when scrolling ends
        saveCurrentPosition()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // Save position when user stops dragging (if not decelerating)
        if !decelerate {
            saveCurrentPosition()
        }
    }
}

// MARK: - Delegates
extension ModernBookReaderViewController: ModernFloatingToolbarDelegate {
    func didTapLibrary() {
        // Check if we're in a navigation controller (pushed) or presented modally
        if let navController = navigationController {
            // We're in a navigation stack, pop back
            navController.popViewController(animated: true)
        } else {
            // We're presented modally, dismiss
            dismiss(animated: true)
        }
    }
    
    func didTapMore() {
        // Show action sheet with additional options
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Stats & Goals
        let statsAction = UIAlertAction(title: "Stats & Goals", style: .default) { [weak self] _ in
            self?.showStats()
        }
        statsAction.setValue(UIImage(systemName: "chart.bar.fill"), forKey: "image")
        actionSheet.addAction(statsAction)
        
        // Search
        let searchAction = UIAlertAction(title: "Search", style: .default) { [weak self] _ in
            self?.didTapSearch()
        }
        searchAction.setValue(UIImage(systemName: "magnifyingglass"), forKey: "image")
        actionSheet.addAction(searchAction)
        
        // Settings
        let settingsAction = UIAlertAction(title: "Reading Settings", style: .default) { [weak self] _ in
            self?.showSettings()
        }
        settingsAction.setValue(UIImage(systemName: "textformat.size"), forKey: "image")
        actionSheet.addAction(settingsAction)
        
        // Theme
        let themeAction = UIAlertAction(title: "Theme", style: .default) { [weak self] _ in
            self?.showThemeSelector()
        }
        themeAction.setValue(UIImage(systemName: "moon.fill"), forKey: "image")
        actionSheet.addAction(themeAction)
        
        // Cancel
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = floatingToolbar
            popover.sourceRect = floatingToolbar.bounds
        }
        
        present(actionSheet, animated: true)
    }
    
    private func showStats() {
        let statsVC = ReadingStatsViewController()
        statsVC.modalPresentationStyle = .pageSheet
        
        if let sheet = statsVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(statsVC, animated: true)
    }
    
    private func showSettings() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.settingsPanel.alpha = self.settingsPanel.alpha == 0 ? 1 : 0
        }
    }
    
    private func showThemeSelector() {
        let alert = UIAlertController(title: "Reading Theme", message: nil, preferredStyle: .actionSheet)
        
        for theme in ReadingTheme.allCases {
            alert.addAction(UIAlertAction(title: theme.displayName, style: .default) { [weak self] _ in
                self?.applyTheme(theme)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = floatingToolbar
            popover.sourceRect = floatingToolbar.bounds
        }
        
        present(alert, animated: true)
    }
    
    func didTapHighlight() {
        // Enable PDF text selection and highlighting
        guard let pdfView = pdfView, !pdfView.isHidden else {
            showAlert(title: "Highlighting", message: "Highlighting is only available for PDF files")
            return
        }
        
        // Check if there's already selected text
        if let currentSelection = pdfView.currentSelection, !(currentSelection.string?.isEmpty ?? true) {
            // There's already selected text, show color picker to highlight it
            showHighlightColorPickerForSelection(currentSelection)
        } else {
            // No selection, enter highlighting mode
            showHighlightColorPicker()
        }
        
        print("🖍️ Highlighting mode enabled - select text in PDF to highlight")
    }
    
    private func showHighlightColorPickerForSelection(_ selection: PDFSelection) {
        let alert = UIAlertController(title: "Highlight Selected Text", 
                                    message: "Choose a color to highlight:\n\"\(selection.string?.prefix(50) ?? "")...\"", 
                                    preferredStyle: .actionSheet)
        
        // Add color options
        let colors: [(String, UIColor)] = [
            ("Yellow", .systemYellow),
            ("Green", .systemGreen),
            ("Pink", .systemPink),
            ("Blue", .systemBlue),
            ("Orange", .systemOrange)
        ]
        
        for (name, color) in colors {
            let action = UIAlertAction(title: name, style: .default) { [weak self] _ in
                // Store color and highlight immediately
                objc_setAssociatedObject(self, &AssociatedKeys.highlightColor, color, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                self?.highlightSelection(selection)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.pdfView?.clearSelection()
        })
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = floatingToolbar
            popover.sourceRect = floatingToolbar.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showHighlightColorPicker() {
        let alert = UIAlertController(title: "Select Highlight Color", message: "Choose a color, then select text in the PDF to highlight", preferredStyle: .actionSheet)
        
        // Add color options
        let colors: [(String, UIColor)] = [
            ("Yellow", .systemYellow),
            ("Green", .systemGreen),
            ("Pink", .systemPink),
            ("Blue", .systemBlue),
            ("Orange", .systemOrange)
        ]
        
        for (name, color) in colors {
            let action = UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.enableHighlightingMode(color: color)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = floatingToolbar
            popover.sourceRect = floatingToolbar.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func enableHighlightingMode(color: UIColor) {
        guard let pdfView = pdfView else { return }
        
        // Store the highlight color
        objc_setAssociatedObject(self, &AssociatedKeys.highlightColor, color, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Enable text selection - this allows native PDF text selection
        pdfView.isUserInteractionEnabled = true
        
        // Clear any existing gesture recognizers to avoid conflicts
        for gesture in pdfView.gestureRecognizers ?? [] {
            if gesture is UILongPressGestureRecognizer && gesture.view == pdfView {
                pdfView.removeGestureRecognizer(gesture)
            }
        }
        
        // Add a simple tap gesture to check for selections
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePDFTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tapGesture)
        
        showAlert(title: "Highlighting Active", message: "Double-tap on text to select it, then use the highlight button again to apply the color.")
        
        // Set a flag to indicate highlighting mode is active
        objc_setAssociatedObject(self, &AssociatedKeys.highlightingMode, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    @objc private func handlePDFTap(_ gesture: UITapGestureRecognizer) {
        guard let pdfView = pdfView else { return }
        
        // Check if there's a current selection
        if let currentSelection = pdfView.currentSelection, !(currentSelection.string?.isEmpty ?? true) {
            // Show option to highlight the selected text
            let alert = UIAlertController(title: "Highlight Selected Text?", 
                                        message: "\"\(currentSelection.string?.prefix(50) ?? "")...\"", 
                                        preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Highlight", style: .default) { [weak self] _ in
                self?.highlightSelection(currentSelection)
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                self?.pdfView?.clearSelection()
            })
            
            present(alert, animated: true)
        }
    }
    
    @objc private func handlePDFLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let pdfView = pdfView,
              let page = pdfView.page(for: gesture.location(in: pdfView), nearest: true) else { return }
        
        let locationOnPage = pdfView.convert(gesture.location(in: pdfView), to: page)
        
        // Try to find text at this location
        if let selection = page.selection(for: CGRect(origin: locationOnPage, size: CGSize(width: 10, height: 10))) {
            pdfView.setCurrentSelection(selection, animate: true)
            
            // Show highlight menu
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showHighlightMenu(for: selection)
            }
        }
    }
    
    private func showHighlightMenu(for selection: PDFSelection) {
        let alert = UIAlertController(title: "Highlight Text", message: "Selected: \"\(selection.string?.prefix(50) ?? "")...\"", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Highlight", style: .default) { [weak self] _ in
            self?.highlightSelection(selection)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.pdfView?.clearSelection()
        })
        
        present(alert, animated: true)
    }
    
    private func highlightSelection(_ selection: PDFSelection) {
        guard let book = currentBook,
              let selectedText = selection.string,
              let color = objc_getAssociatedObject(self, &AssociatedKeys.highlightColor) as? UIColor,
              let pdfView = pdfView else { return }
        
        // Use professional highlight manager to save with exact coordinates
        if let pdfHighlight = ReadingPositionManager.shared.saveHighlight(for: book.id, selection: selection, color: color) {
            
            // Apply the highlight visually to the PDF
            ReadingPositionManager.shared.applyHighlights(to: pdfView, bookId: book.id)
            
            // Also save to legacy systems for compatibility
            if let page = selection.pages.first,
               let pageIndex = pdfView.document?.index(for: page) {
                
                // Create highlight object for BookStorage
                let highlightObj = Highlight(
                    text: selectedText,
                    color: colorToHighlightColor(color),
                    position: TextPosition(
                        startOffset: 0,
                        endOffset: selectedText.count,
                        chapter: nil,
                        pageNumber: pageIndex + 1
                    )
                )
                
                // Save to both legacy storage systems
                if var updatedBook = currentBook {
                    updatedBook.highlights.append(highlightObj)
                    BookStorage.shared.updateBook(updatedBook)
                    self.currentBook = updatedBook
                    
                    NotesManager.shared.addHighlight(
                        to: updatedBook.id,
                        text: selectedText,
                        color: colorToHighlightColor(color),
                        position: highlightObj.position
                    )
                }
            }
            
            print("🖍️ Created professional highlight with exact coordinates")
        }
        
        // Clear selection
        pdfView.clearSelection()
        
        // Show success message
        showAlert(title: "Highlighted", message: "Text has been highlighted successfully!")
    }
    
    private func colorToHighlightColor(_ color: UIColor) -> Highlight.HighlightColor {
        switch color {
        case .systemYellow: return .yellow
        case .systemGreen: return .green
        case .systemPink: return .pink
        case .systemBlue: return .blue
        case .systemOrange: return .orange
        default: return .yellow
        }
    }
    
    func didTapNotes() {
        // Show notes and highlights interface
        guard let book = currentBook else {
            showAlert(title: "Notes", message: "No book is currently loaded")
            return
        }
        
        let notesVC = NotesAndHighlightsViewController(bookId: book.id)
        notesVC.modalPresentationStyle = .pageSheet
        
        if let sheet = notesVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(notesVC, animated: true)
        print("📝 Notes and highlights interface opened")
    }
    
    private func didTapSearch() {
        // Show search interface
        guard let pdfView = pdfView, !pdfView.isHidden, pdfView.document != nil else {
            showAlert(title: "Search", message: "Search is only available for PDF files")
            return
        }
        
        let alert = UIAlertController(title: "Search PDF", message: "Enter text to search for:", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Search term..."
            textField.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: "Search", style: .default) { [weak self] _ in
            guard let searchText = alert.textFields?.first?.text, !searchText.isEmpty else { return }
            self?.searchInPDF(searchText)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func searchInPDF(_ searchText: String) {
        guard let pdfView = pdfView, let document = pdfView.document else { return }
        
        print("🔍 Searching for: \(searchText)")
        
        // Use PDFDocument's built-in search
        let selections = document.findString(searchText, withOptions: [])
        
        if !selections.isEmpty {
            // Go to the first match
            if let firstSelection = selections.first,
               let page = firstSelection.pages.first {
                pdfView.go(to: page)
                pdfView.setCurrentSelection(firstSelection, animate: true)
                
                showAlert(title: "Search Result", message: "Found \(selections.count) match(es). Use PDF gestures to navigate between results.")
            }
        } else {
            showAlert(title: "Search Complete", message: "No matches found for '\(searchText)'")
        }
    }
    
    private func didTapTextToSpeech() {
        // Toggle text-to-speech
        guard !extractedText.isEmpty || (pdfView?.isHidden == false) else {
            showAlert(title: "Text-to-Speech", message: "No text content available to read")
            return
        }
        
        if AVSpeechSynthesizer().isSpeaking {
            AVSpeechSynthesizer().stopSpeaking(at: .immediate)
            showAlert(title: "Text-to-Speech", message: "Speech stopped")
        } else {
            startTextToSpeech()
        }
    }
    
    private func startTextToSpeech() {
        let synthesizer = AVSpeechSynthesizer()
        var textToSpeak = ""
        
        if !textView.isHidden && !extractedText.isEmpty {
            // For text files
            textToSpeak = extractedText
        } else if let pdfView = pdfView, !pdfView.isHidden, let currentPage = pdfView.currentPage {
            // For PDF files - get text from current page
            textToSpeak = currentPage.string ?? ""
        }
        
        guard !textToSpeak.isEmpty else {
            showAlert(title: "Text-to-Speech", message: "No text content available to read")
            return
        }
        
        // Limit to first 1000 characters for demo
        if textToSpeak.count > 1000 {
            textToSpeak = String(textToSpeak.prefix(1000)) + "..."
        }
        
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        synthesizer.speak(utterance)
        showAlert(title: "Text-to-Speech", message: "Started reading...")
        
        print("🔊 Text-to-speech started")
    }
}

// MARK: - Associated Keys
private struct AssociatedKeys {
    static var highlightColor = "highlightColor"
    static var highlightingMode = "highlightingMode"
    static var highlights = "highlights"
}

// MARK: - Reading Session Management
extension ModernBookReaderViewController {
    
    private func startReadingSession() {
        guard currentBook != nil else { return }
        
        // Don't start if already running
        if sessionTimer?.isValid == true {
            return
        }
        
        // Start session timer
        sessionStartTime = Date()
        currentSessionDuration = 0
        
        // Show reading timer widget
        showReadingTimerWidget()
        
        // Update session duration every second
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionDuration()
        }
        
        // Start position save timer (save every 5 seconds)
        positionSaveTimer?.invalidate()
        positionSaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.saveCurrentPosition()
        }
        
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        print("📖 Started reading session for: \(currentBook?.title ?? "Unknown")")
    }
    
    @objc private func appDidEnterBackground() {
        // Pause reading session when app goes to background
        if sessionTimer != nil {
            saveCurrentPosition()
            endReadingSession()
        }
    }
    
    @objc private func appWillEnterForeground() {
        // Resume reading session when app comes back
        if currentBook != nil && view.window != nil {
            startReadingSession()
        }
    }
    
    private func endReadingSession() {
        guard let book = currentBook, let startTime = sessionStartTime else { return }
        
        // Hide reading timer widget
        hideReadingTimerWidget()
        
        // Calculate total session duration
        let sessionDuration = Date().timeIntervalSince(startTime)
        
        // Update book's reading stats
        if var updatedBook = currentBook {
            updatedBook.readingStats.totalReadingTime += sessionDuration
            updatedBook.readingStats.sessionsCount += 1
            updatedBook.readingStats.lastReadDate = Date()
            
            // Update reading streak
            if let lastRead = book.readingStats.lastReadDate {
                let calendar = Calendar.current
                let daysSinceLastRead = calendar.dateComponents([.day], from: lastRead, to: Date()).day ?? 0
                
                if daysSinceLastRead <= 1 {
                    updatedBook.readingStats.currentStreak += 1
                    updatedBook.readingStats.longestStreak = max(updatedBook.readingStats.currentStreak, updatedBook.readingStats.longestStreak)
                } else {
                    updatedBook.readingStats.currentStreak = 1
                }
            } else {
                updatedBook.readingStats.currentStreak = 1
                updatedBook.readingStats.longestStreak = 1
            }
            
            // Save updated book
            BookStorage.shared.updateBook(updatedBook)
            self.currentBook = updatedBook
        }
        
        // End the reading session in tracker
        ReadingSessionTracker.shared.endCurrentSession()
        
        // Stop timers
        sessionTimer?.invalidate()
        sessionTimer = nil
        positionSaveTimer?.invalidate()
        positionSaveTimer = nil
        
        print("📚 Ended reading session. Duration: \(Int(sessionDuration)) seconds")
    }
    
    private func updateSessionDuration() {
        guard let startTime = sessionStartTime else { return }
        currentSessionDuration = Date().timeIntervalSince(startTime)
        
        // Update UI if needed (you could show this in the navigation header)
        let minutes = Int(currentSessionDuration) / 60
        let seconds = Int(currentSessionDuration) % 60
        print("⏱️ Reading time: \(minutes):\(String(format: "%02d", seconds))")
        
        // Update timer widget if visible
        readingTimerWidget?.recordActivity()
    }
    
    // MARK: - Reading Timer Widget
    private func showReadingTimerWidget() {
        guard readingTimerWidget == nil else { return }
        
        let widget = ReadingTimerWidget()
        readingTimerWidget = widget
        
        view.addSubview(widget)
        view.bringSubviewToFront(widget)
        widget.translatesAutoresizingMaskIntoConstraints = false
        
        // Position widget in top-right corner
        NSLayoutConstraint.activate([
            widget.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            widget.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // Animate in
        widget.alpha = 0
        widget.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.4, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            widget.alpha = 1
            widget.transform = .identity
        }
        
        widget.startSession()
        print("📱 Modern reader timer widget shown")
    }
    
    private func hideReadingTimerWidget() {
        guard let widget = readingTimerWidget else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            widget.alpha = 0
            widget.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            widget.removeFromSuperview()
        }
        
        widget.endSession()
        readingTimerWidget = nil
        print("📱 Modern reader timer widget hidden")
    }
    
    private func saveCurrentPosition() {
        guard let book = currentBook else { return }
        
        // Use professional position manager
        if !textView.isHidden {
            ReadingPositionManager.shared.savePosition(for: book.id, textView: textView)
        } else if let pdfView = pdfView, !pdfView.isHidden {
            ReadingPositionManager.shared.savePosition(for: book.id, pdfView: pdfView)
        }
    }
    
    private func restoreLastPosition() {
        guard let book = currentBook else { return }
        
        // Use professional position manager
        if !textView.isHidden {
            ReadingPositionManager.shared.restorePosition(for: book.id, textView: textView)
        } else if let pdfView = pdfView, !pdfView.isHidden {
            ReadingPositionManager.shared.restorePosition(for: book.id, pdfView: pdfView)
        }
        
        // Update progress view based on saved position
        updateReadingProgress()
    }
}

extension ModernBookReaderViewController: ModernNavigationHeaderDelegate {
    func didTapBack() {
        // Check if we're in a navigation stack
        if let navController = navigationController, navController.viewControllers.count > 1 {
            print("🔙 Going back to library from modern reader...")
            navigationController?.popViewController(animated: true)
        } else {
            // Fallback to dismiss if presented modally
            dismiss(animated: true)
        }
    }
    
    func didTapBookmark() {
        // Add bookmark with animation
        guard let book = currentBook else { return }
        
        // Add bookmark logic here
        print("🔖 Adding bookmark for: \(book.title)")
    }
}

extension ModernBookReaderViewController: ModernSettingsPanelDelegate {
    func didChangeTheme(_ theme: ReadingTheme) {
        applyTheme(theme)
    }
    
    func didChangeFontSize(_ size: CGFloat) {
        UIView.animate(withDuration: 0.3) {
            self.textView.font = self.textView.font?.withSize(size)
        }
    }
}

extension ModernBookReaderViewController: ModernTextMenuDelegate {
    func didSelectHighlight(color: Highlight.HighlightColor) {
        // Implement highlighting with beautiful animation
    }
    
    func didSelectDefinition() {
        // Show definition
    }
    
    func didSelectTranslate() {
        // Show translation
    }
    
    func didSelectNote() {
        // Add note
    }
}

extension ModernBookReaderViewController: LibraryViewControllerDelegate {
    func didSelectBook(_ book: Book) {
        loadBook(book)
    }
}

// MARK: - PDFViewDelegate
extension ModernBookReaderViewController: PDFViewDelegate {
    func pdfViewDidEndPageScrolling(_ pdfView: PDFView) {
        // Save position when user stops scrolling
        saveCurrentPosition()
        updateReadingProgress()
    }
    
    func pdfViewDidEndDocumentNavigation(_ pdfView: PDFView) {
        // Save position when navigation ends (page change, zoom, etc.)
        saveCurrentPosition()
        updateReadingProgress()
    }
}