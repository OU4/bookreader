//
//  BookNotesStore.swift
//  BookReader
//
//  Lightweight persistence for personal notes independent from book files.
//

import Foundation

struct BookNotesRecord: Codable {
    let bookId: String
    var bookTitle: String
    var personalSummary: String
    var keyTakeaways: String
    var actionItems: String
    var sessionNotes: [BookSessionNote]
    var notesUpdatedAt: Date?
}

final class BookNotesStore {
    static let shared = BookNotesStore()

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let writeQueue = DispatchQueue(label: "com.bookreader.notes.store.write", qos: .utility)

    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = documentsDirectory.appendingPathComponent("book_notes.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadRecords() -> [String: BookNotesRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let records = try decoder.decode([BookNotesRecord].self, from: data)
            return Dictionary(uniqueKeysWithValues: records.map { ($0.bookId, $0) })
        } catch {
            return [:]
        }
    }

    func saveRecords(_ records: [String: BookNotesRecord]) {
        writeQueue.async { [encoder, fileURL] in
            let array = Array(records.values)
            do {
                let data = try encoder.encode(array)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Best effort persistence; ignore write failures for now.
            }
        }
    }
}
