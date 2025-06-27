import Cocoa
import SwiftUI
import Carbon
import ApplicationServices
// ContentView: 設定ウィンドウ用のSwiftUIビュー
struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Clipboard Manager")
                .font(.title)
                .fontWeight(.bold)
            
            Text("効率的なクリップボード履歴管理")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("使い方:")
                    .fontWeight(.semibold)
                
                Text("• ⌘+Shift+V: 履歴ポップアップを表示")
                Text("• ⌘+Shift+1~9: 該当番号のアイテムを直接ペースト")
                Text("• メニューバーアイコンから操作可能")
                Text("• 最大10個まで履歴を保存")
                Text("• クリップボード変更時のみ自動検出")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Text("※ アクセシビリティ権限が必要です")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding()
        .frame(width: 450, height: 400)
    }
}

// HistoryPopupView: クリップボード履歴表示用のSwiftUIビュー
struct HistoryPopupView: View {
    let clipboardManager: ClipboardManager
    let window: NSWindow
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("クリップボード履歴")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button("閉じる") {
                    window.close()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    let history = clipboardManager.getClipboardHistory()
                    
                    if history.isEmpty {
                        Text("履歴なし")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(history.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                
                                Text(item)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Spacer()
                                
                                Button("ペースト") {
                                    clipboardManager.selectAndPasteItem(at: index)
                                    window.close()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(radius: 1)
                            .onTapGesture {
                                clipboardManager.selectAndPasteItem(at: index)
                                window.close()
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 300)
    }
}

@main
struct ClipboardManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var clipboardManager: ClipboardManager!
    var hotKeyManager: HotKeyManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // アクセシビリティ権限をチェック
        checkAccessibilityPermissions()
        
        // ステータスバーアイテムを作成
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let image = NSImage(named: "MenuBarIcon") {
                image.isTemplate = true
                button.image = image
                print("メニューバーアイコン（MenuBarIcon）を正常に読み込みました")
            } else {
                print("MenuBarIconの読み込みに失敗。システムアイコン（clipboard）にフォールバック")
                button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard Manager")
            }
            button.action = #selector(showMenu)
            button.target = self
        }
        
        // クリップボードマネージャーを初期化
        clipboardManager = ClipboardManager(appDelegate: self)
        clipboardManager.startMonitoring()
        
        // ホットキーマネージャーを初期化
        hotKeyManager = HotKeyManager(clipboardManager: clipboardManager)
        hotKeyManager.registerHotKeys()
        
        // メニューバーのメニューを設定
        setupMenu()
    }
    
