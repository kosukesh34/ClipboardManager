//
//  ContentView.swift
//  ClipboardManager
//
//  Created by Kosuke Shigematsu on 6/26/25.
//

import SwiftUI

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
                Text("• パソコン起動時に自動で起動")
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

#Preview {
    ContentView()
}
