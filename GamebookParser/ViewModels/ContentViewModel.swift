import Foundation
import Observation // Фреймворк для реактивного программирования (замена ObservableObject)

// ============================================================================
// MARK: - VIEWMODEL: УПРАВЛЕНИЕ СОСТОЯНИЕМ ПРИЛОЖЕНИЯ
// ============================================================================

/// Основная ViewModel приложения, управляющая данными книги, валидацией, экспортом и историей изменений.
/// - Аннотация @Observable (iOS 17+) автоматически генерирует код для отслеживания изменений свойств
/// - Любое изменение @Published-подобных свойств автоматически триггерит обновление UI
/// - Класс final для предотвращения наследования и оптимизации диспатча методов
@Observable
final class ContentViewModel {
    
    // MARK: - 📚 МОДЕЛЬ ДАННЫХ (BOOK)
    /// Основная модель книги-игры, содержащая все страницы и их связи.
    /// Опциональна: nil при старте приложения или ошибке загрузки.
    var book: Book?
    
    // MARK: - 🎨 СОСТОЯНИЕ ПОЛЬЗОВАТЕЛЬСКОГО ИНТЕРФЕЙСА
    /// ID текущей выбранной страницы в сайдбаре (для синхронизации выделения)
    var selectedPageID: Int?
    /// Массив проблем валидации для отображения в панели ошибок
    var validationIssues: [ValidationIssue] = []
    /// Строковое представление книги в формате JSON (для вкладки "Просмотр кода")
    var jsonOutput: String = ""
    
    // MARK: - 📁 ИНФОРМАЦИЯ О ФАЙЛАХ
    /// Полный URL исходного загруженного файла (для доступа к ресурсам sandbox)
    var sourceFileURL: URL?
    /// Имя исходного файла с расширением (для отображения в UI)
    var sourceFileName: String = ""
    /// Базовое имя для экспорта (без расширения, формируется из имени исходного файла)
    var exportFileName: String = "book"
    
    // MARK: - ⚙️ СЕРВИСЫ (БИЗНЕС-ЛОГИКА)
    /// Парсер: преобразует сырой текст в структурированную модель Book
    private let parser = BookParser()
    /// Валидатор: проверяет целостность данных книги (ссылки, дубликаты, логика)
    private let validator = BookValidator()
    
    // MARK: - 📥 ОТКРЫТИЕ ФАЙЛА
    /// Загружает и парсит текстовый файл, инициализируя модель книги.
    /// - Parameter url: Security-scoped URL файла, выбранного через fileImporter
    func openFile(url: URL) {
        // ─────────────────────────────────────────────────────
        // БЕЗОПАСНЫЙ ДОСТУП К ФАЙЛУ (SANDBOX)
        // Для файлов, выбранных через системный диалог, требуется явное разрешение
        let access = url.startAccessingSecurityScopedResource()
        
        // defer гарантирует освобождение ресурса ДАЖЕ при возникновении ошибки
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // ─────────────────────────────────────────────────────
            // ЧТЕНИЕ ДАННЫХ
            // Загружаем сырые байты файла в память
            let data = try Data(contentsOf: url)
            
            // ─────────────────────────────────────────────────────
            // ДЕКОДИРОВАНИЕ ТЕКСТА С ПОДДЕРЖКОЙ РАЗНЫХ КОДИРОВОК
            // Пробуем кодировки в порядке приоритета:
            // 1. UTF-8 (современный стандарт)
            // 2. Windows-1251 (кириллица для старых текстовых файлов)
            // 3. Unicode (UTF-16, для файлов из Word/TextEdit)
            // 4. Пустая строка (фолбэк, если всё не удалось)
            let text =
               String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1251)
            ?? String(data: data, encoding: .unicode)
            ?? ""
            
            // Альтернативный вариант (менее гибкий):
            // let text = try String(contentsOf: url, encoding: .utf8)
            
            // ─────────────────────────────────────────────────────
            // СОХРАНЕНИЕ МЕТАДАННЫХ ФАЙЛА
            sourceFileURL = url
            sourceFileName = url.lastPathComponent // "my_book.txt"
            exportFileName = url.deletingPathExtension().lastPathComponent // "my_book"
            
