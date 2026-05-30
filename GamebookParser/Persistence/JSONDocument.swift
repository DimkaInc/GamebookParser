import SwiftUI
import UniformTypeIdentifiers // Фреймворк для работы с типами контента (UTI) — замена устаревшим строковым идентификаторам

// ============================================================================
// MARK: - 📄 ДОКУМЕНТ JSON: АДАПТЕР ДЛЯ СИСТЕМЫ ФАЙЛОВ SWIFTUI
// ============================================================================

/// Структура, представляющая документ в формате JSON для интеграции с системой файлов SwiftUI.
/// - Соответствует протоколу `FileDocument` — контракту для чтения/записи файлов
/// - Используется с модификаторами `.fileExporter` и `.fileImporter` для системных диалогов
/// - Инкапсулирует логику кодирования/декодирования, скрывая её от ViewModel и View
///
/// ## Почему отдельная структура, а не прямая работа с Data/String?
/// ✅ **Типобезопасность**: компилятор проверяет реализацию всех требований протокола
/// ✅ **Изоляция ответственности**: парсинг файлов отделён от бизнес-логики приложения
/// ✅ **Расширяемость**: легко добавить поддержку других форматов (XML, YAML) новым типом
/// ✅ **Тестируемость**: можно тестировать чтение/запись изолированно от UI
///
/// ## Поток данных при экспорте:
/// ```
/// 1. ViewModel готовит jsonOutput: String
/// 2. Создаётся JSONDocument(text: jsonOutput)
/// 3. SwiftUI вызывает fileWrapper(configuration:) → Data
/// 4. Система показывает диалог сохранения пользователю
/// 5. Данные записываются на диск по выбранному пути
/// ```
///
/// ## Поток данных при импорте:
/// ```
/// 1. Пользователь выбирает файл через системный диалог
/// 2. SwiftUI создаёт JSONDocument(configuration:) из данных файла
/// 3. ViewModel получает document.text: String
/// 4. Текст передаётся в парсер для преобразования в модель Book
/// ```
///
/// ## Поддерживаемые типы контента:
/// • Основной: .json (UTType.json) — стандартный тип для данных в формате JSON
/// • Можно расширить: добавить .plainText для совместимости с текстовыми редакторами
/// • Кастомные UTI: если нужно поддерживать специфичное расширение (.gamebook)
struct JSONDocument: FileDocument {
    
    // MARK: - 🏷️ ПОДДЕРЖИВАЕМЫЕ ТИПЫ КОНТЕНТА
    /// Возвращает массив типов контента (UTI), которые этот документ может читать.
    /// - Используется системой для фильтрации файлов в диалоге импорта
    /// - Возвращаем [.json] — только файлы с расширением .json будут показаны пользователю
    /// - Если нужно поддержать несколько форматов: return [.json, .plainText, .utf8Text]
    ///
    /// ## Что такое UTType?
    /// Uniform Type Identifier — стандартизированный способ идентификации типов данных в Apple OS.
    /// • Заменяет устаревшие строковые идентификаторы ("public.json", "com.apple.plain-text")
    /// • Типобезопасный: компилятор проверит существование типа
    /// • Иерархический: .json является подтипом .text, .data и т.д.
    ///
    /// ## Примеры распространённых UTType:
    /// • .json, .xml, .yaml — структурированные данные
    /// • .plainText, .utf8Text, .rtf — текстовые форматы
    /// • .image, .png, .jpeg — изображения
    /// • .movie, .mp4, .quickTimeMovie — видео
    ///
    /// ## Как добавить кастомный тип:
    /// ```swift
    /// // В Info.plist или через код:
    /// static var readableContentTypes: [UTType] {
    ///     [UTType(exportedAs: "com.myapp.gamebook-json") ?? .json]
    /// }
    /// ```
    static var readableContentTypes: [UTType] {
        // Возвращаем массив с одним элементом — типом JSON
        // Система использует это для:
        // • Фильтрации файлов в UIDocumentPickerViewController / NSOpenPanel
        // • Определения иконки файла в интерфейсе
        // • Валидации при перетаскивании (drag & drop)
        [.json]
    }
    
