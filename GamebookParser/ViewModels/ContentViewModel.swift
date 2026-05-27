import Foundation
import Observation
@Observable
final class ContentViewModel {
    // MARK: - BOOK
    var book: Book?
    // MARK: - UI STATE
    var selectedPageID: Int?
    var validationIssues: [ValidationIssue] = []
    var jsonOutput: String = ""
    // MARK: - FILES
    var sourceFileURL: URL?
    var sourceFileName: String = ""
    var exportFileName: String = "book"
    // MARK: - SERVICES
    private let parser = BookParser()
    private let validator = BookValidator()
    // MARK: - OPEN FILE
    func openFile(url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url)
            let text =
               String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1251)
            ?? String(data: data, encoding: .unicode)
            ?? ""
            //let text = try String(
            //    contentsOf: url,
            //    encoding: .utf8
            //)
            sourceFileURL = url
            sourceFileName = url.lastPathComponent
            exportFileName =
                url.deletingPathExtension()
                    .lastPathComponent
            let parsedBook = parser.parseBook(
                from: text
            )
            //print(parsedBook.pages.count)
            self.book = parsedBook
            selectedPageID =
                parsedBook.pages.keys.sorted().first
            validate()
            updateJSON()
            autosave()
        } catch {
            print(error)
        }
    }
    // MARK: - VALIDATION
    func validate() {
        guard let book else {
            return
        }
        validationIssues =
            validator.validate(book: book)
    }
    // MARK: - JSON
    func updateJSON() {
        guard let book else {
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys
            ]
            let data = try encoder.encode(book)
            jsonOutput =
                String(
                    data: data,
                    encoding: .utf8
                ) ?? ""
        } catch {
            jsonOutput = error.localizedDescription
        }
    }
    // MARK: - EXPORT
    func exportJSON(to url: URL) {
        guard let book else {
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys
            ]
            let data = try encoder.encode(book)
            try data.write(to: url)
        } catch {
            print(error)
        }
    }
    // MARK: - AUTOSAVE
    func autosave() {
        guard let book else {
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys
            ]
            let data = try encoder.encode(book)
            let autosaveURL =
                autosaveDirectory()
                .appendingPathComponent(
                    exportFileName + "_autosave.json"
                )
            try data.write(to: autosaveURL)
        } catch {
            print(error)
        }
    }
    // MARK: - HELPERS
    func autosaveDirectory() -> URL {
        FileManager.default
            .urls(
                for: .documentDirectory,
                in: .userDomainMask
            )
            .first!
    }
    func hasValidationIssue(
        _ page: Int
    ) -> Bool {
        validationIssues.contains {
            $0.page == page
        }
    }
    // MARK: - STATS
    var totalTransitions: Int {
        guard let book else {
            return 0
        }
        return book.pages.values.reduce(0) {
            $0 + $1.actions.choice.count
        }
    }
    var totalEnemies: Int {
        guard let book else {
            return 0
        }
        return book.pages.values.reduce(0) {
            $0 + $1.enemy.count
        }
    }
    var totalItems: Int {
        guard let book else {
            return 0
        }
        return book.pages.values.reduce(0) {
            $0
            + $1.items.add.count
            + $1.items.dec.count
        }
    }
}

import Foundation
extension ContentViewModel {
    // MARK: - LOAD AUTOSAVE
    func loadAutosaveIfNeeded() {
        let url =
            autosaveDirectory()
            .appendingPathComponent(
                exportFileName + "_autosave.json"
            )
        guard FileManager.default
            .fileExists(atPath: url.path)
        else {
            return
        }
        do {
            let data = try Data(
                contentsOf: url
            )
            let decoder = JSONDecoder()
            let restored =
                try decoder.decode(
                    Book.self,
                    from: data
                )
            self.book = restored
            updateJSON()
            validate()
        } catch {
            print(error)
        }
    }
}

import Foundation
final class UndoRedoManager<T> {
    // MARK: - STACKS
    private var undoStack: [T] = []
    private var redoStack: [T] = []
    // MARK: - SAVE
    func save(_ value: T) {
        undoStack.append(value)
        redoStack.removeAll()
    }
    // MARK: - UNDO
    func undo(
        current: T
    ) -> T? {
        guard let previous =
                undoStack.popLast()
        else {
            return nil
        }
        redoStack.append(current)
        return previous
    }
    // MARK: - REDO
    func redo(
        current: T
    ) -> T? {
        guard let next =
                redoStack.popLast()
        else {
            return nil
        }
        undoStack.append(current)
        return next
    }
}

import Foundation
extension ContentViewModel {
    // MARK: - UNDO REDO
    private static let history =
        UndoRedoManager<Book>()
    func saveState() {
        guard let book else {
            return
        }
        Self.history.save(book)
    }
    func undo() {
        guard let current = book,
              let previous =
                Self.history.undo(
                    current: current
                )
        else {
            return
        }
        book = previous
        validate()
        updateJSON()
    }
    func redo() {
        guard let current = book,
              let next =
                Self.history.redo(
                    current: current
                )
        else {
            return
        }
        book = next
        validate()
        updateJSON()
    }
}

import Foundation
protocol ParsingRule {
    func apply(
        to page: inout Page
    )
}

import Foundation
struct GoldDetectionRule: ParsingRule {
    func apply(
        to page: inout Page
    ) {
        let text =
            page.text.joined(separator: " ")
        let regex = try! NSRegularExpression(
            pattern:
                #"(\d+)\s+золот"#,
            options: [.caseInsensitive]
        )
        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            range: NSRange(
                location: 0,
                length: nsText.length
            )
        )
        for match in matches {
            guard match.numberOfRanges > 1
            else {
                continue
            }
            let value =
                Int(
                    nsText.substring(
                        with: match.range(at: 1)
                    )
                ) ?? 0
            page.items.add["gold"] =
                (page.items.add["gold"] ?? 0)
                + value
        }
    }
}

