import Foundation

struct TodoHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let createdAt: Date
    let dueDate: Date?
    let urlString: String
    let deletedAt: Date
    
    init(from todo: TodoItem, deletedAt: Date = Date()) {
        self.id = todo.id
        self.title = todo.title
        self.createdAt = todo.createdAt
        self.dueDate = todo.dueDate
        self.urlString = todo.urlString
        self.deletedAt = deletedAt
    }
}

final class TodoHistoryStore {
    private let userDefaults: UserDefaults
    private let key = "TodoList.history"
    private let maxItems = 200
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func load() -> [TodoHistoryItem] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TodoHistoryItem].self, from: data) else {
            return []
        }
        return decoded
    }
    
    func save(_ items: [TodoHistoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        userDefaults.set(data, forKey: key)
    }
    
    func append(_ items: [TodoHistoryItem]) {
        var current = load()
        current.insert(contentsOf: items, at: 0)
        if current.count > maxItems {
            current = Array(current.prefix(maxItems))
        }
        save(current)
    }
}
