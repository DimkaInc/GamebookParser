import SwiftUI

// MARK: - РЕДАКТОР СТРАНИЦЫ
/// Основное представление для редактирования контента одной страницы книги-игры.
/// - Позволяет изменять текст, варианты выбора, предметы, врагов и спутников
/// - Использует @Binding для двустороннего связывания с моделью Page
/// - Вызывает onChanged callback при каждом изменении для обновления ViewModel
struct PageEditorView: View {
    
    // MARK: - СВЯЗЬ С МОДЕЛЬЮ (BINDING)
    /// Двусторонняя связь с объектом Page из ViewModel.
    /// Любое изменение в интерфейсе автоматически обновляет модель, и наоборот.
    @Binding var page: Page
    
    // MARK: - CALLBACK ДЛЯ УВЕДОМЛЕНИЙ
    /// Замыкание, вызываемое при каждом изменении данных страницы.
    /// Используется ViewModel для:
    /// - Сохранения состояния (undo/redo)
    /// - Валидации данных
    /// - Обновления JSON-представления
    /// - Автосохранения на диск
    var onChanged: () -> Void
    
    // MARK: - ЛОКАЛЬНОЕ СОСТОЯНИЕ (STATE)
    /// Временное хранение номера целевой страницы для нового выбора
    @State private var newChoicePage = ""
    /// Временное хранение текста описания для нового выбора
    @State private var newChoiceText = ""
    
    // MARK: - ОСНОВНОЙ ИНТЕРФЕЙС
    var body: some View {
        // ScrollView обеспечивает прокрутку при большом количестве контента
        ScrollView {
            // Вертикальный стек с отступами между секциями
            VStack(
                alignment: .leading, // Выравнивание по левому краю для читаемости
                spacing: 20          // Вертикальный отступ между секциями
            ) {
                header           // Заголовок с номером страницы
                textSection      // Редактирование текста страницы (абзацы)
                choicesSection   // Управление вариантами выбора (переходами)
                itemsSection     // Управление предметами (добавление/удаление)
                enemiesSection   // Редактирование параметров врагов
                companionsSection // Редактирование параметров спутников
            }
            .padding() // Внутренний отступ всего контента от краёв экрана
        }
    }
}

// ============================================================================
// MARK: - РАСШИРЕНИЕ: ЗАГОЛОВОК И ТЕКСТ
// ============================================================================
import SwiftUI
extension PageEditorView {
    
    // MARK: - ЗАГОЛОВОК СТРАНИЦЫ
    /// Простой заголовок с номером текущей страницы и визуальным разделителем
    var header: some View {
        VStack(alignment: .leading) {
            Text("Page \(page.id)") // Отображение уникального ID страницы
                .font(.largeTitle)  // Крупный системный шрифт
            Divider()               // Горизонтальная линия-разделитель
        }
    }
    
    // MARK: - СЕКЦИЯ ТЕКСТА СТРАНИЦЫ
    /// Редактирование массива текстовых абзацев страницы.
    /// - Каждый элемент массива page.text отображается в отдельном TextEditor
    /// - Изменения сразу сохраняются в модель и триггерят onChanged
    var textSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12 // Отступ между заголовком и полями ввода
        ) {
            Text("Text")
                .font(.headline) // Выделение заголовка секции
            
            // Итерируемся по индексам массива текста (не по значениям!)
            // Это необходимо для создания корректных Binding к элементам массива
            ForEach(
                page.text.indices, // Диапазон валидных индексов массива
                id: \.self         // Используем сам индекс как уникальный идентификатор
            ) { index in
                // TextEditor — многострочное редактируемое поле
                TextEditor(
                    text: Binding( // Ручное создание Binding к элементу массива
                        get: {
                            // Чтение: возвращаем текущее значение абзаца
                            page.text[index]
                        },
                        set: {
                            // Запись: обновляем значение в модели
                            page.text[index] = $0
                            // Уведомляем систему об изменении для каскадных обновлений
                            onChanged()
                        }
                    )
                )
                .frame(height: 90) // Фиксированная высота для каждого абзаца
                .padding(6)        // Внутренний отступ текста внутри поля
                .background(
                    Color.gray.opacity(0.1) // Светло-серый фон для визуального выделения
                )
                .cornerRadius(10) // Скруглённые углы поля ввода
            }
        }
    }
}

// ============================================================================
// MARK: - РАСШИРЕНИЕ: ВАРИАНТЫ ВЫБОРА (CHOICES)
// ============================================================================
import SwiftUI
extension PageEditorView {
    
    // MARK: - СЕКЦИЯ ВЫБОРОВ
    /// Управление переходами между страницами (варианты выбора игрока).
    /// - Отображает существующие переходы для редактирования
    /// - Предоставляет форму для добавления нового перехода
    var choicesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Choices")
                .font(.headline)
            
