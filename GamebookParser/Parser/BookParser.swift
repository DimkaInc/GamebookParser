import Foundation
final class BookParser {
    // MARK: - PUBLIC
    func parseBook(
        from text: String
    ) -> Book {
        let pages = splitPages(
            from: text
        )
        return Book(
            name: "Неизвестная книга",
            author: "Неизвестный автор",
            pages: pages
        )
    }
    private func splitPages(
        from text: String
    ) -> [Int: Page] {
        var result: [Int: Page] = [:]
        let patterns = [
            #"(?m)^\s*(\d+)\s*$"#,
            #"(?m)^\s*(\d+)\."#,
            #"(?m)^§\s*(\d+)"#
        ]
        let nsText = text as NSString
        var matches: [NSTextCheckingResult] = []
        // MARK: - FIND PAGE FORMAT
        for pattern in patterns {
            let regex = try! NSRegularExpression(
                pattern: pattern
            )
            matches = regex.matches(
                in: text,
                range: NSRange(
                    location: 0,
                    length: nsText.length
                )
            )
            if !matches.isEmpty {
                //print("PAGE FORMAT FOUND:", pattern)
                break
            }
        }
        // MARK: - NO MATCHES
        guard !matches.isEmpty else {
            let normalized =
                TextCleaner.normalize(text)
            let page = Page(
                id: 0,
                text: normalized,
                items: detectItems(
                    in: normalized
                ),
                companions:
                    detectCompanions(
                        in: normalized
                    ),
                enemy: detectEnemies(
                    in: normalized
                ),
                actions: detectChoices(
                    in: normalized
                )
            )
            result[0] = page
            return result
        }
        // MARK: - INTRO / PAGE 0
        let firstMatch = matches[0]
        if firstMatch.range.location > 0 {
            let introRange = NSRange(
                location: 0,
                length: firstMatch.range.location
            )
            let introText =
                nsText.substring(
                    with: introRange
                )
            let normalized =
                TextCleaner.normalize(
                    introText
                )
            if !normalized.isEmpty {
                let page0 = Page(
                    id: 0,
                    text: normalized,
                    items: detectItems(
                        in: normalized
                    ),
                    companions:
                        detectCompanions(
                            in: normalized
                        ),
                    enemy: detectEnemies(
                        in: normalized
                    ),
                    actions: detectChoices(
                        in: normalized
                    )
                )
                result[0] = page0
            }
        }
        // MARK: - PARSE NORMAL PAGES
        for index in matches.indices {
            let match = matches[index]
            let pageString =
                nsText.substring(
                    with: match.range(at: 1)
                )
            guard let pageNumber =
                    Int(pageString)
            else {
                continue
            }
            let start =
                match.range.upperBound
            let end: Int
            if index + 1 < matches.count {
                end =
                    matches[index + 1]
                    .range.location
            } else {
                end = nsText.length
            }
            guard end > start else {
                continue
            }
            let contentRange = NSRange(
                location: start,
                length: end - start
            )
            let rawText =
                nsText.substring(
                    with: contentRange
                )
            let normalized =
                TextCleaner.normalize(
                    rawText
                )
            let page = Page(
                id: pageNumber,
                text: normalized.isEmpty
                    ? ["EMPTY PAGE"]
                    : normalized,
                items: detectItems(
                    in: normalized
                ),
                companions:
                    detectCompanions(
                        in: normalized
                    ),
                enemy: detectEnemies(
                    in: normalized
                ),
                actions: detectChoices(
                    in: normalized
                )
            )
            result[pageNumber] = page
        }
        //print("TOTAL PAGES:", result.count)
        return result
    }


}

import Foundation
extension BookParser {
    // MARK: - CHOICES
    func detectChoices(
        in lines: [String]
    ) -> PageActions {
        var choices: [Int: String] = [:]
        let regex = try! NSRegularExpression(
            pattern:
                #"(?i)(?:на страницу|перейди на|иди на|turn to|go to)\s+(\d+)"#
        )
        for line in lines {
            let nsLine = line as NSString
            let matches = regex.matches(
                in: line,
                range: NSRange(
                    location: 0,
                    length: nsLine.length
                )
            )
            for match in matches {
                let value = nsLine.substring(
                    with: match.range(at: 1)
                )
                if let page = Int(value) {
                    choices[page] = line
                }
            }
        }
        return PageActions(
            check: .empty,
            choice: choices
        )
    }

}

