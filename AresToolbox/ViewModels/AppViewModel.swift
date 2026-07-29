import Foundation
import SwiftUI

/// 应用主视图模型
///
/// 管理整个应用的状态，包括存档处理、数据库操作、表格编辑、搜索、导出等功能。
/// 所有 UI 状态变更都在主线程（@MainActor）上执行。
@MainActor
final class AppViewModel: ObservableObject {

    // MARK: - 应用状态枚举

    /// 应用当前所处的主要界面状态
    enum AppState: Equatable {
        case mainMenu       ///< 主菜单
        case fileBrowser    ///< 文件浏览/选择
        case processing     ///< 处理中（显示进度）
        case tableEditor    ///< 表格编辑器
        case normalEdit     ///< 常规编辑选项
    }

    // MARK: - 核心管理器

    /// 文件处理器（解压、解密、加密、打包）
    let fileProcessor = FileProcessor()

    /// 数据库管理器（SQLite 操作）
    let databaseManager = DatabaseManager()

    // MARK: - 应用状态

    /// 当前界面状态
    @Published var state: AppState = .mainMenu

    /// 是否正在处理（用于显示进度浮层）
    @Published var isProcessing = false

    /// 进度值 (0-100)
    @Published var progress: Int = 0

    /// 进度描述文字
    @Published var progressMessage: String = ""

    // MARK: - 数据库树

    /// 数据库表的树形结构
    @Published var databaseTree: [TreeNode] = []

    // MARK: - 表格编辑

    /// 当前表的列名
    @Published var currentTableColumns: [String] = []

    /// 当前表的行数据
    @Published var currentTableRows: [DatabaseManager.TableRow] = []

    /// 待保存的单元格编辑（位置 → 新值）
    @Published var editedCells: [CellPosition: String] = [:]

    /// 选中的行索引集合
    @Published var selectedRows: Set<Int> = []

    // MARK: - 搜索

    /// 是否显示搜索界面
    @Published var showSearch = false

    /// 搜索结果
    @Published var searchResults: [SearchResultItem] = []

    /// 是否正在搜索
    @Published var isSearching = false

    /// 搜索进度文字
    @Published var searchProgressText = ""

    // MARK: - 编辑选项

    /// 是否显示编辑选项面板
    @Published var showEditOptions = false

    // MARK: - 提示与弹窗

    /// 是否显示错误/提示弹窗
    @Published var showError = false

    /// 错误/提示消息
    @Published var errorMessage = ""

    /// 是否显示"代码查询"提示
    @Published var showCodeQueryAlert = false

    /// 是否显示导出成功弹窗
    @Published var showExportSuccess = false

    /// 导出的文件路径
    @Published var exportedFilePath = ""

    // MARK: - 最近文件

    /// 最近访问的文件名列表
    @Published var recentFiles: [String] = []

    // MARK: - 文档目录

    /// 应用文档目录（用于存放临时文件和导出文件）
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - 选择存档文件

