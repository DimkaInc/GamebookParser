import Foundation
import NaturalLanguage
final class NLPParser {
    // MARK: - ENTITIES
    func extractEntities(
        from text: String
    ) -> [String] {
        let tagger = NLTagger(
            tagSchemes: [.nameType]
        )
        tagger.string = text
        var entities: [String] = []
        let range =
            text.startIndex..<text.endIndex
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .nameType,
            options: [.joinNames]
        ) { tag, tokenRange in
            if tag == .personalName {
                entities.append(
                    String(text[tokenRange])
                )
            }
            return true
        }
        return entities
    }
}
