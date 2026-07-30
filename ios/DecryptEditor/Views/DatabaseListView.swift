import SwiftUI
import SQLite3

struct DatabaseListView: View {
    @EnvironmentObject var fileService: FileService
    @State private var databases: [URL] = []
    @State private var selectedDB: URL?

    var body: some View {
        NavigationStack {
            List {
                if databases.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cylinder.split.1x2")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("在文件浏览中打开数据库文件")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(databases, id: \.path) { url in
                        Button {
                            selectedDB = url
                        } label: {
                            HStack {
                                Image(systemName: "cylinder")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading) {
                                    Text(url.lastPathComponent)
                                    if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber {
                                        Text("\(ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            try? FileManager.default.removeItem(at: databases[i])
                        }
                        databases = fileService.findDatabaseFiles()
                    }
                }
            }
            .navigationTitle("数据库")
            .onAppear {
                databases = fileService.findDatabaseFiles()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSFileManagerDidChange)) { _ in
                databases = fileService.findDatabaseFiles()
            }
            .sheet(item: $selectedDB) { url in
                NavigationStack {
                    DatabaseView(fileURL: url)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("关闭") { selectedDB = nil }
                            }
                        }
                }
            }
        }
    }
}

struct DatabaseView: View {
    let fileURL: URL
    @State private var tables: [String] = []
    @State private var selectedTable: String?
    @State private var dbPointer: OpaquePointer?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text("打开失败")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if tables.isEmpty {
                ProgressView("加载中...")
            } else {
                List(tables, id: \.self) { table in
                    NavigationLink(table, destination: TableContentView(dbPointer: dbPointer, tableName: table))
                }
                .navigationTitle("\(tables.count) 个表")
            }
        }
        .onAppear { openDatabase() }
        .onDisappear { closeDatabase() }
    }

    private func openDatabase() {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        let result = sqlite3_open_v2(fileURL.path, &dbPointer, flags, nil)
        guard result == SQLITE_OK, let db = dbPointer else {
            errorMessage = "无法打开数据库 (错误码: \(result))"
            return
        }
        loadTables(db: db)
    }

    private func loadTables(db: OpaquePointer) {
        var stmt: OpaquePointer?
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return }

        var result: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0) {
                result.append(String(cString: cStr))
            }
        }
        sqlite3_finalize(stmt)
        tables = result
    }

    private func closeDatabase() {
        if let db = dbPointer {
            sqlite3_close(db)
        }
    }
}

struct TableContentView: View {
    let dbPointer: OpaquePointer?
    let tableName: String
    @State private var columns: [String] = []
    @State private var rows: [[String]] = []
    @State private var searchText = ""
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
            } else {
                HStack {
                    Text("\(rows.count) 行")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)

                ScrollView(.horizontal) {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            headerView
                            Divider()
                            ForEach(Array(filteredRows.enumerated()), id: \.offset) { index, row in
                                NavigationLink(destination: RowDetailView(columns: columns, row: row, tableName: tableName, dbPointer: dbPointer, rowIndex: index)) {
                                    RowView(columns: columns, row: row, index: index)
                                }
                                .buttonStyle(.plain)
                                if index < filteredRows.count - 1 {
                                    Divider().padding(.leading)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(tableName)
        .searchable(text: $searchText, prompt: "搜索")
        .onAppear { loadData() }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Text("#")
                .font(.caption.bold())
                .frame(width: 40, alignment: .center)
            ForEach(columns, id: \.self) { col in
                Text(col)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .frame(minWidth: 100, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    private var filteredRows: [[String]] {
        if searchText.isEmpty { return rows }
        return rows.filter { row in
            row.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func loadData() {
        guard let db = dbPointer else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var stmt: OpaquePointer?
            let pragma = "PRAGMA table_info(\(tableName))"
            var cols: [String] = []
            if sqlite3_prepare_v2(db, pragma, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let cStr = sqlite3_column_text(stmt, 1) {
                        cols.append(String(cString: cStr))
                    }
                }
                sqlite3_finalize(stmt)
            }

            var result: [[String]] = []
            let query = "SELECT rowid, * FROM \"\(tableName)\" LIMIT 5000"
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let count = sqlite3_column_count(stmt)
                    var row: [String] = []
                    for i in 0..<count {
                        if let cStr = sqlite3_column_text(stmt, i) {
                            row.append(String(cString: cStr))
                        } else {
                            row.append("NULL")
                        }
                    }
                    result.append(row)
                }
                sqlite3_finalize(stmt)
            }

            DispatchQueue.main.async {
                columns = cols
                rows = result
                isLoading = false
            }
        }
    }
}

struct RowView: View {
    let columns: [String]
    let row: [String]
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .center)

            ForEach(Array(row.enumerated()), id: \.offset) { _, value in
                Text(value)
                    .font(.caption)
                    .lineLimit(1)
                    .frame(minWidth: 100, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

struct RowDetailView: View {
    let columns: [String]
    let row: [String]
    let tableName: String
    let dbPointer: OpaquePointer?
    let rowIndex: Int
    @State private var editValues: [String] = []
    @State private var editMode = false
    @State private var message: String?

    var body: some View {
        List {
            if let msg = message {
                Section {
                    Text(msg)
                        .foregroundColor(msg.hasPrefix("已") ? .green : .red)
                        .font(.caption)
                }
            }

            Section("字段编辑") {
                ForEach(Array(columns.enumerated()), id: \.offset) { i, col in
                    HStack {
                        Text(col)
                            .font(.caption.bold())
                            .frame(width: 100, alignment: .leading)
                        if editMode, i < editValues.count {
                            TextField("值", text: $editValues[i])
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        } else {
                            Text(row[safe: i] ?? "NULL")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if editMode {
                Section {
                    Button("保存修改") { saveChanges() }
                        .foregroundColor(.blue)
                    Button("取消") { editMode = false }
                        .foregroundColor(.red)
                }
            }

            Section("操作") {
                if !editMode {
                    Button("编辑") { enterEditMode() }
                }
                Button("删除此行", role: .destructive) { deleteRow() }
            }
        }
        .navigationTitle("第 \(rowIndex + 1) 行")
    }

    private func enterEditMode() {
        editValues = row
        editMode = true
    }

    private func saveChanges() {
        guard let db = dbPointer, let rowid = row.first else {
            message = "保存失败"
            return
        }
        var setClauses: [String] = []
        for i in 0..<columns.count {
            if i < editValues.count, editValues[i] != row[safe: i] {
                setClauses.append("\"\(columns[i)]\" = '\(editValues[i].replacingOccurrences(of: "'", with: "''"))'")
            }
        }
        if setClauses.isEmpty {
            message = "没有修改"
            editMode = false
            return
        }
        let sql = "UPDATE \"\(tableName)\" SET \(setClauses.joined(separator: ", ")) WHERE rowid = \(rowid)"
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) == SQLITE_OK {
            message = "已保存"
            editMode = false
        } else {
            message = "保存失败: \(errMsg.map { String(cString: $0) } ?? "")"
        }
    }

    private func deleteRow() {
        guard let db = dbPointer, let rowid = row.first else { return }
        let sql = "DELETE FROM \"\(tableName)\" WHERE rowid = \(rowid)"
        if sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK {
            message = "已删除"
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
