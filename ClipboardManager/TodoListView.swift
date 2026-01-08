import AppKit
import SwiftUI

final class TodoListViewModel: ObservableObject {
    @Published var todos: [TodoItem] {
        didSet { store.save(todos) }
    }
    @Published var history: [TodoHistoryItem] = []
    @Published var newTitle: String = ""
    @Published var newURLString: String = ""
    @Published var hasDueDate: Bool = false
    @Published var newDueDate: Date = Date()
    
    private let store: TodoListStore
    private let historyStore: TodoHistoryStore
    
    init(store: TodoListStore, historyStore: TodoHistoryStore) {
        self.store = store
        self.historyStore = historyStore
        self.todos = store.load()
        self.history = historyStore.load()
    }
    
    func addTodo() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let url = newURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueDate = hasDueDate ? newDueDate : nil
        todos.append(TodoItem(title: title, dueDate: dueDate, urlString: url))
        newTitle = ""
        newURLString = ""
        hasDueDate = false
    }
    
    func deleteTodo(id: UUID) {
        guard let todo = todos.first(where: { $0.id == id }) else { return }
        historyStore.append([TodoHistoryItem(from: todo)])
        history = historyStore.load()
        todos.removeAll { $0.id == id }
    }
    
    func clearCompleted() {
        let completed = todos.filter { $0.isDone }
        if !completed.isEmpty {
            historyStore.append(completed.map { TodoHistoryItem(from: $0) })
            history = historyStore.load()
        }
        todos.removeAll { $0.isDone }
    }
    
    func clearAll() {
        if !todos.isEmpty {
            historyStore.append(todos.map { TodoHistoryItem(from: $0) })
            history = historyStore.load()
        }
        todos.removeAll()
    }
    
    var completionSummary: String {
        let done = todos.filter { $0.isDone }.count
        return "完了 \(done) / 全 \(todos.count)"
    }
}

struct TodoListView: View {
    @StateObject private var viewModel: TodoListViewModel
    @State private var showingClearCompletedAlert = false
    @State private var showingClearAllAlert = false
    @State private var showingHistory = false
    
    init(store: TodoListStore, historyStore: TodoHistoryStore) {
        _viewModel = StateObject(wrappedValue: TodoListViewModel(store: store, historyStore: historyStore))
    }
    
    var body: some View {
        VStack(spacing: 18) {
            header
            
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("新しいToDo", text: $viewModel.newTitle)
                        Button("追加") { viewModel.addTodo() }
                    }
                    
                    TextField("関連URL (任意)", text: $viewModel.newURLString)
                    
                    Toggle("期日を設定", isOn: $viewModel.hasDueDate)
                    
                    if viewModel.hasDueDate {
                        DatePicker("期日", selection: $viewModel.newDueDate, displayedComponents: [.date])
                    }
                    
                    if viewModel.todos.isEmpty {
                        Text("ToDoはまだありません。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        List {
                            ForEach($viewModel.todos) { $todo in
                                HStack {
                                    Toggle(isOn: $todo.isDone) { EmptyView() }
                                        .toggleStyle(.checkbox)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(todo.title)
                                            .strikethrough(todo.isDone)
                                            .foregroundColor(todo.isDone ? .secondary : .primary)
                                        
                                        HStack(spacing: 12) {
                                            Text("作成: \(dateFormatter.string(from: todo.createdAt))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Text("期日: \(todo.dueDate.map { dateFormatter.string(from: $0) } ?? "なし")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let url = todo.url {
                                            Button(url.absoluteString) {
                                                NSWorkspace.shared.open(url)
                                            }
                                            .buttonStyle(.link)
                                            .font(.caption)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        viewModel.deleteTodo(id: todo.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .onMove { indices, newOffset in
                                viewModel.todos.move(fromOffsets: indices, toOffset: newOffset)
                            }
                        }
                        .frame(minHeight: 280)
                    }
                }
            }
            
            HStack {
                Text(viewModel.completionSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("履歴を見る") { showingHistory = true }
                Button("完了を削除") { showingClearCompletedAlert = true }
                Button("全て削除") { showingClearAllAlert = true }
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 520, height: 520)
        .alert("完了タスクを削除しますか？", isPresented: $showingClearCompletedAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                viewModel.clearCompleted()
            }
        } message: {
            Text("完了したタスクを履歴へ移動します。")
        }
        .alert("全て削除しますか？", isPresented: $showingClearAllAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                viewModel.clearAll()
            }
        } message: {
            Text("全てのタスクを履歴へ移動します。")
        }
        .sheet(isPresented: $showingHistory) {
            TodoHistoryView(history: viewModel.history)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("ToDoリスト", systemImage: "checklist")
                .font(.headline)
            Text("URLや期日を含めてタスクを管理できます。")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

struct TodoHistoryView: View {
    let history: [TodoHistoryItem]
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("ToDo履歴", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Text("削除されたタスクの履歴です。")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if history.isEmpty {
                Text("履歴はありません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                List(history) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.headline)
                        Text("作成: \(dateFormatter.string(from: item.createdAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("期日: \(item.dueDate.map { dateFormatter.string(from: $0) } ?? "なし")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("削除: \(dateTimeFormatter.string(from: item.deletedAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let url = URL(string: item.urlString), !item.urlString.isEmpty {
                            Text(url.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 520, height: 520)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}
