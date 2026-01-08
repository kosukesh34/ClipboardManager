import SwiftUI

final class QuickMemoViewModel: ObservableObject {
    @Published var markdownText: String {
        didSet { persistIfNeeded() }
    }
    
    private let store: QuickMemoStore
    private var isLoaded = false
    
    init(store: QuickMemoStore) {
        self.store = store
        let note = store.load()
        self.markdownText = note.markdownText
        self.isLoaded = true
    }
    
    private func persistIfNeeded() {
        guard isLoaded else { return }
        store.save(QuickMemoNote(markdownText: markdownText))
    }
}

struct QuickMemoView: View {
    enum MarkdownMode: String, CaseIterable, Identifiable {
        case edit = "編集"
        case preview = "プレビュー"
        
        var id: String { rawValue }
    }
    
    @StateObject private var viewModel: QuickMemoViewModel
    @State private var markdownMode: MarkdownMode = .edit
    
    init(store: QuickMemoStore) {
        _viewModel = StateObject(wrappedValue: QuickMemoViewModel(store: store))
    }
    
    var body: some View {
        VStack(spacing: 18) {
            header
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("クイックメモ")
                        .font(.headline)
                    Spacer()
                    Picker("表示", selection: $markdownMode) {
                        ForEach(MarkdownMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                GroupBox {
                    if markdownMode == .edit {
                        TextEditor(text: $viewModel.markdownText)
                            .font(.body)
                            .frame(minHeight: 320)
                    } else {
                        ScrollView {
                            markdownPreview
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(minHeight: 320)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(24)
        .frame(width: 640, height: 520)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("クイックメモ", systemImage: "note.text")
                .font(.headline)
            Text("Markdown対応のメモをすぐに書き留められます。")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var markdownPreview: some View {
        let text = viewModel.markdownText.isEmpty ? "Markdownを入力してください。" : viewModel.markdownText
        return Text(markdownAttributedString(text))
    }
}

private func markdownAttributedString(_ text: String) -> AttributedString {
    if #available(macOS 12.0, *) {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) {
            return attributed
        }
    }
    return AttributedString(text)
}
