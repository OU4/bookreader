//
//  ModernBookReaderViewController.swift
//  BookReader
//
//  Beautiful, modern book reader interface
//

import UIKit
import PDFKit
import AVFoundation
import VisionKit

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
    private var accumulatedSessionDuration: TimeInterval = 0
    private var lastKnownProgress: Float = 0
    private var lastKnownPage: Int?
    private var lastKnownTotalPages: Int?

    // Position tracking
    private var lastSavedPosition: Float = 0
    private var positionSaveTimer: Timer?
    private var isObservingAppLifecycle = false
    
    // MARK: - PDF Highlight Handler
    private var pdfHighlightHandler: PDFHighlightHandler?
    private var bookPendingReupload: Book?
    
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
    private let readingStatusHUD = ReadingStatusHUD()
    
    // Bookmark components
    private var bookmarkSidebar: BookmarkSidebarView?

    private var addBookmarkView: AddBookmarkView?
    
    private var searchView: BookSearchView?
    private let searchNavigator = SearchNavigatorView()
    private var searchSelections: [PDFSelection] = []
    private var searchResultIndex: Int = 0
    private var lastSearchQuery: String = ""
    private let notesPeekView = NotesPeekView()
    private let ttsControllerView = TTSMiniControllerView()
    private var totalTextLength: Int {
        if !extractedText.isEmpty {
            return extractedText.count
        }
        return textView.text.count
    }

    // Live Text support
    @available(iOS 16.0, *)
    private lazy var imageAnalyzer = ImageAnalyzer()
    @available(iOS 16.0, *)
    private var imageInteraction: ImageAnalysisInteraction?
    
    // Constraints for animations
    private var toolbarBottomConstraint: NSLayoutConstraint?
    private var headerTopConstraint: NSLayoutConstraint?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupModernUI()
        setupGestures()
        loadTheme()
        setupLiveText()
        showWelcomeAnimation()
        
        // Ensure clean state
        stopAllTimers()
        TextToSpeechService.shared.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(handleFirebaseBooksUpdated), name: NSNotification.Name("FirebaseBooksUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotesOrHighlightsChanged(_:)), name: .highlightAdded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotesOrHighlightsChanged(_:)), name: .highlightRemoved, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotesOrHighlightsChanged(_:)), name: .highlightUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotesOrHighlightsChanged(_:)), name: .noteAdded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotesOrHighlightsChanged(_:)), name: .noteRemoved, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotesOrHighlightsChanged(_:)), name: .noteUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotesOrHighlightsChanged(_:)), name: .bookNotesUpdated, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientBackground.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh toolbar state; session starts after content is ready
        updateToolbarButtonStates()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start reading session only when view is visible and has content
        if currentBook != nil && (!textView.isHidden || (pdfView?.isHidden == false)) {
            startReadingSession()
            
            // Refresh highlights when returning to PDF view
            if pdfView?.isHidden == false {
                pdfHighlightHandler?.refreshHighlights()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Save position immediately before disappearing
        saveCurrentPositionImmediately()
        
        // End reading session to clean up timers
        endReadingSession()
        
        // Clean up PDF memory when leaving the view
        cleanupPDFMemory()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Ensure all timers are stopped when view disappears
        DispatchQueue.main.async { [weak self] in
            self?.stopAllTimers()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return !isToolbarVisible
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    // MARK: - Memory Management
    private func cleanupPDFMemory() {
        // Clear PDF document to free memory
        pdfView?.document = nil
        
        // Clear PDF cache
        optimizedPDFManager?.clearCache()
        
        // Clear Live Text analysis to free memory
        if #available(iOS 16.0, *) {
            imageInteraction?.analysis = nil
        }
        
        // Force memory cleanup
        autoreleasepool {
            // This helps release any retained PDF objects
        }
    }
    
    // MARK: - Cleanup
    deinit {
        // Synchronous cleanup to prevent crashes during deallocation
        stopAllTimersSync()
        
        // Clean up reading timer widget
        readingTimerWidget?.endSession()
        readingTimerWidget?.removeFromSuperview()
        readingTimerWidget = nil
        
        // Clean up PDF resources
        cleanupPDFMemory()
        optimizedPDFManager = nil
        pdfView = nil
        
        // Stop all animations to prevent timer leaks
        view.layer.removeAllAnimations()
        
        // Remove all notification observers
        NotificationCenter.default.removeObserver(self)
        TextToSpeechService.shared.delegate = nil
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
        readingStatusHUD.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(readingStatusHUD)
        searchNavigator.translatesAutoresizingMaskIntoConstraints = false
        searchNavigator.delegate = self
        searchNavigator.isHidden = true
        view.addSubview(searchNavigator)
        notesPeekView.delegate = self
        view.addSubview(notesPeekView)
        ttsControllerView.delegate = self
        ttsControllerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ttsControllerView)
        
        // Setup constraints
        setupConstraints()
        
        // Apply smooth animations
        applyInitialAnimations()
    }
    
    private func setupConstraints() {
        // Header
        headerTopConstraint = navigationHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        
        if let headerTopConstraint = headerTopConstraint {
            NSLayoutConstraint.activate([
                headerTopConstraint,
                navigationHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                navigationHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                navigationHeader.heightAnchor.constraint(equalToConstant: 60)
            ])
        }
        
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
        
        if let toolbarBottomConstraint = toolbarBottomConstraint {
            NSLayoutConstraint.activate([
                floatingToolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                toolbarBottomConstraint,
                floatingToolbar.heightAnchor.constraint(equalToConstant: 60),
                floatingToolbar.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
            ])
        }
        
        // Settings Panel
        NSLayoutConstraint.activate([
            settingsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            settingsPanel.topAnchor.constraint(equalTo: navigationHeader.bottomAnchor, constant: 16),
            settingsPanel.widthAnchor.constraint(equalToConstant: 280),
            settingsPanel.heightAnchor.constraint(equalToConstant: 400),
            
            readingStatusHUD.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            readingStatusHUD.bottomAnchor.constraint(equalTo: readingProgressView.topAnchor, constant: -12),
            
            searchNavigator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchNavigator.topAnchor.constraint(equalTo: navigationHeader.bottomAnchor, constant: 16),

            notesPeekView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            notesPeekView.bottomAnchor.constraint(equalTo: readingProgressView.topAnchor, constant: -16),

            ttsControllerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            ttsControllerView.bottomAnchor.constraint(equalTo: floatingToolbar.topAnchor, constant: -80),
            ttsControllerView.widthAnchor.constraint(equalToConstant: 220)
        ])
    }
    
    private func applyInitialAnimations() {
        // Start with toolbar hidden
        toolbarBottomConstraint?.constant = 100
        headerTopConstraint?.constant = -80
        
        // Animate in
        UIView.animate(withDuration: 0.8, delay: 0.3, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.toolbarBottomConstraint?.constant = -16
            self.headerTopConstraint?.constant = 0
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
    
    // MARK: - Live Text Setup
    private func setupLiveText() {
        guard #available(iOS 16.0, *) else { return }
        
        // Check if Live Text is supported
        guard ImageAnalyzer.isSupported else {
            return
        }
        
        
        // Enable enhanced text interaction for PDFs
        if let pdfView = pdfView {
            pdfView.displayMode = .singlePageContinuous
            
            // Create image interaction for Live Text
            let interaction = ImageAnalysisInteraction()
            interaction.preferredInteractionTypes = [.textSelection, .dataDetectors]
            interaction.delegate = self
            
            // Add interaction to PDFView's document view
            if let documentView = pdfView.documentView {
                documentView.addInteraction(interaction)
                imageInteraction = interaction
            }
            
            // Analyze current page when PDF loads
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pdfPageChanged),
                name: .PDFViewPageChanged,
                object: pdfView
            )
        }
    }
    
    @available(iOS 16.0, *)
    @objc private func pdfPageChanged(_ notification: Notification) {
        guard let pdfView = notification.object as? PDFView,
              let currentPage = pdfView.currentPage else { return }
        
        // Update reading progress and position
        updateReadingProgress()
        saveCurrentPosition()
        
        // Perform Live Text analysis only for small documents or when explicitly needed
        if #available(iOS 16.0, *), !isLargeDocument {
            Task {
                await analyzePDFPageOptimized(currentPage)
            }
        }
        
        // Preload nearby pages for smooth scrolling
        if let document = pdfView.document {
            let currentPageIndex = document.index(for: currentPage)
            optimizedPDFManager?.preloadPages(around: currentPageIndex, radius: 2)
        }
    }
    
    @available(iOS 16.0, *)
    private func analyzePDFPageOptimized(_ page: PDFPage) async {
        // Use much smaller thumbnail for analysis to reduce memory usage
        let maxSize = CGSize(width: 400, height: 500) // Further reduced for memory optimization
        let pageSize = page.bounds(for: .mediaBox).size
        let scaleFactor = min(maxSize.width / pageSize.width, maxSize.height / pageSize.height, 1.0)
        let thumbnailSize = CGSize(width: pageSize.width * scaleFactor, height: pageSize.height * scaleFactor)
        
        // Create thumbnail in autoreleasepool to manage memory
        let image = autoreleasepool {
            return page.thumbnail(of: thumbnailSize, for: .mediaBox)
        }
        
        do {
            // Use text-only analysis for better performance and memory
            let configuration = ImageAnalyzer.Configuration([.text])
            let analysis = try await imageAnalyzer.analyze(image, configuration: configuration)
            
            await MainActor.run {
                if let interaction = self.imageInteraction {
                    // Clear previous analysis to free memory
                    interaction.analysis = nil
                    interaction.analysis = analysis
                    interaction.isSupplementaryInterfaceHidden = true
                }
            }
        } catch {
            // Failed analysis - clear any existing analysis to free memory
            await MainActor.run {
                self.imageInteraction?.analysis = nil
            }
        }
    }
    
    // MARK: - UI Animations
    private func toggleUI() {
        isToolbarVisible.toggle()
        
        let targetConstantToolbar: CGFloat = isToolbarVisible ? -16 : 100
        let targetConstantHeader: CGFloat = isToolbarVisible ? 0 : -80
        let targetAlphaProgress: CGFloat = isToolbarVisible ? 1 : 0
        let shouldKeepTTSVisible = TextToSpeechService.shared.speaking || TextToSpeechService.shared.paused
        let ttsAlpha: CGFloat = shouldKeepTTSVisible ? 1 : targetAlphaProgress
        
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.toolbarBottomConstraint?.constant = targetConstantToolbar
            self.headerTopConstraint?.constant = targetConstantHeader
            self.readingProgressView.alpha = targetAlphaProgress
            self.searchNavigator.alpha = targetAlphaProgress
            self.notesPeekView.alpha = targetAlphaProgress
            self.ttsControllerView.alpha = ttsAlpha
            self.view.layoutIfNeeded()
        }
        
        // Update status bar
        UIView.animate(withDuration: 0.3) {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    // MARK: - Bookmark Actions
    private func addQuickBookmark(showFeedback: Bool = true) {
        guard let book = currentBook else { return }

        let createdBookmark: BookmarkItem?
        if let pdfView = pdfView, !pdfView.isHidden {
            createdBookmark = BookmarkManager.shared.addBookmarkFromPDF(
                bookId: book.id,
                bookTitle: book.title,
                pdfView: pdfView,
                title: "Quick Bookmark"
            )
        } else {
            createdBookmark = BookmarkManager.shared.addBookmarkFromText(
                bookId: book.id,
                bookTitle: book.title,
                textView: textView,
                title: "Quick Bookmark"
            )
        }

        guard createdBookmark != nil else {
            showQuickHint("Couldn't save bookmark")
            return
        }

        if showFeedback {
            showBookmarkConfirmation()
        }

        updateToolbarButtonStates()
    }
    
    private func showBookmarkConfirmation() {
        let label = UILabel()
        label.text = "📑 Bookmark Added"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.layer.cornerRadius = 20
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            label.widthAnchor.constraint(equalToConstant: 160),
            label.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Animate in
        label.alpha = 0
        label.transform = CGAffineTransform(translationX: 0, y: -20)
        
        UIView.animate(withDuration: 0.3, animations: {
            label.alpha = 1
            label.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, animations: {
                label.alpha = 0
                label.transform = CGAffineTransform(translationX: 0, y: -20)
            }) { _ in
                label.removeFromSuperview()
            }
        }
    }
    
    private func showAddBookmarkView() {
        guard let book = currentBook else { return }
        
        let bookmarkView = AddBookmarkView()
        bookmarkView.delegate = self
        bookmarkView.translatesAutoresizingMaskIntoConstraints = false
        
        // Pre-populate with current position
        if let pageNumber = getCurrentPageNumber() {
            bookmarkView.prepopulate(title: "Page \(pageNumber)")
        } else {
            bookmarkView.prepopulate(title: "Reading Position")
        }
        
        view.addSubview(bookmarkView)
        
        NSLayoutConstraint.activate([
            bookmarkView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bookmarkView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            bookmarkView.widthAnchor.constraint(equalToConstant: 320),
            bookmarkView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        // Animate in
        bookmarkView.alpha = 0
        bookmarkView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            bookmarkView.alpha = 1
            bookmarkView.transform = .identity
        }
        
        addBookmarkView = bookmarkView
    }
    
    private func showBookmarkSidebar() {
        guard let book = currentBook else { return }
        
        // Remove existing sidebar if any
        bookmarkSidebar?.removeFromSuperview()
        
        // Create new sidebar
        let sidebar = BookmarkSidebarView()
        sidebar.delegate = self
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(sidebar)
        
        NSLayoutConstraint.activate([
            sidebar.topAnchor.constraint(equalTo: view.topAnchor),
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        bookmarkSidebar = sidebar
        sidebar.show(bookId: book.id)
    }
    
    private func showBookmarksList() {
        guard let book = currentBook else { return }
        
        let bookmarksVC = BookmarksViewController(bookId: book.id)
        let navController = UINavigationController(rootViewController: bookmarksVC)
        
        present(navController, animated: true)
        
        // Listen for bookmark selection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bookmarkSelected(_:)),
            name: NSNotification.Name("BookmarkSelected"),
            object: nil
        )
    }
    
    @objc private func bookmarkSelected(_ notification: Notification) {
        guard let bookmark = notification.object as? BookmarkItem else { return }
        
        // Navigate to bookmark
        if let pdfView = pdfView, pdfView.superview != nil {
            _ = BookmarkManager.shared.navigateToBookmark(bookmark, in: pdfView)
        } else if textView.superview != nil {
            _ = BookmarkManager.shared.navigateToBookmark(bookmark, in: textView)
        }
    }
    
    private func getCurrentPageNumber() -> Int? {
        if let currentPage = pdfView?.currentPage,
           let document = pdfView?.document {
            return document.index(for: currentPage) + 1
        }
        return nil
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
        
        // Create a weak reference to prevent retain cycles
        let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            // Ensure we're on main thread and self still exists
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                // Double-check self still exists after async dispatch
                guard self.textView != nil else {
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
        
        // Store timer reference for potential cleanup
        RunLoop.main.add(timer, forMode: .common)
        
        // Auto-cleanup after maximum duration to prevent indefinite running
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            timer.invalidate()
        }
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
        let resolvedBook = mergeWithLocalNotesIfNeeded(book)
        currentBook = resolvedBook
        navigationHeader.setBookTitle(book.title, author: book.author)

        stopAllTimers()
        accumulatedSessionDuration = 0
        currentSessionDuration = 0
        sessionStartTime = nil

        updateToolbarButtonStates()
        clearSearchResults()
        notesPeekView.update(highlights: 0, notes: 0)

        // Start reading session tracking
        UnifiedReadingTracker.shared.startSession(for: resolvedBook)

        // Load book content with beautiful animation
        loadBookContent(resolvedBook)
        
        // Position restoration now happens inside loadPDFContent when PDF is fully loaded
    }

    private func mergeWithLocalNotesIfNeeded(_ book: Book) -> Book {
        let localBooks = BookStorage.shared.loadBooks()
        guard let localBook = localBooks.first(where: { $0.id == book.id }) else {
            return book
        }

        let localTimestamp = localBook.notesUpdatedAt ?? Date.distantPast
        let remoteTimestamp = book.notesUpdatedAt ?? Date.distantPast

        guard localTimestamp >= remoteTimestamp else {
            return book
        }

        var merged = book
        merged.personalSummary = localBook.personalSummary
        merged.keyTakeaways = localBook.keyTakeaways
        merged.actionItems = localBook.actionItems
        merged.sessionNotes = localBook.sessionNotes
        merged.notesUpdatedAt = localBook.notesUpdatedAt
        return merged
    }
    
    private func loadBookContent(_ book: Book) {
        
        // Show loading animation
        showLoadingAnimation()
        
        // Check if filePath is empty
        if book.filePath.isEmpty {
            hideLoadingAnimation()
            showBookReuploadOption(for: book)
            return
        }
        
        // Check if this is a Firebase URL that needs to be downloaded
        if book.filePath.starts(with: "https://") {
            UnifiedFirebaseStorage.shared.downloadBook(book) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let localURL):
                        // Load content from local file
                        self?.loadContentFromLocalFile(book, localPath: localURL.path)
                    case .failure(let error):
                        self?.hideLoadingAnimation()
                        self?.showErrorMessage("Failed to download book: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Load content directly from local file
            loadContentFromLocalFile(book, localPath: book.filePath)
        }
    }
    
    private func loadContentFromLocalFile(_ book: Book, localPath: String) {
        // Load content based on book type
        switch book.type {
        case .pdf:
            loadPDFContent(from: localPath)
        case .text, .epub:
            loadTextContent(from: localPath)
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
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            showErrorMessage("File not found: \(path)")
            return
        }
        
        // Show loading animation
        showLoadingAnimation()
        
        // Load PDF on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: path)
            
            // Check file size for optimization strategy
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            let isLarge = fileSize > 10 * 1024 * 1024 // 10MB threshold
            
            DispatchQueue.main.async {
                self.isLargeDocument = isLarge
                if isLarge {
                }
            }
            
            // Try to load PDF document
            guard let pdfDocument = PDFDocument(url: url) else {
                DispatchQueue.main.async {
                    self.showErrorMessage("Failed to load PDF document. The file may be corrupted or not a valid PDF.")
                    self.hideLoadingAnimation()
                }
                return
            }
            
            
            // Configure PDF on main thread
            DispatchQueue.main.async {
                // Hide text view and welcome content
                self.textView.isHidden = true
                self.textView.text = ""
                
                // Create PDF view if it doesn't exist
                if self.pdfView == nil {
                    self.setupPDFView()
                    
                    // Initialize optimized PDF manager
                    if let pdfView = self.pdfView {
                        self.optimizedPDFManager = OptimizedPDFManager(pdfView: pdfView)
                    }
                }
                
                // Configure PDF view step by step to avoid scale issues
                self.pdfView?.isHidden = false
                self.pdfView?.backgroundColor = .systemBackground
                
                // Set document first
                self.pdfView?.document = pdfDocument
                
                // Use optimized configuration based on document size
                if self.isLargeDocument {
                    // Optimized settings for large documents
                    self.pdfView?.displayMode = .singlePageContinuous // Allow scrolling
                    self.pdfView?.interpolationQuality = .low // Better performance
                    self.pdfView?.autoScales = true
                    // Disable page shadows and reduce page break margins for memory
                    self.pdfView?.pageShadowsEnabled = false
                    self.pdfView?.pageBreakMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
                } else {
                    // Memory-optimized settings for smaller documents
                    self.pdfView?.displayMode = .singlePageContinuous // Allow scrolling
                    self.pdfView?.interpolationQuality = .low // Better quality for smaller files
                    self.pdfView?.autoScales = true
                    // Enable some visual features for smaller documents
                    self.pdfView?.pageShadowsEnabled = true
                    self.pdfView?.pageBreakMargins = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
                    
                    // Configure scaling with reduced overhead
                    DispatchQueue.main.async {
                        self.configurePDFScalingOptimized()
                    }
                }
                
                self.pdfView?.displayDirection = .vertical
                
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
                
                // Start reading session after PDF is ready
                self.startReadingSession()
                
            }
        }
    }
    
    private var pdfView: PDFView?
    private var optimizedPDFManager: OptimizedPDFManager?
    private var isLargeDocument = false
    
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
        
        // Optimized initial configuration
        pdfV.displayMode = .singlePageContinuous // Always allow scrolling
        pdfV.displayDirection = .vertical
        pdfV.autoScales = true // Enable auto scaling
        pdfV.interpolationQuality = .low // Balanced quality
        
        // Enable text selection and interaction
        pdfV.isUserInteractionEnabled = true
        
        // Optimize page shadows and margins based on document size
        if isLargeDocument {
            pdfV.pageShadowsEnabled = false // Disable shadows for better performance
            pdfV.pageBreakMargins = UIEdgeInsets.zero
        } else {
            pdfV.pageShadowsEnabled = true
            pdfV.pageBreakMargins = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        }
        
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
        
        // Setup PDF highlight handler
        if let book = currentBook {
            pdfHighlightHandler = PDFHighlightHandler(pdfView: pdfV, bookId: book.id)
            pdfHighlightHandler?.delegate = self
        }
        
        // Temporarily disable LiveText overlay - it's blocking UI interactions
        // Will re-enable after fixing gesture handling
        liveTextSelectionView.isHidden = true
        liveTextSelectionView.isUserInteractionEnabled = false
        
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
                
            }
        }
        
        // Enable auto-scaling after manual scale is set
        pdfView.autoScales = true
        
        // Force layout
        pdfView.layoutIfNeeded()
        
    }
    
    private func setupLiveTextForPDF() {
        guard #available(iOS 16.0, *) else {
            return
        }
        
        guard let pdfView = pdfView,
              let currentPage = pdfView.currentPage else { return }
        
        
        // Analyze the current page
        if #available(iOS 16.0, *) {
            Task {
                await analyzePDFPageOptimized(currentPage)
            }
        }
    }
    
    private func loadExistingHighlights() {
        // The PDFHighlightHandler will load existing highlights
        pdfHighlightHandler?.loadExistingHighlights()
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
        var currentPage: Int?
        var totalPages: Int?

        if !textView.isHidden {
            let contentHeight = textView.contentSize.height
            let offset = textView.contentOffset.y
            progress = Float(offset / max(contentHeight - textView.bounds.height, 1))

            let estimatedPages = Int(ceil(contentHeight / max(textView.bounds.height, 1)))
            if estimatedPages > 0 {
                totalPages = estimatedPages
                let derivedPage = Int(round(progress * Float(estimatedPages - 1))) + 1
                currentPage = max(1, min(estimatedPages, derivedPage))
            }
        } else if let pdfView = pdfView, !pdfView.isHidden {
            if let currentPageObj = pdfView.currentPage,
               let document = pdfView.document {
                let pageIndex = document.index(for: currentPageObj)
                let pageCount = document.pageCount
                progress = Float(pageIndex) / Float(max(pageCount - 1, 1))
                currentPage = pageIndex + 1
                totalPages = pageCount
            }
        }

        lastKnownProgress = max(0, min(progress, 1))
        lastKnownPage = currentPage
        lastKnownTotalPages = totalPages
        readingProgressView.setProgress(progress, animated: true)
        updateStatusHUD(page: currentPage, totalPages: totalPages, progress: progress)
        updateNotesPeek(currentPage: currentPage)
    }

    private func updateStatusHUD(page: Int?, totalPages: Int?, progress: Float) {
        let elapsed = currentSessionDuration
        readingStatusHUD.update(page: page, totalPages: totalPages, percentage: progress, elapsed: elapsed)

        let progressDouble = Double(max(progress, 0.0001))
        if elapsed > 30, progressDouble < 1 {
            let totalExpected = elapsed / progressDouble
            let remaining = totalExpected - elapsed
            if remaining.isFinite && remaining > 10 {
                readingStatusHUD.updateEstimatedRemaining(remaining)
            }
        }
    }

    private func updateNotesPeek(currentPage: Int?) {
        guard let book = currentBook, let page = currentPage else {
            notesPeekView.update(highlights: 0, notes: 0)
            return
        }

        let highlights = combinedHighlights(for: book.id).filter({ highlight -> Bool in
            if let pageNumber = highlight.position.pageNumber {
                return pageNumber == page
            }
            if !textView.isHidden,
               totalTextLength > 0,
               let pages = lastKnownTotalPages, pages > 0 {
                let pageSize = max(1, totalTextLength / pages)
                let pageIndex = highlight.position.startOffset / pageSize + 1
                return pageIndex == page
            }
            return false
        })

        let notesArray = combinedNotes(for: book.id).filter({ note -> Bool in
            if let pageNumber = note.position?.pageNumber {
                return pageNumber == page
            }
            if !textView.isHidden,
               let offset = note.position?.startOffset,
               totalTextLength > 0,
               let pages = lastKnownTotalPages, pages > 0 {
                let pageSize = max(1, totalTextLength / pages)
                let pageIndex = offset / pageSize + 1
                return pageIndex == page
            }
            return false
        })

        let sessionNotes = combinedSessionNotes(for: book.id).filter { note in
            guard let hint = note.pageHint else { return false }
            return hint == page
        }

        notesPeekView.update(highlights: highlights.count, notes: notesArray.count + sessionNotes.count)
    }

    @objc private func handleFirebaseBooksUpdated() {
        guard let currentId = currentBook?.id else { return }
        if let refreshed = UnifiedFirebaseStorage.shared.books.first(where: { $0.id == currentId }) {
            currentBook = refreshed
            updateToolbarButtonStates()
            updateNotesPeek(currentPage: lastKnownPage)
        }
    }

    @objc private func handleNotesOrHighlightsChanged(_ notification: Notification) {
        guard let bookId = currentBook?.id else { return }
        if let notifiedBookId = notification.userInfo?["bookId"] as? String, notifiedBookId != bookId {
            return
        }
        refreshCurrentBookSnapshot()
        updateToolbarButtonStates()
        updateNotesPeek(currentPage: lastKnownPage)
    }

    private func refreshCurrentBookSnapshot() {
        guard let id = currentBook?.id else { return }
        let books = BookStorage.shared.loadBooks()
        if let updated = books.first(where: { $0.id == id }) {
            currentBook = updated
        }
    }

    private func combinedHighlights(for bookId: String) -> [Highlight] {
        var merged = [String: Highlight]()

        let sources: [[Highlight]] = [
            NotesManager.shared.getHighlights(for: bookId),
            UnifiedFirebaseStorage.shared.books.first(where: { $0.id == bookId })?.highlights ?? [],
            currentBook?.id == bookId ? currentBook?.highlights ?? [] : []
        ]

        for highlights in sources {
            for highlight in highlights {
                merged[highlight.id] = highlight
            }
        }

        return Array(merged.values)
    }

    private func bookmarkCount(for bookId: String) -> Int {
        var identifiers = Set<String>()

        BookmarkManager.shared.getBookmarks(for: bookId).forEach { identifiers.insert($0.id) }
        if let remote = UnifiedFirebaseStorage.shared.books.first(where: { $0.id == bookId })?.bookmarks {
            remote.forEach { identifiers.insert($0.id) }
        }
        if let local = currentBook?.bookmarks, currentBook?.id == bookId {
            local.forEach { identifiers.insert($0.id) }
        }

        return identifiers.count
    }

    private func combinedNotes(for bookId: String) -> [Note] {
        var merged = [String: Note]()

        let sources: [[Note]] = [
            NotesManager.shared.getNotes(for: bookId),
            UnifiedFirebaseStorage.shared.books.first(where: { $0.id == bookId })?.notes ?? [],
            currentBook?.id == bookId ? currentBook?.notes ?? [] : []
        ]

        for notes in sources {
            for note in notes {
                merged[note.id] = note
            }
        }

        return Array(merged.values)
    }
    
    private func combinedSessionNotes(for bookId: String) -> [BookSessionNote] {
        var merged = [String: BookSessionNote]()

        if let remote = UnifiedFirebaseStorage.shared.books.first(where: { $0.id == bookId })?.sessionNotes {
            for note in remote {
                merged[note.id] = note
            }
        }

        if let current = currentBook, current.id == bookId {
            for note in current.sessionNotes {
                merged[note.id] = note
            }
        }

        return Array(merged.values)
    }
    
    private func showBookReuploadOption(for book: Book) {
        let alert = UIAlertController(
            title: "File Missing", 
            message: "The file for '\(book.title)' is not available. Would you like to upload a new file for this book?", 
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Choose File", style: .default) { [weak self] _ in
            self?.showDocumentPicker(for: book)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showDocumentPicker(for book: Book) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        
        // Store the book reference for later use
        bookPendingReupload = book
        
        present(documentPicker, animated: true)
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
    
    private func showQuickHint(_ message: String) {
        let hintLabel = UILabel()
        hintLabel.text = message
        hintLabel.font = .systemFont(ofSize: 16, weight: .medium)
        hintLabel.textColor = .white
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        hintLabel.textAlignment = .center
        hintLabel.layer.cornerRadius = 20
        hintLabel.clipsToBounds = true
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(hintLabel)
        
        NSLayoutConstraint.activate([
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            hintLabel.heightAnchor.constraint(equalToConstant: 40),
            hintLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
        
        // Add padding
        hintLabel.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        // Animate in
        hintLabel.alpha = 0
        hintLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        
        UIView.animate(withDuration: 0.3, animations: {
            hintLabel.alpha = 1
            hintLabel.transform = .identity
        }) { _ in
            // Animate out after delay
            UIView.animate(withDuration: 0.3, delay: 2.0, animations: {
                hintLabel.alpha = 0
                hintLabel.transform = CGAffineTransform(translationX: 0, y: 20)
            }) { _ in
                hintLabel.removeFromSuperview()
            }
        }
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

        // Text-to-Speech
        let ttsService = TextToSpeechService.shared
        let ttsTitle: String
        if ttsService.speaking {
            ttsTitle = "Pause Text-to-Speech"
        } else if ttsService.paused {
            ttsTitle = "Resume Text-to-Speech"
        } else {
            ttsTitle = "Start Text-to-Speech"
        }
        let ttsAction = UIAlertAction(title: ttsTitle, style: .default) { [weak self] _ in
            self?.didTapTextToSpeech()
        }
        ttsAction.setValue(UIImage(systemName: "waveform"), forKey: "image")
        actionSheet.addAction(ttsAction)

        // Personal Notes Workspace
        if currentBook != nil {
            let notesWorkspace = UIAlertAction(title: "My Notes", style: .default) { [weak self] _ in
                self?.presentNotesWorkspace()
            }
            notesWorkspace.setValue(UIImage(systemName: "square.and.pencil"), forKey: "image")
            actionSheet.addAction(notesWorkspace)
        }

        // Search
        let searchAction = UIAlertAction(title: "Search", style: .default) { [weak self] _ in
            self?.didTapSearch()
        }
        searchAction.setValue(UIImage(systemName: "magnifyingglass"), forKey: "image")
        actionSheet.addAction(searchAction)
        
        // Notes & Highlights
        let notesAction = UIAlertAction(title: "Notes & Highlights", style: .default) { [weak self] _ in
            self?.didTapNotes()
        }
        notesAction.setValue(UIImage(systemName: "highlighter"), forKey: "image")
        actionSheet.addAction(notesAction)
        
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
        // Show simple stats alert
        let stats = UnifiedReadingTracker.shared.getTrackerStats()
        let (todayMinutes, goalProgress) = UnifiedReadingTracker.shared.getTodayProgress()
        let streak = UnifiedReadingTracker.shared.getCurrentStreak()
        
        let message = """
        📚 Today: \(todayMinutes) minutes
        🎯 Goal Progress: \(Int(goalProgress))%
        🔥 Current Streak: \(streak) days
        ⏱️ Total Time: \(Int(stats.totalReadingTime / 3600)) hours
        """
        
        let alert = UIAlertController(title: "Reading Stats", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
        guard let pdfView = pdfView, !pdfView.isHidden else {
            showAlert(title: "Highlighting", message: "Highlighting is only available for PDF files")
            return
        }
        
        // Check if there's any selected text first
        if let selection = pdfView.currentSelection, !(selection.string?.isEmpty ?? true) {
            // There's selected text - show highlight options immediately
            pdfHighlightHandler?.showHighlightOptions(for: selection)
        } else {
            // No selected text - show instruction
            showQuickHint("Select text by tapping and dragging, then use this button to highlight")
            
            // Ensure PDFView is properly configured for text selection
            pdfView.isUserInteractionEnabled = true
            
            // Visual feedback for the highlight button
            floatingToolbar.setHighlightMode(active: true)
            
            // Auto-deactivate highlight mode after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.floatingToolbar.setHighlightMode(active: false)
            }
        }
        
    }
    
    func didTapBookmarks() {
        let sheet = UIAlertController(title: "Bookmarks", message: nil, preferredStyle: .actionSheet)

        let quickAction = UIAlertAction(title: "Quick Bookmark", style: .default) { [weak self] _ in
            self?.addQuickBookmark()
        }
        quickAction.setValue(UIImage(systemName: "bookmark.fill"), forKey: "image")
        sheet.addAction(quickAction)

        let detailedAction = UIAlertAction(title: "Add Bookmark with Note", style: .default) { [weak self] _ in
            self?.showAddBookmarkView()
        }
        detailedAction.setValue(UIImage(systemName: "bookmark.square"), forKey: "image")
        sheet.addAction(detailedAction)

        let sidebarAction = UIAlertAction(title: "Bookmark Sidebar", style: .default) { [weak self] _ in
            self?.showBookmarkSidebar()
        }
        sidebarAction.setValue(UIImage(systemName: "sidebar.left"), forKey: "image")
        sheet.addAction(sidebarAction)

        let listAction = UIAlertAction(title: "View All Bookmarks", style: .default) { [weak self] _ in
            self?.showBookmarksList()
        }
        listAction.setValue(UIImage(systemName: "list.bullet.rectangle"), forKey: "image")
        sheet.addAction(listAction)

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = floatingToolbar
            popover.sourceRect = floatingToolbar.bounds
        }

        present(sheet, animated: true)
    }
    
    
    
    
    
    
    
    
    
    func didTapNotes() {
        // Show notes and highlights interface
        guard let book = currentBook else {
            showAlert(title: "Notes", message: "No book is currently loaded")
            return
        }
        
        let notesVC = BookNotesViewController(book: book,
                                              focus: .highlights,
                                              onHighlightSelected: { [weak self] highlight in
                                                  self?.navigateToHighlight(highlight)
                                              })
        notesVC.modalPresentationStyle = .pageSheet

        if let sheet = notesVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        
        present(notesVC, animated: true)
    }

    private func navigateToHighlight(_ highlight: Highlight) {
        guard let pdfView = pdfView,
              !pdfView.isHidden,
              let document = pdfView.document else {
            showAlert(title: "Highlights", message: "Open the PDF view to navigate to highlights.")
            return
        }

        let targetPageIndex: Int
        if let pageNumber = highlight.position.pageNumber, pageNumber > 0 {
            targetPageIndex = pageNumber - 1
        } else if let storedIndex = highlight.selectionRects?.first?.pageIndex {
            targetPageIndex = storedIndex
        } else {
            showAlert(title: "Highlight", message: "Unable to locate this highlight in the document.")
            return
        }

        guard targetPageIndex >= 0, targetPageIndex < document.pageCount,
              let page = document.page(at: targetPageIndex) else {
            showAlert(title: "Highlight", message: "That page is not available in the current document.")
            return
        }

        pdfView.go(to: page)

        let targetRect: CGRect? = {
            if let rect = highlight.selectionRects?.first(where: { $0.pageIndex == targetPageIndex })?.cgRect {
                return rect
            }

            guard let pageText = page.string else { return nil }
            let normalized = highlight.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized.isEmpty { return nil }

            if let range = pageText.range(of: normalized) ?? pageText.range(of: normalized, options: [.caseInsensitive]) {
                let nsRange = NSRange(range, in: pageText)
                if let selection = page.selection(for: nsRange) {
                    return selection.bounds(for: page)
                }
            }
            return nil
        }()

        if let rect = targetRect {
            let paddedRect = rect.insetBy(dx: -16, dy: -20)
            pdfView.go(to: paddedRect, on: page)

            if let pageText = page.string {
                let normalized = highlight.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalized.isEmpty,
                   let range = pageText.range(of: normalized) ?? pageText.range(of: normalized, options: [.caseInsensitive]) {
                    let nsRange = NSRange(range, in: pageText)
                    if let selection = page.selection(for: nsRange) {
                        pdfView.setCurrentSelection(selection, animate: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            pdfView.clearSelection()
                        }
                    }
                }
            }
        }

        showReadingTimerWidget()
    }
    
    private func didTapSearch() {
        guard let book = currentBook else { return }
        
        showSearchView(for: book)
    }
    
    private func showSearchView(for book: Book) {
        // Remove existing search view if any
        searchView?.removeFromSuperview()
        
        // Create new search view
        let search = BookSearchView()
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(search)
        
        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: view.topAnchor),
            search.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            search.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            search.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        searchView = search
        search.show(for: book, pdfDocument: pdfView?.document)
    }
    
    private func searchInPDF(_ searchText: String) {
        guard let pdfView = pdfView, let document = pdfView.document else { return }

        lastSearchQuery = searchText
        let selections = document.findString(searchText, withOptions: [.caseInsensitive, .diacriticInsensitive])

        guard !selections.isEmpty else {
            clearSearchResults()
            showQuickHint("No matches for “\(searchText)”")
            return
        }

        presentSearchResults(selections, query: searchText, in: pdfView)
    }

    private func presentSearchResults(_ selections: [PDFSelection], query: String, in pdfView: PDFView) {
        searchSelections = selections
        searchResultIndex = 0
        searchNavigator.update(term: query, currentIndex: 1, total: selections.count)
        searchNavigator.isHidden = false
        navigateToSearchResult(at: 0, in: pdfView)
    }

    private func navigateToSearchResult(at index: Int, in pdfView: PDFView) {
        guard !searchSelections.isEmpty else { return }
        let boundedIndex = max(0, min(index, searchSelections.count - 1))
        searchResultIndex = boundedIndex

        let selection = searchSelections[boundedIndex]
        if let page = selection.pages.first {
            pdfView.go(to: page)
        }
        pdfView.setCurrentSelection(selection, animate: true)
        searchNavigator.update(term: lastSearchQuery, currentIndex: boundedIndex + 1, total: searchSelections.count)
    }

    private func clearSearchResults() {
        searchSelections.removeAll()
        searchResultIndex = 0
        searchNavigator.isHidden = true
        pdfView?.clearSelection()
    }
    
    private func didTapTextToSpeech() {
        let service = TextToSpeechService.shared

        if service.speaking {
            service.pause()
        } else if service.paused {
            service.resume()
        } else {
            guard let textToSpeak = currentTextForSpeech(), !textToSpeak.isEmpty else {
                showAlert(title: "Text-to-Speech", message: "No text content available to read")
                return
            }
            service.startReading(text: textToSpeak)
        }
    }

    private func presentNotesWorkspace() {
        guard let book = currentBook else { return }
        let snapshot = BookNotesManager.shared.snapshot(for: book.id, bookTitle: book.title, fallbackBook: book)

        var updatedBook = book
        updatedBook.personalSummary = snapshot.personalSummary
        updatedBook.keyTakeaways = snapshot.keyTakeaways
        updatedBook.actionItems = snapshot.actionItems
        updatedBook.sessionNotes = snapshot.sessionNotes
        updatedBook.notesUpdatedAt = snapshot.notesUpdatedAt ?? Date()
        currentBook = updatedBook

        let notesVC = BookNotesViewController(
            bookId: snapshot.bookId,
            bookTitle: snapshot.bookTitle,
            initialRecord: snapshot
        )
        let nav = UINavigationController(rootViewController: notesVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    private func currentTextForSpeech() -> String? {
        if !textView.isHidden && !extractedText.isEmpty {
            return extractedText
        } else if let pdfView = pdfView, !pdfView.isHidden, let currentPage = pdfView.currentPage {
            return currentPage.string
        }
        return nil
    }
}

// MARK: - PDFHighlightHandlerDelegate
extension ModernBookReaderViewController: PDFHighlightHandlerDelegate {
    func pdfHighlightHandler(_ handler: PDFHighlightHandler, didCreateHighlight highlight: Highlight) {
        if var book = currentBook {
            if !book.highlights.contains(where: { $0.id == highlight.id }) {
                book.highlights.append(highlight)
                currentBook = book
            }
        }
        
        showQuickHint("✨ Highlighted!")
        updateToolbarButtonStates()
    }
    
    func pdfHighlightHandler(_ handler: PDFHighlightHandler, didFailWithError error: Error) {
        showAlert(title: "Error", message: "Failed to create highlight: \(error.localizedDescription)")
    }
    
    private func updateToolbarButtonStates() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateToolbarButtonStates()
            }
            return
        }

        guard let book = currentBook else {
            floatingToolbar.updateBookmarkCount(0)
            floatingToolbar.updateHighlightCount(0)
            notesPeekView.update(highlights: 0, notes: 0)
            return
        }

        floatingToolbar.updateBookmarkCount(bookmarkCount(for: book.id))

        let highlightCount = combinedHighlights(for: book.id).count
        floatingToolbar.updateHighlightCount(highlightCount)
        updateNotesPeek(currentPage: lastKnownPage)
    }
}