    // MARK: - 📦 ВНУТРЕННЕЕ ПРЕДСТАВЛЕНИЕ ДАННЫХ
    /// Строковое представление содержимого документа.
    /// - Хранит готовый JSON-текст для экспорта или сырой текст для импорта
    /// - Не выполняет парсинг/сериализацию — это ответственность внешних компонентов
    /// - Мутабельный (var): позволяет обновлять контент при редактировании
    ///
    /// ## Почему String, а не Data или Book?
    /// ✅ **Универсальность**: String легко конвертируется в Data и обратно
    /// ✅ **Отладка**: можно логировать, показывать в UI, копировать в буфер
    /// ✅ **Кодировки**: явно указываем .utf8 при конвертации — нет неявных догадок
    /// ✅ **Разделение ответственности**: этот тип не знает о структуре Book
    ///
    /// ## Альтернативные подходы:
    /// ```swift
    /// // Хранить распарсенную модель (требует Codable):
    /// var book: Book
    /// // Но тогда FileDocument должен знать о доменной модели — нарушение изоляции
    ///
    /// // Хранить Data:
    /// var data: Data
    /// // Менее удобно для отладки и текстовых операций
    /// ```
    var text: String
    
    // MARK: - 🆕 ИНИЦИАЛИЗАТОР ДЛЯ ЭКСПОРТА (СОЗДАНИЕ ДОКУМЕНТА)
    /// Создаёт новый документ для экспорта данных из приложения.
    /// - Parameter text: Готовая строка JSON, подготовленная ViewModel
    /// - Вызывается кодом приложения при запуске fileExporter
    /// - Не выбрасывает ошибки: предполагается, что текст уже валиден
    ///
    /// ## Пример использования в ContentView:
    /// ```swift
    /// .fileExporter(
    ///     isPresented: $showExporter,
    ///     document: JSONDocument(text: viewModel.jsonOutput), // ← этот init
    ///     contentType: .json,
    ///     defaultFilename: viewModel.exportFileName
    /// ) { result in
    ///     // Обработка результата сохранения
    /// }
    /// ```
    ///
    /// ## Почему не делаем валидацию здесь?
    /// • Валидация данных — ответственность ViewModel/BookValidator
    /// • FileDocument должен быть "глупым" адаптером, а не бизнес-логикой
    /// • Если текст невалиден — это проявится при декодировании на стороне получателя
    init(text: String) {
        // Простое присваивание: сохраняем переданный текст как есть
        // Никаких преобразований, кодировок или проверок — минимализм и скорость
        self.text = text
    }
    
