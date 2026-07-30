import SwiftUI

struct SettingsView: View {
    @AppStorage("theme") private var theme = "dark"
    @AppStorage("pageSize") private var pageSize = 100
    @State private var showingClearConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("显示") {
                    Picker("主题", selection: $theme) {
                        Text("深色").tag("dark")
                        Text("浅色").tag("light")
                    }
                }

                Section("数据库") {
                    Stepper("每页行数: \(pageSize)", value: $pageSize, in: 50...500, step: 50)
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("最低支持")
                        Spacer()
                        Text("iOS 17.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("来源项目")
                        Spacer()
                        Text("com.ars.decrypt")
                            .foregroundColor(.secondary)
                    }
                }

                Section("数据管理") {
                    Button("清除所有数据", role: .destructive) {
                        showingClearConfirm = true
                    }
                }
            }
            .navigationTitle("设置")
            .alert("确认清除", isPresented: $showingClearConfirm) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("所有导入的数据库和缓存将被删除")
            }
        }
    }

    private func clearAllData() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let contents = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
            for url in contents {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
