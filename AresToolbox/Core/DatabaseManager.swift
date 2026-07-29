import Foundation
import SQLite3

/// SQLite 数据库操作管理器
///
/// 基于 SQLite3 C API 封装，提供表结构查询、数据加载、增删改查、搜索等功能。
/// 所有数据库操作在后台线程执行，通过回调返回主线程。
final class DatabaseManager {

    // MARK: - 公开属性

    /// 当前数据库路径
    private(set) var databasePath: String?

    /// 所有表名
    private(set) var tableNames: [String] = []

    /// 表名 → 列名列表
    private(set) var tableColumns: [String: [String]] = [:]

    /// 表名 → 非空列名列表
    private(set) var notNullColumns: [String: [String]] = [:]

    /// 当前选中的表
    var currentTable: String?

    // MARK: - 私有属性

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.ares.db", qos: .userInitiated)

    // MARK: - 搜索结果

    struct SearchResult: Identifiable {
        let id = UUID()
        let tableName: String
        let rowId: Int64
        let columnName: String
        let matchedText: String
        let rowPosition: Int
        let columnIndex: Int
    }

    // MARK: - 打开/关闭

    /// 打开数据库
    func openDatabase(at path: String) -> Bool {
        self.databasePath = path
        let result = sqlite3_open(path, &db)
        if result != SQLITE_OK {
            sqlite3_close(db)
            db = nil
            return false
        }
        return true
    }

