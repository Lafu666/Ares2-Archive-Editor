import SwiftUI

/// 搜索视图
///
/// 提供搜索栏和搜索结果列表。
/// 点击搜索结果可跳转到对应的表。
struct SearchView: View {

    @ObservedObject var viewModel: AppViewModel

    /// 搜索输入文字
    @State private var searchText = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar

                Divider()

                // 内容区域
                if viewModel.isSearching {
                    searchingContent
                } else if viewModel.searchResults.isEmpty {
                    emptyContent
                } else {
                    resultsList
                }
            }
            .navigationTitle("全局搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        viewModel.showSearch = false
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("输入搜索关键词", text: $searchText, onCommit: {
                viewModel.search(searchText)
            })
            .submitLabel(.search)
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    viewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if !searchText.isEmpty {
                Button("搜索") {
                    viewModel.search(searchText)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
        .padding()
    }

    // MARK: - 搜索中

    private var searchingContent: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text(viewModel.searchProgressText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - 空状态

    @ViewBuilder
    private var emptyContent: some View {
        if searchText.isEmpty {
            ContentUnavailableView(
                "搜索数据库",
                systemImage: "magnifyingglass",
                description: Text("输入关键词搜索所有表中的数据")
            )
        } else {
            ContentUnavailableView(
                "没有找到结果",
                systemImage: "text.magnifyingglass",
                description: Text("没有找到包含「\(searchText)」的内容")
            )
        }
    }

    // MARK: - 结果列表

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("共 \(viewModel.searchResults.count) 条结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            List(viewModel.searchResults) { result in
                Button {
                    viewModel.loadTable(result.tableName)
                    viewModel.showSearch = false
                    dismiss()
                } label: {
                    resultRow(result)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func resultRow(_ result: SearchResultItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(result.tableName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.tint)

                Text("·")
                    .foregroundStyle(.secondary)

                Text(result.columnName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("行 #\(result.rowPosition + 1)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(result.matchedText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SearchView(viewModel: AppViewModel())
}
