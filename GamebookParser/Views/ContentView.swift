import SwiftUI
import UniformTypeIdentifiers
import Observation

// MARK: - ГЛАВНЫЙ ВЬЮ (КОРНЕВОЙ)
/// Основной контейнер приложения с навигацией SplitView.
/// Управляет импортом/экспортом файлов, отображением сайдбара и детальной области.
struct ContentView: View {
    
    // MARK: - СОСТОЯНИЕ (STATE)
    /// ViewModel для управления бизнес-логикой и данными приложения
    @State private var vm = ContentViewModel()
    /// Флаг отображения системного диалога импорта файлов
    @State private var showImporter = false
    /// Флаг отображения системного диалога экспорта файлов
    @State private var showExporter = false
    /// Текст поискового запроса для фильтрации страниц
    @State private var searchText = ""
    
    // MARK: - ОСНОВНОЙ ИНТЕРФЕЙС (BODY)
    var body: some View {
        // NavigationSplitView обеспечивает адаптивную навигацию:
        // - на iPad/Mac: две колонки одновременно
        // - на iPhone: навигация через push/pop
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced) // Оптимальное распределение ширины колонок
        
        // ─────────────────────────────────────────────────────────────
        // ИМПОРТ ФАЙЛА (TXT)
        // Системный модальный диалог выбора файла с фильтрацией по типу
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.plainText] // Разрешены только текстовые файлы
        ) { result in
            switch result {
            case .success(let url):
                // Передаём URL файла в ViewModel для парсинга и загрузки
                vm.openFile(url: url)
            case .failure(let error):
                // Логируем ошибку импорта в консоль
                print(error)
            }
        }
        
        // ─────────────────────────────────────────────────────────────
        // ЭКСПОРТ ФАЙЛА (JSON)
        // Системный диалог сохранения документа
        .fileExporter(
            isPresented: $showExporter,
            document: JSONDocument(
                text: vm.jsonOutput // Данные для экспорта из ViewModel
            ),
            contentType: .json, // Тип сохраняемого файла
            defaultFilename: vm.exportFileName // Имя файла по умолчанию
        ) { result in
            switch result {
            case .success:
                // Уведомление об успешном экспорте (локализованная строка)
                print(Text("json_exported_success"))
            case .failure(let error):
                // Логируем ошибку экспорта с описанием
                print(Text("file_export_error"), error.localizedDescription)
            }
        }
    }

    // MARK: - САЙДБАР (ЛЕВАЯ ПАНЕЛЬ)
    /// Вертикальный контейнер сайдбара с элементами управления и списком страниц
    var sidebarView: some View {
        VStack(spacing: 0) {
            headerButtons      // Кнопки импорта/экспорта + информация о файле
            Divider()          // Визуальный разделитель
            searchField        // Поле поиска по страницам
            Divider()
            pagesList          // Список страниц книги с фильтрацией
            Divider()
            validationPanel    // Панель валидации: ошибки и предупреждения
        }
        .navigationTitle(Text("program_title")) // Заголовок навигации
    }

    // MARK: - КНОПКИ В ЗАГОЛОВКЕ
    /// Группа кнопок управления файлами и отображение имён текущих файлов
    var headerButtons: some View {
        VStack(spacing: 12) {
            // Кнопка "Открыть файл" — вызывает системный импортер
            Button {
                showImporter = true
            } label: {
                Label(
                    String(localized: "open_txt"),
                    systemImage: "folder"
                )
            }
            .buttonStyle(.borderedProminent) // Акцентный стиль кнопки
            
            // Кнопка "Экспорт JSON" — вызывает системный экспортер
            Button {
                showExporter = true
            } label: {
                Label(
                    String(localized: "export_json"),
                    systemImage: "square.and.arrow.down"
                )
            }
            .buttonStyle(.bordered) // Стандартный стиль кнопки
            
            // Отображение имён файлов (только если файл загружен)
            if !vm.sourceFileName.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("source_file")
                        .font(.caption)
                    Text(vm.sourceFileName) // Имя исходного TXT-файла
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("export")
                        .font(.caption)
                    Text(vm.exportFileName + ".json") // Предлагаемое имя JSON
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    // MARK: - ПОЛЕ ПОИСКА
    /// Текстовое поле для фильтрации списка страниц по содержимому
    var searchField: some View {
        VStack {
            TextField(
                String(localized: "search_pages"), // Placeholder
                text: $searchText // Двустороннее связывание с состоянием
            )
            .textFieldStyle(.roundedBorder) // Системный стиль поля
        }
        .padding()
    }

    // MARK: - СПИСОК СТРАНИЦ
    /// Список ID страниц с поддержкой выбора и визуальной индикацией ошибок
    var pagesList: some View {
        List(
            filteredPages, // Отфильтрованный массив ID страниц
            id: \.self,
            selection: $vm.selectedPageID // Выбранная страница в ViewModel
        ) { pageID in
            pageRow(pageID) // Кастомный ряд для каждой страницы
        }
    }
    
    /// Вычисляемое свойство: возвращает отфильтрованный список ID страниц
    /// - Фильтрация по поисковому запросу (регистронезависимая)
    /// - Поиск осуществляется по объединённому тексту страницы
    private var filteredPages: [Int] {
        guard let book = vm.book else {
            return []
        }
        return book.pages.keys
            .sorted() // Сортировка по возрастанию номеров страниц
            .filter { pageID in
                // Если поиск пустой — показываем все страницы
                guard !searchText.isEmpty else {
                    return true
                }
                guard let page = book.pages[pageID] else {
                    return false
                }
                // Поиск подстроки в тексте страницы (без учёта регистра)
                return page.text
                    .joined(separator: " ")
                    .localizedCaseInsensitiveContains(searchText)
            }
    }
    
    /// Строитель представления для отдельной строки страницы
    /// - Отображает номер страницы
    /// - Показывает иконку предупреждения при наличии ошибок валидации
    @ViewBuilder
    private func pageRow(_ pageID: Int) -> some View {
        HStack {
            Text(String(format: NSLocalizedString("page", comment: ""), pageID))
            Spacer()
            // Индикатор ошибки валидации (оранжевый треугольник)
            if vm.hasValidationIssue(pageID) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - ПАНЕЛЬ ВАЛИДАЦИИ
    /// Скроллируемая панель с сообщениями об ошибках и предупреждениях
    var validationPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("validation")
                    .font(.headline)
                // Статус "Ошибок нет" при пустом списке проблем
                if vm.validationIssues.isEmpty {
                    Label(
                        String(localized:"no_issues"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
                // Список карточек с деталями каждой проблемы
                ForEach(vm.validationIssues) { issue in
                    validationCard(issue)
                }
            }
            .padding()
        }
        .frame(minHeight: 220) // Минимальная высота для удобства скролла
    }
    
    /// Карточка отдельной проблемы валидации
    /// - Визуально различает ошибки (красные) и предупреждения (оранжевые)
    /// - Отображает номер страницы и текст сообщения
    @ViewBuilder
    private func validationCard(
        _ issue: ValidationIssue
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Иконка в зависимости от серьёзности проблемы
                Image(
                    systemName:
                        issue.severity == .error
                    ? "xmark.octagon.fill"   // Ошибка: красный восьмиугольник
                    : "exclamationmark.triangle.fill" // Предупреждение: треугольник
                )
                Text(
                    issue.severity == .error
                    ? "error"
                    : "wsrning" // ⚠️ Опечатка в ключе локализации (warning)
                )
                .bold()
            }
            Text(String(format: NSLocalizedString("page", comment: ""), issue.page))
            Text(issue.message) // Детальное описание проблемы
                .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Цветовая индикация фона по типу проблемы
        .background(
            issue.severity == .error
            ? Color.red.opacity(0.15)
            : Color.orange.opacity(0.15)
        )
        .cornerRadius(12) // Скруглённые углы карточки
    }

    // MARK: - ДЕТАЛЬНАЯ ОБЛАСТЬ (ПРАВАЯ ПАНЕЛЬ)
    /// Контейнер с вкладками: редактор, граф, JSON, статистика
    /// Показывает emptyState, если книга не загружена
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

    // MARK: - ПУСТОЕ СОСТОЯНИЕ
    /// Экран-заглушка с призывом загрузить файл, когда книга не открыта
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 80))
            Text("open_txt")
                .font(.largeTitle)
            Button {
                showImporter = true
            } label: {
                Label(
                    String(localized: "open_txt"),
                    systemImage: "folder"
                )
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - ВКЛАДКА РЕДАКТОРА
    /// Редактор текста выбранной страницы с авто-сохранением и валидацией
    @ViewBuilder
    func editorTab(
        _ book: Book
    ) -> some View {
        if let selected = vm.selectedPageID {
            // Получаем Binding к странице для двустороннего редактирования
            if let pageBinding = bindingForPage(selected) {
                PageEditorView(
                    page: pageBinding,
                    onChanged: {
                        // Цепочка действий при изменении контента:
                        vm.saveState()      // Сохранение состояния для undo/redo
                        vm.validate()       // Проверка на ошибки
                        vm.updateJSON()     // Обновление JSON-представления
                        vm.autosave()       // Автосохранение на диск
                    }
                )
                .tabItem{
                    Label(
                        "book",
                        systemImage: "book.closed"
                    )
                }
            } else {
                Text("invalid_page_binding") // Фолбэк при ошибке связывания
            }
        } else {
            Text("select_page") // Подсказка: выберите страницу в сайдбаре
        }
    }

    // MARK: - ВКЛАДКА ГРАФА
    /// Визуализация структуры книги в виде графа переходов между страницами
    func graphTab(
        _ book: Book
    ) -> some View {
        GraphCanvasView(book: book) // Кастомный Canvas-вью для отрисовки графа
            .padding()
            .tabItem {
                Label(
                    "graph",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            }
    }

    // MARK: - ВКЛАДКА JSON
    /// Просмотр и копирование сгенерированного JSON-представления книги
    var jsonTab: some View {
        ScrollView {
            Text(vm.jsonOutput)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding()
                .textSelection(.enabled) // Разрешает выделение и копирование текста
                .font(.system(.body, design: .monospaced)) // Моноширинный шрифт для кода
        }
        .tabItem {
            Label(
                "JSON",
                systemImage: "curlybraces"
            )
        }
    }

    // MARK: - ВКЛАДКА СТАТИСТИКИ
    /// Сводная статистика по книге: страницы, переходы, враги, предметы
    func statisticsTab(
        _ book: Book
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statisticCard(
                    title: String(localized: "pages"),
                    value: "\(book.pages.count)"
                )
                statisticCard(
                    title: String(localized: "transitions"),
                    value: "\(vm.totalTransitions)"
                )
                statisticCard(
                    title: String(localized: "enemies"),
                    value: "\(vm.totalEnemies)"
                )
                statisticCard(
                    title: String(localized: "items"),
                    value: "\(vm.totalItems)"
                )
            }
            .padding()
        }
        .tabItem {
            Label(
                String(localized: "stats"),
                systemImage: "chart.bar.fill"
            )
        }
    }
    
    /// Переиспользуемая карточка для отображения пары "название: значение"
    @ViewBuilder
    private func statisticCard(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.largeTitle) // Крупное выделение числового значения
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(16)
    }

    // MARK: - ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
    
    /// Создаёт Binding к объекту Page для безопасного редактирования
    /// - Возвращает nil, если книга не загружена
    /// - В set-блоке автоматически триггерит обновление JSON, валидацию и сохранение
    func bindingForPage(
        _ pageID: Int
    ) -> Binding<Page>? {
        guard vm.book != nil else {
            return nil
        }
        return Binding<Page>(
            get: {
                // Безопасное извлечение страницы (предполагается, что pageID валиден)
                vm.book!.pages[pageID]!
            },
            set: {
                // Обновление страницы в модели данных
                vm.book!.pages[pageID] = $0
                
                // Принудительное обновление наблюдаемых свойств (если требуется)
                vm.book = vm.book
                // Каскадное обновление зависимых данных
                vm.updateJSON()
                vm.validate()
            }
        )
    }
}

// MARK: - PREVIEW
/// Предпросмотр в Canvas Xcode для быстрой итерации над интерфейсом
#Preview {
    ContentView()
}
