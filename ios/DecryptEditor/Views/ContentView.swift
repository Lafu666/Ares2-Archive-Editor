import SwiftUI

enum AppTab: String, CaseIterable {
    case files = "文件"
    case database = "数据库"
    case tools = "工具"
    case settings = "设置"

    var icon: String {
        switch self {
        case .files: return "folder"
        case .database: return "cylinder.split.1x2"
        case .tools: return "wrench.and.screwdriver"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .files

    var body: some View {
        TabView(selection: $selectedTab) {
            FileBrowserView()
                .tabItem { Label(AppTab.files.rawValue, systemImage: AppTab.files.icon) }
                .tag(AppTab.files)

            DatabaseListView()
                .tabItem { Label(AppTab.database.rawValue, systemImage: AppTab.database.icon) }
                .tag(AppTab.database)

            ToolsView()
                .tabItem { Label(AppTab.tools.rawValue, systemImage: AppTab.tools.icon) }
                .tag(AppTab.tools)

            SettingsView()
                .tabItem { Label(AppTab.settings.rawValue, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
    }
}