// MARK: - Reading Session Management
extension ModernBookReaderViewController {
    
    private func startReadingSession() {
        guard currentBook != nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.sessionTimer?.isValid == true {
                return
            }

            self.stopAllTimers()

            if self.accumulatedSessionDuration == 0 {
                self.currentSessionDuration = 0
            }

            self.sessionStartTime = Date()
            self.startSessionTimer()
            self.startPositionSaveTimer()

            if !self.isObservingAppLifecycle {
                NotificationCenter.default.addObserver(self, selector: #selector(self.appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(self.appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
                self.isObservingAppLifecycle = true
            }

            self.readingTimerWidget?.resumeSession()
        }
    }
    
    private func startSessionTimer() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSessionDuration()
        }
        RunLoop.main.add(timer, forMode: .common)
        sessionTimer = timer
    }

    private func startPositionSaveTimer() {
        let saveInterval: TimeInterval = isLargeDocument ? 10.0 : 5.0
        let timer = Timer(timeInterval: saveInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let currentProgress = self.getCurrentReadingProgress()
            if abs(currentProgress - self.lastSavedPosition) > 0.01 {
                self.saveCurrentPosition()
                self.lastSavedPosition = currentProgress
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        positionSaveTimer = timer
    }

    // MARK: - Timer Management Helper
    private func stopAllTimers() {
        let invalidateTimers: () -> Void = { [weak self] in
            guard let self = self else { return }

            if let startTime = self.sessionStartTime {
                self.accumulatedSessionDuration += Date().timeIntervalSince(startTime)
                self.sessionStartTime = nil
            }

            self.sessionTimer?.invalidate()
            self.sessionTimer = nil
            self.positionSaveTimer?.invalidate()
            self.positionSaveTimer = nil

            self.currentSessionDuration = self.accumulatedSessionDuration
            self.readingTimerWidget?.pauseSession()
        }

        if Thread.isMainThread {
            invalidateTimers()
        } else {
            DispatchQueue.main.async(execute: invalidateTimers)
        }
    }
    
    // Synchronous timer cleanup for deinit - safe to call from any thread
    private func stopAllTimersSync() {
        if let startTime = sessionStartTime {
            accumulatedSessionDuration += Date().timeIntervalSince(startTime)
            sessionStartTime = nil
        }

        sessionTimer?.invalidate()
        sessionTimer = nil
        positionSaveTimer?.invalidate()
        positionSaveTimer = nil

        currentSessionDuration = accumulatedSessionDuration
        readingTimerWidget?.pauseSession()
    }
    
    // Emergency cleanup method for when normal cleanup fails
    private func emergencyCleanup() {
        // Force cleanup all resources - use async to avoid blocking
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.sessionTimer?.invalidate()
            self.positionSaveTimer?.invalidate()
            self.readingTimerWidget?.endSession()
            self.readingTimerWidget?.removeFromSuperview()
            
            // Clear all references
            self.sessionTimer = nil
            self.positionSaveTimer = nil
            self.readingTimerWidget = nil
        }
    }
    
    @objc private func appDidEnterBackground() {
        // Pause reading session when app goes to background
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.saveCurrentPositionImmediately()
            self.saveCurrentPosition()
            ThreadSafePositionManager.shared.saveAllPendingPositions()
            UnifiedReadingTracker.shared.pauseSession()
            self.stopAllTimers()
        }
    }

    @objc private func appWillEnterForeground() {
        // Resume reading session when app comes back
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.currentBook != nil,
                  self.view.window != nil else { return }
            
            UnifiedReadingTracker.shared.resumeSession()
            
            if self.sessionTimer?.isValid != true {
                self.sessionStartTime = Date()
                self.startSessionTimer()
            }

            if self.positionSaveTimer?.isValid != true {
                self.startPositionSaveTimer()
            }

            self.readingTimerWidget?.setElapsedTime(self.currentSessionDuration)
            self.readingTimerWidget?.resumeSession()
        }
    }
    
    private func endReadingSession() {
        guard let book = currentBook else { return }
        
        // Ensure timer cleanup happens on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Hide reading timer widget first
            self.hideReadingTimerWidget()
            
            // End the reading session in unified tracker
            UnifiedReadingTracker.shared.endSession()
            
            // Stop all timers safely
            self.stopAllTimers()
            self.accumulatedSessionDuration = 0
            self.currentSessionDuration = 0
        }
    }
    
    private func updateSessionDuration() {
        guard let startTime = sessionStartTime else {
            currentSessionDuration = accumulatedSessionDuration
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.readingTimerWidget?.setElapsedTime(self.currentSessionDuration)
            }
            return
        }

        let elapsed = accumulatedSessionDuration + Date().timeIntervalSince(startTime)
        currentSessionDuration = elapsed

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.readingTimerWidget?.setElapsedTime(elapsed)
            self.updateStatusHUD(page: self.lastKnownPage, totalPages: self.lastKnownTotalPages, progress: self.lastKnownProgress)
        }
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
        widget.setElapsedTime(currentSessionDuration)
    }
    
    private func hideReadingTimerWidget() {
        guard let widget = readingTimerWidget else { return }
        
        // End session first to stop internal timers
        widget.endSession()
        
        // Animate removal
        UIView.animate(withDuration: 0.3, animations: {
            widget.alpha = 0
            widget.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { [weak self] _ in
            widget.removeFromSuperview()
            self?.readingTimerWidget = nil
        }
    }
    
    private func saveCurrentPosition() {
        guard let book = currentBook else { return }
        
        let progress = getCurrentReadingProgress()

        // Use thread-safe position manager for position saving
        if !textView.isHidden {
            let position = TrackerPosition.fromTextView(textView, bookId: book.id, totalLength: extractedText.count)
            ThreadSafePositionManager.shared.updatePosition(position)
        } else if let pdfView = pdfView, !pdfView.isHidden {
            let position = TrackerPosition.fromPDFView(pdfView, bookId: book.id)
            ThreadSafePositionManager.shared.updatePosition(position)
        }

        readingTimerWidget?.recordActivity()
        readingTimerWidget?.updateProgress(progress)
    }
    
    private func saveCurrentPositionImmediately() {
        guard let book = currentBook else { return }
        
        // Save position directly to Firebase without debouncing
        if !textView.isHidden {
            let contentHeight = textView.contentSize.height
            let offset = textView.contentOffset.y
            let progress = Float(offset / max(contentHeight - textView.bounds.height, 1))
            
            UnifiedFirebaseStorage.shared.updateReadingProgress(
                bookId: book.id,
                position: progress
            ) { result in
            }
        } else if let pdfView = pdfView, !pdfView.isHidden {
            let pageIndex = pdfView.currentPage.flatMap { pdfView.document?.index(for: $0) } ?? 0
            let totalPages = pdfView.document?.pageCount ?? 1
            let progress = Float(pageIndex) / Float(max(totalPages - 1, 1))
            
            UnifiedFirebaseStorage.shared.updateReadingProgress(
                bookId: book.id,
                position: progress
            ) { result in
            }
        }
        
        // Also force save any pending positions
        ThreadSafePositionManager.shared.saveAllPendingPositions()
    }
    
    private func restoreLastPosition() {
        guard let book = currentBook else { return }
        
        
        // Load position from Firebase/local storage
        if !textView.isHidden {
            // For text books, use UnifiedReadingTracker
            UnifiedReadingTracker.shared.restorePosition(for: book.id, in: textView)
        } else if let pdfView = pdfView, !pdfView.isHidden {
            // For PDFs, check if book has saved position
            let savedPosition = book.lastReadPosition
            if savedPosition > 0 {
                
                guard let document = pdfView.document else { return }
                let totalPages = document.pageCount
                let targetPage = Int(savedPosition * Float(totalPages - 1))
                
                if targetPage >= 0 && targetPage < totalPages {
                    if let page = document.page(at: targetPage) {
                        pdfView.go(to: page)
                        
                        // Also update the last saved position for the timer
                        self.lastSavedPosition = savedPosition
                    }
                }
            } else {
            }
        }
        
        // Update progress view
        updateReadingProgress()
    }
    
    
    private func configurePDFScalingOptimized() {
        guard let pdfView = pdfView,
              let document = pdfView.document,
              document.pageCount > 0 else { return }
        
        // Simplified scaling configuration
        pdfView.autoScales = true
        
        // Set minimum and maximum scale factors for better UX
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = isLargeDocument ? 3.0 : 5.0 // Lower max for large docs
        
        // Use fit-to-width as default for better reading experience
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        }
    }
    
    private func getCurrentReadingProgress() -> Float {
        if !textView.isHidden {
            let contentHeight = textView.contentSize.height
            let offset = textView.contentOffset.y
            return Float(offset / max(contentHeight - textView.bounds.height, 1))
        } else if let pdfView = pdfView,
                  let document = pdfView.document,
                  let currentPage = pdfView.currentPage {
            let pageIndex = document.index(for: currentPage)
            return Float(pageIndex) / Float(max(document.pageCount - 1, 1))
        }
        return 0.0
    }
}

