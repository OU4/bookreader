//
//  ReadingTheme.swift
//  BookReader
//
//  Reading themes for different reading experiences
//

import UIKit

enum ReadingTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case sepia = "sepia"
    case night = "night"
    case highContrast = "highContrast"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .sepia: return "Sepia"
        case .night: return "Night"
        case .highContrast: return "High Contrast"
        }
    }
    
    var backgroundColor: UIColor {
        switch self {
        case .light:
            return UIColor.systemBackground
        case .dark:
            return UIColor.black
        case .sepia:
            return UIColor(red: 0.96, green: 0.91, blue: 0.78, alpha: 1.0) // Warm beige
        case .night:
            return UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0) // Very dark blue
        case .highContrast:
            return UIColor.black
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .light:
            return UIColor.label
        case .dark:
            return UIColor.white
        case .sepia:
            return UIColor(red: 0.2, green: 0.1, blue: 0.0, alpha: 1.0) // Dark brown
        case .night:
            return UIColor(red: 0.9, green: 0.9, blue: 0.85, alpha: 1.0) // Warm white
        case .highContrast:
            return UIColor.white
        }
    }
    
    var isDarkMode: Bool {
        switch self {
        case .light, .sepia:
            return false
        case .dark, .night, .highContrast:
            return true
        }
    }
    
    var selectionColor: UIColor {
        switch self {
        case .light:
            return UIColor.systemBlue.withAlphaComponent(0.3)
        case .dark:
            return UIColor.systemBlue.withAlphaComponent(0.4)
        case .sepia:
            return UIColor.systemOrange.withAlphaComponent(0.3)
        case .night:
            return UIColor.systemPurple.withAlphaComponent(0.4)
        case .highContrast:
            return UIColor.systemYellow.withAlphaComponent(0.5)
        }
    }
}

enum MessageType {
    case info
    case success
    case error
    case warning
    
    var title: String {
        switch self {
        case .info: return "Info"
        case .success: return "Success"
        case .error: return "Error"
        case .warning: return "Warning"
        }
    }
}