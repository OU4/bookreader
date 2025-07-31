//
//  ReaderSettings.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
////
//
//import UIKit
//
//struct ReaderSettings {
//    var fontSize: CGFloat
//    var fontName: String?
//    var isDarkMode: Bool
//    var scrollingEnabled: Bool
//    var pageMargins: CGFloat
//    var lineSpacing: CGFloat
//    
//    init(fontSize: CGFloat = 18,
//         fontName: String? = "Georgia",
//         isDarkMode: Bool = false,
//         scrollingEnabled: Bool = true,
//         pageMargins: CGFloat = 16,
//         lineSpacing: CGFloat = 1.5) {
//        self.fontSize = fontSize
//        self.fontName = fontName
//        self.isDarkMode = isDarkMode
//        self.scrollingEnabled = scrollingEnabled
//        self.pageMargins = pageMargins
//        self.lineSpacing = lineSpacing
//    }
//}
//
//// Protocols
//protocol LibraryViewControllerDelegate: AnyObject {
//    func didSelectBook(_ book: Book)
//}
//
//protocol SettingsViewControllerDelegate: AnyObject {
//    func didUpdateSettings(_ settings: ReaderSettings)
//}
