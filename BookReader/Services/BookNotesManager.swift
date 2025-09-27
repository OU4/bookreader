//
//  BookNotesManager.swift
//  BookReader
//
//  Central coordinator for personal notes backed by BookNotesStore.
//

import Foundation

final class BookNotesManager {
    static let shared = BookNotesManager()

    private let queue = DispatchQueue(label: "com.bookreader.notes.manager", qos: .userInitiated)
    private let storage = BookStorage.shared
    private let notesStore = BookNotesStore.shared

    private var records: [String: BookNotesRecord] = [:]
    private var isLoaded = false

    private init() {}

    // MARK: - Public API

    func snapshot(for bookId: String, bookTitle: String, fallbackBook: Book? = nil) -> BookNotesRecord {
        return queue.sync {
            ensureRecordsLoaded()
            if var record = records[bookId] {
                if let latestSource = fallbackBook ?? self.fallbackBook(for: bookId),
                   shouldReplace(record: record, with: latestSource) {
                    record = makeRecord(bookId: bookId, title: bookTitle, fallback: latestSource)
                    records[bookId] = record
                    persistLocked()
                }
                if record.bookTitle != bookTitle {
                    record.bookTitle = bookTitle
                    records[bookId] = record
                    persistLocked()
                }
                return record
            }

            let fallback = fallbackBook ?? self.fallbackBook(for: bookId)
            var newRecord = makeRecord(bookId: bookId, title: bookTitle, fallback: fallback)
            records[bookId] = newRecord
            persistLocked()
            return newRecord
        }
    }