            // ─────────────────────────────────────────────────────
            // ПАРСИНГ И ИНИЦИАЛИЗАЦИЯ МОДЕЛИ
            // Преобразуем сырой текст в структурированный объект Book
            let parsedBook = parser.parseBook(from: text)
            // print(parsedBook.pages.count) // Отладочная информация
            
            // Обновляем основное состояние — это триггерит перерисовку UI
            self.book = parsedBook
            
            // Автовыбор первой страницы для удобства пользователя
            selectedPageID = parsedBook.pages.keys.sorted().first
            
            // ─────────────────────────────────────────────────────
            // КАСКАДНОЕ ОБНОВЛЕНИЕ ЗАВИСИМЫХ ДАННЫХ
            validate()      // Проверка на ошибки (битые ссылки, дубликаты)
            updateJSON()    // Генерация JSON для вкладки "Код"
            autosave()      // Немедленное автосохранение на диск
            
        } catch {
            // Логируем ошибки чтения файла в консоль (в продакшене — показать Alert)
            print(error)
        }
    }
    
    // MARK: - ✅ ВАЛИДАЦИЯ ДАННЫХ
    /// Запускает проверку целостности книги и обновляет список ошибок.
    /// - Вызывается после каждого изменения контента
    func validate() {
        // Guard-проверка: нельзя валидировать несуществующую книгу
        guard let book else {
            return
        }
        // Делегируем проверку специализированному сервису
        validationIssues = validator.validate(book: book)
        // Изменение массива автоматически обновит UI панели валидации
    }
    
    // MARK: - 🔄 ГЕНЕРАЦИЯ JSON
    /// Преобразует модель Book в отформатированную JSON-строку для отображения.
    /// - Используется для вкладки "Просмотр кода" и отладки
    func updateJSON() {
        guard let book else {
            return
        }
        do {
            let encoder = JSONEncoder()
            // Настройки форматирования для читаемости человеком:
            encoder.outputFormatting = [
                .prettyPrinted,  // Переносы строк и отступы
                .sortedKeys      // Алфавитный порядок ключей (для стабильного diff)
            ]
            let data = try encoder.encode(book)
            jsonOutput = String(data: data, encoding: .utf8) ?? ""
        } catch {
            // При ошибке сериализации показываем описание ошибки вместо JSON
            jsonOutput = error.localizedDescription
        }
    }
    
    // MARK: - 📤 ЭКСПОРТ В ФАЙЛ
    /// Сохраняет модель книги в указанный пользователем файл (через fileExporter).
    /// - Parameter url: Целевой URL для сохранения, выбранный в системном диалоге
    func exportJSON(to url: URL) {
        guard let book else {
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(book)
            // Атомарная запись данных на диск
            try data.write(to: url)
        } catch {
            print(error) // В продакшене: показать пользователю ошибку экспорта
        }
    }
    
    // MARK: - 💾 АВТОСОХРАНЕНИЕ
    /// Автоматически сохраняет текущее состояние книги в директорию документов.
    /// - Файл именуется "<имя>_autosave.json" для предотвращения конфликтов
    /// - Вызывается после каждого значимого изменения (onChanged в редакторе)
    func autosave() {
        guard let book else {
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(book)
            
            // Формируем путь к файлу автосохранения:
            // ~/Documents/book_autosave.json
            let autosaveURL =
                autosaveDirectory()
                .appendingPathComponent(exportFileName + "_autosave.json")
            
            try data.write(to: autosaveURL)
        } catch {
            print(error) // Ошибки автосохранения не должны прерывать работу пользователя
        }
    }
    
    // MARK: - 🛠 ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
    
    /// Возвращает URL директории документов приложения (песочница iOS/macOS).
    /// - Используется для автосохранения и загрузки резервных копий
    func autosaveDirectory() -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first! // force-unwrap безопасен: documentDirectory всегда существует
    }
    
    /// Проверяет, есть ли ошибки валидации для конкретной страницы.
    /// - Parameter page: ID проверяемой страницы
    /// - Returns: true, если найдена хотя бы одна проблема
    func hasValidationIssue(_ page: Int) -> Bool {
        validationIssues.contains { $0.page == page }
    }
    
    // MARK: - 📊 ВЫЧИСЛЯЕМАЯ СТАТИСТИКА
    /// Общее количество переходов (выборов) во всей книге.
    /// - Вычисляется "на лету" через reduce по всем страницам
    var totalTransitions: Int {
        guard let book else { return 0 }
        return book.pages.values.reduce(0) {
            $0 + $1.actions.choice.count // Суммируем количество ключей в словаре choice
        }
    }
    
    /// Общее количество уникальных врагов во всей книге.
    var totalEnemies: Int {
        guard let book else { return 0 }
        return book.pages.values.reduce(0) {
            $0 + $1.enemy.count
        }
    }
    
    /// Общее количество операций с предметами (добавление + удаление).
    var totalItems: Int {
        guard let book else { return 0 }
        return book.pages.values.reduce(0) {
            $0 + $1.items.add.count + $1.items.dec.count
        }
    }
}

