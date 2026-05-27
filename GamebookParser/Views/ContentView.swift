import SwiftUI
import UniformTypeIdentifiers
import Observation
// MARK: - ROOT VIEW
struct ContentView: View {
    // MARK: - STATE
    @State private var vm = ContentViewModel()
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var searchText = ""
    // MARK: - BODY
    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        // IMPORT TXT
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText]
        ) { result in
            switch result {
            case .success(let url):
                vm.openFile(url: url)
            case .failure(let error):
                print(error)
            }
        }
        // EXPORT JSON
        .fileExporter(
            isPresented: $showExporter,
            document: JSONDocument(
                text: vm.jsonOutput
            ),
            contentType: .json,
            defaultFilename: vm.exportFileName
        ) { result in
            switch result {
            case .success:
                print("JSON exported")
            case .failure(let error):
                print(error)
            }
        }
    }
}

// MARK: - SIDEBAR
extension ContentView {
    var sidebarView: some View {
        VStack(spacing: 0) {
            headerButtons
            Divider()
            searchField
            Divider()
            pagesList
            Divider()
            validationPanel
        }
        .navigationTitle("Gamebook Parser")
    }
}

// MARK: - HEADER BUTTONS
extension ContentView {
    var headerButtons: some View {
        VStack(spacing: 12) {
            Button {
                showImporter = true
            } label: {
                Label(
                    "Open TXT",
                    systemImage: "folder"
                )
            }
            .buttonStyle(.borderedProminent)
            Button {
                showExporter = true
            } label: {
                Label(
                    "Export JSON",
                    systemImage: "square.and.arrow.down"
                )
            }
            .buttonStyle(.bordered)
            if !vm.sourceFileName.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source File")
                        .font(.caption)
                    Text(vm.sourceFileName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Export")
                        .font(.caption)
                    Text(vm.exportFileName + ".json")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}

// MARK: - SEARCH FIELD
extension ContentView {
    var searchField: some View {
        VStack {
            TextField(
                "Search pages...",
                text: $searchText
            )
            .textFieldStyle(.roundedBorder)
        }
        .padding()
    }
}

// MARK: - PAGES LIST
extension ContentView {
    var pagesList: some View {
        List(
            filteredPages,
            id: \.self,
            selection: $vm.selectedPageID
        ) { pageID in
            pageRow(pageID)
        }
    }
    private var filteredPages: [Int] {
        guard let book = vm.book else {
            return []
        }
        return book.pages.keys
            .sorted()
            .filter { pageID in
                guard !searchText.isEmpty else {
                    return true
                }
                guard let page = book.pages[pageID] else {
                    return false
                }
                return page.text
                    .joined(separator: " ")
                    .localizedCaseInsensitiveContains(searchText)
            }
    }
    @ViewBuilder
    private func pageRow(_ pageID: Int) -> some View {
        HStack {
            Text("Page \(pageID)")
            Spacer()
            if vm.hasValidationIssue(pageID) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - VALIDATION PANEL
extension ContentView {
    var validationPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Validation")
                    .font(.headline)
                if vm.validationIssues.isEmpty {
                    Label(
                        "No issues",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
                ForEach(vm.validationIssues) { issue in
                    validationCard(issue)
                }
            }
            .padding()
        }
        .frame(minHeight: 220)
    }
    @ViewBuilder
    private func validationCard(
        _ issue: ValidationIssue
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(
                    systemName:
                        issue.severity == .error
                    ? "xmark.octagon.fill"
                    : "exclamationmark.triangle.fill"
                )
                Text(
                    issue.severity == .error
                    ? "ERROR"
                    : "WARNING"
                )
                .bold()
            }
            Text("Page: \(issue.page)")
            Text(issue.message)
                .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            issue.severity == .error
            ? Color.red.opacity(0.15)
            : Color.orange.opacity(0.15)
        )
        .cornerRadius(12)
    }
}

// MARK: - DETAIL VIEW
extension ContentView {
    var detailView: some View {
        Group {
            if let book = vm.book {
                TabView {
                    editorTab(book)
                    graphTab(book)
                    jsonTab
                    statisticsTab(book)
                }
            } else {
                emptyState
            }
        }
    }
}

// MARK: - EMPTY STATE
extension ContentView {
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
            Text("Open TXT gamebook")
                .font(.largeTitle)
            Button {
                showImporter = true
            } label: {
                Label(
                    "Open File",
                    systemImage: "folder"
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - EDITOR TAB
extension ContentView {
    @ViewBuilder
    func editorTab(
        _ book: Book
    ) -> some View {
        if let selected = vm.selectedPageID {
            if let pageBinding =
                bindingForPage(selected)
            {
                PageEditorView(
                    page: pageBinding,
                    onChanged: {
                        vm.saveState()
                        vm.validate()
                        vm.updateJSON()
                        vm.autosave()
                    }
                )
            } else {
                Text("Invalid page binding")
            }
        } else {
            Text("Select page")
        }
    }
}

// MARK: - GRAPH TAB
extension ContentView {
    func graphTab(
        _ book: Book
    ) -> some View {
        GraphCanvasView(book: book)
            .padding()
            .tabItem {
                Label(
                    "Graph",
                    systemImage:
                        "point.3.connected.trianglepath.dotted"
                )
            }
    }
}

// MARK: - JSON TAB
extension ContentView {
    var jsonTab: some View {
        ScrollView {
            Text(vm.jsonOutput)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding()
                .textSelection(.enabled)
                .font(.system(.body, design: .monospaced))
        }
        .tabItem {
            Label(
                "JSON",
                systemImage: "curlybraces"
            )
        }
    }
}

// MARK: - STATISTICS TAB
extension ContentView {
    func statisticsTab(
        _ book: Book
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statisticCard(
                    title: "Pages",
                    value: "\(book.pages.count)"
                )
                statisticCard(
                    title: "Transitions",
                    value: "\(vm.totalTransitions)"
                )
                statisticCard(
                    title: "Enemies",
                    value: "\(vm.totalEnemies)"
                )
                statisticCard(
                    title: "Items",
                    value: "\(vm.totalItems)"
                )
            }
            .padding()
        }
        .tabItem {
            Label(
                "Stats",
                systemImage: "chart.bar.fill"
            )
        }
    }
    @ViewBuilder
    private func statisticCard(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.largeTitle)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(16)
    }
}

// MARK: - PAGE BINDING
extension ContentView {
    func bindingForPage(
        _ pageID: Int
    ) -> Binding<Page>? {
        guard vm.book != nil else {
            return nil
        }
        return Binding<Page>(
            get: {
                vm.book!.pages[pageID]!
            },
            set: {
                vm.book!.pages[pageID] = $0
                
                vm.book = vm.book
                vm.updateJSON()
                vm.validate()
            }
        )
    }
}
