import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class ImageBatchExportViewModel: ObservableObject {
    @Published var items: [ImageFileItem] = []
    @Published var isPaddingEnabled: Bool
    @Published var padding: Double
    @Published var isResizeEnabled: Bool
    @Published var targetWidth: Double
    @Published var targetHeight: Double
    @Published var backgroundColor: Color
    @Published var outputPresets: [OutputSizePreset] = []
    @Published var selectedPresetIDs: Set<UUID> = []
    @Published var outputFolderURL: URL?
    @Published var statusMessage: String = ""
    @Published var newPresetName: String = ""
    @Published var newPresetWidth: String = ""
    @Published var newPresetHeight: String = ""
    
    private let settingsStore: ImageBatchSettingsStore
    private let presetStore: OutputSizePresetStore
    private let locationStore: OutputLocationStore
    private let processor: ImageBatchProcessor
    private var isLoaded = false
    
    init(
        settingsStore: ImageBatchSettingsStore,
        presetStore: OutputSizePresetStore,
        locationStore: OutputLocationStore,
        processor: ImageBatchProcessor = ImageBatchProcessor()
    ) {
        self.settingsStore = settingsStore
        self.presetStore = presetStore
        self.locationStore = locationStore
        self.processor = processor
        
        let settings = settingsStore.load()
        self.isPaddingEnabled = settings.isPaddingEnabled
        self.padding = Double(settings.padding)
        self.isResizeEnabled = settings.isResizeEnabled
        self.targetWidth = Double(settings.targetWidth)
        self.targetHeight = Double(settings.targetHeight)
        self.backgroundColor = Color(settings.backgroundColor)
        self.outputPresets = presetStore.load()
        self.outputFolderURL = locationStore.load()
        self.selectedPresetIDs = Set(outputPresets.map(\.id))
        self.isLoaded = true
    }
    
    func addItems(from urls: [URL]) {
        let valid = urls.filter { $0.isFileURL }
        let existing = Set(items.map { $0.url })
        let newItems = valid.filter { !existing.contains($0) }.map(ImageFileItem.init)
        items.append(contentsOf: newItems)
    }
    
    func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    func clearItems() {
        items.removeAll()
    }
    
    func togglePreset(_ preset: OutputSizePreset, isSelected: Bool) {
        if isSelected {
            selectedPresetIDs.insert(preset.id)
        } else {
            selectedPresetIDs.remove(preset.id)
        }
    }
    
    func addPreset() {
        let width = Double(newPresetWidth.trimmingCharacters(in: .whitespaces)) ?? 0
        let height = Double(newPresetHeight.trimmingCharacters(in: .whitespaces)) ?? 0
        guard width > 0, height > 0 else {
            statusMessage = "サイズを正しく入力してください。"
            return
        }
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? "\(Int(width))x\(Int(height))" : name
        let preset = OutputSizePreset(name: displayName, width: width, height: height)
        outputPresets.append(preset)
        presetStore.save(outputPresets)
        newPresetName = ""
        newPresetWidth = ""
        newPresetHeight = ""
    }
    
    func deletePreset(_ preset: OutputSizePreset) {
        outputPresets.removeAll { $0.id == preset.id }
        selectedPresetIDs.remove(preset.id)
        presetStore.save(outputPresets)
    }
    
    func selectAllPresets() {
        selectedPresetIDs = Set(outputPresets.map(\.id))
    }
    
    func clearPresetSelection() {
        selectedPresetIDs.removeAll()
    }
    
    func setOutputFolderToDownloads() {
        outputFolderURL = OutputLocationStore.downloadsURL
        locationStore.save(outputFolderURL)
    }
    
    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "保存先を選択"
        
        if panel.runModal() == .OK {
            outputFolderURL = panel.url
            locationStore.save(outputFolderURL)
        }
    }
    
    func exportImages() {
        guard !items.isEmpty else {
            statusMessage = "画像を追加してください。"
            return
        }
        
        let folder = outputFolderURL ?? OutputLocationStore.downloadsURL
        outputFolderURL = folder
        locationStore.save(folder)
        
        let settings = ImageAdjustmentSettings(
            isPaddingEnabled: isPaddingEnabled,
            padding: CGFloat(padding),
            isResizeEnabled: isResizeEnabled,
            targetWidth: CGFloat(targetWidth),
            targetHeight: CGFloat(targetHeight),
            backgroundColor: NSColor(backgroundColor)
        )
        settingsStore.save(settings)
        
        let selectedPresets = outputPresets.filter { selectedPresetIDs.contains($0.id) }
        
        do {
            let outputs = try processor.exportImages(
                items: items,
                settings: settings,
                outputPresets: selectedPresets,
                outputFolder: folder
            )
            statusMessage = outputs.isEmpty ? "書き出しに失敗しました。" : "書き出し完了: \(outputs.count)件"
        } catch {
            statusMessage = "書き出しエラー: \(error.localizedDescription)"
        }
    }
    
    func persistIfNeeded() {
        guard isLoaded else { return }
        let settings = ImageAdjustmentSettings(
            isPaddingEnabled: isPaddingEnabled,
            padding: CGFloat(padding),
            isResizeEnabled: isResizeEnabled,
            targetWidth: CGFloat(targetWidth),
            targetHeight: CGFloat(targetHeight),
            backgroundColor: NSColor(backgroundColor)
        )
        settingsStore.save(settings)
    }
}