            // ─────────────────────────────────────────────────────
            // СПИСОК СУЩЕСТВУЮЩИХ ВЫБОРОВ (ДЛЯ РЕДАКТИРОВАНИЯ)
            ForEach(
                page.actions.choice.keys.sorted(), // Сортируем ключи (номера страниц) для стабильного порядка
                id: \.self
            ) { key in
                HStack {
                    // Отображение целевого номера страницы (не редактируется)
                    Text("→ \(key)")
                        .frame(width: 80) // Фиксированная ширина для выравнивания
                    
                    // Поле для редактирования текста описания выбора
                    TextField(
                        "Description", // Placeholder при пустом значении
                        text: Binding(
                            get: {
                                // Безопасное чтение: если ключа нет — пустая строка
                                page.actions.choice[key] ?? ""
                            },
                            set: {
                                // Запись нового текста описания
                                page.actions.choice[key] = $0
                                onChanged()
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder) // Системный стиль поля
                }
            }
            
            Divider() // Визуальное разделение между списком и формой добавления
            
            // ─────────────────────────────────────────────────────
            // ФОРМА ДОБАВЛЕНИЯ НОВОГО ВЫБОРА
            HStack {
                // Поле ввода номера целевой страницы
                TextField(
                    "Page",
                    text: $newChoicePage // Двустороннее связывание с @State
                )
                .frame(width: 100) // Компактная ширина для числового ввода
                
                // Поле ввода текста описания нового выбора
                TextField(
                    "Description",
                    text: $newChoiceText
                )
                
                // Кнопка подтверждения добавления
                Button("Add") {
                    addChoice() // Вызов метода-обработчика
                }
            }
        }
    }
    
    // MARK: - МЕТОД ДОБАВЛЕНИЯ ВЫБОРА
    /// Обрабатывает добавление нового перехода в словарь page.actions.choice
    /// - Валидирует ввод: номер страницы должен быть целым числом
    /// - Очищает поля ввода после успешного добавления
    /// - Вызывает onChanged для уведомления об изменении
    func addChoice() {
        // Попытка преобразовать строку ввода в целое число (номер страницы)
        guard let pageNum = Int(newChoicePage) else {
            // Если преобразование не удалось — просто выходим без ошибок
            return
        }
        
        // Добавляем новую запись в словарь переходов:
        // ключ = номер страницы, значение = текст описания
        page.actions.choice[pageNum] = newChoiceText
        
        // Сбрасываем поля ввода для готовности к следующему добавлению
        newChoicePage = ""
        newChoiceText = ""
        
        // Уведомляем систему об изменении данных
        onChanged()
    }
}

// ============================================================================
// MARK: - РАСШИРЕНИЕ: ПРЕДМЕТЫ (ITEMS)
// ============================================================================
import SwiftUI
extension PageEditorView {
    
    // MARK: - СЕКЦИЯ ПРЕДМЕТОВ
    /// Управление инвентарём: предметы, которые добавляются или удаляются на странице.
    /// Разделено на два подблока: "Добавить" и "Удалить" для наглядности.
    var itemsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 16 // Больший отступ между подблоками
        ) {
            Text("Items")
                .font(.headline)
            addItemsBlock    // Список предметов для добавления
            removeItemsBlock // Список предметов для удаления
        }
    }
    
    // MARK: - БЛОК ДОБАВЛЕНИЯ ПРЕДМЕТОВ
    /// Отображает предметы, которые игрок получит при посещении этой страницы.
    /// - Использует itemRow для единообразного отображения
    /// - Позволяет менять количество через Stepper (0...999)
    var addItemsBlock: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("Add")
                .font(.subheadline)
                .bold() // Выделение подзаголовка
            
            // Итерируемся по ключам словаря (названиям предметов)
            ForEach(
                page.items.add.keys.sorted(),
                id: \.self
            ) { key in
                // Переиспользуемый компонент строки предмета
                itemRow(
                    name: key,
                    count: Binding(
                        get: {
                            // Чтение количества: если ключа нет — 0
                            page.items.add[key] ?? 0
                        },
                        set: {
                            // Запись нового количества
                            page.items.add[key] = $0
                            onChanged()
                        }
                    )
                )
            }
        }
    }
    
    // MARK: - БЛОК УДАЛЕНИЯ ПРЕДМЕТОВ
    /// Отображает предметы, которые будут удалены из инвентаря игрока.
    /// Логика аналогична addItemsBlock, но работает со словарём page.items.dec
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
    
    // MARK: - УНИВЕРСАЛЬНАЯ СТРОКА ПРЕДМЕТА
    /// Переиспользуемый компонент для отображения предмета с регулятором количества.
    /// - name: название предмета (только для чтения)
    /// - count: Binding к количеству для изменения через Stepper
    @ViewBuilder // Позволяет возвращать разные типы представлений (опционально здесь)
    func itemRow(
        name: String,
        count: Binding<Int>
    ) -> some View {
        HStack {
            Text(name) // Название предмета
            Spacer()   // Прижимает Stepper к правому краю
            Stepper(
                "\(count.wrappedValue)", // Отображение текущего значения в кнопке
                value: count,            // Binding к значению для обновления
                in: 0...999              // Диапазон допустимых значений
            )
            .frame(width: 160) // Фиксированная ширина для выравнивания
        }
        .padding(8)
        .background(
            Color.gray.opacity(0.08) // Лёгкий фон для визуального группирования
        )
        .cornerRadius(10)
    }
}