extension ModernBookReaderViewController: ModernNavigationHeaderDelegate {
    func didTapBack() {
        // Check if we're in a navigation stack
        if let navController = navigationController, navController.viewControllers.count > 1 {
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

// MARK: - SearchNavigatorViewDelegate
extension ModernBookReaderViewController: SearchNavigatorViewDelegate {
    func searchNavigatorDidTapNext(_ navigator: SearchNavigatorView) {
        guard let pdfView = pdfView else { return }
        let nextIndex = searchResultIndex + 1
        navigateToSearchResult(at: nextIndex >= searchSelections.count ? 0 : nextIndex, in: pdfView)
    }

    func searchNavigatorDidTapPrevious(_ navigator: SearchNavigatorView) {
        guard let pdfView = pdfView else { return }
        let previousIndex = searchResultIndex - 1
        navigateToSearchResult(at: previousIndex < 0 ? searchSelections.count - 1 : previousIndex, in: pdfView)
    }

    func searchNavigatorDidTapClose(_ navigator: SearchNavigatorView) {
        clearSearchResults()
    }
}

// MARK: - NotesPeekViewDelegate
extension ModernBookReaderViewController: NotesPeekViewDelegate {
    func notesPeekViewDidTapOpen(_ view: NotesPeekView) {
        didTapNotes()
    }
}

extension ModernBookReaderViewController: TTSMiniControllerViewDelegate {
    func ttsControllerDidTapPlay(_ controller: TTSMiniControllerView) {
        let service = TextToSpeechService.shared
        if service.paused {
            service.resume()
        } else if !service.speaking {
            guard let text = currentTextForSpeech(), !text.isEmpty else {
                showQuickHint("No readable text")
                return
            }
            service.startReading(text: text)
        }
    }

    func ttsControllerDidTapPause(_ controller: TTSMiniControllerView) {
        TextToSpeechService.shared.pause()
    }

    func ttsControllerDidTapStop(_ controller: TTSMiniControllerView) {
        TextToSpeechService.shared.stop()
    }
}

// MARK: - TextToSpeechDelegate
extension ModernBookReaderViewController: TextToSpeechDelegate {
    func speechDidStart() {
        ttsControllerView.isHidden = false
        ttsControllerView.alpha = 1
        ttsControllerView.setState(.playing)
    }

    func speechDidPause() {
        ttsControllerView.setState(.paused)
    }

    func speechDidResume() {
        ttsControllerView.setState(.playing)
    }

    func speechDidStop() {
        ttsControllerView.setState(.idle)
        ttsControllerView.updateProgress(0)
        ttsControllerView.isHidden = true
    }

    func speechDidFinish() {
        speechDidStop()
    }

    func speechDidUpdatePosition(_ position: Int) {
        let progress = TextToSpeechService.shared.progress
        ttsControllerView.updateProgress(progress)
    }
}
// MARK: - AddBookmarkViewDelegate
extension ModernBookReaderViewController: AddBookmarkViewDelegate {
    
    func addBookmarkView(_ view: AddBookmarkView, didCreateBookmarkWithTitle title: String, note: String?, type: BookmarkItem.BookmarkType) {
        guard let book = currentBook else { return }
        
        // Add the bookmark
        if let pdfView = pdfView, pdfView.superview != nil {
            _ = BookmarkManager.shared.addBookmarkFromPDF(
                bookId: book.id,
                bookTitle: book.title,
                pdfView: pdfView,
                title: title,
                note: note,
                type: type
            )
        } else if textView.superview != nil {
            _ = BookmarkManager.shared.addBookmarkFromText(
                bookId: book.id,
                bookTitle: book.title,
                textView: textView,
                title: title,
                note: note,
                type: type
            )
        }
        
        // Remove the view with animation
        UIView.animate(withDuration: 0.3, animations: {
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            view.removeFromSuperview()
            self.addBookmarkView = nil
        }
        
        // Show confirmation
        showBookmarkConfirmation()
        updateToolbarButtonStates()
    }
    
    func addBookmarkViewDidCancel(_ view: AddBookmarkView) {
        // Remove the view with animation
        UIView.animate(withDuration: 0.3, animations: {
            view.alpha = 0
            view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            view.removeFromSuperview()
            self.addBookmarkView = nil
        }
    }
}

// MARK: - Bookmark Sidebar Delegate
extension ModernBookReaderViewController: BookmarkSidebarDelegate {
    func bookmarkSidebar(_ sidebar: BookmarkSidebarView, didSelectBookmark bookmark: BookmarkItem) {
        // Navigate to the selected bookmark
        if let pdfView = pdfView, pdfView.superview != nil {
            _ = BookmarkManager.shared.navigateToBookmark(bookmark, in: pdfView)
        } else if textView.superview != nil {
            _ = BookmarkManager.shared.navigateToBookmark(bookmark, in: textView)
        }
    }
    
    func bookmarkSidebarDidRequestNewBookmark(_ sidebar: BookmarkSidebarView) {
        // Hide sidebar and show add bookmark view
        sidebar.hide()
        showAddBookmarkView()
    }
}

// MARK: - ImageAnalysisInteractionDelegate
@available(iOS 16.0, *)
extension ModernBookReaderViewController: ImageAnalysisInteractionDelegate {
    
    func interaction(_ interaction: ImageAnalysisInteraction, shouldBeginAt point: CGPoint, for interactionType: ImageAnalysisInteraction.InteractionTypes) -> Bool {
        // Allow all interaction types
        return true
    }
    
    func interaction(_ interaction: ImageAnalysisInteraction, highlightSelectedItemsDidChange highlightSelectedItems: Bool) {
        // Handle highlight changes if needed
        if highlightSelectedItems {
        }
    }
    
    func contentsRect(for interaction: ImageAnalysisInteraction) -> CGRect {
        // Return the visible area of the PDF
        return pdfView?.documentView?.bounds ?? .zero
    }
}

// MARK: - BookSearchDelegate
extension ModernBookReaderViewController: BookSearchDelegate {
    func bookSearch(_ searchView: BookSearchView, didSelectResult result: BookSearchResult) {
        
        guard let pdfView = pdfView else {
            return
        }
        
        // First, try to navigate using the selection (more precise)
        if let selection = result.selection,
           let page = selection.pages.first {
            
            pdfView.go(to: page)
            
            // Highlight the selection temporarily
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                pdfView.setCurrentSelection(selection, animate: true)
                
                // Clear selection after showing it
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    pdfView.clearSelection()
                }
            }
            
        } else if let document = pdfView.document,
                  result.pageNumber > 0 && result.pageNumber <= document.pageCount {
            
            // Fallback: navigate by page number
            let page = document.page(at: result.pageNumber - 1)
            pdfView.go(to: page!)
            
            // Show a brief visual indicator
            showPageNavigationFeedback(pageNumber: result.pageNumber)
            
        } else {
            showAlert(title: "Navigation Error", message: "Could not navigate to page \(result.pageNumber)")
        }
    }
    
    private func showPageNavigationFeedback(pageNumber: Int) {
        // Create a temporary label to show page navigation
        let feedbackLabel = UILabel()
        feedbackLabel.text = "Page \(pageNumber)"
        feedbackLabel.textColor = .white
        feedbackLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        feedbackLabel.textAlignment = .center
        feedbackLabel.font = .boldSystemFont(ofSize: 16)
        feedbackLabel.layer.cornerRadius = 8
        feedbackLabel.clipsToBounds = true
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(feedbackLabel)
        
        NSLayoutConstraint.activate([
            feedbackLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            feedbackLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            feedbackLabel.widthAnchor.constraint(equalToConstant: 120),
            feedbackLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Animate in and out
        feedbackLabel.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            feedbackLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0, animations: {
                feedbackLabel.alpha = 0
            }) { _ in
                feedbackLabel.removeFromSuperview()
            }
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension ModernBookReaderViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedURL = urls.first else { return }
        
        
        // Find the book that needs re-uploading
        guard let bookToUpdate = bookPendingReupload else {
            showErrorMessage("Could not identify which book to update")
            return
        }
        
        // Clear the pending reupload reference
        bookPendingReupload = nil
        
        // Start accessing the security-scoped resource
        guard selectedURL.startAccessingSecurityScopedResource() else {
            showErrorMessage("Unable to access the selected file")
            return
        }
        
        defer { selectedURL.stopAccessingSecurityScopedResource() }
        
        // Copy file to documents directory
        // Validate file before processing
        switch SecurityValidator.validateFileUpload(at: selectedURL) {
        case .failure(let error):
            self.showQuickHint("Invalid file: \(error.localizedDescription)")
            return
        case .success:
            break
        }
        
        // Perform file operations on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let sanitizedFileName = SecurityValidator.sanitizeFileName(selectedURL.lastPathComponent)
            let destinationURL = documentsPath.appendingPathComponent(sanitizedFileName)
            
            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file
                try FileManager.default.copyItem(at: selectedURL, to: destinationURL)
                
                // Upload to Firebase and update the book
                UnifiedFirebaseStorage.shared.uploadBook(
                    fileURL: destinationURL, 
                    title: bookToUpdate.title, 
                    author: bookToUpdate.author
                ) { [weak self] result in
                    DispatchQueue.main.async {
                    switch result {
                    case .success(let updatedBook):
                        // Update the current book with new file path
                        self?.currentBook = updatedBook
                        // Try loading the book again
                        self?.loadBookContent(updatedBook)
                    case .failure(let error):
                        self?.showErrorMessage("Failed to upload file: \(error.localizedDescription)")
                    }
                }
            }
            } catch {
                DispatchQueue.main.async {
                    self.showErrorMessage("Error copying file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        bookPendingReupload = nil // Clear the reference
    }
}