    /// 选择并处理存档文件
    ///
    /// 将选中的 ZIP 文件复制到文档目录，然后进行解压和解密，
    /// 打开数据库并加载所有表结构，最后切换到表格编辑界面。
    func selectArchive(at url: URL) {
        let fileName = url.lastPathComponent
        if !recentFiles.contains(fileName) {
            recentFiles.insert(fileName, at: 0)
            if recentFiles.count > 10 {
                recentFiles.removeLast()
            }
        }

        state = .processing
        isProcessing = true
        progress = 0
        progressMessage = "开始处理存档..."

        // 复制文件到文档目录以确保后续访问权限
        let copiedPath = documentsDirectory.appendingPathComponent("input_save.zip")
        do {
            if FileManager.default.fileExists(atPath: copiedPath.path) {
                try FileManager.default.removeItem(at: copiedPath)
            }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            try FileManager.default.copyItem(at: url, to: copiedPath)
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        } catch {
            isProcessing = false
            state = .mainMenu
            errorMessage = "无法访问文件: \(error.localizedDescription)"
            showError = true
            return
        }

        fileProcessor.processFile(
            inputPath: copiedPath,
            outputDir: documentsDirectory,
            progress: { [weak self] p, msg in
                self?.progress = p
                self?.progressMessage = msg
            },
            completion: { [weak self] success, message in
                guard let self = self else { return }
                if success, let dbPath = self.fileProcessor.decryptedDbPath {
                    let opened = self.databaseManager.openDatabase(at: dbPath.path)
                    if opened {
                        self.progress = 80
                        self.progressMessage = "正在加载数据库结构..."
                        self.databaseManager.initializeDatabase { [weak self] in
                            guard let self = self else { return }
                            self.progress = 100
                            self.progressMessage = "加载完成"
                            self.buildDatabaseTree()
                            self.isProcessing = false
                            self.state = .tableEditor
                        }
                    } else {
                        self.isProcessing = false
                        self.state = .mainMenu
                        self.errorMessage = "打开数据库失败"
                        self.showError = true
                    }
                } else {
                    self.isProcessing = false
                    self.state = .mainMenu
                    self.errorMessage = message
                    self.showError = true
                }
            }
        )
    }

    // MARK: - 构建数据库树

    /// 根据数据库表名构建树形结构
    func buildDatabaseTree() {
        var tree: [TreeNode] = []

        var dbNode = TreeNode(
            name: "GameWorld.db",
            rawName: "GameWorld.db",
            type: .database,
            isExpanded: true
        )

        var children: [TreeNode] = []
        for table in databaseManager.tableNames {
            // 跳过系统表
            if table.hasPrefix("sqlite_") || table == "android_metadata" { continue }

            let count = databaseManager.getRowCount(table)
            let tableNode = TreeNode(
                name: "\(table) (\(count))",
                rawName: table,
                type: .table
            )
            children.append(tableNode)
        }
        dbNode.children = children
        tree.append(dbNode)
        databaseTree = tree
    }

    // MARK: - 加载表数据

    /// 加载指定表的数据到编辑器
    func loadTable(_ tableName: String) {
        databaseManager.currentTable = tableName
        currentTableColumns = databaseManager.tableColumns[tableName] ?? []
        currentTableRows = databaseManager.loadTableData(tableName)
        editedCells.removeAll()
        selectedRows.removeAll()
    }

    // MARK: - 保存编辑

    /// 将所有待保存的单元格编辑写入数据库
    func saveEdits() {
        guard let table = databaseManager.currentTable else {
            errorMessage = "没有选中的表"
            showError = true
            return
        }

        guard !editedCells.isEmpty else {
            errorMessage = "没有需要保存的修改"
            showError = true
            return
        }

        var edits: [(rowId: Int64, column: String, value: String)] = []
        for (position, value) in editedCells {
            if position.row < currentTableRows.count, position.col < currentTableColumns.count {
                let rowId = currentTableRows[position.row].rowId
                let column = currentTableColumns[position.col]
                edits.append((rowId: rowId, column: column, value: value))
            }
        }

        let count = databaseManager.saveChanges(in: table, edits: edits)
        editedCells.removeAll()
        currentTableRows = databaseManager.loadTableData(table)

        if count > 0 {
            errorMessage = "成功保存 \(count) 处修改"
        } else {
            errorMessage = "保存失败，请检查数据是否有效"
        }
        showError = true
    }

    // MARK: - 添加行

    /// 向当前表添加指定数量的空行
    func addRows(_ count: Int) {
        guard let table = databaseManager.currentTable else {
            errorMessage = "没有选中的表"
            showError = true
            return
        }
        let added = databaseManager.addRows(to: table, count: count)
        currentTableRows = databaseManager.loadTableData(table)
        errorMessage = "成功添加 \(added) 行"
        showError = true
    }

    // MARK: - 删除行

