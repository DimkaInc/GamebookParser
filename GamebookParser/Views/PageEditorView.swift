import SwiftUI
struct PageEditorView: View {
    // MARK: - BINDING
    @Binding var page: Page
    // MARK: - CALLBACK
    var onChanged: () -> Void
    // MARK: - STATE
    @State private var newChoicePage = ""
    @State private var newChoiceText = ""
    // MARK: - BODY
    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                header
                textSection
                choicesSection
                itemsSection
                enemiesSection
                companionsSection
            }
            .padding()
        }
    }
}

import SwiftUI
extension PageEditorView {
    // MARK: - HEADER
    var header: some View {
        VStack(alignment: .leading) {
            Text("Page \(page.id)")
                .font(.largeTitle)
            Divider()
        }
    }
    // MARK: - TEXT
    var textSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Text")
                .font(.headline)
            ForEach(
                page.text.indices,
                id: \.self
            ) { index in
                TextEditor(
                    text: Binding(
                        get: {
                            page.text[index]
                        },
                        set: {
                            page.text[index] = $0
                            onChanged()
                        }
                    )
                )
                .frame(height: 90)
                .padding(6)
                .background(
                    Color.gray.opacity(0.1)
                )
                .cornerRadius(10)
            }
        }
    }
}

import SwiftUI
extension PageEditorView {
    // MARK: - CHOICES
    var choicesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Choices")
                .font(.headline)
            ForEach(
                page.actions.choice
                    .keys
                    .sorted(),
                id: \.self
            ) { key in
                HStack {
                    Text("→ \(key)")
                        .frame(width: 80)
                    TextField(
                        "Description",
                        text: Binding(
                            get: {
                                page.actions
                                    .choice[key] ?? ""
                            },
                            set: {
                                page.actions
                                    .choice[key] = $0
                                onChanged()
                            }
                        )
                    )
                    .textFieldStyle(
                        .roundedBorder
                    )
                }
            }
            Divider()
            HStack {
                TextField(
                    "Page",
                    text: $newChoicePage
                )
                .frame(width: 100)
                TextField(
                    "Description",
                    text: $newChoiceText
                )
                Button("Add") {
                    addChoice()
                }
            }
        }
    }
    // MARK: - ADD CHOICE
    func addChoice() {
        guard let pageNum =
                Int(newChoicePage)
        else {
            return
        }
        page.actions.choice[pageNum] =
            newChoiceText
        newChoicePage = ""
        newChoiceText = ""
        onChanged()
    }
}

import SwiftUI
extension PageEditorView {
    // MARK: - ITEMS
    var itemsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            Text("Items")
                .font(.headline)
            addItemsBlock
            removeItemsBlock
        }
    }
    // MARK: - ADD ITEMS
    var addItemsBlock: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("Add")
                .font(.subheadline)
                .bold()
            ForEach(
                page.items.add.keys.sorted(),
                id: \.self
            ) { key in
                itemRow(
                    name: key,
                    count: Binding(
                        get: {
                            page.items.add[key] ?? 0
                        },
                        set: {
                            page.items.add[key] = $0
                            onChanged()
                        }
                    )
                )
            }
        }
    }
    // MARK: - REMOVE ITEMS
    var removeItemsBlock: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("Remove")
                .font(.subheadline)
                .bold()
            ForEach(
                page.items.dec.keys.sorted(),
                id: \.self
            ) { key in
                itemRow(
                    name: key,
                    count: Binding(
                        get: {
                            page.items.dec[key] ?? 0
                        },
                        set: {
                            page.items.dec[key] = $0
                            onChanged()
                        }
                    )
                )
            }
        }
    }
    // MARK: - ITEM ROW
    @ViewBuilder
    func itemRow(
        name: String,
        count: Binding<Int>
    ) -> some View {
        HStack {
            Text(name)
            Spacer()
            Stepper(
                "\(count.wrappedValue)",
                value: count,
                in: 0...999
            )
            .frame(width: 160)
        }
        .padding(8)
        .background(
            Color.gray.opacity(0.08)
        )
        .cornerRadius(10)
    }
}

import SwiftUI
extension PageEditorView {
    // MARK: - ENEMIES
    var enemiesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Enemies")
                .font(.headline)
            ForEach(
                page.enemy.keys.sorted(),
                id: \.self
            ) { key in
                enemyRow(name: key)
            }
        }
    }
    // MARK: - ENEMY ROW
    @ViewBuilder
    func enemyRow(
        name: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(name)
                .font(.headline)
            HStack {
                Text("Skill")
                Stepper(
                    "\(page.enemy[name]?.skill ?? 0)",
                    value: Binding(
                        get: {
                            page.enemy[name]?.skill ?? 0
                        },
                        set: {
                            page.enemy[name]?.skill = $0
                            onChanged()
                        }
                    ),
                    in: 0...99
                )
            }
            HStack {
                Text("Vitality")
                Stepper(
                    "\(page.enemy[name]?.vitality ?? 0)",
                    value: Binding(
                        get: {
                            page.enemy[name]?.vitality ?? 0
                        },
                        set: {
                            page.enemy[name]?.vitality = $0
                            onChanged()
                        }
                    ),
                    in: 0...999
                )
            }
        }
        .padding()
        .background(
            Color.red.opacity(0.1)
        )
        .cornerRadius(12)
    }
}

import SwiftUI
extension PageEditorView {
    // MARK: - COMPANIONS
    var companionsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Companions")
                .font(.headline)
            ForEach(
                page.companions
                    .add
                    .keys
                    .sorted(),
                id: \.self
            ) { key in
                companionRow(name: key)
            }
        }
    }
    // MARK: - COMPANION ROW
    @ViewBuilder
    func companionRow(
        name: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(name)
                .font(.headline)
            HStack {
                Text("Skill")
                Stepper(
                    "\(page.companions.add[name]?.skill ?? 0)",
                    value: Binding(
                        get: {
                            page.companions
                                .add[name]?
                                .skill ?? 0
                        },
                        set: {
                            page.companions
                                .add[name]?
                                .skill = $0
                            onChanged()
                        }
                    ),
                    in: 0...99
                )
            }
            HStack {
                Text("Vitality")
                Stepper(
                    "\(page.companions.add[name]?.vitality ?? 0)",
                    value: Binding(
                        get: {
                            page.companions
                                .add[name]?
                                .vitality ?? 0
                        },
                        set: {
                            page.companions
                                .add[name]?
                                .vitality = $0
                            onChanged()
                        }
                    ),
                    in: 0...999
                )
            }
        }
        .padding()
        .background(
            Color.green.opacity(0.1)
        )
        .cornerRadius(12)
    }
}

