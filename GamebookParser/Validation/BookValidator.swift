import Foundation
final class BookValidator {
    // MARK: - VALIDATE
    func validate(
        book: Book
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let allPages =
            Set(book.pages.keys)
        // REACHABILITY
        var reachable: Set<Int> = []
        func dfs(_ page: Int) {
            guard !reachable.contains(page)
            else {
                return
            }
            reachable.insert(page)
            guard let current =
                    book.pages[page]
            else {
                return
            }
            for next in current
                .actions
                .choice
                .keys
            {
                dfs(next)
            }
        }
        if let start =
            allPages.sorted().first
        {
            dfs(start)
        }
        // UNREACHABLE
        for page in allPages.sorted() {
            if !reachable.contains(page) {
                issues.append(
                    ValidationIssue(
                        severity: .warning,
                        page: page,
                        message:
                            "Страница недостижима"
                    )
                )
            }
        }
        // INVALID LINKS
        for (_, page) in book.pages {
            for target in page
                .actions
                .choice
                .keys
            {
                if !allPages.contains(target) {
                    issues.append(
                        ValidationIssue(
                            severity: .error,
                            page: page.id,
                            message:
                                "Переход на несуществующую страницу \(target)"
                        )
                    )
                }
            }
        }
        // DEAD ENDS
        for (_, page) in book.pages {
            let hasChoices =
                !page.actions.choice.isEmpty
            let isEnding =
                page.text
                    .joined()
                    .lowercased()
                    .contains("конец")
            if !hasChoices && !isEnding {
                issues.append(
                    ValidationIssue(
                        severity: .warning,
                        page: page.id,
                        message:
                            "Возможный dead-end"
                    )
                )
            }
        }
        // CYCLES
        issues += detectCycles(
            book: book
        )
        return issues
    }
    // MARK: - CYCLES
    private func detectCycles(
        book: Book
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        var visited: Set<Int> = []
        var stack: Set<Int> = []
        func dfs(_ page: Int) {
            if stack.contains(page) {
                issues.append(
                    ValidationIssue(
                        severity: .warning,
                        page: page,
                        message:
                            "Обнаружен цикл"
                    )
                )
                return
            }
            if visited.contains(page) {
                return
            }
            visited.insert(page)
            stack.insert(page)
            guard let current =
                    book.pages[page]
            else {
                return
            }
            for next in current
                .actions
                .choice
                .keys
            {
                dfs(next)
            }
            stack.remove(page)
        }
        if let start =
            book.pages.keys.sorted().first
        {
            dfs(start)
        }
        return issues
    }
}