// ============================================================================
// MARK: - ЗАГРУЗКА АВТОСОХРАНЕНИЯ (EXTENSION)
// ============================================================================

import Foundation
extension ContentViewModel {
    
    /// Пытается загрузить ранее автосохранённую версию книги при старте приложения.
    /// - Вызывается в AppDelegate или при инициализации ViewModel
    /// - Если файл не найден или повреждён — молча игнорируется (пользователь начнёт с чистого листа)
    func loadAutosaveIfNeeded() {
        let url = autosaveDirectory()
            .appendingPathComponent(exportFileName + "_autosave.json")
        
        // Проверяем существование файла перед попыткой чтения
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // Декодируем байты обратно в модель Book
            // Требует, чтобы Book соответствовал протоколу Codable
            let restored = try decoder.decode(Book.self, from: data)
            
            // Восстанавливаем состояние приложения
            self.book = restored
            updateJSON()  // Обновляем вкладку "Код"
            validate()    // Перепроверяем валидность восстановленных данных
        } catch {
            // При ошибке декодирования (устаревший формат, повреждение) — сбрасываем
            print(error)
        }
    }
}

// ============================================================================
// MARK: - МЕНЕДЖЕР ИСТОРИИ: UNDO/REDO
// ============================================================================

import Foundation

/// Универсальный менеджер истории изменений на основе двух стеков.
/// - Generic-тип T позволяет использовать с любой моделью (Book, Page, etc.)
/// - Реализует классический паттерн "Command History"
final class UndoRedoManager<T> {
    
    // MARK: - СТЕКИ ИЗМЕНЕНИЙ
    /// Стек состояний для отмены (последнее сохранённое → самое старое)
    private var undoStack: [T] = []
    /// Стек состояний для повтора (отменённые действия)
    private var redoStack: [T] = []
    
    // MARK: - СОХРАНЕНИЕ ТОЧКИ ВОССТАНОВЛЕНИЯ
    /// Добавляет текущее состояние в историю отмены.
    /// - ВАЖНО: При новом сохранении очищается redoStack (нельзя "вернуть отменённое" после нового действия)
    func save(_ value: T) {
        undoStack.append(value)
        redoStack.removeAll()
    }
    
    // MARK: - ОТМЕНА ДЕЙСТВИЯ (UNDO)
    /// Возвращает предыдущее состояние из истории.
    /// - Parameter current: Текущее состояние (сохраняется в redoStack для возможного повтора)
    /// - Returns: Предыдущее состояние или nil, если история пуста
    func undo(current: T) -> T? {
        guard let previous = undoStack.popLast() else {
            return nil // История пуста — нечего отменять
        }
        // Текущее состояние становится доступным для повтора (Redo)
        redoStack.append(current)
        return previous
    }
    
