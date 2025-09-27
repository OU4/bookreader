//
//  NotesManager.swift
//  BookReader
//
//  Manage highlights, notes, and annotations for books
//

import Foundation
import UIKit

class NotesManager {
    static let shared = NotesManager()
    private init() {}
    
    // MARK: - Highlights Management
    func addHighlight(
        to bookId: String,
        text: String,
        color: Highlight.HighlightColor,
        position: TextPosition,
        note: String? = nil,
        selectionRects: [SelectionRect]? = nil
    ) {
        var highlights = loadHighlights(for: bookId)
        
        let highlight = Highlight(
            text: text,
            color: color,
            position: position,
            note: note,
            selectionRects: selectionRects
        )
        
        highlights.append(highlight)
        saveHighlights(highlights, for: bookId)
        
        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .highlightAdded,
            object: nil,
            userInfo: ["bookId": bookId, "highlight": highlight]
        )
    }
    
    func removeHighlight(id: String, from bookId: String) {
        var highlights = loadHighlights(for: bookId)
        highlights.removeAll { $0.id == id }
        saveHighlights(highlights, for: bookId)
        
        NotificationCenter.default.post(
            name: .highlightRemoved,
            object: nil,
            userInfo: ["bookId": bookId, "highlightId": id]
        )
    }
    
    func updateHighlight(id: String, in bookId: String, note: String?) {
        var highlights = loadHighlights(for: bookId)
        
        if let index = highlights.firstIndex(where: { $0.id == id }) {
            highlights[index].note = note
            saveHighlights(highlights, for: bookId)
            
            NotificationCenter.default.post(
                name: .highlightUpdated,
                object: nil,
                userInfo: ["bookId": bookId, "highlight": highlights[index]]
            )
        }
    }
    
    func getHighlights(for bookId: String) -> [Highlight] {
        return loadHighlights(for: bookId)
    }
    
    func getHighlightsInRange(for bookId: String, startOffset: Int, endOffset: Int) -> [Highlight] {
        let highlights = loadHighlights(for: bookId)
        return highlights.filter { highlight in
            let highlightStart = highlight.position.startOffset
            let highlightEnd = highlight.position.endOffset
            
            // Check if highlight overlaps with the given range
            return !(highlightEnd < startOffset || highlightStart > endOffset)
        }
    }
    
    // MARK: - Notes Management
    func addNote(to bookId: String, title: String, content: String, position: TextPosition? = nil, tags: [String] = []) {
        var notes = loadNotes(for: bookId)
        
        let note = Note(
            title: title,
            content: content,
            position: position,
            tags: tags
        )
        
        notes.append(note)
        saveNotes(notes, for: bookId)
        
        NotificationCenter.default.post(
            name: .noteAdded,
            object: nil,
            userInfo: ["bookId": bookId, "note": note]
        )
    }
    
    func updateNote(id: String, in bookId: String, title: String, content: String, tags: [String]) {
        var notes = loadNotes(for: bookId)
        
        if let index = notes.firstIndex(where: { $0.id == id }) {
            let updatedNote = Note(
                id: notes[index].id,
                title: title,
                content: content,
                position: notes[index].position,
                tags: tags,
                dateCreated: notes[index].dateCreated,
                dateModified: Date()
            )
            
            notes[index] = updatedNote
            saveNotes(notes, for: bookId)
            
            NotificationCenter.default.post(
                name: .noteUpdated,
                object: nil,
                userInfo: ["bookId": bookId, "note": updatedNote]
            )
        }
    }
    
    func removeNote(id: String, from bookId: String) {
        var notes = loadNotes(for: bookId)
        notes.removeAll { $0.id == id }
        saveNotes(notes, for: bookId)
        
        NotificationCenter.default.post(
            name: .noteRemoved,
            object: nil,
            userInfo: ["bookId": bookId, "noteId": id]
        )
    }
    
    func getNotes(for bookId: String) -> [Note] {
        return loadNotes(for: bookId)
    }
    
    func searchNotes(query: String, in bookId: String? = nil) -> [Note] {
        let lowercaseQuery = query.lowercased()
        
        if let bookId = bookId {
            // Search within specific book
            let notes = loadNotes(for: bookId)
            return notes.filter { note in
                note.title.lowercased().contains(lowercaseQuery) ||
                note.content.lowercased().contains(lowercaseQuery) ||
                note.tags.contains { $0.lowercased().contains(lowercaseQuery) }
            }
        } else {
            // Search across all books
            var allNotes: [Note] = []
            let bookIds = getAllBookIds()
            
            for bookId in bookIds {
                let notes = loadNotes(for: bookId)
                let matchingNotes = notes.filter { note in
                    note.title.lowercased().contains(lowercaseQuery) ||
                    note.content.lowercased().contains(lowercaseQuery) ||
                    note.tags.contains { $0.lowercased().contains(lowercaseQuery) }
                }
                allNotes.append(contentsOf: matchingNotes)
            }
            
            return allNotes
        }
    }
    
    // MARK: - Export Functionality
    func exportNotesAndHighlights(for bookId: String, format: ExportFormat) -> String {
        let highlights = loadHighlights(for: bookId)
        let notes = loadNotes(for: bookId)
        let bookTitle = getBookTitle(for: bookId)
        
        switch format {
        case .text:
            return exportAsText(bookTitle: bookTitle, highlights: highlights, notes: notes)
        case .markdown:
            return exportAsMarkdown(bookTitle: bookTitle, highlights: highlights, notes: notes)
        case .json:
            return exportAsJSON(bookTitle: bookTitle, highlights: highlights, notes: notes)
        }
    }
    
    // MARK: - Private Methods
    private func loadHighlights(for bookId: String) -> [Highlight] {
        let key = "highlights_\(bookId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let highlights = try? JSONDecoder().decode([Highlight].self, from: data) else {
            return []
        }
        return highlights
    }
    
    private func saveHighlights(_ highlights: [Highlight], for bookId: String) {
        let key = "highlights_\(bookId)"
        if let data = try? JSONEncoder().encode(highlights) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func loadNotes(for bookId: String) -> [Note] {
        let key = "notes_\(bookId)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let notes = try? JSONDecoder().decode([Note].self, from: data) else {
            return []
        }
        return notes
    }
    
    private func saveNotes(_ notes: [Note], for bookId: String) {
        let key = "notes_\(bookId)"
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private func getAllBookIds() -> [String] {
        // Get all book IDs from stored books
        let books = BookStorage.shared.loadBooks()
        return books.map { $0.id }
    }
    
    private func getBookTitle(for bookId: String) -> String {
        let books = BookStorage.shared.loadBooks()
        return books.first { $0.id == bookId }?.title ?? "Unknown Book"
    }
    
    // MARK: - Export Methods
    private func exportAsText(bookTitle: String, highlights: [Highlight], notes: [Note]) -> String {
        var content = "Notes and Highlights for: \(bookTitle)\n"
        content += "Generated on: \(DateFormatter.readable.string(from: Date()))\n\n"
        
        if !highlights.isEmpty {
            content += "HIGHLIGHTS\n"
            content += String(repeating: "=", count: 50) + "\n\n"
            
            for highlight in highlights.sorted(by: { $0.dateCreated < $1.dateCreated }) {
                content += "• \(highlight.text)\n"
                content += "  Color: \(highlight.color.displayName)\n"
                
                if let note = highlight.note, !note.isEmpty {
                    content += "  Note: \(note)\n"
                }
                
                content += "  Date: \(DateFormatter.readable.string(from: highlight.dateCreated))\n\n"
            }
        }
        
        if !notes.isEmpty {
            content += "NOTES\n"
            content += String(repeating: "=", count: 50) + "\n\n"
            
            for note in notes.sorted(by: { $0.dateCreated < $1.dateCreated }) {
                content += "Title: \(note.title)\n"
                content += "Content: \(note.content)\n"
                
                if !note.tags.isEmpty {
                    content += "Tags: \(note.tags.joined(separator: ", "))\n"
                }
                
                content += "Date: \(DateFormatter.readable.string(from: note.dateCreated))\n\n"
            }
        }
        
        return content
    }
    
    private func exportAsMarkdown(bookTitle: String, highlights: [Highlight], notes: [Note]) -> String {
        var content = "# Notes and Highlights for: \(bookTitle)\n\n"
        content += "*Generated on: \(DateFormatter.readable.string(from: Date()))*\n\n"
        
        if !highlights.isEmpty {
            content += "## Highlights\n\n"
            
            for highlight in highlights.sorted(by: { $0.dateCreated < $1.dateCreated }) {
                content += "### \(highlight.color.displayName) Highlight\n\n"
                content += "> \(highlight.text)\n\n"
                
                if let note = highlight.note, !note.isEmpty {
                    content += "**Note:** \(note)\n\n"
                }
                
                content += "*\(DateFormatter.readable.string(from: highlight.dateCreated))*\n\n"
                content += "---\n\n"
            }
        }
        
        if !notes.isEmpty {
            content += "## Notes\n\n"
            
            for note in notes.sorted(by: { $0.dateCreated < $1.dateCreated }) {
                content += "### \(note.title)\n\n"
                content += "\(note.content)\n\n"
                
                if !note.tags.isEmpty {
                    content += "**Tags:** \(note.tags.map { "#\($0)" }.joined(separator: " "))\n\n"
                }
                
                content += "*\(DateFormatter.readable.string(from: note.dateCreated))*\n\n"
                content += "---\n\n"
            }
        }
        
        return content
    }
    
    private func exportAsJSON(bookTitle: String, highlights: [Highlight], notes: [Note]) -> String {
        let exportData = ExportData(
            bookTitle: bookTitle,
            exportDate: Date(),
            highlights: highlights,
            notes: notes
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(exportData)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error encoding JSON: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Types
enum ExportFormat: CaseIterable {
    case text
    case markdown
    case json
    
    var displayName: String {
        switch self {
        case .text: return "Plain Text"
        case .markdown: return "Markdown"
        case .json: return "JSON"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .markdown: return "md"
        case .json: return "json"
        }
    }
}

struct ExportData: Codable {
    let bookTitle: String
    let exportDate: Date
    let highlights: [Highlight]
    let notes: [Note]
}

// MARK: - Notifications
extension Notification.Name {
    static let highlightAdded = Notification.Name("highlightAdded")
    static let highlightRemoved = Notification.Name("highlightRemoved")
    static let highlightUpdated = Notification.Name("highlightUpdated")
    static let noteAdded = Notification.Name("noteAdded")
    static let noteRemoved = Notification.Name("noteRemoved")
    static let noteUpdated = Notification.Name("noteUpdated")
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let readable: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