    func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "アクセシビリティ権限が必要です"
            alert.informativeText = "システム設定 > プライバシーとセキュリティ > アクセシビリティで「ClipboardManager」を許可してください。アプリケーションを「アプリケーション」フォルダで実行していることを確認してください。"
            alert.addButton(withTitle: "システム設定を開く")
            alert.addButton(withTitle: "後で")
            alert.alertStyle = .critical
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        } else {
            print("アクセシビリティ権限が付与されています")
        }
    }
    
    @objc func showMenu() {
        statusItem.menu = createMenu()
        statusItem.button?.performClick(nil)
    }
    
    func setupMenu() {
        let menu = createMenu()
        statusItem.menu = menu
        print("メニューバーを更新: 履歴数 = \(clipboardManager.getClipboardHistory().count)")
    }
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem.separator())
        
        let clipboardItems = clipboardManager.getClipboardHistory()
        
        if clipboardItems.isEmpty {
            let emptyItem = NSMenuItem(title: "履歴なし", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, item) in clipboardItems.enumerated() {
                let title = item.count > 50 ? String(item.prefix(50)) + "..." : item
                let menuItem = NSMenuItem(title: "[\(index + 1)] \(title)", action: #selector(selectClipboardItem(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.tag = index
                menu.addItem(menuItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let clearItem = NSMenuItem(title: "履歴をクリア", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc func selectClipboardItem(_ sender: NSMenuItem) {
        let index = sender.tag
        clipboardManager.selectAndPasteItem(at: index)
    }
    
    @objc func clearHistory() {
        clipboardManager.clearHistory()
        setupMenu()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

class ClipboardManager: ObservableObject {
    private var clipboardHistory: [String] = []
    private var lastChangeCount: Int = 0
    private let maxHistoryCount = 10
    private weak var appDelegate: AppDelegate?
    
    init(appDelegate: AppDelegate? = nil) {
        self.appDelegate = appDelegate
    }
    
    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        print("クリップボード監視開始: 初期changeCount = \(lastChangeCount)")
        
        if let content = NSPasteboard.general.string(forType: .string) {
            print("初期クリップボード内容: \(content.prefix(50))")
            if !content.isEmpty {
                addToHistory(content)
            }
        }
    }
    
    func checkClipboardChange() {
        let currentChangeCount = NSPasteboard.general.changeCount
        print("クリップボードチェック: currentChangeCount = \(currentChangeCount), lastChangeCount = \(lastChangeCount)")
        
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            if let content = NSPasteboard.general.string(forType: .string) {
                if !content.isEmpty {
                    print("クリップボード変更検出: \(content.prefix(50))")
                    addToHistory(content)
                    DispatchQueue.main.async {
                        self.appDelegate?.setupMenu()
                    }
                } else {
                    print("クリップボード内容が空です")
                }
            } else {
                print("クリップボードに文字列データがありません")
            }
        }
    }
    
    private func addToHistory(_ content: String) {
        if let existingIndex = clipboardHistory.firstIndex(of: content) {
            clipboardHistory.remove(at: existingIndex)
        }
        clipboardHistory.insert(content, at: 0)
        
        if clipboardHistory.count > maxHistoryCount {
            clipboardHistory.removeLast()
        }
        
        print("クリップボード履歴に追加: \(content.prefix(50)), 履歴数: \(clipboardHistory.count)")
    }
    
    func getClipboardHistory() -> [String] {
        return clipboardHistory
    }
    
    func selectItem(at index: Int) {
        guard index < clipboardHistory.count else { return }
        
        let selectedContent = clipboardHistory[index]
        setClipboard(selectedContent)
        
        clipboardHistory.remove(at: index)
        clipboardHistory.insert(selectedContent, at: 0)
        
        print("クリップボードに設定: \(selectedContent.prefix(50))")
        DispatchQueue.main.async {
            self.appDelegate?.setupMenu()
        }
    }
    
    func selectAndPasteItem(at index: Int) {
        guard index < clipboardHistory.count else {
            print("選択されたインデックス \(index) は履歴範囲外です")
            return
        }
        
        let selectedContent = clipboardHistory[index]
        setClipboard(selectedContent)
        
        clipboardHistory.remove(at: index)
        clipboardHistory.insert(selectedContent, at: 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performPaste()
        }
        
        print("クリップボードに設定してペースト: \(selectedContent.prefix(50))")
        DispatchQueue.main.async {
            self.appDelegate?.setupMenu()
        }
    }
    
    private func setClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        lastChangeCount = pasteboard.changeCount
        print("クリップボードを設定: changeCount = \(lastChangeCount)")
    }
    
    private func performPaste() {
        guard AXIsProcessTrusted() else {
            print("アクセシビリティ権限が不足しているためペーストできません")
            return
        }
        
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        keyDownEvent?.flags = .maskCommand
        keyUpEvent?.flags = .maskCommand
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
        print("ペーストを実行")
    }
    
    func clearHistory() {
        clipboardHistory.removeAll()
        print("クリップボード履歴をクリア")
        DispatchQueue.main.async {
            self.appDelegate?.setupMenu()
        }
    }
    
    func showHistoryPopup() {
        let popupWindow = createHistoryPopupWindow()
        popupWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("履歴ポップアップを表示")
    }
    
    private func createHistoryPopupWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = "クリップボード履歴"
        window.level = .floating
        
        let contentView = NSHostingView(rootView: HistoryPopupView(
            clipboardManager: self,
            window: window
        ))
        
        window.contentView = contentView
        return window
    }
    
    deinit {
        print("ClipboardManagerを解放")
    }
}

class HotKeyManager {
    let clipboardManager: ClipboardManager
    private var hotKeyMonitor: Any?
    private var clipboardCheckTimer: Timer?
    
    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }
    
    func registerHotKeys() {
        // キーイベント監視（⌘+Shift+V および ⌘+Shift+1~9）
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            print("ホットキーイベント: keyCode = \(event.keyCode), modifiers = \(event.modifierFlags)")
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 0x09 { // V key
                self.clipboardManager.showHistoryPopup()
            }
            
            let numberKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25] // 1-9 keys
            if event.modifierFlags.contains([.command, .shift]),
               let index = numberKeyCodes.firstIndex(of: event.keyCode) {
                if index < self.clipboardManager.getClipboardHistory().count {
                    self.clipboardManager.selectAndPasteItem(at: index)
                } else {
                    print("選択されたインデックス \(index) は履歴範囲外です")
                }
            }
            
            // ⌘+C の検出
            if event.modifierFlags.contains(.command) && event.keyCode == 0x08 { // C key
                print("コピー操作（⌘+C）を検出")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.clipboardManager.checkClipboardChange()
                }
            }
        }
        
        // 定期的なクリップボードチェック（アクセシビリティイベントの代替）
        startClipboardPolling()
        
        print("ホットキーとクリップボード監視を開始しました")
    }
    
    private func startClipboardPolling() {
        // 1秒ごとにクリップボードの変更をチェック
        clipboardCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.clipboardManager.checkClipboardChange()
        }
        print("クリップボードのポーリング開始")
    }
    
    deinit {
        if let monitor = hotKeyMonitor {
            NSEvent.removeMonitor(monitor)
            print("ホットキーモニターを解放")
        }
        
        clipboardCheckTimer?.invalidate()
        clipboardCheckTimer = nil
        print("クリップボードチェッククタイマーを解放")
    }
}
