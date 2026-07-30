import Foundation
import SQLite3

class DatabaseManager {
    private var db: OpaquePointer?

    func open(url: URL) -> Bool {
        close()
        let rc = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        return rc == SQLITE_OK
    }

    func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    var isOpen: Bool { db != nil }

    func getTables() -> [String] {
        guard let db = db else { return [] }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }

        var tables: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 0) {
                tables.append(String(cString: cStr))
            }
        }
        return tables
    }

    func getColumns(table: String) -> [(name: String, type: String)] {
        guard let db = db else { return [] }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        let query = "PRAGMA table_info(\"\(table)\")"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }

        var columns: [(String, String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 1),
               let tStr = sqlite3_column_text(stmt, 2) {
                columns.append((String(cString: cStr), String(cString: tStr)))
            }
        }
        return columns
    }

    func query(table: String, limit: Int = 5000) -> [[String]] {
        guard let db = db else { return [] }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        let sql = "SELECT rowid, * FROM \"\(table)\" LIMIT \(limit)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        var rows: [[String]] = []
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
            rows.append(row)
        }
        return rows
    }

    func update(table: String, column: String, value: String, rowid: String) -> Bool {
        guard let db = db else { return false }
        let escaped = value.replacingOccurrences(of: "'", with: "''")
        let sql = "UPDATE \"\(table)\" SET \"\(column)\" = '\(escaped)' WHERE rowid = \(rowid)"
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    func deleteRow(table: String, rowid: String) -> Bool {
        guard let db = db else { return false }
        let sql = "DELETE FROM \"\(table)\" WHERE rowid = \(rowid)"
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    func globalSearch(keyword: String) -> [(table: String, count: Int)] {
        guard let db = db else { return [] }
        let tables = getTables()
        var results: [(String, Int)] = []

        for table in tables {
            let columns = getColumns(table: table).map { "\"\($0.name)\"" }
            guard !columns.isEmpty else { continue }

            let likeClauses = columns.map { "\($0) LIKE '%\(keyword)%'" }.joined(separator: " OR ")
            let sql = "SELECT COUNT(*) FROM \"\(table)\" WHERE \(likeClauses)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }

            if sqlite3_step(stmt) == SQLITE_ROW, let cStr = sqlite3_column_text(stmt, 0) {
                let count = Int(String(cString: cStr)) ?? 0
                if count > 0 {
                    results.append((table, count))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
}
