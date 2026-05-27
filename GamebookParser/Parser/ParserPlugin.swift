import Foundation
protocol ParserPlugin {
    var name: String { get }
    func process(
        page: inout Page
    )
}

import Foundation
final class PluginManager {
    // MARK: - PLUGINS
    private var plugins:
        [ParserPlugin] = []
    // MARK: - REGISTER
    func register(
        _ plugin: ParserPlugin
    ) {
        plugins.append(plugin)
    }
    // MARK: - RUN
    func process(
        page: inout Page
    ) {
        for plugin in plugins {
            plugin.process(
                page: &page
            )
        }
    }
}

import Foundation
final class AIParsingEngine {
    // MARK: - ANALYZE
    func analyze(
        text: String
    ) async -> [String] {
        // future AI integration
        return []
    }
}

