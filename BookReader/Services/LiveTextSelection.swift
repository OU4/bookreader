//
//  LiveTextSelection.swift
//  BookReader
//
//  Apple-style Live Text feature implementation
//

import UIKit
import Vision
import PDFKit

class LiveTextSelectionView: UIView {
    
    // MARK: - Properties
    private var textRecognitionRequest: VNRecognizeTextRequest?
    private var recognizedTextElements: [TextElement] = []
    private var selectedTextElements: [TextElement] = []
    
    // Selection UI elements (Apple-style)
    private var selectionPath: UIBezierPath?
    private var selectionLayer: CAShapeLayer?
    private var startHandle: SelectionHandle?
    private var endHandle: SelectionHandle?
    private var isSelecting = false
    private var longPressStarted = false
    
    weak var delegate: LiveTextSelectionDelegate?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextRecognition()
        setupGestures()
        backgroundColor = .clear
        // Allow touches to pass through when not actively selecting
        isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextRecognition()
        setupGestures()
        backgroundColor = .clear
        // Allow touches to pass through when not actively selecting
        isUserInteractionEnabled = true
    }
    
    // Override to allow touches to pass through to underlying views
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // If we're actively selecting, handle the touch
        if isSelecting || longPressStarted {
            return super.hitTest(point, with: event)
        }
        
        // If there are selection handles visible, handle touches on them
        if let startHandle = startHandle, startHandle.frame.contains(point) {
            return startHandle
        }
        if let endHandle = endHandle, endHandle.frame.contains(point) {
            return endHandle
        }
        
        // Only handle touches on recognized text, and only for long press gestures
        // Let other touches pass through to PDF view and UI elements
        return nil
    }
    
    // MARK: - Setup
    private func setupTextRecognition() {
        textRecognitionRequest = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleTextRecognition(request: request, error: error)
            }
        }
        
        textRecognitionRequest?.recognitionLevel = .accurate
        textRecognitionRequest?.usesLanguageCorrection = true
        textRecognitionRequest?.automaticallyDetectsLanguage = true
        textRecognitionRequest?.recognitionLanguages = ["en-US", "ar-SA", "ar"]
    }
    
    private func setupGestures() {
        // Single tap to position cursor and show text actions (like Apple)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        
        // Long press to start text selection
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.4
        addGestureRecognizer(longPressGesture)
        
        // Pan for extending selection
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.require(toFail: longPressGesture)
        addGestureRecognizer(panGesture)
    }
    
    // MARK: - Public Methods
    func enableTextSelection(for image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let request = self?.textRecognitionRequest else { return }
            
            do {
                try handler.perform([request])
            } catch {
            }
        }
    }
    
    func attachToPDFView(_ pdfView: PDFView?) {
        guard let pdfView = pdfView else { return }
        
        // Enable text recognition for the current page
        if let currentPage = pdfView.currentPage {
            enableTextSelection(for: currentPage, in: pdfView.bounds)
        }
        
        // Listen for page changes
        NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: pdfView,
            queue: .main
        ) { [weak self] _ in
            if let currentPage = pdfView.currentPage {
                self?.enableTextSelection(for: currentPage, in: pdfView.bounds)
            }
        }
        
    }
    
    func enableTextSelection(for pdfPage: PDFPage, in rect: CGRect) {
        // Convert PDF page to image for text recognition
        let pageRect = pdfPage.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        let image = renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)
            
            context.cgContext.translateBy(x: 0, y: pageRect.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            
            pdfPage.draw(with: .mediaBox, to: context.cgContext)
        }
        
        enableTextSelection(for: image)
    }
    
    // MARK: - Text Recognition Handler
    private func handleTextRecognition(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        recognizedTextElements.removeAll()
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first,
                  topCandidate.confidence > 0.3 else { continue }
            
            let boundingBox = observation.boundingBox
            let convertedRect = convertVisionRect(boundingBox)
            
            let textElement = TextElement(
                text: topCandidate.string,
                bounds: convertedRect,
                confidence: topCandidate.confidence
            )
            
            recognizedTextElements.append(textElement)
        }
        
    }
    
    private func convertVisionRect(_ visionRect: CGRect) -> CGRect {
        // Convert Vision coordinate system (bottom-left origin) to UIKit (top-left origin)
        let convertedRect = CGRect(
            x: visionRect.origin.x * bounds.width,
            y: (1 - visionRect.origin.y - visionRect.height) * bounds.height,
            width: visionRect.width * bounds.width,
            height: visionRect.height * bounds.height
        )
        return convertedRect
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)
        
        switch gesture.state {
        case .began:
            longPressStarted = true
            
            // Find word at location
            if let textElement = findTextElement(at: location) {
                // Select the entire word (Apple-like behavior)
                selectedTextElements = [textElement]
                updateSelectionVisual()
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            
        case .changed:
            // Allow dragging to extend selection
            if longPressStarted, let endElement = findTextElement(at: location) {
                if let startElement = selectedTextElements.first {
                    selectedTextElements = getTextElements(from: startElement, to: endElement)
                    updateSelectionVisual()
                }
            }
            
        case .ended, .cancelled:
            longPressStarted = false
            if !selectedTextElements.isEmpty {
                // Show text menu after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.showTextSelectionMenu()
                }
            }
            
        default:
            break
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // Pan gesture is handled by selection handles, no longer needed for old selection approach
        return
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // Check if tapping on recognized text
        if let textElement = findTextElement(at: location) {
            // Show cursor and text actions like Apple
            showCursorAndActions(for: textElement, at: location)
        } else {
            // Clear any existing selection
            clearSelection()
        }
    }
    
    // MARK: - Text Selection Helper Methods
    
    private func findTextElement(at point: CGPoint) -> TextElement? {
        return recognizedTextElements.first { element in
            element.bounds.contains(point)
        }
    }
    
    private func updateSelectionVisual() {
        // Remove existing selection
        clearSelectionVisual()
        
        guard !selectedTextElements.isEmpty else { return }
        
        // Create Apple-style text selection path
        let selectionPath = createTextSelectionPath(for: selectedTextElements)
        
        // Create selection layer with Apple-style appearance
        let layer = CAShapeLayer()
        layer.path = selectionPath.cgPath
        layer.fillColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        layer.strokeColor = UIColor.clear.cgColor
        
        // Add subtle animation
        layer.opacity = 0
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        layer.opacity = 1
        CATransaction.commit()
        
        self.layer.addSublayer(layer)
        selectionLayer = layer
        
        // Add selection handles
        addSelectionHandles()
    }
    
    private func createTextSelectionPath(for elements: [TextElement]) -> UIBezierPath {
        let path = UIBezierPath()
        
        // Group elements by lines
        let sortedElements = elements.sorted { first, second in
            if abs(first.bounds.midY - second.bounds.midY) < 5 {
                return first.bounds.minX < second.bounds.minX
            }
            return first.bounds.midY < second.bounds.midY
        }
        
        var currentLineElements: [TextElement] = []
        var lines: [[TextElement]] = []
        
        for element in sortedElements {
            if let lastElement = currentLineElements.last,
               abs(element.bounds.midY - lastElement.bounds.midY) > 5 {
                lines.append(currentLineElements)
                currentLineElements = [element]
            } else {
                currentLineElements.append(element)
            }
        }
        
        if !currentLineElements.isEmpty {
            lines.append(currentLineElements)
        }
        
        // Create rounded selection paths for each line
        for line in lines {
            guard let firstElement = line.first, let lastElement = line.last else { continue }
            
            let lineRect = CGRect(
                x: firstElement.bounds.minX - 2,
                y: firstElement.bounds.minY - 2,
                width: lastElement.bounds.maxX - firstElement.bounds.minX + 4,
                height: firstElement.bounds.height + 4
            )
            
            let roundedRect = UIBezierPath(roundedRect: lineRect, cornerRadius: 4)
            path.append(roundedRect)
        }
        
        return path
    }
    
    private func addSelectionHandles() {
        guard let firstElement = selectedTextElements.first,
              let lastElement = selectedTextElements.last else { return }
        
        // Start handle
        startHandle = SelectionHandle(type: .start)
        startHandle?.center = CGPoint(
            x: firstElement.bounds.minX,
            y: firstElement.bounds.minY
        )
        if let handle = startHandle {
            addSubview(handle)
            addHandleGesture(to: handle, type: .start)
        }
        
        // End handle
        endHandle = SelectionHandle(type: .end)
        endHandle?.center = CGPoint(
            x: lastElement.bounds.maxX,
            y: lastElement.bounds.maxY
        )
        if let handle = endHandle {
            addSubview(handle)
            addHandleGesture(to: handle, type: .end)
        }
    }
    
    private func addHandleGesture(to handle: SelectionHandle, type: SelectionHandle.HandleType) {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDragged(_:)))
        handle.addGestureRecognizer(panGesture)
        handle.tag = type == .start ? 1 : 2
    }
    
    @objc private func handleDragged(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let isStartHandle = gesture.view?.tag == 1
        
        switch gesture.state {
        case .changed:
            // Find text element at new location
            if let textElement = findTextElement(at: location) {
                updateSelection(extendingTo: textElement, fromStart: isStartHandle)
            }
            
        case .ended:
            // Show text menu
            showTextSelectionMenu()
            
        default:
            break
        }
    }
    
    private func updateSelection(extendingTo element: TextElement, fromStart: Bool) {
        guard let currentFirst = selectedTextElements.first,
              let currentLast = selectedTextElements.last else { return }
        
        // Update selection based on which handle was dragged
        if fromStart {
            // Extend from start
            selectedTextElements = getTextElements(from: element, to: currentLast)
        } else {
            // Extend from end
            selectedTextElements = getTextElements(from: currentFirst, to: element)
        }
        
        updateSelectionVisual()
    }
    
    private func clearSelection() {
        clearSelectionVisual()
        selectedTextElements.removeAll()
        isSelecting = false
    }
    
    private func clearSelectionVisual() {
        selectionLayer?.removeFromSuperlayer()
        selectionLayer = nil
        
        startHandle?.removeFromSuperview()
        startHandle = nil
        
        endHandle?.removeFromSuperview()  
        endHandle = nil
    }
    
    private func getTextElements(from startElement: TextElement, to endElement: TextElement) -> [TextElement] {
        // Find all text elements between start and end
        let startIndex = recognizedTextElements.firstIndex { $0.text == startElement.text && $0.bounds == startElement.bounds } ?? 0
        let endIndex = recognizedTextElements.firstIndex { $0.text == endElement.text && $0.bounds == endElement.bounds } ?? recognizedTextElements.count - 1
        
        let range = min(startIndex, endIndex)...max(startIndex, endIndex)
        return Array(recognizedTextElements[range])
    }
    
    private func showTextSelectionMenu() {
        guard !selectedTextElements.isEmpty else { return }
        
        let selectedText = selectedTextElements.map { $0.text }.joined(separator: " ")
        
        // Use UIMenuController for native iOS text menu
        let menuController = UIMenuController.shared
        
        // Store selected text for menu actions
        objc_setAssociatedObject(self, &AssociatedKeys.selectedText, selectedText, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Calculate menu position (center of selection)
        let selectionBounds = selectedTextElements.reduce(CGRect.null) { result, element in
            result.union(element.bounds)
        }
        
        let menuRect = CGRect(
            x: selectionBounds.midX - 50,
            y: selectionBounds.minY - 50,
            width: 100,
            height: 40
        )
        
        // Show menu
        menuController.showMenu(from: self, rect: menuRect)
    }
    
    private func showCursorAndActions(for textElement: TextElement, at point: CGPoint) {
        // Show blinking cursor like Apple
        showBlinkingCursor(at: point)
        
        // Show native iOS text menu
        showNativeTextMenu(for: textElement.text, at: point)
    }
    
    private func showBlinkingCursor(at point: CGPoint) {
        // Remove existing cursor
        layer.sublayers?.removeAll { $0.name == "textCursor" }
        
        // Create cursor line
        let cursorLayer = CAShapeLayer()
        cursorLayer.name = "textCursor"
        
        let cursorPath = UIBezierPath()
        cursorPath.move(to: CGPoint(x: point.x, y: point.y - 10))
        cursorPath.addLine(to: CGPoint(x: point.x, y: point.y + 10))
        
        cursorLayer.path = cursorPath.cgPath
        cursorLayer.strokeColor = UIColor.systemBlue.cgColor
        cursorLayer.lineWidth = 2.0
        cursorLayer.lineCap = .round
        
        // Add blinking animation
        let blinkAnimation = CABasicAnimation(keyPath: "opacity")
        blinkAnimation.fromValue = 1.0
        blinkAnimation.toValue = 0.0
        blinkAnimation.duration = 0.5
        blinkAnimation.autoreverses = true
        blinkAnimation.repeatCount = .infinity
        
        cursorLayer.add(blinkAnimation, forKey: "blink")
        layer.addSublayer(cursorLayer)
        
        // Remove cursor after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            cursorLayer.removeFromSuperlayer()
        }
    }
    
    private func showNativeTextMenu(for text: String, at point: CGPoint) {
        // Create a temporary invisible text view for native menu
        let textView = UITextView()
        textView.text = text
        textView.isHidden = true
        addSubview(textView)
        
        // Select all text
        textView.selectAll(nil)
        
        // Configure menu controller
        let menuController = UIMenuController.shared
        
        // Custom menu items
        let copyItem = UIMenuItem(title: "Copy", action: #selector(copyText))
        let searchItem = UIMenuItem(title: "Search", action: #selector(searchText))
        let defineItem = UIMenuItem(title: "Define", action: #selector(defineText))
        
        menuController.menuItems = [copyItem, searchItem, defineItem]
        
        // Store text for menu actions
        objc_setAssociatedObject(self, &AssociatedKeys.selectedText, text, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Show menu
        let targetRect = CGRect(x: point.x - 50, y: point.y - 25, width: 100, height: 50)
        menuController.showMenu(from: self, rect: targetRect)
        
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textView.removeFromSuperview()
        }
    }
    
    @objc private func copyText() {
        if let text = objc_getAssociatedObject(self, &AssociatedKeys.selectedText) as? String {
            UIPasteboard.general.string = text
            
            // Show success feedback
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        }
    }
    
    @objc private func searchText() {
        if let text = objc_getAssociatedObject(self, &AssociatedKeys.selectedText) as? String,
           let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.google.com/search?q=\(encodedText)") {
            UIApplication.shared.open(url)
        }
    }
    
    @objc private func defineText() {
        if let text = objc_getAssociatedObject(self, &AssociatedKeys.selectedText) as? String,
           let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "dict://\(encodedText)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Helper Extensions
extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}

// MARK: - Supporting Types
struct TextElement {
    let text: String
    let bounds: CGRect
    let confidence: Float
}

protocol LiveTextSelectionDelegate: AnyObject {
    func didSelectText(_ text: String, in rect: CGRect)
    func didTapText(_ text: String, at point: CGPoint)
}

// MARK: - Selection Handle (Apple-style)
class SelectionHandle: UIView {
    enum HandleType {
        case start, end
    }
    
    private let handleType: HandleType
    private let circleLayer = CAShapeLayer()
    private let stemLayer = CAShapeLayer()
    
    init(type: HandleType) {
        self.handleType = type
        super.init(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        setupHandle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupHandle() {
        backgroundColor = .clear
        
        // Create circle handle
        let circleSize: CGFloat = 8
        let circleRect = CGRect(x: 8, y: 8, width: circleSize, height: circleSize)
        circleLayer.path = UIBezierPath(ovalIn: circleRect).cgPath
        circleLayer.fillColor = UIColor.systemBlue.cgColor
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.lineWidth = 1.0
        
        // Create stem
        let stemPath = UIBezierPath()
        if handleType == .start {
            stemPath.move(to: CGPoint(x: 12, y: 8))
            stemPath.addLine(to: CGPoint(x: 12, y: 2))
        } else {
            stemPath.move(to: CGPoint(x: 12, y: 16))
            stemPath.addLine(to: CGPoint(x: 12, y: 22))
        }
        
        stemLayer.path = stemPath.cgPath
        stemLayer.strokeColor = UIColor.systemBlue.cgColor
        stemLayer.lineWidth = 2.0
        stemLayer.lineCap = .round
        
        layer.addSublayer(stemLayer)
        layer.addSublayer(circleLayer)
        
        // Add drop shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 2
    }
}

// MARK: - Associated Keys
private struct AssociatedKeys {
    static var selectedText = "selectedText"
}