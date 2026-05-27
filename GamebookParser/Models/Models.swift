import Foundation
// MARK: - BOOK
struct Book: Codable {
    var name: String
    var author: String
    var pages: [Int: Page]
}
// MARK: - PAGE
struct Page: Codable, Identifiable {
    var id: Int
    var text: [String]
    var items: ItemOperations
    var companions: CompanionOperations
    var enemy: [String: CharacterStats]
    var actions: PageActions
}
// MARK: - CHARACTER
struct CharacterStats: Codable {
    var skill: Int
    var vitality: Int
}
// MARK: - ITEMS
struct ItemOperations: Codable {
    var add: [String: Int]
    var dec: [String: Int]
    static let empty = ItemOperations(
        add: [:],
        dec: [:]
    )
}
// MARK: - COMPANIONS
struct CompanionOperations: Codable {
    var add: [String: CharacterStats]
    var dec: [String: CharacterStats]
    static let empty = CompanionOperations(
        add: [:],
        dec: [:]
    )
}
// MARK: - CHECK ACTIONS
struct CheckActions: Codable {
    var values: [String: [String: String]]
    static let empty = CheckActions(
        values: [:]
    )
}
// MARK: - ACTIONS
struct PageActions: Codable {
    var check: CheckActions
    var choice: [Int: String]
    static let empty = PageActions(
        check: .empty,
        choice: [:]
    )
}
// MARK: - VALIDATION
struct ValidationIssue: Identifiable {
    enum Severity {
        case warning
        case error
    }
    let id = UUID()
    let severity: Severity
    let page: Int
    let message: String
}
