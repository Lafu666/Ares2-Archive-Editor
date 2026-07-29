import Foundation

/// 从 Bundle 加载资源文件
enum AssetLoaderUtil {

    // MARK: - 分类物品

    /// 分类物品数据
    struct CategoryItem: Identifiable, Hashable {
        let id = UUID()
        let itemId: String
        let name: String
    }

    /// 从「已分类ID.txt」加载指定分类的物品列表
    static func loadCategoryItems(category: String) -> [CategoryItem] {
        var items: [CategoryItem] = []
        guard let content = loadAsset("已分类ID.txt") else { return items }

        var inTargetCategory = false

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // 检查是否是分类标题（不以数字开头）
            if !trimmed.isEmpty && !trimmed.first!.isNumber {
                inTargetCategory = trimmed == category
                continue
            }

            // 如果在目标分类中，提取物品ID和名称
            if inTargetCategory && trimmed.first!.isNumber {
                let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count >= 2 {
                    items.append(CategoryItem(itemId: String(parts[0]), name: String(parts[1])))
                }
            }
        }
        return items
    }

    // MARK: - 地图名称

    /// 从「地图.txt」加载地图ID → 名称映射
    static func loadMapNames() -> [Int: String] {
        var mapNames: [Int: String] = [:]
        guard let content = loadAsset("地图.txt") else { return mapNames }

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count >= 2, let sceneId = Int(parts[0]) {
                mapNames[sceneId] = String(parts[1])
            }
        }
        return mapNames
    }

    // MARK: - 天赋数据

    /// 从「天赋技能.txt」加载天赋数据
    /// - Returns: 天赋ID → (等级 → 描述)
    static func loadTalentData() -> [Int: [Int: String]] {
        var talentData: [Int: [Int: String]] = [:]
        guard let content = loadAsset("天赋技能.txt") else { return talentData }

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            // 格式: ID 等级 描述
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            if parts.count >= 3,
               let id = Int(parts[0]),
               let level = Int(parts[1]) {
                if talentData[id] == nil {
                    talentData[id] = [:]
                }
                talentData[id]?[level] = String(parts[2])
            }
        }
        return talentData
    }

    // MARK: - 物品名称映射

    /// 从「物品ID22.txt」加载物品ID → 名称映射
    static func loadItemMappings() -> [Int: String] {
        var mappings: [Int: String] = [:]
        guard let content = loadAsset("物品ID22.txt") else { return mappings }

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count >= 2, let itemId = Int(parts[0]) {
                mappings[itemId] = String(parts[1])
            }
        }
        return mappings
    }

    /// 根据物品ID获取名称
    private static var itemMappingsCache: [Int: String]?

    static func getItemName(byId id: String) -> String {
        if itemMappingsCache == nil {
            itemMappingsCache = loadItemMappings()
        }
        if let intId = Int(id), let name = itemMappingsCache?[intId] {
            return name
        }
        return "未知物品"
    }

    // MARK: - 私有

    /// 从 Bundle 加载资源文件内容
    private static func loadAsset(_ name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) ??
                Bundle.main.url(forResource: name, withExtension: "txt") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

