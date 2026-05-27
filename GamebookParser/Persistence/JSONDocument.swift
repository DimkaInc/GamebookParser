import SwiftUI
import UniformTypeIdentifiers
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json]
    }
    var text: String
    init(text: String) {
        self.text = text
    }
    init(configuration: ReadConfiguration) throws {
        guard let data =
                configuration.file.regularFileContents,
              let string = String(
                data: data,
                encoding: .utf8
              )
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }
    func fileWrapper(
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(
            regularFileWithContents: data
        )
    }
}
