import SwiftUI

protocol AutoLaunchManaging: AnyObject {
    func enableAutoLaunch()
    func disableAutoLaunch()
    func isAutoLaunchEnabled() -> Bool
}

final class AutoLaunchViewModel: ObservableObject {
    @Published var isAutoLaunchEnabled: Bool
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    private weak var autoLaunchManager: AutoLaunchManaging?
    
    init(autoLaunchManager: AutoLaunchManaging) {
        self.autoLaunchManager = autoLaunchManager
        self.isAutoLaunchEnabled = autoLaunchManager.isAutoLaunchEnabled()
    }
    
    func refreshStatus() {
        isAutoLaunchEnabled = autoLaunchManager?.isAutoLaunchEnabled() ?? false
    }
    
    func updateAutoLaunch(enabled: Bool) {
        if enabled {
            autoLaunchManager?.enableAutoLaunch()
        } else {
            autoLaunchManager?.disableAutoLaunch()
        }
        
        alertMessage = enabled ? "自動起動が有効になりました" : "自動起動が無効になりました"
        showingAlert = true
    }
}

struct AutoLaunchSettingsView: View {
    @StateObject private var viewModel: AutoLaunchViewModel
    
    init(autoLaunchManager: AutoLaunchManaging) {
        _viewModel = StateObject(wrappedValue: AutoLaunchViewModel(autoLaunchManager: autoLaunchManager))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                if #available(macOS 13.0, *) {
                    Label("自動起動設定", systemImage: "power")
                        .font(.title2)
                        .fontWeight(.bold)
                } else {
                    // Fallback on earlier versions
                }
                Text("アプリ起動時の自動実行を管理します。")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("パソコン起動時に自動で起動", isOn: $viewModel.isAutoLaunchEnabled)
                        .onChange(of: viewModel.isAutoLaunchEnabled) { newValue in
                            viewModel.updateAutoLaunch(enabled: newValue)
                        }
                    
                    Text("有効にすると、ログイン後すぐにクリップボードマネージャーが起動します。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } label: {
                Text("起動オプション")
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 220)
        .onAppear {
            viewModel.refreshStatus()
        }
        .alert("通知", isPresented: $viewModel.showingAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}
