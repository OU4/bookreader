import UIKit
import PDFKit
import UniformTypeIdentifiers
import AVFoundation

class BookReaderViewController: UIViewController {
    
    // MARK: - UI Components
    let textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.backgroundColor = .systemBackground
        tv.font = UIFont(name: "Georgia", size: 18)
        tv.textColor = .label
        tv.textAlignment = .justified
        tv.translatesAutoresizingMaskIntoConstraints = false
        
        // Force initial colors to ensure visibility
        tv.textColor = UIColor.label
        tv.backgroundColor = UIColor.systemBackground
        
        // Enhanced Kindle-like styling
        tv.textContainerInset = UIEdgeInsets(top: 32, left: 28, bottom: 32, right: 28)
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainer.lineBreakMode = .byWordWrapping
        
        // Smooth scrolling like Kindle
        tv.isScrollEnabled = true
        tv.showsVerticalScrollIndicator = false
        tv.showsHorizontalScrollIndicator = false
        tv.bounces = true
        tv.alwaysBounceVertical = true
        tv.decelerationRate = .fast
        
        // Better selection behavior
        tv.isSelectable = true
        tv.dataDetectorTypes = []
        
        return tv
    }()
    
    let pdfView: PDFView = {
        let pv = PDFView()
        pv.autoScales = true
        pv.displayMode = .singlePage
        pv.displayDirection = .vertical
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.isHidden = true
        
        // Better settings for Arabic reading
        pv.backgroundColor = .systemBackground
        pv.maxScaleFactor = 5.0
        pv.minScaleFactor = 0.5
        
        // Enable smooth scrolling and zooming
        pv.usePageViewController(true, withViewOptions: nil)
        
        return pv
    }()
    
    // Live text selection overlay
    private lazy var liveTextSelectionView: LiveTextSelectionView = {
        let view = LiveTextSelectionView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        view.isHidden = true
        return view
    }()
    
    private let bottomToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        return toolbar
    }()
    
    private let progressSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    // MARK: - Properties
    private var currentBook: Book?
    private var currentPDFDocument: PDFDocument?
    private var extractedText: String = ""
    private var isShowingExtractedText = true
    
    private var fontSize: CGFloat = 18 {
        didSet {
            updateFontSize()
        }
    }
    
    private var isDarkMode = false {
        didSet {
            updateTheme()
        }
    }
    
    // Reading tracking
    private var sessionStartTime: Date?
    private var lastWordCount: Int = 0
    private var currentTheme: ReadingTheme = .light
    
    // Text selection for highlights
    private var selectedTextRange: NSRange?
    private var isSelectionMode = false
    
    // Reading timer widget
    private var readingTimerWidget: ReadingTimerWidget?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupToolbar()
        setupTextViewGestures()
        setupAppLifecycleObservers()
        
        // Enable swipe back gesture only from left edge
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        // Only show welcome message if no book is loaded
        if currentBook == nil {
            showWelcomeMessage()
        }
        
        
        // Load current theme
        loadCurrentTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update navigation bar based on navigation stack
        updateNavigationBarForContext()
        
        // Start reading session if book is loaded
        startReadingSessionIfNeeded()
    }
    
    private func updateNavigationBarForContext() {
        // Check if we're in a navigation stack (came from library)
        if let navController = navigationController, navController.viewControllers.count > 1 {
            // We're pushed from library, so show back button
            print("📱 Setting up back button - in navigation stack")
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Library",
                style: .plain,
                target: self,
                action: #selector(goBack)
            )
        } else {
            // We're the root controller, show library button
            print("📱 Setting up library button - root controller")
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "books.vertical"),
                style: .plain,
                target: self,
                action: #selector(showLibrary)
            )
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // End reading session when leaving the view
        endReadingSession()
        
        // Clean up observers
        NotificationCenter.default.removeObserver(
            self,
            name: .PDFViewPageChanged,
            object: pdfView
        )
    }
    
    deinit {
        // Clean up observers and end session
        endReadingSession()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Reading Session Management
    private func startReadingSessionIfNeeded() {
        guard let book = currentBook else { 
            print("❌ Cannot start reading session - no book loaded")
            return 
        }
        
        print("📖 Starting reading session for: \(book.title)")
        ReadingSessionTracker.shared.startSession(for: book)
        sessionStartTime = Date()
        
        // Show reading timer widget
        showReadingTimerWidget()
        
        // Update progress tracking
        updateReadingProgress()
        print("✅ Reading session started successfully")
    }
    
    private func endReadingSession() {
        ReadingSessionTracker.shared.endCurrentSession()
        sessionStartTime = nil
        
        // Hide reading timer widget
        hideReadingTimerWidget()
    }
    
    private func pauseReadingSession() {
        ReadingSessionTracker.shared.pauseSession()
        readingTimerWidget?.pauseSession()
    }
    
    private func resumeReadingSession() {
        ReadingSessionTracker.shared.resumeSession()
        readingTimerWidget?.resumeSession()
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appWillResignActive() {
        // Pause session when app becomes inactive (calls, notifications, etc.)
        pauseReadingSession()
    }
    
    @objc private func appDidBecomeActive() {
        // Resume session when app becomes active
        if currentBook != nil {
            resumeReadingSession()
        }
    }
    
    @objc private func appDidEnterBackground() {
        // End session when app goes to background
        endReadingSession()
    }
    
    @objc private func appWillEnterForeground() {
        // Restart session when app comes back to foreground
        startReadingSessionIfNeeded()
    }
    
    // MARK: - Reading Timer Widget
    private func showReadingTimerWidget() {
        guard readingTimerWidget == nil else { return }
        
        let widget = ReadingTimerWidget()
        readingTimerWidget = widget
        
        view.addSubview(widget)
        // Ensure widget appears above all other views
        view.bringSubviewToFront(widget)
        widget.translatesAutoresizingMaskIntoConstraints = false
        
        // Position widget in top-right corner initially
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
        
        print("📱 Reading timer widget shown with alpha: \(widget.alpha)")
    }
    
    private func hideReadingTimerWidget() {
        guard let widget = readingTimerWidget else { return }
        
        widget.endSession()
        readingTimerWidget = nil
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(textView)
        view.addSubview(pdfView)
        view.addSubview(liveTextSelectionView)
        view.addSubview(bottomToolbar)
        view.addSubview(progressSlider)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Text View
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: progressSlider.topAnchor, constant: -10),
            
            // PDF View
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: progressSlider.topAnchor, constant: -10),
            
            // Live Text Selection Overlay (matches PDF View bounds)
            liveTextSelectionView.topAnchor.constraint(equalTo: pdfView.topAnchor),
            liveTextSelectionView.leadingAnchor.constraint(equalTo: pdfView.leadingAnchor),
            liveTextSelectionView.trailingAnchor.constraint(equalTo: pdfView.trailingAnchor),
            liveTextSelectionView.bottomAnchor.constraint(equalTo: pdfView.bottomAnchor),
            
            // Progress Slider
            progressSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressSlider.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor, constant: -10),
            progressSlider.heightAnchor.constraint(equalToConstant: 30),
            
            // Bottom Toolbar
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        
        // Progress slider action
        progressSlider.addTarget(self, action: #selector(progressChanged), for: .valueChanged)
    }
    
    private func setupNavigationBar() {
        title = "Book Reader"
        
        // Check if we're in a navigation stack (came from library)
        if let navController = navigationController, navController.viewControllers.count > 1 {
            // We're pushed from library, so show back button
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"),
                style: .plain,
                target: self,
                action: #selector(goBack)
            )
        } else {
            // We're the root controller, show library button
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "books.vertical"),
                style: .plain,
                target: self,
                action: #selector(showLibrary)
            )
        }
        
        // Settings button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
    }
    
    @objc private func goBack() {
        print("🔙 Going back to library...")
        navigationController?.popViewController(animated: true)
    }
    
    private func updateNavigationForPDF() {
        // For PDF documents, show settings and optional text extraction
        if currentPDFDocument != nil {
            let settingsButton = UIBarButtonItem(
                image: UIImage(systemName: "gear"),
                style: .plain,
                target: self,
                action: #selector(showSettings)
            )
            
            // Add text extraction option
            let textButton = UIBarButtonItem(
                image: UIImage(systemName: "doc.text"),
                style: .plain,
                target: self,
                action: #selector(showTextExtractionOption)
            )
            textButton.accessibilityLabel = "Extract Text"
            
            navigationItem.rightBarButtonItems = [settingsButton, textButton]
        } else {
            navigationItem.rightBarButtonItems = [navigationItem.rightBarButtonItem].compactMap { $0 }
        }
    }
    
    @objc private func showTextExtractionOption() {
        guard let document = currentPDFDocument else { return }
        
        let alert = UIAlertController(
            title: "Text Extraction",
            message: "Would you like to extract text for easier reading?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Extract Text", style: .default) { [weak self] _ in
            self?.extractTextFromPDF(document: document)
        })
        
        alert.addAction(UIAlertAction(title: "Keep PDF View", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func extractTextFromPDF(document: PDFDocument) {
        // Show loading
        let loadingAlert = UIAlertController(title: "Extracting Text", message: "Please wait...", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        loadingAlert.view.addSubview(spinner)
        
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: loadingAlert.view.bottomAnchor, constant: -20)
        ])
        
        present(loadingAlert, animated: true)
        
        // Extract text in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let extractedText = self?.extractTextFromPDF(document) ?? ""
            
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if !extractedText.isEmpty {
                        // Show extracted text
                        self?.extractedText = extractedText
                        self?.isShowingExtractedText = true
                        self?.textView.isHidden = false
                        self?.pdfView.isHidden = true
                        self?.liveTextSelectionView.isHidden = true
                        self?.displayTextSafely(extractedText)
                    } else {
                        // Show error
                        let errorAlert = UIAlertController(
                            title: "No Text Found",
                            message: "This PDF appears to contain images. Continue with Live Text Selection.",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errorAlert, animated: true)
                    }
                }
            }
        }
    }
    
    @objc private func togglePDFView() {
        guard let document = currentPDFDocument else { return }
        
        isShowingExtractedText.toggle()
        
        if isShowingExtractedText && !extractedText.isEmpty {
            // Show formatted text
            pdfView.isHidden = true
            textView.isHidden = false
            formatTextContent(extractedText)
            
            // Show text formatting toolbar
            bottomToolbar.isHidden = false
        } else {
            // Show original PDF with graphics, tables, images
            textView.isHidden = true
            pdfView.isHidden = false
            pdfView.document = document
            
            // Configure PDF view for optimal viewing
            pdfView.autoScales = true
            pdfView.displayMode = .singlePage
            pdfView.displayDirection = .vertical
            
            // Start from first page
            if let firstPage = document.page(at: 0) {
                pdfView.go(to: firstPage)
            }
            
            // Show PDF navigation toolbar if needed
            setupPDFToolbar()
            bottomToolbar.isHidden = false
        }
        
        updateNavigationForPDF()
    }
    
    private func setupToolbar() {
        // Set toolbar background
        bottomToolbar.backgroundColor = .systemBackground
        bottomToolbar.barTintColor = .systemBackground
        
        let fontButton = UIBarButtonItem(
            image: UIImage(systemName: "textformat.size"),
            style: .plain,
            target: self,
            action: #selector(adjustFont)
        )
        
        let themeButton = UIBarButtonItem(
            image: UIImage(systemName: "moon"),
            style: .plain,
            target: self,
            action: #selector(showThemeSelector)
        )
        
        let highlightButton = UIBarButtonItem(
            image: UIImage(systemName: "highlighter"),
            style: .plain,
            target: self,
            action: #selector(toggleHighlightMode)
        )
        
        let notesButton = UIBarButtonItem(
            image: UIImage(systemName: "note.text"),
            style: .plain,
            target: self,
            action: #selector(showNotesAndHighlights)
        )
        
        let statsButton = UIBarButtonItem(
            image: UIImage(systemName: "chart.bar"),
            style: .plain,
            target: self,
            action: #selector(showReadingStats)
        )
        
        let searchButton = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(showSearchView)
        )
        
        
        let bookmarkButton = UIBarButtonItem(
            image: UIImage(systemName: "bookmark"),
            style: .plain,
            target: self,
            action: #selector(toggleBookmark)
        )
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        bottomToolbar.items = [fontButton, flexSpace, highlightButton, flexSpace, notesButton, flexSpace, statsButton, flexSpace, searchButton, flexSpace, themeButton, flexSpace, bookmarkButton]
        
        // Force layout to avoid constraint conflicts
        bottomToolbar.setNeedsLayout()
        bottomToolbar.layoutIfNeeded()
    }
    
    // MARK: - Setup Methods
    private func setupTextViewGestures() {
        // Add long press gesture for text selection and highlighting
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleTextSelection(_:)))
        longPressGesture.minimumPressDuration = 0.5
        textView.addGestureRecognizer(longPressGesture)
        
        // Enable text selection
        textView.isSelectable = true
        textView.isEditable = false
        
        // Set up scroll delegate for progress tracking
        textView.delegate = self
    }
    
    private func loadCurrentTheme() {
        if let themeData = UserDefaults.standard.data(forKey: "currentTheme"),
           let theme = try? JSONDecoder().decode(ReadingTheme.self, from: themeData) {
            currentTheme = theme
        }
        applyTheme(currentTheme)
    }
    
    // MARK: - New Feature Actions
    @objc private func handleTextSelection(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: textView)
        
        if let textPosition = textView.closestPosition(to: location),
           let range = textView.tokenizer.rangeEnclosingPosition(textPosition, with: .word, inDirection: .layout(.left)) {
            
            let selectedText = textView.text(in: range) ?? ""
            
            // Record activity for auto-pause detection
            readingTimerWidget?.recordActivity()
            
            // Show selection menu
            showTextSelectionMenu(for: selectedText, at: location)
        }
    }
    
    private func showTextSelectionMenu(for text: String, at location: CGPoint) {
        let alert = UIAlertController(title: "Text Actions", message: "\"\(text)\"", preferredStyle: .actionSheet)
        
        // Highlight action
        alert.addAction(UIAlertAction(title: "Highlight", style: .default) { [weak self] _ in
            self?.showHighlightColorPicker(for: text)
        })
        
        // Dictionary lookup
        alert.addAction(UIAlertAction(title: "Define", style: .default) { [weak self] _ in
            self?.lookupDefinition(for: text)
        })
        
        // Translate
        alert.addAction(UIAlertAction(title: "Translate", style: .default) { [weak self] _ in
            self?.translateText(text)
        })
        
        // Copy
        alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = text
        })
        
        // Add Note
        alert.addAction(UIAlertAction(title: "Add Note", style: .default) { [weak self] _ in
            self?.showAddNoteDialog(for: text)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = textView
            popover.sourceRect = CGRect(origin: location, size: CGSize(width: 1, height: 1))
        }
        
        present(alert, animated: true)
    }
    
    @objc private func toggleHighlightMode() {
        isSelectionMode.toggle()
        
        let highlightButton = bottomToolbar.items?.first { item in
            item.image == UIImage(systemName: "highlighter")
        }
        
        if isSelectionMode {
            highlightButton?.tintColor = .systemYellow
            showMessage("Tap and drag to highlight text", type: .info)
        } else {
            highlightButton?.tintColor = .label
        }
    }
    
    @objc private func showNotesAndHighlights() {
        guard let book = currentBook else { return }
        
        let notesVC = NotesAndHighlightsViewController(bookId: book.id)
        let navController = UINavigationController(rootViewController: notesVC)
        present(navController, animated: true)
    }
    
    @objc private func showSearchView() {
        guard let book = currentBook else { return }
        
        let searchVC = BookSearchViewController(book: book, text: extractedText)
        let navController = UINavigationController(rootViewController: searchVC)
        present(navController, animated: true)
    }
    
    @objc private func showReadingStats() {
        let statsVC = ReadingStatsViewController()
        let navController = UINavigationController(rootViewController: statsVC)
        present(navController, animated: true)
    }
    
    @objc private func showThemeSelector() {
        let alert = UIAlertController(title: "Reading Theme", message: nil, preferredStyle: .actionSheet)
        
        for theme in ReadingTheme.allCases {
            let action = UIAlertAction(title: theme.displayName, style: .default) { [weak self] _ in
                self?.applyTheme(theme)
                self?.currentTheme = theme
                self?.saveCurrentTheme()
            }
            
            if theme == currentTheme {
                action.setValue(true, forKey: "checked")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = bottomToolbar.items?.first { $0.image == UIImage(systemName: "moon") }
        }
        
        present(alert, animated: true)
    }
    
    private func showHighlightColorPicker(for text: String) {
        let alert = UIAlertController(title: "Highlight Color", message: nil, preferredStyle: .actionSheet)
        
        for color in Highlight.HighlightColor.allCases {
            let action = UIAlertAction(title: color.displayName, style: .default) { [weak self] _ in
                self?.addHighlight(text: text, color: color)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func addHighlight(text: String, color: Highlight.HighlightColor) {
        guard let book = currentBook else { return }
        
        // Calculate position in text
        let position = TextPosition(startOffset: 0, endOffset: text.count) // Simplified for now
        
        NotesManager.shared.addHighlight(to: book.id, text: text, color: color, position: position)
        
        showMessage("Highlighted text", type: .success)
    }
    
    private func lookupDefinition(for word: String) {
        showLoadingView()
        
        TranslationService.shared.lookupDefinition(for: word) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoadingView()
                
                switch result {
                case .success(let definition):
                    self?.showDefinition(definition)
                case .failure(let error):
                    self?.showMessage("Definition not found: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
    
    private func translateText(_ text: String) {
        let alert = UIAlertController(title: "Translate to", message: nil, preferredStyle: .actionSheet)
        
        let languages = [
            ("ar", "Arabic"),
            ("es", "Spanish"),
            ("fr", "French"),
            ("de", "German"),
            ("it", "Italian"),
            ("ja", "Japanese"),
            ("ko", "Korean"),
            ("zh", "Chinese")
        ]
        
        for (code, name) in languages {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.performTranslation(text, to: code)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func performTranslation(_ text: String, to language: String) {
        showLoadingView()
        
        TranslationService.shared.translateText(text, to: language) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideLoadingView()
                
                switch result {
                case .success(let translation):
                    self?.showTranslation(translation)
                case .failure(let error):
                    self?.showMessage("Translation failed: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
    
    private func showAddNoteDialog(for text: String) {
        let alert = UIAlertController(title: "Add Note", message: "Selected text: \"\(text)\"", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Note title"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Note content"
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let book = self?.currentBook,
                  let title = alert.textFields?[0].text, !title.isEmpty,
                  let content = alert.textFields?[1].text, !content.isEmpty else { return }
            
            let position = TextPosition(startOffset: 0, endOffset: text.count)
            NotesManager.shared.addNote(to: book.id, title: title, content: content, position: position)
            
            self?.showMessage("Note added", type: .success)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Theme Management
    private func applyTheme(_ theme: ReadingTheme) {
        view.backgroundColor = theme.backgroundColor
        textView.backgroundColor = theme.backgroundColor
        textView.textColor = theme.textColor
        
        if isDarkMode != theme.isDarkMode {
            isDarkMode = theme.isDarkMode
        }
    }
    
    private func saveCurrentTheme() {
        if let data = try? JSONEncoder().encode(currentTheme) {
            UserDefaults.standard.set(data, forKey: "currentTheme")
        }
    }
    
    // MARK: - UI Helper Methods
    private func showLoadingView() {
        // Add loading spinner
    }
    
    private func hideLoadingView() {
        // Remove loading spinner
    }
    
    private func showDefinition(_ definition: WordDefinition) {
        let alert = UIAlertController(title: definition.word, message: nil, preferredStyle: .alert)
        
        var content = ""
        if let pronunciation = definition.pronunciation {
            content += "Pronunciation: \(pronunciation)\n\n"
        }
        
        if let partOfSpeech = definition.partOfSpeech {
            content += "Part of Speech: \(partOfSpeech)\n\n"
        }
        
        content += "Definitions:\n"
        for (index, def) in definition.definitions.enumerated() {
            content += "\(index + 1). \(def)\n"
        }
        
        if !definition.examples.isEmpty {
            content += "\nExamples:\n"
            for example in definition.examples.prefix(2) {
                content += "• \(example)\n"
            }
        }
        
        alert.message = content
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showTranslation(_ translation: Translation) {
        let alert = UIAlertController(title: "Translation", message: nil, preferredStyle: .alert)
        
        let content = """
        Original: \(translation.originalText)
        
        Translation: \(translation.translatedText)
        """
        
        alert.message = content
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showMessage(_ message: String, type: MessageType) {
        let alert = UIAlertController(title: type.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func toggleTextToSpeech() {
        let ttsService = TextToSpeechService.shared
        
        if ttsService.speaking {
            ttsService.pause()
        } else if ttsService.paused {
            ttsService.resume()
        } else {
            // Start TTS with current text
            if !extractedText.isEmpty {
                let alert = UIAlertController(title: "Text-to-Speech", message: "Start reading from current position?", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Start", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    ttsService.delegate = self
                    ttsService.startReading(text: self.extractedText)
                    self.updateTTSButton(isPlaying: true)
                })
                
                alert.addAction(UIAlertAction(title: "Settings", style: .default) { [weak self] _ in
                    self?.showTTSSettings()
                })
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                present(alert, animated: true)
            }
        }
    }
    
    private func showTTSSettings() {
        let settingsVC = TTSSettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
    
    private func updateTTSButton(isPlaying: Bool) {
        let ttsButton = bottomToolbar.items?.first { item in
            item.image == UIImage(systemName: "speaker.2") || item.image == UIImage(systemName: "pause.circle")
        }
        
        if isPlaying {
            ttsButton?.image = UIImage(systemName: "pause.circle")
        } else {
            ttsButton?.image = UIImage(systemName: "speaker.2")
        }
    }
    
    // MARK: - Actions
    @objc private func showLibrary() {
        let libraryVC = LibraryViewController()
        libraryVC.delegate = self
        let navController = UINavigationController(rootViewController: libraryVC)
        present(navController, animated: true)
    }
    
    @objc private func showSettings() {
        let settingsVC = SettingsViewController()
        settingsVC.delegate = self
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
    
    @objc private func adjustFont() {
        let alertController = UIAlertController(title: "Reading Settings", message: nil, preferredStyle: .actionSheet)
        
        // Font Size options
        alertController.addAction(UIAlertAction(title: "Font Size", style: .default) { [weak self] _ in
            self?.showFontSizePicker()
        })
        
        // Font Type options  
        alertController.addAction(UIAlertAction(title: "Font Style", style: .default) { [weak self] _ in
            self?.showFontStylePicker()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alertController.popoverPresentationController {
            popover.barButtonItem = bottomToolbar.items?.first
        }
        
        present(alertController, animated: true)
    }
    
    private func showFontSizePicker() {
        let alertController = UIAlertController(title: "Font Size", message: nil, preferredStyle: .actionSheet)
        
        let sizes: [CGFloat] = [14, 16, 18, 20, 22, 24, 28, 32]
        for size in sizes {
            let action = UIAlertAction(title: "\(Int(size))pt", style: .default) { [weak self] _ in
                self?.fontSize = size
            }
            if size == fontSize {
                action.setValue(true, forKey: "checked")
            }
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertController, animated: true)
    }
    
    private func showFontStylePicker() {
        let alertController = UIAlertController(title: "Font Style", message: nil, preferredStyle: .actionSheet)
        
        let fonts = [
            ("Georgia", "Georgia (Serif)"),
            ("Palatino", "Palatino (Serif)"),
            ("Times New Roman", "Times New Roman"),
            ("Baskerville", "Baskerville (Classic)"),
            ("Charter", "Charter (Modern)"),
            ("Avenir", "Avenir (Sans-serif)"),
            ("Helvetica", "Helvetica (Clean)"),
            ("San Francisco", "SF Pro (System)")
        ]
        
        for (fontName, displayName) in fonts {
            let action = UIAlertAction(title: displayName, style: .default) { [weak self] _ in
                self?.changeFontStyle(to: fontName)
            }
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertController, animated: true)
    }
    
    private func changeFontStyle(to fontName: String) {
        // Update the text view with new font while keeping current content
        if let currentText = textView.text, !currentText.isEmpty {
            formatTextContent(currentText, fontName: fontName)
        }
    }
    
    @objc private func toggleTheme() {
        isDarkMode.toggle()
    }
    
    @objc private func toggleBookmark() {
        // TODO: Implement bookmark functionality
        print("Bookmark toggled")
    }
    
    @objc private func progressChanged() {
        // Update reading position based on progress slider
        guard var book = currentBook else { return }
        
        let newPosition = progressSlider.value / 100.0
        book.lastReadPosition = newPosition
        currentBook = book
        
        // Save updated book position
        BookStorage.shared.saveBook(book)
        
        // Update session tracker
        updateReadingProgress()
        
        // Jump to position if text view
        if !textView.isHidden {
            jumpToTextPosition(newPosition)
        }
    }
    
    // MARK: - Progress Tracking
    private func updateReadingProgress() {
        guard var book = currentBook else { return }
        
        let currentPosition = getCurrentReadingPosition()
        let wordsOnScreen = estimateWordsOnScreen()
        
        // Update session tracker
        ReadingSessionTracker.shared.updateReadingProgress(
            position: currentPosition,
            wordsOnScreen: wordsOnScreen
        )
        
        // Update progress slider
        progressSlider.value = currentPosition * 100
        
        // Update timer widget
        readingTimerWidget?.updateProgress(currentPosition)
        
        // Check for achievements
        checkForAchievements()
        
        // Save reading position
        book.lastReadPosition = currentPosition
        currentBook = book
        BookStorage.shared.saveBook(book)
    }
    
    private func getCurrentReadingPosition() -> Float {
        if !textView.isHidden {
            // Text view position based on scroll
            let contentHeight = textView.contentSize.height
            let scrollOffset = textView.contentOffset.y
            let visibleHeight = textView.bounds.height
            
            if contentHeight > visibleHeight {
                return Float(scrollOffset / (contentHeight - visibleHeight))
            }
        } else if !pdfView.isHidden, let document = currentPDFDocument {
            // PDF position based on page
            if let currentPage = pdfView.currentPage {
                let pageIndex = document.index(for: currentPage)
                return Float(pageIndex) / Float(document.pageCount)
            }
        }
        
        return currentBook?.lastReadPosition ?? 0
    }
    
    private func estimateWordsOnScreen() -> Int {
        if !textView.isHidden && !textView.text.isEmpty {
            // Get actual visible text and count words accurately
            let visibleRect = textView.bounds
            let glyphRange = textView.layoutManager.glyphRange(forBoundingRect: visibleRect, in: textView.textContainer)
            let characterRange = textView.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            
            if characterRange.location != NSNotFound && characterRange.location < textView.text.count {
                let endLocation = min(characterRange.location + characterRange.length, textView.text.count)
                let adjustedRange = NSRange(location: characterRange.location, length: endLocation - characterRange.location)
                
                let visibleText = (textView.text as NSString).substring(with: adjustedRange)
                let wordCount = countWords(in: visibleText)
                
                return max(wordCount, 50) // Minimum 50 words for reasonable estimates
            }
        }
        
        // For PDF or when text view is empty
        if !pdfView.isHidden && pdfView.currentPage != nil {
            // Get text from current PDF page for more accurate count
            if let pageText = pdfView.currentPage?.string {
                let pageWordCount = countWords(in: pageText)
                return max(pageWordCount, 200) // Minimum 200 words per PDF page
            }
        }
        
        return 300 // Fallback estimate
    }
    
    private func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    private func jumpToTextPosition(_ position: Float) {
        guard !textView.isHidden else { return }
        
        let contentHeight = textView.contentSize.height
        let visibleHeight = textView.bounds.height
        
        if contentHeight > visibleHeight {
            let targetOffset = CGFloat(position) * (contentHeight - visibleHeight)
            textView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: true)
        }
    }
    
    private func trackScrollProgress() {
        // Called when user scrolls to update progress
        updateReadingProgress()
    }
    
    // MARK: - Helper Methods
    private func showWelcomeMessage() {
        pdfView.isHidden = true
        textView.isHidden = false
        
        let welcomeText = """
        Welcome to Book Reader!
        
        📚 To get started:
        • Tap the library icon (📚) in the top left to add books
        • Tap the settings icon (⚙️) in the top right to customize your reading experience
        
        Supported formats:
        • PDF documents (with Live Text Selection)
        • Text files (.txt)
        • EPUB books
        
        You can import books from Files app or cloud storage.
        
        Happy reading! 📖
        """
        
        formatTextContent(welcomeText)
    }
    
    private func showFileNotFoundMessage(for bookTitle: String) {
        pdfView.isHidden = true
        textView.isHidden = false
        
        let errorText = """
        📚 File Not Found
        
        The book "\(bookTitle)" could not be loaded.
        
        This can happen when:
        • The app was updated/rebuilt (common in development)
        • The file was moved or deleted
        • Storage permissions changed
        
        To fix this:
        • Re-import the book using the library (📚) button
        • Or try importing a new book
        
        Sample books are always available in your library!
        """
        
        formatTextContent(errorText)
    }
    
    private func showPDFLoadError() {
        pdfView.isHidden = true
        textView.isHidden = false
        
        let errorText = """
        📄 PDF Loading Error
        
        There was a problem loading this PDF file.
        
        This could be due to:
        • File corruption or damage
        • Unsupported PDF format
        • File permission issues
        • Large file size causing memory issues
        
        Please try:
        • Re-importing the file
        • Using a different PDF file
        • Checking if the file opens in other apps
        
        You can also try the original PDF view by tapping the toggle button if available.
        """
        
        formatTextContent(errorText)
    }
    
    private func updateFontSize() {
        // Re-format the current text with new font size
        if let currentText = textView.text, !currentText.isEmpty {
            formatTextContent(currentText)
        }
    }
    
    private func updateTheme() {
        if isDarkMode {
            overrideUserInterfaceStyle = .dark
            view.backgroundColor = .black
        } else {
            overrideUserInterfaceStyle = .light
            view.backgroundColor = .systemBackground
        }
        
        // Re-apply safe formatting with new theme colors
        if let currentText = textView.text, !currentText.isEmpty {
            let currentFont = textView.font?.fontName ?? "Georgia"
            displayTextSafely(currentText, fontName: currentFont)
        }
    }
    
    // MARK: - Book Loading
    func loadBook(_ book: Book) {
        print("📚 BookReaderViewController.loadBook() called")
        print("📖 Loading book: \(book.title) from path: \(book.filePath)")
        print("📄 Book type: \(book.type)")
        
        currentBook = book
        title = book.title
        
        // Update navigation bar for book reading mode
        setupNavigationBar()
        
        // Hide welcome message and prepare for book content
        textView.isHidden = true
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: book.filePath) else {
            print("❌ File does not exist at path: \(book.filePath)")
            showFileNotFoundMessage(for: book.title)
            return
        }
        
        print("✅ File exists, proceeding with loading...")
        
        switch book.type {
        case .pdf:
            print("📄 Loading as PDF...")
            loadPDF(from: book.filePath)
        case .text, .epub:
            print("📝 Loading as text...")
            loadText(from: book.filePath)
        case .image:
            showUnsupportedFormatMessage()
        }
    }
    
    private func loadPDF(from path: String) {
        let url = URL(fileURLWithPath: path)
        
        // Check if file exists and is readable
        guard FileManager.default.fileExists(atPath: path),
              FileManager.default.isReadableFile(atPath: path) else {
            print("PDF file does not exist or is not readable at path: \(path)")
            showFileNotFoundMessage(for: currentBook?.title ?? "Unknown")
            return
        }
        
        guard let document = PDFDocument(url: url) else { 
            print("Failed to load PDF from path: \(path)")
            showPDFLoadError()
            return 
        }
        
        // Check if document has any pages
        guard document.pageCount > 0 else {
            print("PDF document has no pages: \(path)")
            showPDFLoadError()
            return
        }
        
        // Store PDF document
        currentPDFDocument = document
        
        // Always open PDF with Live Text Selection directly - no text extraction
        print("📄 Opening PDF with Live Text Selection")
        enableLiveTextSelection(document: document)
    }
    
    private func handlePDFProcessingResult(_ extractedText: String, document: PDFDocument) {
        print("🔍 HANDLING PDF RESULT:")
        print("   - Extracted text length: \(extractedText.count)")
        print("   - Is empty: \(extractedText.isEmpty)")
        print("   - First 200 chars: \(String(extractedText.prefix(200)))")
        
        self.extractedText = extractedText
        
        if !extractedText.isEmpty {
            // Display extracted text directly
            self.isShowingExtractedText = true
            self.pdfView.isHidden = true
            self.textView.isHidden = false
            self.displayTextSafely(extractedText)
            self.updateNavigationForPDF()
        } else {
            print("❌ No text found - enabling Live Text Selection")
            // PDF contains images instead of text - use Live Text Selection directly
            self.enableLiveTextSelection(document: document)
        }
    }
    
    
    private func displayTextSafely(_ text: String, fontName: String = "Georgia") {
        print("🎨 DISPLAYING TEXT SAFELY:")
        print("   - Input length: \(text.count)")
        
        // Step 1: ALWAYS clear attributed text first - this prevents invisible text
        textView.attributedText = nil
        
        // Step 2: Set explicit colors that work reliably
        let textColor: UIColor
        let backgroundColor: UIColor
        
        if isDarkMode {
            textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
            backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        } else {
            textColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
            backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
        
        textView.backgroundColor = backgroundColor
        
        // Step 3: Fix all visibility issues
        textView.alpha = 1.0
        textView.isOpaque = true
        textView.layer.opacity = 1.0
        textView.layer.mask = nil
        textView.transform = CGAffineTransform.identity
        textView.isHidden = false
        
        // Step 4: Handle font names
        let actualFontName: String
        switch fontName {
        case "San Francisco":
            actualFontName = "SF Pro Text"
        case "Times New Roman":
            actualFontName = "TimesNewRomanPSMT"
        default:
            actualFontName = fontName
        }
        
        // Step 5: Set font and basic properties
        textView.font = UIFont(name: actualFontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        textView.textColor = textColor
        
        // Step 6: Configure text container for better layout
        textView.textAlignment = .justified
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainerInset = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        
        // Step 7: Clean and format the text content
        let cleanedText = cleanAndFormatText(text)
        let displayText = String(cleanedText.prefix(75000)) // Increased limit
        
        // Step 8: Use SIMPLE text assignment first (no attributed text yet)
        textView.text = displayText
        
        // Step 9: Force immediate layout
        textView.setNeedsDisplay()
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        
        // Step 10: After a delay, apply better formatting if text is visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !self.textView.text.isEmpty && self.textView.alpha > 0 {
                self.applyBetterFormatting(to: displayText, with: textColor, font: self.textView.font!)
            }
        }
        
        // Scroll to top
        textView.setContentOffset(.zero, animated: false)
        
        print("✅ Displayed \(displayText.count) characters safely")
    }
    
    private func cleanAndFormatText(_ text: String) -> String {
        var cleaned = text
        
        // Fix common PDF text extraction issues
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?<!\\.)\\n(?![A-Z])", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\.(?! )", with: ". ", options: .regularExpression)
        
        // Add proper paragraph breaks
        cleaned = cleaned.replacingOccurrences(of: "\\. ([A-Z])", with: ".\n\n$1", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func applyBetterFormatting(to text: String, with color: UIColor, font: UIFont) {
        // Only apply attributed formatting if plain text is visible
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.alignment = .justified
        paragraphStyle.firstLineHeadIndent = 16
        paragraphStyle.lineHeightMultiple = 1.2
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
            .kern: 0.1
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        
        // Apply attributed text carefully
        self.textView.attributedText = attributedText
        
        // Verify it's still visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.textView.text.isEmpty || self.textView.alpha < 1 {
                // If formatting broke visibility, revert to plain text
                print("⚠️ Formatting broke visibility, reverting to plain text")
                self.textView.attributedText = nil
                self.textView.text = text
                self.textView.textColor = color
            }
        }
    }
    
    
    private func enableLiveTextSelection(document: PDFDocument) {
        // Show PDF with Live Text overlay
        self.isShowingExtractedText = false
        self.textView.isHidden = true
        self.pdfView.isHidden = false
        self.liveTextSelectionView.isHidden = false
        
        self.pdfView.document = document
        
        // Configure PDF view for Live Text
        self.pdfView.autoScales = true
        self.pdfView.displayMode = .singlePage
        self.pdfView.displayDirection = .vertical
        
        // Go to first page
        if let firstPage = document.page(at: 0) {
            self.pdfView.go(to: firstPage)
            
            // Enable text recognition for current page
            enableTextRecognitionForCurrentPage()
        }
        
        // Set up notification for page changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pdfPageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        self.updateNavigationForPDF()
        self.setupPDFToolbar()
    }
    
    private func enableTextRecognitionForCurrentPage() {
        guard let currentPage = pdfView.currentPage else { return }
        
        // Enable text recognition for the current page
        liveTextSelectionView.enableTextSelection(for: currentPage, in: pdfView.bounds)
    }
    
    @objc private func pdfPageChanged() {
        // Update text recognition when page changes
        enableTextRecognitionForCurrentPage()
        
        // Track page turn and update progress
        trackPageTurn()
        updateReadingProgress()
    }
    
    
    private func showOriginalPDF(document: PDFDocument) {
        self.isShowingExtractedText = false
        self.textView.isHidden = true
        self.pdfView.isHidden = false
        self.liveTextSelectionView.isHidden = false // Show live text selection for PDFs
        self.pdfView.document = document
        
        // Enable text recognition for the first page
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.enableTextRecognitionForCurrentPage()
        }
        
        // Go to first page
        if let firstPage = document.page(at: 0) {
            self.pdfView.go(to: firstPage)
        }
        
        // Remove page change observer if it exists
        NotificationCenter.default.removeObserver(
            self,
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        self.updateNavigationForPDF()
        self.setupPDFToolbar()
    }
    
    private func setupPDFToolbar() {
        guard let document = currentPDFDocument else { return }
        
        let prevButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.left"),
            style: .plain,
            target: self,
            action: #selector(previousPage)
        )
        
        let nextButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.right"),
            style: .plain,
            target: self,
            action: #selector(nextPage)
        )
        
        // Page input field
        let pageButton = UIBarButtonItem(
            title: "1/\(document.pageCount)",
            style: .plain,
            target: self,
            action: #selector(showPageSelector)
        )
        
        let fitToWidthButton = UIBarButtonItem(
            image: UIImage(systemName: "rectangle.ratio.16.to.9"),
            style: .plain,
            target: self,
            action: #selector(fitToWidth)
        )
        
        let fitToPageButton = UIBarButtonItem(
            image: UIImage(systemName: "doc.fill"),
            style: .plain,
            target: self,
            action: #selector(fitToPage)
        )
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        bottomToolbar.items = [prevButton, flexSpace, pageButton, flexSpace, nextButton, flexSpace, fitToWidthButton, fitToPageButton]
        
        // Add swipe gestures
        addPDFGestures()
    }
    
    private func addPDFGestures() {
        // Add swipe gestures for page navigation
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(nextPage))
        leftSwipe.direction = .left
        pdfView.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(previousPage))
        rightSwipe.direction = .right
        pdfView.addGestureRecognizer(rightSwipe)
        
        // Add tap gesture for hiding/showing toolbar
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleToolbar))
        doubleTap.numberOfTapsRequired = 2
        pdfView.addGestureRecognizer(doubleTap)
    }
    
    @objc private func previousPage() {
        pdfView.goToPreviousPage(nil)
        updatePageLabel()
        trackPageTurn()
        updateReadingProgress()
    }
    
    @objc private func nextPage() {
        pdfView.goToNextPage(nil)
        updatePageLabel()
        trackPageTurn()
        updateReadingProgress()
    }
    
    private func trackPageTurn() {
        ReadingSessionTracker.shared.trackPageTurn()
        // Record activity for auto-pause detection
        readingTimerWidget?.recordActivity()
    }
    
    @objc private func fitToWidth() {
        pdfView.autoScales = false
        if let currentPage = pdfView.currentPage {
            let pageRect = currentPage.bounds(for: .mediaBox)
            let viewWidth = pdfView.bounds.width - 40 // Some padding
            let scale = viewWidth / pageRect.width
            pdfView.scaleFactor = scale
        }
    }
    
    @objc private func fitToPage() {
        pdfView.autoScales = true
        if let currentPage = pdfView.currentPage {
            pdfView.go(to: currentPage)
        }
    }
    
    @objc private func showPageSelector() {
        guard let document = currentPDFDocument else { return }
        
        let alert = UIAlertController(title: "Go to Page", message: "Enter page number (1-\(document.pageCount))", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Page number"
            textField.keyboardType = .numberPad
            if let currentPage = self.pdfView.currentPage {
                let currentIndex = document.index(for: currentPage)
                textField.text = "\(currentIndex + 1)"
            }
        }
        
        alert.addAction(UIAlertAction(title: "Go", style: .default) { [weak self] _ in
            if let text = alert.textFields?.first?.text,
               let pageNumber = Int(text),
               pageNumber >= 1,
               pageNumber <= document.pageCount,
               let page = document.page(at: pageNumber - 1) {
                self?.pdfView.go(to: page)
                self?.updatePageLabel()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    @objc private func toggleToolbar() {
        UIView.animate(withDuration: 0.3) {
            self.bottomToolbar.isHidden.toggle()
            self.progressSlider.isHidden.toggle()
        }
    }
    
    private func updatePageLabel() {
        guard let document = currentPDFDocument,
              let currentPage = pdfView.currentPage else { return }
        
        let pageIndex = document.index(for: currentPage)
        
        if let pageItem = bottomToolbar.items?[2] {
            pageItem.title = "\(pageIndex + 1)/\(document.pageCount)"
        }
    }
    
    
    
    
    private func extractTextFromPDF(_ document: PDFDocument) -> String {
        var allPages: [String] = []
        let pageCount = document.pageCount
        
        print("Starting PDF text extraction for \(pageCount) pages...")
        
        // Extract text from each page with error handling
        for i in 0..<pageCount {
            do {
                if let page = document.page(at: i) {
                    if let pageText = page.string, !pageText.isEmpty {
                        print("Page \(i + 1) raw text length: \(pageText.count)")
                        let cleanedPageText = cleanPDFPageText(pageText, pageNumber: i + 1, totalPages: pageCount)
                        print("Page \(i + 1) cleaned text length: \(cleanedPageText.count)")
                        
                        // Skip pages that are essentially empty or just contain useless content
                        let trimmedText = cleanedPageText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let isUsefulPage = trimmedText.count > 20 && 
                                          !trimmedText.lowercased().contains("intentionally left blank") &&
                                          trimmedText.range(of: "^[\\s\\n▬📄PAGE\\d\\s]*$", options: .regularExpression) == nil
                        
                        if isUsefulPage {
                            allPages.append(cleanedPageText)
                            print("Successfully extracted text from page \(i + 1)")
                        } else {
                            print("Page \(i + 1) skipped - not useful content")
                        }
                    } else {
                        print("No text found on page \(i + 1)")
                    }
                } else {
                    print("Could not access page \(i + 1)")
                }
            } catch {
                print("Error extracting text from page \(i + 1): \(error)")
                continue
            }
        }
        
        print("Text extraction completed. Extracted \(allPages.count) pages with content.")
        
        if allPages.isEmpty {
            print("ERROR: No pages with content found!")
            return ""
        }
        
        // Join pages with smart separation for natural reading flow
        let rawText = smartJoinPages(allPages)
        print("Raw text length: \(rawText.count) characters")
        print("Raw text sample (first 200 chars): \(String(rawText.prefix(200)))")
        
        // EMERGENCY DEBUG MODE: Return raw text to test if processing is the issue
        let debugMode = false // Set to false when debugging is complete
        
        if debugMode {
            print("🚨 DEBUG MODE: Returning raw text without processing")
            return rawText
        }
        
        // For debugging, let's try without heavy processing first
        if rawText.count > 1000 {
            print("Large text detected, using simplified processing")
            let processedText = simplifyPDFTextProcessing(rawText)
            print("Processed text length: \(processedText.count) characters")
            print("Processed text sample (first 200 chars): \(String(processedText.prefix(200)))")
            return processedText
        } else {
            let processedText = enhancedPDFTextProcessing(rawText)
            print("Processed text length: \(processedText.count) characters")
            print("Processed text sample (first 200 chars): \(String(processedText.prefix(200)))")
            return processedText
        }
    }
    
    private func cleanPDFPageText(_ text: String, pageNumber: Int, totalPages: Int) -> String {
        let originalLength = text.count
        print("🧹 CLEANING PAGE \(pageNumber):")
        print("   - Original length: \(originalLength)")
        print("   - Original sample: \(String(text.prefix(100)))")
        
        var cleaned = text
        
        // NO PAGE SEPARATORS - they ruin the reading experience
        let pageHeader = ""
        
        // Remove common headers and footers
        let lines = cleaned.components(separatedBy: .newlines)
        var filteredLines: [String] = []
        var removedLines = 0
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Be less aggressive with filtering - only remove obvious headers/footers
            var shouldSkip = false
            
            // Skip only very obvious headers (first 2 lines)
            if index < 2 && (
                trimmedLine.range(of: "^\\d+$", options: .regularExpression) != nil ||
                trimmedLine.range(of: "^Page \\d+", options: .regularExpression) != nil ||
                trimmedLine.count < 3
            ) {
                shouldSkip = true
                removedLines += 1
            }
            
            // Skip only very obvious footers (last 2 lines)
            if index >= lines.count - 2 && (
                trimmedLine.range(of: "^\\d+$", options: .regularExpression) != nil ||
                trimmedLine.range(of: "^Page \\d+", options: .regularExpression) != nil ||
                trimmedLine.count < 3
            ) {
                shouldSkip = true
                removedLines += 1
            }
            
            // Keep more content - only skip completely empty lines
            if !shouldSkip && trimmedLine.count > 0 {
                filteredLines.append(trimmedLine)
            }
        }
        
        let cleanedPageText = filteredLines.joined(separator: "\n")
        let finalText = pageHeader + cleanedPageText
        
        print("   - Removed \(removedLines) lines")
        print("   - Final length: \(finalText.count)")
        print("   - Final sample: \(String(finalText.prefix(100)))")
        
        return finalText
    }
    
    private func smartJoinPages(_ pages: [String]) -> String {
        var result = ""
        
        for (index, page) in pages.enumerated() {
            let cleanPage = page.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanPage.isEmpty {
                // Add the page content
                result += cleanPage
                
                // Smart separation between pages
                if index < pages.count - 1 {
                    // Check if current page ends with sentence/paragraph
                    let lastChar = cleanPage.last
                    
                    if lastChar == "." || lastChar == "!" || lastChar == "?" || lastChar == ":" {
                        // Sentence ending - add paragraph break
                        result += "\n\n"
                    } else if cleanPage.hasSuffix("-") {
                        // Hyphenated word continues on next page - no space
                        result += ""
                    } else {
                        // Word likely continues - add space
                        result += " "
                    }
                }
            }
        }
        
        return result
    }
    
    private func simplifyPDFTextProcessing(_ text: String) -> String {
        var processed = text
        
        print("Using simplified PDF processing...")
        
        // Basic cleanup only
        processed = processed.replacingOccurrences(of: "-\\s*\\n\\s*([a-z])", with: "$1", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        processed = processed.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        
        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func enhancedPDFTextProcessing(_ text: String) -> String {
        var processed = text
        
        print("Starting enhanced PDF text processing...")
        print("Input text length: \(processed.count)")
        
        // 1. Fix hyphenated words across lines
        processed = processed.replacingOccurrences(
            of: "-\\s*\\n\\s*([a-z])",
            with: "$1",
            options: .regularExpression
        )
        print("After hyphenation fix: \(processed.count) characters")
        
        // 2. Detect and format main chapter headings (more comprehensive)
        processed = processed.replacingOccurrences(
            of: "^(Chapter|CHAPTER|Part|PART)\\s*(\\d+|[IVX]+)(.*)$",
            with: "\n\n" + String(repeating: "━", count: 50) + "\n📖 $1 $2$3\n" + String(repeating: "━", count: 50) + "\n",
            options: .regularExpression
        )
        
        // 3. Detect section headings (numbered sections)
        processed = processed.replacingOccurrences(
            of: "^(\\d+\\.\\d*\\s+[A-Z][A-Za-z\\s]{3,})$",
            with: "\n\n🔸 $1\n" + String(repeating: "─", count: 30) + "\n",
            options: .regularExpression
        )
        
        // 4. Detect subsection headings (like 1.1, 2.3, etc.)
        processed = processed.replacingOccurrences(
            of: "^(\\d+\\.\\d+\\.?\\d*\\s+[A-Z][A-Za-z\\s]{2,})$",
            with: "\n\n▪️ $1\n",
            options: .regularExpression
        )
        
        // 5. Detect all-caps section titles
        processed = processed.replacingOccurrences(
            of: "^([A-Z][A-Z\\s]{4,}[A-Z])$",
            with: "\n\n🔷 $1\n" + String(repeating: "─", count: 25) + "\n",
            options: .regularExpression
        )
        
        // 6. Detect title case headings (proper titles)
        processed = processed.replacingOccurrences(
            of: "^([A-Z][a-z]+(?:\\s+[A-Z][a-z]+){2,})$",
            with: "\n\n📝 $1\n",
            options: .regularExpression
        )
        
        // 7. Handle multi-column text ordering
        processed = fixMultiColumnText(processed)
        
        // 8. Detect and format tables
        processed = formatTableContent(processed)
        
        // 9. Handle footnotes and references
        processed = processFootnotes(processed)
        
        // 10. Detect and format image captions
        processed = formatImageCaptions(processed)
        
        // 11. Handle bibliography and references
        processed = formatBibliography(processed)
        
        // 12. Handle mathematical expressions
        processed = formatMathematicalExpressions(processed)
        
        // 13. Fix paragraph breaks - merge lines that should be in same paragraph
        processed = processed.replacingOccurrences(
            of: "([a-z,])\\n([a-z])",
            with: "$1 $2",
            options: .regularExpression
        )
        
        // 14. Create proper paragraph breaks for sentences ending with periods
        processed = processed.replacingOccurrences(
            of: "([.!?])\\n([A-Z])",
            with: "$1\n\n$2",
            options: .regularExpression
        )
        
        // 15. Clean up multiple whitespace
        processed = processed.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        
        // 16. Fix spacing around punctuation
        processed = processed.replacingOccurrences(
            of: "\\s+([.!?,:;])",
            with: "$1",
            options: .regularExpression
        )
        
        // 17. Ensure proper spacing after punctuation
        processed = processed.replacingOccurrences(
            of: "([.!?])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        
        // 18. Remove excessive line breaks
        processed = processed.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        
        // 19. Handle common PDF artifacts
        processed = processed.replacingOccurrences(
            of: "\\b(\\w)\\s+(\\w)\\b",
            with: "$1$2",
            options: .regularExpression
        )
        
        return processed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func fixMultiColumnText(_ text: String) -> String {
        var processed = text
        
        // Detect potential column breaks (short lines followed by text that seems to continue from earlier)
        processed = processed.replacingOccurrences(
            of: "\\n([A-Z][a-z]{1,15})\\n([a-z])",
            with: "\n$1 $2",
            options: .regularExpression
        )
        
        // Fix common column ordering issues where text gets split mid-sentence
        processed = processed.replacingOccurrences(
            of: "([a-z])\\n([A-Z][a-z]+)\\n([a-z])",
            with: "$1 $3\n\n$2",
            options: .regularExpression
        )
        
        return processed
    }
    
    private func formatTableContent(_ text: String) -> String {
        var processed = text
        
        // Detect and format table headers (lines with multiple capitalized words that look like headers)
        processed = processed.replacingOccurrences(
            of: "^([A-Z][A-Za-z]+\\s+[A-Z][A-Za-z]+\\s+[A-Z][A-Za-z]+.*?)$",
            with: "\n\n📋 TABLE: $1\n" + String(repeating: "═", count: 50) + "\n",
            options: .regularExpression
        )
        
        // Detect table-like content (items with aligned numbers/data)
        processed = processed.replacingOccurrences(
            of: "^([A-Za-z][^\\n]*?)\\s{3,}(\\d+[.\\d%]*)\\s*$",
            with: "📊 $1 ··········· $2",
            options: .regularExpression
        )
        
        // Format list items with bullet points
        processed = processed.replacingOccurrences(
            of: "^[•·▪▫]\\s*([A-Z][^\\n]+)$",
            with: "• $1",
            options: .regularExpression
        )
        
        // Format numbered lists better
        processed = processed.replacingOccurrences(
            of: "^(\\d+\\.)\\s*([A-Z][^\\n]+)$",
            with: "\n$1 $2",
            options: .regularExpression
        )
        
        return processed
    }
    
    private func processFootnotes(_ text: String) -> String {
        var processed = text
        
        // Detect footnote numbers and separate them
        processed = processed.replacingOccurrences(
            of: "([.!?])\\s*(\\d+)\\s*([A-Z])",
            with: "$1 [$2] $3",
            options: .regularExpression
        )
        
        // Format actual footnotes at bottom
        processed = processed.replacingOccurrences(
            of: "^(\\d+)\\s+([A-Z][^\\n]+)$",
            with: "\n🔗 Note $1: $2",
            options: .regularExpression
        )
        
        return processed
    }
    
    private func formatMathematicalExpressions(_ text: String) -> String {
        var processed = text
        
        // Preserve mathematical expressions and formulas
        processed = processed.replacingOccurrences(
            of: "([\\w\\s])([=<>±×÷∞∑∫√π∆∇∂]+)([\\w\\s])",
            with: "$1 『$2』 $3",
            options: .regularExpression
        )
        
        // Format equations on their own lines
        processed = processed.replacingOccurrences(
            of: "^([^\\n]*[=<>±×÷∞∑∫√π∆∇∂][^\\n]*)$",
            with: "\n🧮 $1\n",
            options: .regularExpression
        )
        
        return processed
    }
    
    private func formatImageCaptions(_ text: String) -> String {
        var processed = text
        
        // Detect image captions (typically start with "Figure", "Image", "Photo", etc.)
        processed = processed.replacingOccurrences(
            of: "^(Figure|Image|Photo|Diagram|Chart|Graph)\\s+(\\d+[.:])\\s*([^\\n]+)$",
            with: "\n🖼️ $1 $2 $3\n",
            options: .regularExpression
        )
        
        // Handle captions that might be separated from their numbers
        processed = processed.replacingOccurrences(
            of: "^([A-Z][a-z]+\\s+\\d+)$\\n^([A-Z][^\\n]+)$",
            with: "\n🖼️ $1: $2\n",
            options: .regularExpression
        )
        
        return processed
    }
    
    private func formatBibliography(_ text: String) -> String {
        var processed = text
        
        // Detect bibliography section
        processed = processed.replacingOccurrences(
            of: "^(References|Bibliography|Works Cited|Sources)\\s*$",
            with: "\n\n📚 $1\n" + String(repeating: "═", count: 30) + "\n",
            options: .regularExpression
        )
        
        // Format individual citations (author, year pattern)
        processed = processed.replacingOccurrences(
            of: "^([A-Z][a-z]+,\\s+[A-Z]\\..*?)(\\d{4})[).]\\s*([A-Z][^\\n]+)$",
            with: "📖 $1 ($2). $3",
            options: .regularExpression
        )
        
        // Handle DOI and URL citations
        processed = processed.replacingOccurrences(
            of: "(doi:|https?://[^\\s]+)",
            with: "🔗 $1",
            options: .regularExpression
        )
        
        return processed
    }
    
    private func loadText(from path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            pdfView.isHidden = true
            textView.isHidden = false
            
            // Format text with Kindle-like styling
            formatTextContent(content)
        } catch {
            print("Failed to load text from path: \(path), error: \(error)")
            // Show error message to user
            textView.text = "Failed to load book content. Please try again."
        }
    }
    
    private func formatTextContent(_ content: String, fontName: String = "Georgia") {
        // Clean up the text content
        let cleanedContent = cleanupText(content)
        
        // Use the proven safe approach - no attributed text
        displayTextSafely(cleanedContent, fontName: fontName)
    }
    
    
    private func cleanupText(_ text: String) -> String {
        var cleaned = text
        
        // Remove excessive whitespace and fix common PDF extraction issues
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Fix paragraph breaks - convert multiple newlines to proper paragraph breaks
        cleaned = cleaned.replacingOccurrences(of: "\\n\\s*\\n", with: "\n\n", options: .regularExpression)
        
        // Remove single newlines that break mid-sentence (common in PDFs)
        cleaned = cleaned.replacingOccurrences(of: "(?<!\\.)\\n(?![A-Z])", with: " ", options: .regularExpression)
        
        // Ensure proper spacing after periods
        cleaned = cleaned.replacingOccurrences(of: "\\.(?! )", with: ". ", options: .regularExpression)
        
        // Clean up any remaining multiple spaces
        cleaned = cleaned.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Achievement System
    private func checkForAchievements() {
        let achievements = ReadingGoalManager.shared.checkForAchievements()
        
        for achievement in achievements {
            showAchievementNotification(achievement)
        }
    }
    
    private func showAchievementNotification(_ achievement: Achievement) {
        // Create achievement banner
        let achievementView = UIView()
        achievementView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.95)
        achievementView.layer.cornerRadius = 12
        achievementView.layer.shadowColor = UIColor.black.cgColor
        achievementView.layer.shadowOffset = CGSize(width: 0, height: 4)
        achievementView.layer.shadowRadius = 8
        achievementView.layer.shadowOpacity = 0.3
        achievementView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconLabel = UILabel()
        iconLabel.text = achievement.icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = achievement.title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = achievement.description
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        descriptionLabel.numberOfLines = 2
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        achievementView.addSubview(iconLabel)
        achievementView.addSubview(titleLabel)
        achievementView.addSubview(descriptionLabel)
        
        view.addSubview(achievementView)
        
        NSLayoutConstraint.activate([
            achievementView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            achievementView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            achievementView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            achievementView.heightAnchor.constraint(equalToConstant: 80),
            
            iconLabel.leadingAnchor.constraint(equalTo: achievementView.leadingAnchor, constant: 16),
            iconLabel.centerYAnchor.constraint(equalTo: achievementView.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: achievementView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: achievementView.topAnchor, constant: 16),
            
            descriptionLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            descriptionLabel.trailingAnchor.constraint(equalTo: achievementView.trailingAnchor, constant: -16),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: achievementView.bottomAnchor, constant: -16)
        ])
        
        // Animate in
        achievementView.alpha = 0
        achievementView.transform = CGAffineTransform(translationX: 0, y: -50)
        
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            achievementView.alpha = 1
            achievementView.transform = .identity
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Auto-remove after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            UIView.animate(withDuration: 0.4, animations: {
                achievementView.alpha = 0
                achievementView.transform = CGAffineTransform(translationX: 0, y: -30)
            }) { _ in
                achievementView.removeFromSuperview()
            }
        }
        
        // Send notification to ReadingGoalManager if goal completed
        if achievement.type == .dailyGoalCompleted {
            ReadingGoalManager.shared.sendGoalCompletionNotification()
        }
    }
}


// MARK: - Delegates
extension BookReaderViewController: LibraryViewControllerDelegate {
    func didSelectBook(_ book: Book) {
        loadBook(book)
    }
}

extension BookReaderViewController: SettingsViewControllerDelegate {
    func didUpdateSettings(_ settings: ReaderSettings) {
        // Apply settings
        fontSize = settings.fontSize
        isDarkMode = settings.isDarkMode
        if let fontName = settings.fontName {
            textView.font = UIFont(name: fontName, size: fontSize)
        }
    }
}

// MARK: - TextToSpeechDelegate
extension BookReaderViewController: TextToSpeechDelegate {
    func speechDidStart() {
        updateTTSButton(isPlaying: true)
    }
    
    func speechDidPause() {
        updateTTSButton(isPlaying: false)
    }
    
    func speechDidResume() {
        updateTTSButton(isPlaying: true)
    }
    
    func speechDidStop() {
        updateTTSButton(isPlaying: false)
    }
    
    func speechDidFinish() {
        updateTTSButton(isPlaying: false)
        showMessage("Finished reading", type: .info)
    }
    
    func speechDidUpdatePosition(_ position: Int) {
        // Could highlight current word being spoken
    }
    
    private func showUnsupportedFormatMessage() {
        pdfView.isHidden = true
        textView.isHidden = false
        
        let message = """
        📷 Image Format Not Supported
        
        Image processing is not available in this version.
        
        For PDFs with images or scanned documents, use the Live Text Selection feature:
        • Import as PDF format
        • Use Live Text Selection to select and copy text directly from images
        
        Supported formats:
        • PDF documents (with Live Text Selection)
        • Text files (.txt)
        • EPUB books
        """
        
        textView.text = message
    }
}

// MARK: - LiveTextSelectionDelegate
extension BookReaderViewController: LiveTextSelectionDelegate {
    func didSelectText(_ text: String, in rect: CGRect) {
        print("📝 Selected text: \(text)")
        
        // Optional: Show selection feedback or process the text
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func didTapText(_ text: String, at point: CGPoint) {
        print("👆 Tapped text: \(text)")
        
        // Optional: Show word definition or quick actions
        if text.count > 1 {
            showQuickActions(for: text, at: point)
        }
    }
    
    private func showQuickActions(for text: String, at point: CGPoint) {
        let alert = UIAlertController(title: "Quick Actions", message: "\"\(text)\"", preferredStyle: .actionSheet)
        
        // Copy action
        alert.addAction(UIAlertAction(title: "Copy", style: .default) { _ in
            UIPasteboard.general.string = text
            
            // Show success feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        })
        
        // Search action
        alert.addAction(UIAlertAction(title: "Search", style: .default) { _ in
            if let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.google.com/search?q=\(encodedText)") {
                UIApplication.shared.open(url)
            }
        })
        
        // Define action (for single words)
        let words = text.split(separator: " ")
        if words.count == 1 {
            alert.addAction(UIAlertAction(title: "Define", style: .default) { _ in
                if let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let url = URL(string: "dict://\(encodedText)") {
                    UIApplication.shared.open(url)
                }
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present from current view controller
        if let popover = alert.popoverPresentationController {
            popover.sourceView = liveTextSelectionView
            popover.sourceRect = CGRect(origin: point, size: CGSize(width: 1, height: 1))
        }
        
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate
extension BookReaderViewController: UITextViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Track reading progress when user scrolls
        if scrollView == textView {
            trackScrollProgress()
            // Record activity for auto-pause detection
            readingTimerWidget?.recordActivity()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Update progress when scrolling stops
        if scrollView == textView {
            updateReadingProgress()
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // Update progress immediately if not decelerating
        if scrollView == textView && !decelerate {
            updateReadingProgress()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension BookReaderViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only allow back gesture if we're in a navigation stack
        if gestureRecognizer == navigationController?.interactivePopGestureRecognizer {
            let canGoBack = navigationController?.viewControllers.count ?? 0 > 1
            print("🔄 Back gesture should begin: \(canGoBack)")
            return canGoBack
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Don't interfere with PDF view gestures unless it's the back gesture from the very left edge
        if gestureRecognizer == navigationController?.interactivePopGestureRecognizer {
            let location = gestureRecognizer.location(in: view)
            let isFromLeftEdge = location.x < 20 // Only from very left edge
            print("🔄 Back gesture from left edge: \(isFromLeftEdge), location.x: \(location.x)")
            return isFromLeftEdge
        }
        return false
    }
}