    func updateNotes(for bookId: String,
                     bookTitle: String,
                     summary: String?,
                     takeaways: String?,
                     actionItems: String?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.ensureRecordsLoaded()

            var record = self.records[bookId] ?? self.makeRecord(bookId: bookId, title: bookTitle, fallback: self.fallbackBook(for: bookId))
            record.bookTitle = bookTitle
            record.personalSummary = summary ?? ""
            record.keyTakeaways = takeaways ?? ""
            record.actionItems = actionItems ?? ""
            record.notesUpdatedAt = Date()

            self.records[bookId] = record
            self.persistLocked()
            self.syncBookStorage(with: record)
            self.notifyUpdate(record)
        }
    }

    func addSessionNote(to bookId: String,
                        bookTitle: String,
                        text: String,
                        tags: [String],
                        pageHint: Int?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.ensureRecordsLoaded()

            var record = self.records[bookId] ?? self.makeRecord(bookId: bookId, title: bookTitle, fallback: self.fallbackBook(for: bookId))
            record.bookTitle = bookTitle

            var notes = record.sessionNotes
            let note = BookSessionNote(text: text, tags: tags, pageHint: pageHint)
            notes.append(note)
            notes.sort { $0.createdAt < $1.createdAt }

            record.sessionNotes = notes
            record.notesUpdatedAt = Date()

            self.records[bookId] = record
            self.persistLocked()
            self.syncBookStorage(with: record)
            self.notifyUpdate(record)
        }
    }

    func updateSessionNote(bookId: String,
                           bookTitle: String,
                           noteId: String,
                           text: String,
                           tags: [String],
                           pageHint: Int?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.ensureRecordsLoaded()

            var record = self.records[bookId] ?? self.makeRecord(bookId: bookId, title: bookTitle, fallback: self.fallbackBook(for: bookId))

            record.bookTitle = bookTitle
            guard let index = record.sessionNotes.firstIndex(where: { $0.id == noteId }) else { return }

            var note = record.sessionNotes[index]
            note.text = text
            note.tags = tags
            note.pageHint = pageHint
            note.updatedAt = Date()
            record.sessionNotes[index] = note
            record.sessionNotes.sort { $0.createdAt < $1.createdAt }
            record.notesUpdatedAt = Date()

            self.records[bookId] = record
            self.persistLocked()
            self.syncBookStorage(with: record)
            self.notifyUpdate(record)
        }
    }

    func removeSessionNote(bookId: String,
                           bookTitle: String,
                           noteId: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.ensureRecordsLoaded()

            var record = self.records[bookId] ?? self.makeRecord(bookId: bookId, title: bookTitle, fallback: self.fallbackBook(for: bookId))
            record.bookTitle = bookTitle

            let originalCount = record.sessionNotes.count
            record.sessionNotes.removeAll { $0.id == noteId }
            guard record.sessionNotes.count != originalCount else { return }
            record.notesUpdatedAt = Date()

            self.records[bookId] = record
            self.persistLocked()
            self.syncBookStorage(with: record)
            self.notifyUpdate(record)
        }
    }

    // MARK: - Helpers

    private func ensureRecordsLoaded() {
        if !isLoaded {
            records = notesStore.loadRecords()
            isLoaded = true
        }
    }

    private func makeRecord(bookId: String, title: String, fallback: Book?) -> BookNotesRecord {
        if let fallback {
            return BookNotesRecord(
                bookId: bookId,
                bookTitle: fallback.title.isEmpty ? title : fallback.title,
                personalSummary: fallback.personalSummary,
                keyTakeaways: fallback.keyTakeaways,
                actionItems: fallback.actionItems,
                sessionNotes: fallback.sessionNotes.sorted { $0.createdAt < $1.createdAt },
                notesUpdatedAt: fallback.notesUpdatedAt
            )
        }

        return BookNotesRecord(
            bookId: bookId,
            bookTitle: title,
            personalSummary: "",
            keyTakeaways: "",
            actionItems: "",
            sessionNotes: [],
            notesUpdatedAt: nil
        )
    }

    private func fallbackBook(for bookId: String) -> Book? {
        if let remote = UnifiedFirebaseStorage.shared.books.first(where: { $0.id == bookId }) {
            return remote
        }

        let localBooks = storage.loadBooks()
        return localBooks.first(where: { $0.id == bookId })
    }

    private func shouldReplace(record: BookNotesRecord, with book: Book) -> Bool {
        let recordTimestamp = record.notesUpdatedAt ?? Date.distantPast
        let candidateTimestamp = book.notesUpdatedAt ?? Date.distantPast

        if candidateTimestamp > recordTimestamp {
            return true
        }

        if candidateTimestamp == recordTimestamp {
            return notesContentIsEmpty(record: record) && !notesContentIsEmpty(book: book)
        }

        return false
    }

    private func notesContentIsEmpty(record: BookNotesRecord) -> Bool {
        return record.personalSummary.isEmpty &&
            record.keyTakeaways.isEmpty &&
            record.actionItems.isEmpty &&
            record.sessionNotes.isEmpty
    }

    private func notesContentIsEmpty(book: Book) -> Bool {
        return book.personalSummary.isEmpty &&
            book.keyTakeaways.isEmpty &&
            book.actionItems.isEmpty &&
            book.sessionNotes.isEmpty
    }

    private func persistLocked() {
        notesStore.saveRecords(records)
    }

    private func syncBookStorage(with record: BookNotesRecord) {
        var books = storage.loadBooks()
        if let index = books.firstIndex(where: { $0.id == record.bookId }) {
            var book = books[index]
            book.personalSummary = record.personalSummary
            book.keyTakeaways = record.keyTakeaways
            book.actionItems = record.actionItems
            book.sessionNotes = record.sessionNotes
            book.notesUpdatedAt = record.notesUpdatedAt ?? Date()
            storage.updateBook(book)
            return
        }

        if var remote = UnifiedFirebaseStorage.shared.books.first(where: { $0.id == record.bookId }) {
            remote.personalSummary = record.personalSummary
            remote.keyTakeaways = record.keyTakeaways
            remote.actionItems = record.actionItems
            remote.sessionNotes = record.sessionNotes
            remote.notesUpdatedAt = record.notesUpdatedAt ?? Date()
            UnifiedFirebaseStorage.shared.updateBook(remote) { _ in }
        }
    }

    private func notifyUpdate(_ record: BookNotesRecord) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .bookNotesUpdated,
                object: nil,
                userInfo: [
                    "bookId": record.bookId,
                    "record": record
                ]
            )
        }
    }
}
