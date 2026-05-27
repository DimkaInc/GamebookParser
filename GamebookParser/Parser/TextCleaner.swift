import Foundation
enum TextCleaner {
    static func normalize(
        _ text: String
    ) -> [String] {
        let lines = text.components(
            separatedBy: .newlines
        )
        var result: [String] = []
        var current = ""
        for rawLine in lines {
            let line = rawLine
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            guard !line.isEmpty else {
                continue
            }
            if current.isEmpty {
                current = line
                continue
            }
            if shouldMerge(
                current: current,
                next: line
            ) {
                current += " " + line
            } else {
                result.append(current)
                current = line
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }
    // MARK: - MERGE RULES
    private static func shouldMerge(
        current: String,
        next: String
    ) -> Bool {
        guard let last = current.last else {
            return false
        }
        let endings: [Character] = [
            ".",
            "!",
            "?",
            ":",
            ";"
        ]
        if endings.contains(last) {
            return false
        }
        guard let first = next.first else {
            return false
        }
        return first.isLowercase
    }
}
