import Foundation

// MARK: - 树形目录节点

/// 数据库树形目录节点
struct TreeNode: Identifiable {
    let id = UUID()
    let name: String      // 显示名称
    let rawName: String   // 原始名称（表名）
    let type: NodeType
    var isExpanded: Bool = false
    var children: [TreeNode] = []

    enum NodeType {
        case root
        case database
        case table
        case folder
    }

    var isExpandable: Bool {
        type == .root || type == .database || type == .folder
    }

    var isTable: Bool { type == .table }
}

// MARK: - 游戏数据模型

/// 工人信息
struct WorkerInfo: Identifiable, Hashable {
    let id = UUID()
    let workerId: Int64
    let name: String
    var isSelected: Bool = false
}

/// 地图信息
struct MapInfo: Identifiable, Hashable {
    let id = UUID()
    let sceneId: Int
    let name: String
    var arrival: Bool = false
    var owned: Bool = false
    var refreshTime: Int64 = 0
}

/// 天赋信息
struct TalentInfo: Identifiable, Hashable {
    let id = UUID()
    let talentId: Int
    var level: Int
    var description: String
}

/// 家具信息
struct FurnitureInfo: Identifiable, Hashable {
    let id = UUID()
    let furnitureId: Int
    let name: String
    var count: Int
}

/// 物品信息
struct ItemInfo: Identifiable, Hashable {
    let id = UUID()
    let itemId: String
    let name: String
    var quantity: Int64
}

/// 编辑单元格位置
struct CellPosition: Hashable {
    let row: Int
    let col: Int
}

/// 编辑历史记录
struct EditHistory: Identifiable {
    let id = UUID()
    let cellPosition: CellPosition
    let oldValue: String
    let newValue: String
}

/// 搜索结果项（UI用）
struct SearchResultItem: Identifiable {
    let id = UUID()
    let tableName: String
    let rowId: Int64
    let columnName: String
    let matchedText: String
    let rowPosition: Int
    let columnIndex: Int
}