// ============================================================================
// MARK: - РАСШИРЕНИЕ: ВРАГИ (ENEMIES)
// ============================================================================
import SwiftUI
extension PageEditorView {
    
    // MARK: - СЕКЦИЯ ВРАГОВ
    /// Редактирование параметров врагов, встречающихся на странице.
    /// - Отображает список врагов с возможностью настройки характеристик
    var enemiesSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Enemies")
                .font(.headline)
            
            // Итерируемся по ключам словаря врагов (их названиям)
            ForEach(
                page.enemy.keys.sorted(),
                id: \.self
            ) { key in
                enemyRow(name: key) // Делегируем отрисовку строки врага
            }
        }
    }
    
    // MARK: - СТРОКА ВРАГА
    /// Карточка врага с редакторами характеристик: навык (skill) и жизнеспособность (vitality).
    /// - Использует опциональную навигацию по вложенным свойствам модели
    /// - Визуально выделена красным фоном для ассоциации с опасностью
    @ViewBuilder
    func enemyRow(
        name: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            // Название врага как заголовок карточки
            Text(name)
                .font(.headline)
            
            // ─────────────────────────────────────────────────────
            // РЕДАКТОР НАВЫКА (SKILL)
            HStack {
                Text("Skill") // Подпись параметра
                Stepper(
                    "\(page.enemy[name]?.skill ?? 0)", // Отображение текущего значения
                    value: Binding( // Создание Binding к опциональному свойству
                        get: {
                            // Безопасное чтение: если врага нет или skill nil — 0
                            page.enemy[name]?.skill ?? 0
                        },
                        set: {
                            // Запись через опциональную цепочку:
                            // ?-оператор гарантирует, что мы не создадим новый объект случайно
                            page.enemy[name]?.skill = $0
                            onChanged()
                        }
                    ),
                    in: 0...99 // Диапазон значения навыка
                )
            }
            
            // ─────────────────────────────────────────────────────
            // РЕДАКТОР ЖИЗНЕСПОСОБНОСТИ (VITALITY)
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
                    in: 0...999 // Диапазон значения жизнеспособности
                )
            }
        }
        .padding()
        .background(
            Color.red.opacity(0.1) // Светло-красный фон для визуальной категоризации
        )
        .cornerRadius(12)
    }
}

// ============================================================================
// MARK: - РАСШИРЕНИЕ: СПУТНИКИ (COMPANIONS)
// ============================================================================
import SwiftUI
extension PageEditorView {
    
    // MARK: - СЕКЦИЯ СПУТНИКОВ
    /// Редактирование параметров спутников (союзников), доступных на странице.
    /// Структура аналогична врагам, но работает с другим словарём модели.
    var companionsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            Text("Companions")
                .font(.headline)
            
            // Обратите внимание: используем page.companions.add (не .dec)
            // Это предполагает, что спутники только добавляются, а не удаляются
            ForEach(
                page.companions.add.keys.sorted(),
                id: \.self
            ) { key in
                companionRow(name: key)
            }
        }
    }
    
    // MARK: - СТРОКА СПУТНИКА
    /// Карточка спутника с редакторами характеристик.
    /// Визуально выделена зелёным фоном для позитивной ассоциации.
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
            
            // ─────────────────────────────────────────────────────
            // РЕДАКТОР НАВЫКА СПУТНИКА
            HStack {
                Text("Skill")
                Stepper(
                    "\(page.companions.add[name]?.skill ?? 0)",
                    value: Binding(
                        get: {
                            // Навигация по вложенной структуре:
                            // page → companions → add → [name] → skill
                            page.companions.add[name]?.skill ?? 0
                        },
                        set: {
                            page.companions.add[name]?.skill = $0
                            onChanged()
                        }
                    ),
                    in: 0...99
                )
            }
            
            // ─────────────────────────────────────────────────────
            // РЕДАКТОР ЖИЗНЕСПОСОБНОСТИ СПУТНИКА
            HStack {
                Text("Vitality")
                Stepper(
                    "\(page.companions.add[name]?.vitality ?? 0)",
                    value: Binding(
                        get: {
                            page.companions.add[name]?.vitality ?? 0
                        },
                        set: {
                            page.companions.add[name]?.vitality = $0
                            onChanged()
                        }
                    ),
                    in: 0...999
                )
            }
        }
        .padding()
        .background(
            Color.green.opacity(0.1) // Светло-зелёный фон для визуальной категоризации
        )
        .cornerRadius(12)
    }
}
