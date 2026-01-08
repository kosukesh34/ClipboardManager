import SwiftUI

final class ImageAdjustmentViewModel: ObservableObject {
    @Published var isPaddingEnabled: Bool
    @Published var padding: Double
    @Published var isResizeEnabled: Bool
    @Published var targetWidth: Double
    @Published var targetHeight: Double
    @Published var paddingColor: Color
    
    private let store: ImageAdjustmentSettingsStore
    private weak var iconApplier: MenuBarIconApplying?
    
    init(store: ImageAdjustmentSettingsStore, iconApplier: MenuBarIconApplying) {
        self.store = store
        self.iconApplier = iconApplier
        let settings = store.load()
        
        self.isPaddingEnabled = settings.isPaddingEnabled
        self.padding = Double(settings.padding)
        self.isResizeEnabled = settings.isResizeEnabled
        self.targetWidth = Double(settings.targetWidth)
        self.targetHeight = Double(settings.targetHeight)
        self.paddingColor = Color(settings.backgroundColor)
    }
    
    func applyAdjustments() {
        let settings = ImageAdjustmentSettings(
            isPaddingEnabled: isPaddingEnabled,
            padding: CGFloat(padding),
            isResizeEnabled: isResizeEnabled,
            targetWidth: CGFloat(targetWidth),
            targetHeight: CGFloat(targetHeight),
            backgroundColor: NSColor(paddingColor)
        )
        
        store.save(settings)
        iconApplier?.applyMenuBarIconAdjustments()
    }
}

struct ImageAdjustmentView: View {
    @StateObject private var viewModel: ImageAdjustmentViewModel
    private let settingsStore: ImageBatchSettingsStore
    private let presetStore: OutputSizePresetStore
    private let locationStore: OutputLocationStore
    private let todoStore: ImageProcessingTodoStore
    
    init(
        store: ImageAdjustmentSettingsStore,
        iconApplier: MenuBarIconApplying,
        settingsStore: ImageBatchSettingsStore,
        presetStore: OutputSizePresetStore,
        locationStore: OutputLocationStore,
        todoStore: ImageProcessingTodoStore
    ) {
        _viewModel = StateObject(
            wrappedValue: ImageAdjustmentViewModel(store: store, iconApplier: iconApplier)
        )
        self.settingsStore = settingsStore
        self.presetStore = presetStore
        self.locationStore = locationStore
        self.todoStore = todoStore
    }
    
    var body: some View {
        TabView {
            menuBarIconTab
                .tabItem {
                    Label("メニューバーアイコン", systemImage: "menubar.rectangle")
                }
            
            ImageBatchExportView(
                settingsStore: settingsStore,
                presetStore: presetStore,
                locationStore: locationStore,
                todoStore: todoStore
            )
            .tabItem {
                Label("画像書き出し", systemImage: "square.and.arrow.down")
            }
        }
        .frame(width: 940, height: 660)
    }
    
    private var menuBarIconTab: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Label("メニューバーアイコンの調整", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                Text("アプリのメニューバーアイコンに余白とサイズを適用します。")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("余白を追加", isOn: $viewModel.isPaddingEnabled)
                    
                    HStack {
                        Text("余白(px)")
                        TextField("0", value: $viewModel.padding, formatter: numberFormatter)
                            .frame(width: 60)
                        Stepper("", value: $viewModel.padding, in: 0...64, step: 1)
                        Spacer()
                    }
                    .disabled(!viewModel.isPaddingEnabled)
                    
                    ColorPicker("余白の色", selection: $viewModel.paddingColor)
                        .disabled(!viewModel.isPaddingEnabled)
                }
                .padding(.vertical, 4)
            } label: {
                Text("余白")
            }
            
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("リサイズ", isOn: $viewModel.isResizeEnabled)
                    
                    HStack(spacing: 12) {
                        Text("幅")
                        TextField("18", value: $viewModel.targetWidth, formatter: numberFormatter)
                            .frame(width: 60)
                        Stepper("", value: $viewModel.targetWidth, in: 8...64, step: 1)
                        
                        Text("高さ")
                        TextField("18", value: $viewModel.targetHeight, formatter: numberFormatter)
                            .frame(width: 60)
                        Stepper("", value: $viewModel.targetHeight, in: 8...64, step: 1)
                        
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
                .disabled(!viewModel.isResizeEnabled)
            } label: {
                Text("サイズ")
            }
            
            HStack {
                Spacer()
                Button("メニューバーアイコンに適用") {
                    viewModel.applyAdjustments()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 440, height: 420)
    }
    
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 999
        return formatter
    }
}