    /// 删除指定行索引集合对应的行
    func deleteRows(_ rowIndices: Set<Int>) {
        guard let table = databaseManager.currentTable, !rowIndices.isEmpty else {
            errorMessage = "请先选择要删除的行"
            showError = true
            return
        }

        var deletedCount = 0
        for index in rowIndices {
            if index < currentTableRows.count {
                let rowId = currentTableRows[index].rowId
                if databaseManager.deleteRow(in: table, rowId: rowId) {
                    deletedCount += 1
                }
            }
        }
        currentTableRows = databaseManager.loadTableData(table)
        selectedRows.removeAll()
        editedCells.removeAll()
        errorMessage = "成功删除 \(deletedCount) 行"
        showError = true
    }

    // MARK: - 搜索

    /// 在所有表中搜索包含关键词的数据
    func search(_ keyword: String) {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchProgressText = "正在搜索..."
        searchResults = []

        databaseManager.searchAllTables(
            keyword: keyword,
            onProgress: { [weak self] table, count in
                self?.searchProgressText = "正在搜索: \(table)（已找到 \(count) 条）"
            },
            completion: { [weak self] results in
                guard let self = self else { return }
                self.searchResults = results.map {
                    SearchResultItem(
                        tableName: $0.tableName,
                        rowId: $0.rowId,
                        columnName: $0.columnName,
                        matchedText: $0.matchedText,
                        rowPosition: $0.rowPosition,
                        columnIndex: $0.columnIndex
                    )
                }
                self.isSearching = false
                self.searchProgressText = "搜索完成，共找到 \(self.searchResults.count) 条结果"
            }
        )
    }

    // MARK: - 导出存档

    /// 将修改后的数据库重新加密并打包为 ZIP 文件
    func exportSave() {
        guard let zipPath = fileProcessor.originalZipPath,
              let dbPath = fileProcessor.decryptedDbPath else {
            errorMessage = "没有可导出的存档"
            showError = true
            return
        }

        isProcessing = true
        progress = 0
        progressMessage = "开始导出存档..."

        let userFolderName = databaseManager.getUserId() ?? "AresToolboxExport"

        fileProcessor.processFileForExport(
            inputPath: zipPath,
            outputDir: documentsDirectory,
            currentDbPath: dbPath,
            userFolderName: userFolderName,
            progress: { [weak self] p, msg in
                self?.progress = p
                self?.progressMessage = msg
            },
            completion: { [weak self] success, result in
                guard let self = self else { return }

                if success {
                    // result 为临时目录路径
                    let tempDir = URL(fileURLWithPath: result)
                    let outputPath = self.documentsDirectory
                        .appendingPathComponent("\(userFolderName)_export.zip")

                    // 更新 MD5 标记文件
                    if let md5 = self.fileProcessor.calculateMD5(at: dbPath) {
                        self.fileProcessor.updateMd5File(md5, rootDir: tempDir)
                    }

                    self.fileProcessor.finishExport(
                        tempDir: tempDir,
                        outputPath: outputPath,
                        progress: { [weak self] p, msg in
                            self?.progress = p
                            self?.progressMessage = msg
                        },
                        completion: { [weak self] exportSuccess, exportMessage in
                            guard let self = self else { return }
                            self.isProcessing = false
                            if exportSuccess {
                                self.exportedFilePath = exportMessage
                                self.showExportSuccess = true
                            } else {
                                self.errorMessage = exportMessage
                                self.showError = true
                            }
                        }
                    )
                } else {
                    self.isProcessing = false
                    self.errorMessage = result
                    self.showError = true
                }
            }
        )
    }

    // MARK: - 全选 / 取消全选

    /// 切换全选状态
    func toggleSelectAll() {
        if selectedRows.count == currentTableRows.count && !currentTableRows.isEmpty {
            selectedRows.removeAll()
        } else {
            selectedRows = Set(0..<currentTableRows.count)
        }
    }

    // MARK: - 返回主菜单

    /// 清理资源并返回主菜单
    func goToMainMenu() {
        databaseManager.closeDatabase()
        fileProcessor.cleanup()
        databaseTree = []
        currentTableColumns = []
        currentTableRows = []
        editedCells.removeAll()
        selectedRows.removeAll()
        searchResults = []
        showSearch = false
        showEditOptions = false
        state = .mainMenu
    }
}

