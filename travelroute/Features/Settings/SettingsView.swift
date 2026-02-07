//
//  SettingsView.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    
    var body: some View {
        NavigationView {
            List {
                // 外观设置
                Section("外观") {
                    Picker("颜色模式", selection: $colorScheme) {
                        Text("跟随系统").tag("system")
                        Text("浅色模式").tag("light")
                        Text("深色模式").tag("dark")
                    }
                }
                
                // 应用信息
                Section("关于") {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("TravelRoute")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
