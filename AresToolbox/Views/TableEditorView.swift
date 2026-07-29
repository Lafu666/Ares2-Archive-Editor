import SwiftUI

/// 表格编辑器视图
///
/// 以电子表格形式展示当前选中表的数据，支持单元格编辑、
/// 行选择、添加行、删除行、保存、搜索等功能。
struct TableEditorView: View {

    @ObservedObject var viewModel: AppViewModel

    // MARK: - 本地状态

    /// 是否显示数据库树面板
    @State private var showDatabaseTree = false

    /// 是否显示添加行对话框
    @State private var showAddRowsDialog = false

    /// 要添加的行数
    @State private var addRowCount = 1

    /// 正在编辑的单元格数据
    @State private var editingCellData: EditingCellData?

    // MARK: - 常量

    /// 行号列宽度
    private let rowNumberColumnWidth: CGFloat = 56
    /// 单元格最小宽度
    private let cellMinWidth: CGFloat = 120
    /// 单元格高度
    private let cellHeight: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            if let _ = viewModel.databaseManager.currentTable {
                if viewModel.currentTableColumns.isEmpty {
                    noColumnsView
                } else if viewModel.currentTableRows.isEmpty {
                    noDataView
                } else {
                    tableGrid
                }
            } else {
                noTableSelectedView
            }
        }
        .navigationTitle(viewModel.databaseManager.currentTable ?? "表格编辑器")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showDatabaseTree) {
            NavigationStack {
                DatabaseTreeView(viewModel: viewModel)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { showDatabaseTree = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $viewModel.showEditOptions) {
            EditOptionsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSearch) {
            SearchView(viewModel: viewModel)
        }
        .sheet(isPresented: $showAddRowsDialog) {
            addRowsDialog
        }
        .sheet(item: $editingCellData) { data in
            cellEditSheet(data: data)
        }
        .onAppear {
            // 首次进入时自动弹出数据库树
            if viewModel.databaseManager.currentTable == nil {
                showDatabaseTree = true
            }
        }
    }

    // MARK: - 表格网格

    private var tableGrid: some View {
        VStack(spacing: 0) {
            // 编辑状态栏
            editStatusBar

            // 表格内容
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    // 表头
                    headerRow

                    Divider()
                        .frame(height: 2)

                    // 数据行
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<viewModel.currentTableRows.count, id: \.self) { rowIndex in
                            dataRow(rowIndex: rowIndex, row: viewModel.currentTableRows[rowIndex])
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - 编辑状态栏

    private var editStatusBar: some View {
        HStack(spacing: 12) {
            if !viewModel.editedCells.isEmpty {
                Label("\(viewModel.editedCells.count) 处未保存", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if !viewModel.selectedRows.isEmpty {
                Label("已选 \(viewModel.selectedRows.count) 行", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            Spacer()
            Label("\(viewModel.currentTableRows.count) 行", systemImage: "tablecells")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.08))
    }

    // MARK: - 表头行

    private var headerRow: some View {
        HStack(spacing: 0) {
            // 行号列表头
            Text("#")
                .font(.caption.bold())
                .frame(width: rowNumberColumnWidth, height: cellHeight)
                .background(Color.gray.opacity(0.25))

            ForEach(viewModel.currentTableColumns, id: \.self) { column in
                Text(column)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .frame(minWidth: cellMinWidth, height: cellHeight, alignment: .leading)
                    .padding(.horizontal, 4)
                    .background(Color.gray.opacity(0.25))

                Divider()
                    .frame(width: 1)
                    .background(Color.gray.opacity(0.3))
            }
        }
    }

    // MARK: - 数据行

    private func dataRow(rowIndex: Int, row: DatabaseManager.TableRow) -> some View {
        let isSelected = viewModel.selectedRows.contains(rowIndex)

        return HStack(spacing: 0) {
            // 行号 + 选择框
            HStack(spacing: 2) {
                Text("\(rowIndex + 1)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .tint : .secondary)
            }
            .frame(width: rowNumberColumnWidth, height: cellHeight)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.selectedRows.contains(rowIndex) {
                    viewModel.selectedRows.remove(rowIndex)
                } else {
                    viewModel.selectedRows.insert(rowIndex)
                }
            }

            // 数据单元格
            ForEach(0..<row.values.count, id: \.self) { colIndex in
                let value = row.values[colIndex]
                let position = CellPosition(row: rowIndex, col: colIndex)
                let editedValue = viewModel.editedCells[position]

                cellView(
                    position: position,
                    displayValue: editedValue ?? value,
                    isEdited: editedValue != nil
                )

                Divider()
                    .frame(width: 1)
                    .background(Color.gray.opacity(0.2))
            }
        }
        .background(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
    }

    // MARK: - 单元格

    private func cellView(
        position: CellPosition,
        displayValue: String,
        isEdited: Bool
    ) -> some View {
        Text(displayValue.isEmpty ? "（空）" : displayValue)
            .font(.caption)
            .foregroundStyle(displayValue.isEmpty ? .secondary : .primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(minWidth: cellMinWidth, height: cellHeight, alignment: .leading)
            .padding(.horizontal, 4)
            .background(isEdited ? Color.yellow.opacity(0.3) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                editingCellData = EditingCellData(
                    position: position,
                    value: displayValue
                )
            }
    }

    // MARK: - 空状态视图

    private var noTableSelectedView: some View {
        ContentUnavailableView {
            Label("未选择表", systemImage: "tablecells")
        } description: {
            Text("请从数据库树中选择一个表进行编辑")
        } actions: {
            Button("选择表") {
                showDatabaseTree = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var noColumnsView: some View {
        ContentUnavailableView(
            "表没有可显示的列",
            systemImage: "tablecells.badge.ellipsis",
            description: Text("该表不包含可显示的列数据")
        )
    }

    private var noDataView: some View {
        ContentUnavailableView {
            Label("表没有数据", systemImage: "tray")
        } description: {
            Text("该表当前没有任何行数据")
        } actions: {
            Button("添加行") {
                showAddRowsDialog = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 添加行对话框

    private var addRowsDialog: some View {
        NavigationStack {
            Form {
                Section("添加空行") {
                    Stepper("行数: \(addRowCount)", value: $addRowCount, in: 1...100)
                }
                Section {
                    Text("将在当前表的末尾添加 \(addRowCount) 行空数据。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("添加行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAddRowsDialog = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        viewModel.addRows(addRowCount)
                        showAddRowsDialog = false
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - 单元格编辑面板

    private func cellEditSheet(data: EditingCellData) -> some View {
        NavigationStack {
            Form {
                Section("单元格信息") {
                    if data.position.col < viewModel.currentTableColumns.count {
                        LabeledContent("列名") {
                            Text(viewModel.currentTableColumns[data.position.col])
                                .foregroundStyle(.secondary)
                        }
                    }
                    if data.position.row < viewModel.currentTableRows.count {
                        LabeledContent("行 ID") {
                            Text("\(viewModel.currentTableRows[data.position.row].rowId)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("行号") {
                        Text("#\(data.position.row + 1)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("编辑值") {
                    TextField(
                        "输入新值",
                        text: Binding(
                            get: { editingCellData?.value ?? "" },
                            set: { editingCellData?.value = $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .autocorrectionDisabled()
                }
            }
            .navigationTitle("编辑单元格")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        editingCellData = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let data = editingCellData {
                            viewModel.editedCells[data.position] = data.value
                        }
                        editingCellData = nil
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            menuButton
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            // 保存
            Button {
                viewModel.saveEdits()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .disabled(viewModel.editedCells.isEmpty)

            // 添加行
            Button {
                showAddRowsDialog = true
            } label: {
                Image(systemName: "plus")
            }

            // 删除选中行
            Button {
                viewModel.deleteRows(viewModel.selectedRows)
            } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.selectedRows.isEmpty)

            // 全选
            Button {
                viewModel.toggleSelectAll()
            } label: {
                Image(systemName: "checklist")
            }

            // 搜索
            Button {
                viewModel.showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
        }
    }

    // MARK: - 菜单按钮

    private var menuButton: some View {
        Menu {
            Button {
                showDatabaseTree = true
            } label: {
                Label("数据库表", systemImage: "list.bullet")
            }

            Button {
                viewModel.showEditOptions = true
            } label: {
                Label("编辑选项", systemImage: "slider.horizontal.3")
            }

            Button {
                viewModel.exportSave()
            } label: {
                Label("导出存档", systemImage: "square.and.arrow.up")
            }

            Divider()

            Button(role: .destructive) {
                viewModel.goToMainMenu()
            } label: {
                Label("返回主菜单", systemImage: "house")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
        }
    }
}

// MARK: - 编辑单元格数据

/// 用于 sheet(item:) 的单元格编辑数据包装
private struct EditingCellData: Identifiable {
    let id = UUID()
    let position: CellPosition
    var value: String
}

#Preview {
    NavigationStack {
        TableEditorView(viewModel: AppViewModel())
    }
}
