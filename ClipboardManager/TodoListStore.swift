import Foundation

final class TodoListStore {
    private let userDefaults: UserDefaults
    private let key = "TodoList.data"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func load() -> [TodoItem] {
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return decoded
    }
    
    func save(_ todos: [TodoItem]) {
        guard let data = try? JSONEncoder().encode(todos) else { return }
        userDefaults.set(data, forKey: key)
    }
}