final class ImageProcessingTodoViewModel: ObservableObject {
    @Published var todos: [TodoItem] {
        didSet { store.save(todos) }
    }
    @Published var newTitle: String = ""
    
    private let store: ImageProcessingTodoStore
    
    init(store: ImageProcessingTodoStore) {
        self.store = store
        self.todos = store.load()
    }
    
    func addTodo() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        todos.append(TodoItem(title: title))
        newTitle = ""
    }
    
    func deleteTodo(id: UUID) {
        todos.removeAll { $0.id == id }
    }
}

struct ImageBatchExportView: View {
    @StateObject private var viewModel: ImageBatchExportViewModel
    @StateObject private var todoViewModel: ImageProcessingTodoViewModel
    @State private var isDropTargeted = false
    
    init(
        settingsStore: ImageBatchSettingsStore,
        presetStore: OutputSizePresetStore,
        locationStore: OutputLocationStore,
        todoStore: ImageProcessingTodoStore
    ) {
        _viewModel = StateObject(
            wrappedValue: ImageBatchExportViewModel(
                settingsStore: settingsStore,
                presetStore: presetStore,
                locationStore: locationStore
            )
        )
        _todoViewModel = StateObject(wrappedValue: ImageProcessingTodoViewModel(store: todoStore))
    }
    
    var body: some View {
        VStack(spacing: 18) {
            header
            
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    dropArea
                    fileList
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 12) {
                    adjustmentOptions
                    presetOptions
                    outputOptions
                }
                .frame(width: 300)
            }
            