import Foundation
extension BookParser {
    // MARK: - ITEMS
    func detectItems(
        in lines: [String]
    ) -> ItemOperations {
        var add: [String: Int] = [:]
        var dec: [String: Int] = [:]
        for line in lines {
            let lower = line.lowercased()
            // ADD
            if lower.contains("получи")
                || lower.contains("возьми")
                || lower.contains("найди")
            {
                let item =
                    extractLastWord(
                        from: lower
                    )
                add[item] =
                    (add[item] ?? 0) + 1
            }
            // REMOVE
            if lower.contains("отдай")
                || lower.contains("потеряй")
                || lower.contains("лишись")
            {
                let item =
                    extractLastWord(
                        from: lower
                    )
                dec[item] =
                    (dec[item] ?? 0) + 1
            }
        }
        return ItemOperations(
            add: add,
            dec: dec
        )
    }
    // MARK: - HELPERS
    func extractLastWord(
        from text: String
    ) -> String {
        text
            .components(
                separatedBy:
                    .whitespacesAndNewlines
            )
            .last?
            .replacingOccurrences(
                of: ".",
                with: ""
            )
            .replacingOccurrences(
                of: ",",
                with: ""
            )
            ?? "unknown"
    }
}

import Foundation
extension BookParser {
    // MARK: - ENEMIES
    func detectEnemies(
        in lines: [String]
    ) -> [String: CharacterStats] {
        var enemies: [String: CharacterStats] = [:]
        let enemyKeywords = [
            "орк",
            "гоблин",
            "enemy",
            "monster",
            "враг",
            "страж",
            "зомби",
            "скелет",
            "демон",
            "рыцарь"
        ]
        let regex = try! NSRegularExpression(
            pattern:
                #"([А-ЯA-Z][а-яa-zA-Z]+).*?(\d+).*?(\d+)"#,
            options: []
        )
        for line in lines {
            let lower = line.lowercased()
            guard enemyKeywords.contains(
                where: { lower.contains($0) }
            ) else {
                continue
            }
            let nsLine = line as NSString
            let matches = regex.matches(
                in: line,
                range: NSRange(
                    location: 0,
                    length: nsLine.length
                )
            )
            for match in matches {
                guard match.numberOfRanges >= 4
                else {
                    continue
                }
                let name =
                    nsLine.substring(
                        with: match.range(at: 1)
                    )
                let skill = Int(
                    nsLine.substring(
                        with: match.range(at: 2)
                    )
                ) ?? 0
                let vitality = Int(
                    nsLine.substring(
                        with: match.range(at: 3)
                    )
                ) ?? 0
                enemies[name] = CharacterStats(
                    skill: skill,
                    vitality: vitality
                )
            }
        }
        return enemies
    }
}

import Foundation
extension BookParser {
    // MARK: - COMPANIONS
    func detectCompanions(
        in lines: [String]
    ) -> CompanionOperations {
        var companions:
            [String: CharacterStats] = [:]
        let keywords = [
            "союзник",
            "спутник",
            "друг",
            "ally",
            "companion",
            "wizard",
            "warrior"
        ]
        let regex = try! NSRegularExpression(
            pattern:
                #"([А-ЯA-Z][а-яa-zA-Z]+).*?(\d+).*?(\d+)"#,
            options: []
        )
        for line in lines {
            let lower = line.lowercased()
            guard keywords.contains(
                where: {
                    lower.contains($0)
                }
            ) else {
                continue
            }
            let nsLine = line as NSString
            let matches = regex.matches(
                in: line,
                range: NSRange(
                    location: 0,
                    length: nsLine.length
                )
            )
            for match in matches {
                guard match.numberOfRanges >= 4
                else {
                    continue
                }
                let name =
                    nsLine.substring(
                        with: match.range(at: 1)
                    )
                let skill = Int(
                    nsLine.substring(
                        with: match.range(at: 2)
                    )
                ) ?? 0
                let vitality = Int(
                    nsLine.substring(
                        with: match.range(at: 3)
                    )
                ) ?? 0
                companions[name] = CharacterStats(
                    skill: skill,
                    vitality: vitality
                )
            }
        }
        return CompanionOperations(
            add: companions,
            dec: [:]
        )
    }
}

