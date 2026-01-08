import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date
    var dueDate: Date?
    var urlString: String
    
    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        urlString: String = ""
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.urlString = urlString
    }
    
    var url: URL? {
        guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return URL(string: urlString)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString) ?? ""
    }
}

struct QuickMemoNote: Codable, Equatable {
    var markdownText: String
    
    static let empty = QuickMemoNote(markdownText: "")
}

final class QuickMemoStore {
    private let userDefaults: UserDefaults
    private let dataKey = "QuickMemo.data"
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func load() -> QuickMemoNote {
        guard let data = userDefaults.data(forKey: dataKey) else {
            return .empty
        }
        
        if let note = try? JSONDecoder().decode(QuickMemoNote.self, from: data) {
            return note
        }
        
        if let legacy = try? JSONDecoder().decode(QuickMemoData.self, from: data) {
            return QuickMemoNote(markdownText: legacy.markdownText)
        }
        
        return .empty
    }
    
    func save(_ note: QuickMemoNote) {
        guard let encoded = try? JSONEncoder().encode(note) else { return }
        userDefaults.set(encoded, forKey: dataKey)
    }
}

private struct QuickMemoData: Codable, Equatable {
    var markdownText: String
    var todos: [TodoItem]
}
