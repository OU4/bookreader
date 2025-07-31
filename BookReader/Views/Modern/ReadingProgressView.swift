//
//  ReadingProgressView.swift
//  BookReader
//
//  Beautiful reading progress indicator
//

import UIKit

class ReadingProgressView: UIView {
    
    // MARK: - Properties
    private var progress: Float = 0.0
    
    // MARK: - UI Components
    private lazy var trackLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.systemGray5.cgColor
        layer.lineWidth = 4
        layer.lineCap = .round
        return layer
    }()
    
    private lazy var progressLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.systemBlue.cgColor
        layer.lineWidth = 4
        layer.lineCap = .round
        layer.strokeEnd = 0
        return layer
    }()
    
    private lazy var gradientLayer: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.systemBlue.cgColor,
            UIColor.systemPurple.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        return gradient
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        
        layer.addSublayer(trackLayer)
        
        // Add gradient to progress layer
        layer.addSublayer(gradientLayer)
        gradientLayer.mask = progressLayer
        
        // Add glow effect
        progressLayer.shadowColor = UIColor.systemBlue.cgColor
        progressLayer.shadowOffset = .zero
        progressLayer.shadowRadius = 4
        progressLayer.shadowOpacity = 0.6
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayers()
    }
    
    private func updateLayers() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 8, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.width - 8, y: bounds.midY))
        
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        
        gradientLayer.frame = bounds
    }
    
    // MARK: - Public Methods
    func setProgress(_ progress: Float, animated: Bool) {
        self.progress = max(0, min(1, progress))
        
        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.strokeEnd
            animation.toValue = self.progress
            animation.duration = 0.5
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            progressLayer.add(animation, forKey: "progressAnimation")
        }
        
        progressLayer.strokeEnd = CGFloat(self.progress)
        
        // Add pulse animation for milestones
        if animated && shouldCelebrateMilestone() {
            addCelebrationAnimation()
        }
    }
    
    private func shouldCelebrateMilestone() -> Bool {
        let percentage = Int(progress * 100)
        return percentage % 25 == 0 && percentage > 0
    }
    
    private func addCelebrationAnimation() {
        // Create celebration particles
        for _ in 0..<6 {
            let particle = createParticle()
            layer.addSublayer(particle)
            
            let animation = createParticleAnimation()
            particle.add(animation, forKey: "celebration")
            
            // Remove particle after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                particle.removeFromSuperlayer()
            }
        }
        
        // Add glow pulse
        let pulseAnimation = CABasicAnimation(keyPath: "shadowOpacity")
        pulseAnimation.fromValue = 0.6
        pulseAnimation.toValue = 1.0
        pulseAnimation.duration = 0.3
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = 2
        
        progressLayer.add(pulseAnimation, forKey: "glow")
    }
    
    private func createParticle() -> CAShapeLayer {
        let particle = CAShapeLayer()
        let size: CGFloat = 4
        
        particle.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).cgPath
        particle.fillColor = [UIColor.systemBlue, UIColor.systemPurple, UIColor.systemGreen].randomElement()?.cgColor
        particle.position = CGPoint(x: bounds.width * CGFloat(progress), y: bounds.midY)
        
        return particle
    }
    
    private func createParticleAnimation() -> CAAnimationGroup {
        let group = CAAnimationGroup()
        group.duration = 1.0
        
        // Position animation
        let position = CABasicAnimation(keyPath: "position")
        position.fromValue = NSValue(cgPoint: CGPoint(x: bounds.width * CGFloat(progress), y: bounds.midY))
        position.toValue = NSValue(cgPoint: CGPoint(
            x: bounds.width * CGFloat(progress) + CGFloat.random(in: -30...30),
            y: bounds.midY + CGFloat.random(in: -20...20)
        ))
        
        // Opacity animation
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 1.0
        opacity.toValue = 0.0
        
        // Scale animation
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 0.5
        
        group.animations = [position, opacity, scale]
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        return group
    }
    
    func updateTheme(_ theme: ReadingTheme) {
        UIView.animate(withDuration: 0.3) {
            self.trackLayer.strokeColor = theme.isDarkMode ? 
                UIColor.systemGray2.cgColor : UIColor.systemGray5.cgColor
        }
    }
}