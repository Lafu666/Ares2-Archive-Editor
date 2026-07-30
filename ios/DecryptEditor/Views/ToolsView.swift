import SwiftUI
import SQLite3

struct ToolsView: View {
    @EnvironmentObject var fileService: FileService
    @State private var searchResult: String = ""
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var dbPath = ""

    var body: some View {
        NavigationStack {
            List {
                Section("全局搜索") {
                    TextField("搜索关键词", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        performGlobalSearch()
                    } label: {
                        HStack {
                            Spacer()
                            if isSearching {
                                ProgressView()
                            } else {
                                Image(systemName: "magnifyingglass")
                                Text("开始搜索")
                            }
                            Spacer()
                        }
                    }
                    .disabled(searchText.isEmpty || isSearching)
                    .buttonStyle(.borderedProminent)
                }

                if !searchResult.isEmpty {
                    Section("搜索结果") {
                        Text(searchResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("数据编辑工具") {
                    NavigationLink(destination: GameDataEditorView()) {
                        Label("物品编辑器", systemImage: "backpack")
                    }
                    NavigationLink(destination: MapEditorView()) {
                        Label("地图编辑器", systemImage: "map")
                    }
                    NavigationLink(destination: TalentEditorView()) {
                        Label("天赋编辑器", systemImage: "star")
                    }
                    NavigationLink(destination: SimpleEditorView(title: "家具编辑器", tableName: "Furniture")) {
                        Label("家具编辑器", systemImage: "sofa")
                    }
                    NavigationLink(destination: SimpleEditorView(title: "雇佣编辑器", tableName: "Worker")) {
                        Label("雇佣编辑器", systemImage: "person")
                    }
                }

                Section("导入/导出") {
                    NavigationLink(destination: ImportExportView()) {
                        Label("物品导入/导出", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationTitle("工具")
        }
    }

    private func performGlobalSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        searchResult = ""

        let dbFiles = fileService.findDatabaseFiles()

        DispatchQueue.global(qos: .userInitiated).async {
            var results: [String] = []
            for dbURL in dbFiles {
                var db: OpaquePointer?
                guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let dbPtr = db else {
                    continue
                }

                var stmt: OpaquePointer?
                let tableQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
                var tables: [String] = []
                if sqlite3_prepare_v2(dbPtr, tableQuery, -1, &stmt, nil) == SQLITE_OK {
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        if let cStr = sqlite3_column_text(stmt, 0) {
                            tables.append(String(cString: cStr))
                        }
                    }
                    sqlite3_finalize(stmt)
                }

                for table in tables {
                    let colQuery = "PRAGMA table_info(\"\(table)\")"
                    var cols: [String] = []
                    if sqlite3_prepare_v2(dbPtr, colQuery, -1, &stmt, nil) == SQLITE_OK {
                        while sqlite3_step(stmt) == SQLITE_ROW {
                            if let cStr = sqlite3_column_text(stmt, 1) {
                                cols.append(String(cString: cStr))
                            }
                        }
                        sqlite3_finalize(stmt)
                    }

                    let likeClauses = cols.map { "\"\($0)\" LIKE '%\(searchText)%'" }.joined(separator: " OR ")
                    let searchSQL = "SELECT rowid FROM \"\(table)\" WHERE \(likeClauses) LIMIT 100"
                    if sqlite3_prepare_v2(dbPtr, searchSQL, -1, &stmt, nil) == SQLITE_OK {
                        var count = 0
                        while sqlite3_step(stmt) == SQLITE_ROW { count += 1 }
                        if count > 0 {
                            results.append("\(dbURL.lastPathComponent)/\(table): \(count) 条")
                        }
                        sqlite3_finalize(stmt)
                    }
                }
                sqlite3_close(dbPtr)
            }

            DispatchQueue.main.async {
                searchResult = results.isEmpty ? "未找到匹配结果" : results.joined(separator: "\n")
                isSearching = false
            }
        }
    }
}

struct GameDataEditorView: View {
    @EnvironmentObject var fileService: FileService
    @State private var categories: [String] = []
    @State private var selectedCategory = ""
    @State private var selectedDB: URL?

    var body: some View {
        List {
            if fileService.findDatabaseFiles().isEmpty {
                Text("请先导入数据库文件")
                    .foregroundColor(.secondary)
            } else {
                Section("选择数据库") {
                    ForEach(fileService.findDatabaseFiles(), id: \.path) { url in
                        Button {
                            selectedDB = url
                        } label: {
                            Text(url.lastPathComponent)
                        }
                    }
                }

                Section("物品分类") {
                    ForEach(categories, id: \.self) { cat in
                        NavigationLink(cat, destination: CategoryItemsView(category: cat, dbURL: selectedDB))
                    }
                }
            }
        }
        .navigationTitle("物品编辑器")
        .onAppear { loadCategories() }
    }

    private func loadCategories() {
        categories = [
            "普通物资", "BOSS掉落物", "诱饵", "养殖", "工具", "食物",
            "子弹", "成就物品", "剧情物品", "藏宝图", "战利品",
            "装修物品", "武器", "消耗品", "武器配件", "护具装备",
            "地图", "情报", "蓝图模具图纸", "家装修", "出租房装修",
            "配件", "鱼类"
        ]
    }
}

struct CategoryItemsView: View {
    let category: String
    let dbURL: URL?
    @State private var items: [(id: Int, name: String)] = []

    var body: some View {
        List(items, id: \.id) { item in
            HStack {
                Text("\(item.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
                Text(item.name)
            }
        }
        .navigationTitle(category)
        .onAppear { loadItems() }
    }

    private func loadItems() {
        guard let url = dbURL, let path = Bundle.main.path(forResource: "物品ID22", ofType: "txt"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }

        items = content.components(separatedBy: .newlines)
            .compactMap { line -> (Int, String)? in
                let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
                guard parts.count == 2, let id = Int(parts[0]) else { return nil }
                return (id, parts[1])
            }
    }
}

struct MapEditorView: View {
    @EnvironmentObject var fileService: FileService

    var body: some View {
        List {
            if let url = fileService.findDatabaseFiles().first {
                NavigationLink(destination: TableContentView(dbPointer: openDB(url), tableName: "Map")) {
                    Label("地图列表", systemImage: "map")
                }
            }
        }
        .navigationTitle("地图编辑器")
    }

    private func openDB(_ url: URL) -> OpaquePointer? {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil)
        return rc == SQLITE_OK ? db : nil
    }
}

struct TalentEditorView: View {
    var body: some View {
        VStack {
            if let path = Bundle.main.path(forResource: "天赋技能", ofType: "txt"),
               let content = try? String(contentsOfFile: path, encoding: .utf8) {
                List(content.components(separatedBy: .newlines).filter { !$0.isEmpty }, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                }
            } else {
                Text("天赋数据未加载")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("天赋编辑器")
    }
}

struct SimpleEditorView: View {
    let title: String
    let tableName: String
    @EnvironmentObject var fileService: FileService

    var body: some View {
        if let url = fileService.findDatabaseFiles().first, let db = openDB(url) {
            TableContentView(dbPointer: db, tableName: tableName)
                .navigationTitle(title)
        } else {
            Text("请先导入数据库文件")
                .foregroundColor(.secondary)
                .navigationTitle(title)
        }
    }

    private func openDB(_ url: URL) -> OpaquePointer? {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil)
        return rc == SQLITE_OK ? db : nil
    }
}

struct ImportExportView: View {
    @EnvironmentObject var fileService: FileService
    @State private var message = ""

    var body: some View {
        List {
            Section("导入") {
                Button("从文件导入物品数据") {
                    message = "功能开发中"
                }
                Button("导入打包数据") {
                    message = "功能开发中"
                }
            }

            Section("导出") {
                Button("导出当前数据库") {
                    exportDatabase()
                }
                Button("导出为JSON") {
                    message = "功能开发中"
                }
            }

            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("导入/导出")
    }

    private func exportDatabase() {
        guard let src = fileService.findDatabaseFiles().first else {
            message = "没有可导出的数据库"
            return
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dest = docs.appendingPathComponent("export_\(src.lastPathComponent)")
        try? FileManager.default.copyItem(at: src, to: dest)
        message = "已导出到: \(dest.lastPathComponent)"
    }
}