    /// 关闭数据库
    func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
        tableNames.removeAll()
        tableColumns.removeAll()
        notNullColumns.removeAll()
        currentTable = nil
    }

    // MARK: - 表结构查询

    /// 加载所有表名
    func loadAllTableNames() {
        tableNames.removeAll()
        guard let db = db else { return }

        var stmt: OpaquePointer?
        let query = "SELECT name FROM sqlite_master WHERE type='table'"
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cName = sqlite3_column_text(stmt, 0) {
                    tableNames.append(String(cString: cName))
                }
            }
        }
        sqlite3_finalize(stmt)
    }

    /// 加载表的列信息（排除 BLOB 类型）
    func loadTableColumnInfo(_ tableName: String) {
        guard let db = db else { return }
        var columns: [String] = []
        var stmt: OpaquePointer?
        let query = "PRAGMA table_info(\(tableName))"

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cName = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: cName)
                    let cType = sqlite3_column_text(stmt, 2)
                    let type = cType != nil ? String(cString: cType!) : ""
                    if !"BLOB".equalsIgnoreCase(type) {
                        columns.append(name)
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        tableColumns[tableName] = columns
    }

    /// 加载非空约束列
    func loadNotNullColumns(_ tableName: String) {
        guard let db = db else { return }
        var notNulls: [String] = []
        var stmt: OpaquePointer?
        let query = "PRAGMA table_info(\(tableName))"

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let notNull = sqlite3_column_int(stmt, 3) // notnull 字段
                if notNull == 1 {
                    if let cName = sqlite3_column_text(stmt, 1) {
                        notNulls.append(String(cString: cName))
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        notNullColumns[tableName] = notNulls
    }

    // MARK: - 数据加载

    /// 表格行数据
    struct TableRow {
        let rowId: Int64
        let values: [String]
    }

    /// 加载表数据
    func loadTableData(_ tableName: String) -> [TableRow] {
        guard let db = db, let columns = tableColumns[tableName], !columns.isEmpty else {
            return []
        }

        var colList = "rowid"
        for col in columns {
            colList += ", \(col)"
        }
        let query = "SELECT \(colList) FROM \(tableName) ORDER BY rowid"

        var rows: [TableRow] = []
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            let colCount = Int32(columns.count + 1) // +1 for rowid

            while sqlite3_step(stmt) == SQLITE_ROW {
                let rowId = sqlite3_column_int64(stmt, 0)
                var values: [String] = []

                for i in 1..<colCount {
                    let value = columnString(stmt, index: i)
                    values.append(value)
                }
                rows.append(TableRow(rowId: rowId, values: values))
            }
        }
        sqlite3_finalize(stmt)
        return rows
    }

    /// 初始化数据库：加载所有表结构
    func initializeDatabase(completion: @escaping () -> Void) {
        queue.async {
            self.loadAllTableNames()
            for table in self.tableNames {
                self.loadTableColumnInfo(table)
                self.loadNotNullColumns(table)
            }
            DispatchQueue.main.async { completion() }
        }
    }

    // MARK: - 增删改

    /// 插入行
    func insertRow(into tableName: String, values: [String?]) -> Int64 {
        guard let db = db, let columns = tableColumns[tableName] else { return -1 }
        guard columns.count == values.count else { return -1 }

        var placeholders = ""
        for (i, _) in columns.enumerated() {
            placeholders += i == 0 ? "?" : ", ?"
        }
        let query = "INSERT INTO \(tableName) VALUES (\(placeholders))"

        var stmt: OpaquePointer?
        var rowId: Int64 = -1

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            for (i, value) in values.enumerated() {
                if let v = value {
                    sqlite3_bind_text(stmt, Int32(i + 1), v, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, Int32(i + 1))
                }
            }
            if sqlite3_step(stmt) == SQLITE_DONE {
                rowId = sqlite3_last_insert_rowid(db)
            }
        }
        sqlite3_finalize(stmt)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        return rowId
    }

    /// 添加多行（使用默认值）
    func addRows(to tableName: String, count: Int) -> Int {
        guard let db = db, let columns = tableColumns[tableName] else { return 0 }

        var placeholders = ""
        for (i, _) in columns.enumerated() {
            placeholders += i == 0 ? "?" : ", ?"
        }
        let query = "INSERT INTO \(tableName) VALUES (\(placeholders))"

        var stmt: OpaquePointer?
        var successCount = 0

        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            let notNulls = notNullColumns[tableName] ?? []

            for _ in 0..<count {
                for (i, col) in columns.enumerated() {
                    if notNulls.contains(col) {
                        // 非空列设置默认值
                        sqlite3_bind_text(stmt, Int32(i + 1), "", -1, nil)
                    } else {
                        sqlite3_bind_null(stmt, Int32(i + 1))
                    }
                }
                if sqlite3_step(stmt) == SQLITE_DONE {
                    successCount += 1
                }
                sqlite3_reset(stmt)
            }
        }
        sqlite3_finalize(stmt)
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        return successCount
    }

    /// 删除最后 N 行
    func deleteLastRows(from tableName: String, count: Int) -> Int {
        guard let db = db else { return 0 }

        // 获取行数
        var totalRows = 0
        var countStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(tableName)", -1, &countStmt, nil) == SQLITE_OK {
            if sqlite3_step(countStmt) == SQLITE_ROW {
                totalRows = Int(sqlite3_column_int(countStmt, 0))
            }
        }
        sqlite3_finalize(countStmt)

        if count > totalRows { return 0 }

        // 获取要删除的 rowid
        var rowIds: [Int64] = []
        var selectStmt: OpaquePointer?
        let selectQuery = "SELECT rowid FROM \(tableName) ORDER BY rowid DESC LIMIT \(count)"
        if sqlite3_prepare_v2(db, selectQuery, -1, &selectStmt, nil) == SQLITE_OK {
            while sqlite3_step(selectStmt) == SQLITE_ROW {
                rowIds.append(sqlite3_column_int64(selectStmt, 0))
            }
        }
        sqlite3_finalize(selectStmt)

        // 执行删除
        var deletedCount = 0
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        for rowId in rowIds {
            let deleteQuery = "DELETE FROM \(tableName) WHERE rowid = \(rowId)"
            if sqlite3_exec(db, deleteQuery, nil, nil, nil) == SQLITE_OK {
                deletedCount += 1
            }
        }
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        return deletedCount
    }

    /// 按 rowid 删除行
    func deleteRow(in tableName: String, rowId: Int64) -> Bool {
        guard let db = db else { return false }
        let query = "DELETE FROM \(tableName) WHERE rowid = \(rowId)"
        return sqlite3_exec(db, query, nil, nil, nil) == SQLITE_OK
    }

    /// 更新单元格
    func updateCell(in tableName: String, rowId: Int64, column: String, value: String) -> Bool {
        guard let db = db else { return false }
        let query = "UPDATE \(tableName) SET \(column) = ? WHERE rowid = ?"
        var stmt: OpaquePointer?
        var success = false

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, value, -1, nil)
            sqlite3_bind_int64(stmt, 2, rowId)
            success = sqlite3_step(stmt) == SQLITE_DONE
        }
        sqlite3_finalize(stmt)
        return success
    }

    /// 批量保存编辑的单元格
    func saveChanges(in tableName: String, edits: [(rowId: Int64, column: String, value: String)]) -> Int {
        guard let db = db else { return 0 }

        var updateCount = 0
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)

        for edit in edits {
            let query = "UPDATE \(tableName) SET \(edit.column) = ? WHERE rowid = ?"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, edit.value, -1, nil)
                sqlite3_bind_int64(stmt, 2, edit.rowId)
                if sqlite3_step(stmt) == SQLITE_DONE {
                    updateCount += 1
                }
            }
            sqlite3_finalize(stmt)
        }

        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        return updateCount
    }

    // MARK: - 搜索

    /// 全局搜索所有表
    func searchAllTables(keyword: String,
                          onProgress: @escaping (String, Int) -> Void,
                          completion: @escaping ([SearchResult]) -> Void) {
        queue.async {
            var results: [SearchResult] = []

            for table in self.tableNames {
                if table.hasPrefix("sqlite_") || table == "android_metadata" { continue }

                guard let columns = self.tableColumns[table], !columns.isEmpty else { continue }

                DispatchQueue.main.async { onProgress(table, results.count) }

                guard let db = self.db else { continue }
                var colList = "rowid"
                for col in columns { colList += ", \(col)" }
                let query = "SELECT \(colList) FROM \(table) ORDER BY rowid"
                var stmt: OpaquePointer?

                if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                    var rowPosition = 0
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        let rowId = sqlite3_column_int64(stmt, 0)
                        for (col, column) in columns.enumerated() {
                            let value = self.columnString(stmt, index: Int32(col + 1))
                            if value.lowercased().contains(keyword.lowercased()) {
                                results.append(SearchResult(
                                    tableName: table,
                                    rowId: rowId,
                                    columnName: column,
                                    matchedText: value,
                                    rowPosition: rowPosition,
                                    columnIndex: col
                                ))
                            }
                        }
                        rowPosition += 1
                    }
                }
                sqlite3_finalize(stmt)
            }

            DispatchQueue.main.async { completion(results) }
        }
    }

    // MARK: - 辅助

    /// 获取 UserID
    func getUserId() -> String? {
        guard let db = db else { return nil }
        var stmt: OpaquePointer?
        var userId: String?

        if sqlite3_prepare_v2(db, "SELECT UserID FROM DBData LIMIT 1", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let cText = sqlite3_column_text(stmt, 0) {
                    userId = String(cString: cText)
                }
            }
        }
        sqlite3_finalize(stmt)
        return userId
    }

    /// 获取表行数
    func getRowCount(_ tableName: String) -> Int {
        guard let db = db else { return 0 }
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(tableName)", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }

    /// 获取单行数据
    func getRowData(tableName: String, rowId: Int64) -> [String] {
        guard let db = db else { return [] }
        var values: [String] = []
        var stmt: OpaquePointer?
        let query = "SELECT * FROM \(tableName) WHERE rowid = \(rowId)"

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let colCount = sqlite3_column_count(stmt)
                for i in 0..<colCount {
                    values.append(columnString(stmt, index: i))
                }
            }
        }
        sqlite3_finalize(stmt)
        return values
    }

    /// 读取列值并转换为字符串
    private func columnString(_ stmt: OpaquePointer?, index: Int32) -> String {
        let type = sqlite3_column_type(stmt, index)
        switch type {
        case SQLITE_INTEGER:
            return String(sqlite3_column_int64(stmt, index))
        case SQLITE_FLOAT:
            return String(sqlite3_column_double(stmt, index))
        case SQLITE_TEXT:
            if let cText = sqlite3_column_text(stmt, index) {
                return String(cString: cText)
            }
            return ""
        case SQLITE_BLOB, SQLITE_NULL:
            return ""
        default:
            return ""
        }
    }

    /// 执行原始 SQL
    func executeUpdate(_ sql: String) -> Bool {
        guard let db = db else { return false }
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }
}

// MARK: - String 忽略大小写比较扩展

private extension String {
    func equalsIgnoreCase(_ other: String) -> Bool {
        return lowercased() == other.lowercased()
    }
}
