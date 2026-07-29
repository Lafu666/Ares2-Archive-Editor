import SwiftUI

/// 数据库树形结构视图
///
/// 以折叠列表的形式展示数据库及其所有表。
/// 点击表节点可将其加载到表格编辑器中。
struct DatabaseTreeView: View {

    @ObservedObject var viewModel: AppViewModel

    /// 展开的节点 ID 集合
    @State private var expandedNodeIds: Set<UUID> = []

    var body: some View {
        List {
            ForEach(viewModel.databaseTree) { node in
                nodeView(node, level: 0)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("数据库表")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 默认展开所有可展开节点
            for node in viewModel.databaseTree {
                if node.isExpandable {
                    expandedNodeIds.insert(node.id)
                }
            }
        }
    }

    // MARK: - 节点视图

    @ViewBuilder
    private func nodeView(_ node: TreeNode, level: Int) -> some View {
        if node.isExpandable {
            // 数据库 / 文件夹节点 - 使用 DisclosureGroup
            DisclosureGroup(isExpanded: Binding(
                get: { expandedNodeIds.contains(node.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedNodeIds.insert(node.id)
                    } else {
                        expandedNodeIds.remove(node.id)
                    }
                }
            )) {
                ForEach(node.children) { child in
                    nodeView(child, level: level + 1)
                }
            } label: {
                Label {
                    Text(node.name)
                } icon: {
                    Image(systemName: node.type == .database ? "cylinder" : "folder")
                        .foregroundStyle(.tint)
                }
            }
        } else {
            // 表节点 - 点击加载
            Button {
                viewModel.loadTable(node.rawName)
            } label: {
                HStack {
                    Image(systemName: "tablecells")
                        .foregroundStyle(.tint)
                    Text(node.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    if viewModel.databaseManager.currentTable == node.rawName {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        DatabaseTreeView(viewModel: AppViewModel())
    }
}
