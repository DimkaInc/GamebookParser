import Foundation
final class RuleEngine {
    // MARK: - RULES
    private let rules: [ParsingRule] = [
        GoldDetectionRule()
    ]
    // MARK: - APPLY
    func process(
        page: inout Page
    ) {
        for rule in rules {
            rule.apply(to: &page)
        }
    }
}