    // MARK: - ПОВТОР ДЕЙСТВИЯ (REDO)
    /// Восстанавливает состояние, которое было отменено.
    /// - Parameter current: Текущее состояние (возвращается в undoStack)
    /// - Returns: Следующее состояние или nil, если redoStack пуст
    func redo(current: T) -> T? {
        guard let next = redoStack.popLast() else {
            return nil // Нечего повторять
        }
        // Восстановленное состояние снова можно отменить
        undoStack.append(current)
        return next
    }
}

// ============================================================================
// MARK: - ИНТЕГРАЦИЯ UNDO/REDO В VIEWMODEL
// ============================================================================

import Foundation
extension ContentViewModel {
    
    // MARK: - ОБЩАЯ ИСТОРИЯ ИЗМЕНЕНИЙ
    /// Статический менеджер истории для всех экземпляров ViewModel.
    /// - static позволяет разделять историю между разными представлениями
    /// - Тип Book означает, что мы сохраняем полные снимки модели (Memento pattern)
    private static let history = UndoRedoManager<Book>()
    
    /// Сохраняет текущее состояние книги в историю перед изменением.
    /// - Вызывается в onChanged редактора ДО внесения изменений
    func saveState() {
        guard let book else { return }
        Self.history.save(book)
    }
    
    /// Отменяет последнее изменение, восстанавливая предыдущую версию книги.
    func undo() {
        guard let current = book,
              let previous = Self.history.undo(current: current)
        else {
            return
        }
        book = previous
        // После отмены необходимо обновить зависимые данные
        validate()
        updateJSON()
    }
    
    /// Повторяет ранее отменённое действие.
    func redo() {
        guard let current = book,
              let next = Self.history.redo(current: current)
        else {
            return
        }
        book = next
        validate()
        updateJSON()
    }
}

// ============================================================================
// MARK: - ПРОТОКОЛЫ ПАРСИНГА (PARSING RULES)
// ============================================================================

import Foundation

/// Протокол для правил разбора текста в стиле "цепочка обязанностей" (Chain of Responsibility).
/// - Каждое правило инкапсулирует логику извлечения одного типа данных
/// - Позволяет легко добавлять новые правила без изменения существующего кода (Open/Closed Principle)
protocol ParsingRule {
    /// Применяет правило к странице, модифицируя её "на месте".
    /// - Parameter page: Ссылка на страницу для прямого изменения (inout)
    func apply(to page: inout Page)
}

// ============================================================================
// MARK: - ПРАВИЛО: ОБНАРУЖЕНИЕ ЗОЛОТА (GOLD DETECTION)
// ============================================================================

import Foundation

/// Правило парсинга: находит упоминания золота в тексте и добавляет их в инвентарь.
/// - Пример: "Вы нашли 50 золотых" → page.items.add["gold"] += 50
/// - Использует регулярные выражения для гибкого поиска
struct GoldDetectionRule: ParsingRule {
    
    func apply(to page: inout Page) {
        // Объединяем все абзацы страницы в одну строку для поиска
        let text = page.text.joined(separator: " ")
        
        // Компиляция регулярного выражения:
        // (\d+)      — группа 1: одно или более чисел (количество золота)
        // \s+        — один или более пробелов
        // золот      — слово "золот" (без окончания для поиска "золотых", "золото", etc.)
        // options: .caseInsensitive — регистронезависимый поиск
        let regex = try! NSRegularExpression(
            pattern: #"(\d+)\s+золот"#,
            options: [.caseInsensitive]
        )
        
        // NSRegularExpression работает с NSRange (на основе UTF-16), поэтому приводим строку
        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )
        
        // Обрабатываем каждое найденное вхождение
        for match in matches {
            // Проверка: в паттерне должна быть хотя бы одна группа захвата (количество)
            guard match.numberOfRanges > 1 else {
                continue
            }
            
            // Извлекаем подстроку, соответствующую первой группе захвата (число)
            let value = Int(nsText.substring(with: match.range(at: 1))) ?? 0
            
            // Добавляем найденное золото в инвентарь страницы:
            // - Если ключ "gold" уже есть — увеличиваем значение
            // - Если нет — создаём с начальным значением 0, затем прибавляем
            page.items.add["gold"] = (page.items.add["gold"] ?? 0) + value
        }
    }
}
