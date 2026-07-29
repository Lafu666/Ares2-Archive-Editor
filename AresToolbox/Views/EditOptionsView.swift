import SwiftUI

/// 编辑选项视图
///
/// 以网格形式展示所有快捷编辑选项（背包、雇佣、哈士奇等）。
/// 背包、工人、场景地图、天赋四个选项有实际数据展示，
/// 其余选项显示占位界面。
struct EditOptionsView: View {

    @ObservedObject var viewModel: AppViewModel

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Constants.editOptions, id: \.self) { option in
                        NavigationLink {
                            editOptionDetail(option)
                        } label: {
                            optionCard(option)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("编辑选项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        viewModel.showEditOptions = false
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 选项卡片

    private func optionCard(_ option: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: iconFor(option))
                .font(.title)
                .foregroundStyle(.tint)

            Text(option)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(14)
    }

    // MARK: - 选项详情

    @ViewBuilder
    private func editOptionDetail(_ option: String) -> some View {
        switch option {
        case "背包":
            BackpackEditorView()
        case "工人":
            WorkersEditorView()
        case "场景地图":
            MapsEditorView()
        case "天赋":
            TalentsEditorView()
        default:
            PlaceholderEditorView(title: option)
        }
    }

    // MARK: - 图标

    private func iconFor(_ option: String) -> String {
        switch option {
        case "背包":         return "bag.fill"
        case "雇佣":         return "person.badge.plus"
        case "哈士奇":       return "pawprint.fill"
        case "增益效果":     return "sparkles"
        case "当前人物坐骑": return "figure.walk"
        case "工人":         return "person.2.fill"
        case "场景地图":     return "map.fill"
        case "天赋":         return "star.fill"
        case "场景建筑":     return "building.2.fill"
        case "改造":         return "wrench.and.screwdriver.fill"
        case "家具":         return "house.fill"
        case "奖杯次数":     return "trophy.fill"
        case "研究":         return "book.fill"
        case "挑战":         return "flag.checkered"
        default:             return "square.dashed"
        }
    }
}

// MARK: - 背包编辑器

/// 背包编辑器：按分类浏览游戏物品
private struct BackpackEditorView: View {

    @State private var selectedCategory = "全部"

    var body: some View {
        VStack(spacing: 0) {
            // 分类选择器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<Constants.itemCategories.count, id: \.self) { index in
                        let category = Constants.itemCategories[index]
                        Button {
                            selectedCategory = category.key
                        } label: {
                            Text(category.displayName)
                                .font(.caption.bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    selectedCategory == category.key
                                        ? Color.accentColor
                                        : Color.gray.opacity(0.2)
                                )
                                .foregroundStyle(
                                    selectedCategory == category.key ? .white : .primary
                                )
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }

            Divider()

            // 物品列表
            let items = AssetLoaderUtil.loadCategoryItems(category: selectedCategory)
            if items.isEmpty {
                ContentUnavailableView(
                    "暂无物品",
                    systemImage: "bag",
                    description: Text("该分类下没有物品数据")
                )
            } else {
                List(items) { item in
                    HStack {
                        Text(item.itemId)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(item.name)
                        Spacer()
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("背包 - \(selectedCategory)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 工人编辑器

/// 工人编辑器：展示允许的工人列表
private struct WorkersEditorView: View {

    var body: some View {
        let workers = Constants.allowedWorkers.sorted(by: { $0.key < $1.key })

        List {
            ForEach(0..<workers.count, id: \.self) { index in
                let (id, name) = workers[index]
                HStack {
                    Text("\(id)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Text(name)
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("工人列表")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 地图编辑器

/// 地图编辑器：展示场景地图名称列表
private struct MapsEditorView: View {

    var body: some View {
        let mapNames = AssetLoaderUtil.loadMapNames()
        let sortedMaps = mapNames.sorted(by: { $0.key < $1.key })

        if sortedMaps.isEmpty {
            ContentUnavailableView(
                "暂无地图数据",
                systemImage: "map",
                description: Text("无法加载地图资源文件")
            )
        } else {
            List {
                ForEach(0..<sortedMaps.count, id: \.self) { index in
                    let (sceneId, name) = sortedMaps[index]
                    HStack {
                        Text("\(sceneId)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(name)
                        Spacer()
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("场景地图")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 天赋编辑器

/// 天赋编辑器：展示天赋技能数据
private struct TalentsEditorView: View {

    var body: some View {
        let talentData = AssetLoaderUtil.loadTalentData()
        let sortedTalents = talentData.sorted(by: { $0.key < $1.key })

        if sortedTalents.isEmpty {
            ContentUnavailableView(
                "暂无天赋数据",
                systemImage: "star",
                description: Text("无法加载天赋资源文件")
            )
        } else {
            List {
                ForEach(0..<sortedTalents.count, id: \.self) { index in
                    let (talentId, levels) = sortedTalents[index]
                    let sortedLevels = levels.sorted(by: { $0.key < $1.key })
                    Section("天赋 \(talentId)") {
                        ForEach(0..<sortedLevels.count, id: \.self) { levelIndex in
                            let (level, desc) = sortedLevels[levelIndex]
                            VStack(alignment: .leading, spacing: 2) {
                                Text("等级 \(level)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tint)
                                Text(desc)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("天赋技能")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 占位编辑器

/// 占位编辑器：功能开发中
private struct PlaceholderEditorView: View {

    let title: String

    var body: some View {
        ContentUnavailableView(
            "功能开发中",
            systemImage: "wrench.adjustable",
            description: Text("「\(title)」功能正在开发中，敬请期待")
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    EditOptionsView(viewModel: AppViewModel())
}