            HStack(alignment: .top, spacing: 16) {
                todoSection
                statusSection
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 920, height: 620)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("画像書き出し", systemImage: "square.and.arrow.down")
                .font(.headline)
            Text("複数画像の余白・リサイズ、App Storeスクリーンショットの一括生成に対応します。")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var dropArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
            
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 28))
                Text("画像ファイルをドラッグ&ドロップ")
                    .font(.headline)
                Text("PNG/JPG/PDFなどをまとめて追加できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(height: 140)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private var fileList: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("入力ファイル")
                        .font(.headline)
                    Spacer()
                    Button("クリア") {
                        viewModel.clearItems()
                    }
                }
                
                if viewModel.items.isEmpty {
                    Text("まだ画像が追加されていません。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            HStack {
                                Image(systemName: "doc.richtext")
                                    .foregroundColor(.secondary)
                                Text(item.displayName)
                                    .lineLimit(1)
                            }
                        }
                        .onDelete(perform: viewModel.removeItems)
                    }
                    .frame(minHeight: 180)
                }
            }
        }
    }
    
    private var adjustmentOptions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("余白を追加", isOn: $viewModel.isPaddingEnabled)
                    .onChange(of: viewModel.isPaddingEnabled) { _ in
                        viewModel.persistIfNeeded()
                    }
                
                HStack {
                    Text("余白(px)")
                    TextField("0", value: $viewModel.padding, formatter: numberFormatter)
                        .frame(width: 60)
                    Stepper("", value: $viewModel.padding, in: 0...128, step: 1)
                    Spacer()
                }
                .onChange(of: viewModel.padding) { _ in
                    viewModel.persistIfNeeded()
                }
                .disabled(!viewModel.isPaddingEnabled)
                
                ColorPicker("余白の色", selection: $viewModel.backgroundColor)
                    .onChange(of: viewModel.backgroundColor) { _ in
                        viewModel.persistIfNeeded()
                    }
                    .disabled(!viewModel.isPaddingEnabled)
                
                Divider()
                
                Toggle("リサイズ", isOn: $viewModel.isResizeEnabled)
                    .onChange(of: viewModel.isResizeEnabled) { _ in
                        viewModel.persistIfNeeded()
                    }
                
                HStack(spacing: 12) {
                    Text("幅")
                    TextField("幅", value: $viewModel.targetWidth, formatter: numberFormatter)
                        .frame(width: 60)
                    Stepper("", value: $viewModel.targetWidth, in: 8...5000, step: 1)
                    
                    Text("高さ")
                    TextField("高さ", value: $viewModel.targetHeight, formatter: numberFormatter)
                        .frame(width: 60)
                    Stepper("", value: $viewModel.targetHeight, in: 8...5000, step: 1)
                    
                    Spacer()
                }
                .onChange(of: viewModel.targetWidth) { _ in
                    viewModel.persistIfNeeded()
                }
                .onChange(of: viewModel.targetHeight) { _ in
                    viewModel.persistIfNeeded()
                }
                .disabled(!viewModel.isResizeEnabled)
            }
            .padding(.vertical, 4)
        } label: {
            Text("調整オプション")
        }
    }
    
    private var presetOptions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("App Storeサイズ")
                        .font(.headline)
                    Spacer()
                    Button("全選択") { viewModel.selectAllPresets() }
                    Button("解除") { viewModel.clearPresetSelection() }
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.outputPresets) { preset in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { viewModel.selectedPresetIDs.contains(preset.id) },
                                    set: { viewModel.togglePreset(preset, isSelected: $0) }
                                )) {
                                    Text("\(preset.name) (\(Int(preset.width))x\(Int(preset.height)))")
                                        .font(.caption)
                                }
                                .toggleStyle(.checkbox)
                                
                                Spacer()
                                
                                Button {
                                    viewModel.deletePreset(preset)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .frame(height: 140)
                
                Divider()
                
                Text("サイズ追加")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("名前", text: $viewModel.newPresetName)
                HStack {
                    TextField("幅", text: $viewModel.newPresetWidth)
                    TextField("高さ", text: $viewModel.newPresetHeight)
                }
                
                Button("サイズを追加") {
                    viewModel.addPreset()
                }
            }
        }
    }
    
    private var outputOptions: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("保存先")
                    .font(.headline)
                Text(viewModel.outputFolderURL?.path ?? OutputLocationStore.downloadsURL.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Button("保存先を選択") {
                        viewModel.chooseOutputFolder()
                    }
                    Button("Downloadsに保存") {
                        viewModel.setOutputFolderToDownloads()
                    }
                }
                
                Divider()
                
                Button("PNGを書き出す") {
                    viewModel.exportImages()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var todoSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("作業ToDo")
                    .font(.headline)
                
                HStack {
                    TextField("ToDoを追加", text: $todoViewModel.newTitle)
                    Button("追加") { todoViewModel.addTodo() }
                }
                
                if todoViewModel.todos.isEmpty {
                    Text("ToDoはありません。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach($todoViewModel.todos) { $todo in
                            HStack {
                                Toggle(isOn: $todo.isDone) {
                                    Text(todo.title)
                                        .strikethrough(todo.isDone)
                                        .foregroundColor(todo.isDone ? .secondary : .primary)
                                }
                                .toggleStyle(.checkbox)
                                
                                Spacer()
                                
                                Button {
                                    todoViewModel.deleteTodo(id: todo.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .frame(height: 130)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("ステータス")
                    .font(.headline)
                Text(viewModel.statusMessage.isEmpty ? "待機中" : viewModel.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 260)
    }
    
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 99999
        return formatter
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        let lock = NSLock()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
            }
        }
        
        group.notify(queue: .main) {
            viewModel.addItems(from: urls)
        }
        
        return true
    }
}