    // MARK: - 📥 ИНИЦИАЛИЗАТОР ДЛЯ ИМПОРТА (ЧТЕНИЕ ФАЙЛА)
    /// Создаёт документ из данных файла, выбранного пользователем.
    /// - Parameter configuration: Объект с данными файла от системы
    /// - Throws: CocoaError.fileReadCorruptFile если данные не удалось декодировать
    /// - Вызывается автоматически системой при выборе файла в fileImporter
    ///
    /// ## Что содержит ReadConfiguration?
    /// • file: FileRepresentation — обёртка над данными файла
    /// • Доступ к метаданным: имя, тип, дата изменения (при необходимости)
    /// • Потоковый доступ для больших файлов (не используется здесь)
    ///
    /// ## Почему guard let, а не try??
    /// • regularFileContents может вернуть nil если файл не регулярный (ссылка, директория)
    /// • String(data:encoding:) возвращает nil при неудачном декодировании
    /// • guard позволяет централизованно обработать все случаи ошибки
    init(configuration: ReadConfiguration) throws {
        // ─────────────────────────────────────────────────────
        // ШАГ 1: ИЗВЛЕЧЕНИЕ СЫРЫХ ДАННЫХ ИЗ ФАЙЛА
        // regularFileContents возвращает Data? для обычных файлов
        // Для пакетов (.app, .pages) или специальных типов может вернуть nil
        guard let data = configuration.file.regularFileContents else {
            // Если не удалось получить данные — файл повреждён или неподдерживаемого типа
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // ─────────────────────────────────────────────────────
        // ШАГ 2: ДЕКОДИРОВАНИЕ БАЙТОВ В СТРОКУ
        // Пробуем декодировать как UTF-8 — стандарт для JSON
        // Если файл в другой кодировке — вернёт nil и выбросим ошибку
        guard let string = String(data: data, encoding: .utf8) else {
            // UTF-8 не подошёл — файл может быть в другой кодировке
            // Для расширения поддержки можно добавить fallback:
            // String(data: data, encoding: .windowsCP1251) ?? ...
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        
        // ─────────────────────────────────────────────────────
        // ШАГ 3: СОХРАНЕНИЕ РЕЗУЛЬТАТА
        // Присваиваем декодированную строку внутреннему свойству
        // Дальнейший парсинг (JSON → Book) — ответственность вызывающего кода
        text = string
        
        // 💡 Совет для отладки:
        // Можно добавить логирование размера импортируемых данных:
        // print("📥 Imported JSON: \(data.count) bytes, \(string.count) characters")
    }
    
    // MARK: - 📤 СЕРИАЛИЗАЦИЯ ДОКУМЕНТА В ФАЙЛ (ЭКСПОРТ)
    /// Преобразует внутреннее представление документа в файл для записи на диск.
    /// - Parameter configuration: Настройки записи от системы (пока не используем)
    /// - Returns: FileWrapper — обёртка над данными файла для системы
    /// - Throws: Может выбросить ошибку при кодировании (но у нас !, см. ниже)
    ///
    /// ## Что такое FileWrapper?
    /// Абстракция файла в Cocoa, поддерживающая:
    /// • Регулярные файлы (наш случай) — простой массив байтов
    /// • Пакеты/директории — иерархическая структура файлов
    /// • Символические ссылки — редкий случай для пользовательских данных
    ///
    /// ## Почему возвращаем именно регулярный файл?
    /// • JSON — это один плоский файл, не пакет с ресурсами
    /// • Проще для системы: не нужно управлять вложенной структурой
    /// • Совместимо со всеми платформами и файловыми системами
    ///
    /// ## Когда использовать сложную структуру:
    /// ```swift
    /// // Если документ — это пакет с несколькими файлами:
    /// let wrapper = FileWrapper(directoryWithFileWrappers: [
    ///     "content.json": contentWrapper,
    ///     "preview.png": imageWrapper,
    ///     "metadata.plist": metaWrapper
    /// ])
    /// return wrapper
    /// ```
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // ─────────────────────────────────────────────────────
        // ШАГ 1: КОДИРОВАНИЕ СТРОКИ В БАЙТЫ
        // Конвертируем текст в Data используя UTF-8 — стандарт для JSON
        // Используем ! (force unwrap) потому что:
        // • String.data(using:) всегда успешен для .utf8 (любая строка валидна в UTF-8)
        // • Если бы использовали .ascii или другую ограниченную кодировку — нужна проверка
        let data = text.data(using: .utf8)!
        
        // ─────────────────────────────────────────────────────
        // ШАГ 2: СОЗДАНИЕ ОБЁРТКИ ФАЙЛА
        // regularFileWithContents: создаёт FileWrapper для простого файла
        // Система использует это для атомарной записи на диск
        return FileWrapper(regularFileWithContents: data)
        
        // 💡 Совет для расширения:
        // Если нужно добавить метаданные файла (например, дату экспорта):
        // ```
        // let wrapper = FileWrapper(regularFileWithContents: data)
        // wrapper.fileAttributes = [
        //     FileAttributeKey.modificationDate: Date()
        // ]
        // return wrapper
        // ```
    }
    
    // ========================================================================
    // MARK: - 💡 РАСШИРЕНИЕ ФУНКЦИОНАЛА (ИДЕИ ДЛЯ БУДУЩЕГО)
    // ========================================================================
    
    /*
     // ─────────────────────────────────────────────────────
     // ИДЕЯ 1: Поддержка нескольких кодировок при импорте
     // Сейчас только UTF-8. Для совместимости со старыми файлами:
     init(configuration: ReadConfiguration) throws {
         guard let data = configuration.file.regularFileContents else {
             throw CocoaError(.fileReadCorruptFile)
         }
         
         // Пробуем кодировки по приоритету
         let encodings: [String.Encoding] = [.utf8, .windowsCP1251, .isoLatin1, .unicode]
         
         for encoding in encodings {
             if let string = String(data: data, encoding: encoding) {
                 self.text = string
                 print("✅ Decoded with \(encoding)")
                 return
             }
         }
         throw CocoaError(.fileReadInapplicableStringEncoding)
     }
     
     // ─────────────────────────────────────────────────────
     // ИДЕЯ 2: Валидация JSON при импорте
     // Можно сразу проверить, что текст — валидный JSON, и дать понятную ошибку:
     init(configuration: ReadConfiguration) throws {
         // ... загрузка data и string как выше ...
         
         // Быстрая проверка валидности JSON без полного парсинга в модель
         guard let jsonData = string.data(using: .utf8),
               try JSONSerialization.isValidJSONObject(jsonData) else {
             throw CocoaError(.fileReadCorruptFile,
                            userInfo: [NSLocalizedDescriptionKey: "Файл содержит невалидный JSON"])
         }
         text = string
     }
     
     // ─────────────────────────────────────────────────────
     // ИДЕЯ 3: Сжатие больших файлов
     // Если JSON становится очень большим (>10MB), можно сжимать при экспорте:
     func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
         let data = text.data(using: .utf8)!
         
         // Сжимаем если размер превышает порог
         if data.count > 10 * 1024 * 1024 {
             let compressed = try (data as NSData).compressed(using: .lz4) as Data
             let wrapper = FileWrapper(regularFileWithContents: compressed)
             // Помечаем файл как сжатый для корректного чтения при импорте
             wrapper.fileAttributes = ["com.myapp.compressed": true]
             return wrapper
         }
         return FileWrapper(regularFileWithContents: data)
     }
     
     // ─────────────────────────────────────────────────────
     // ИДЕЯ 4: Поддержка кастомного расширения файла
     // По умолчанию система использует .json. Можно добавить своё:
     static var readableContentTypes: [UTType] {
         // Зарегистрировать "com.myapp.gamebook" в Info.plist
         [UTType(exportedAs: "com.myapp.gamebook") ?? .json]
     }
     
     // И при экспорте указать предпочитаемое расширение:
     // .fileExporter(..., preferredContentTypes: [.gamebook, .json])
     
     // ─────────────────────────────────────────────────────
     // ИДЕЯ 5: Асинхронная загрузка для очень больших файлов
     // Если файл >100MB, regularFileContents может блокировать поток
     // Для такого случая — асинхронная инициализация (требует изменения протокола):
     /*
     init(configuration: ReadConfiguration) async throws {
         // Чтение в фоне
         let data = try await configuration.file.loadRegularFileContents()
         guard let string = String(data: data, encoding: .utf8) else {
             throw CocoaError(.fileReadInapplicableStringEncoding)
         }
         text = string
     }
     */
     // ⚠️ Но: FileDocument пока не поддерживает async init (на 2024 год)
     // Решение: загружать данные до создания документа в ViewModel
     */
}

// ============================================================================
// MARK: - 🧪 ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ В ПРИЛОЖЕНИИ
// ============================================================================

/*
 // ─────────────────────────────────────────────────────
 // ЭКСПОРТ: Сохранение книги в файл
 // В ContentView или ViewModel:
 
 @State private var showExporter = false
 @State private var viewModel = ContentViewModel()
 
 var body: some View {
     ContentView()
         .fileExporter(
             isPresented: $showExporter,
             document: JSONDocument(text: viewModel.jsonOutput), // ← создание документа
             contentType: .json,                                  // ← фильтр типов
             defaultFilename: viewModel.exportFileName + ".json" // ← имя по умолчанию
         ) { result in
             switch result {
             case .success(let url):
                 print("✅ Exported to: \(url.path)")
                 // Можно показать уведомление пользователю
             case .failure(let error):
                 print("❌ Export failed: \(error.localizedDescription)")
                 // Показать Alert с ошибкой
             }
         }
 }
 
 // ─────────────────────────────────────────────────────
 // ИМПОРТ: Загрузка книги из файла
 
 @State private var showImporter = false
 @State private var viewModel = ContentViewModel()
 
 var body: some View {
     ContentView()
         .fileImporter(
             isPresented: $showImporter,
             allowedContentTypes: [.json], // ← фильтр: только JSON файлы
             allowsMultipleSelection: false
         ) { result in
             switch result {
             case .success(let url):
                 // Системный диалог вернул URL, но не содержимое!
                 // Нам нужно прочитать файл вручную или использовать JSONDocument:
                 do {
                     // Вариант 1: Ручное чтение (как в openFile)
                     let data = try Data(contentsOf: url)
                     let text = String(data: data, encoding: .utf8) ?? ""
                     viewModel.parseAndLoad(text: text)
                     
                     // Вариант 2: Через JSONDocument (если нужно валидировать)
                     // Примечание: fileImporter не создаёт FileDocument автоматически,
                     // это делает только fileExporter. Для импорта читаем вручную.
                     
                 } catch {
                     print("❌ Import failed: \(error)")
                 }
                 
             case .failure(let error):
                 print("❌ Import cancelled or failed: \(error)")
             }
         }
 }
 
 // ⚠️ Важное замечание:
 // fileImporter и fileExporter работают по-разному:
 // • fileExporter: вы передаёте FileDocument, система вызывает его методы
 // • fileImporter: система передаёт вам URL, вы читаете файл сами
 // Это асимметрия в дизайне API, которую нужно учитывать.
 
 // ─────────────────────────────────────────────────────
 // ПРЕДПРОСМОТР В XCODE (Canvas)
 // Для тестирования документа без запуска приложения:
 
 #Preview {
     // Создаём тестовый документ с фиктивными данными
     let previewDoc = JSONDocument(
         text: """
         {
           "name": "Test Book",
           "pages": {
             "0": { "id": 0, "text": ["Hello"], "items": { "add": {}, "dec": {} }, ... }
           }
         }
         """
     )
     
     // Можно проверить сериализацию:
     // let wrapper = try? previewDoc.fileWrapper(configuration: .init())
     // print(wrapper?.regularFileContents?.count ?? 0)
     
     return Text("Preview: \(previewDoc.text.prefix(50))...")
 }
 */

// ============================================================================
// MARK: - 📋 ЧЕКЛИСТ РЕАЛИЗАЦИИ FILEDOCUMENT
// ============================================================================

/*
 ✅ 1. Объявить соответствие протоколу: struct MyDoc: FileDocument
 ✅ 2. Реализовать static var readableContentTypes: [UTType]
 ✅ 3. Добавить свойство для хранения данных: var content: DataType
 ✅ 4. Реализовать init(text: DataType) для создания документа
 ✅ 5. Реализовать init(configuration:) throws для чтения из файла
 ✅ 6. Реализовать fileWrapper(configuration:) throws для записи в файл
 ✅ 7. Протестировать импорт/экспорт на всех целевых платформах
 ✅ 8. Обработать ошибки: невалидные данные, неподдерживаемые кодировки
 ✅ 9. Добавить локализацию сообщений об ошибках (если показываете пользователю)
 ✅ 10. Документировать ожидаемый формат данных для других разработчиков
 
 // Распространённые ошибки:
 ❌ Забыли throw в init(configuration:) — компилятор не пропустит, но логика сломается
 ❌ Использовали ! там, где может быть nil — краш при импорте битого файла
 ❌ Не указали правильный UTType — файл не виден в диалоге выбора
 ❌ Кодировали в неверной кодировке — кракозябры при открытии в других программах
 */
