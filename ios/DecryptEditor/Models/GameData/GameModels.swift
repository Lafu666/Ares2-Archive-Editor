import Foundation

struct GameItem: Identifiable, Codable {
    let id: Int
    let name: String
    let category: String

    init(id: Int, name: String, category: String = "") {
        self.id = id
        self.name = name
        self.category = category
    }
}

struct MapInfo: Identifiable, Codable {
    let id: Int
    let name: String
    var isDiscovered: Bool
    var isOwned: Bool
    var refreshTime: Date?

    init(id: Int, name: String, isDiscovered: Bool = false, isOwned: Bool = false, refreshTime: Date? = nil) {
        self.id = id
        self.name = name
        self.isDiscovered = isDiscovered
        self.isOwned = isOwned
        self.refreshTime = refreshTime
    }
}

struct TalentInfo: Identifiable, Codable {
    let id: Int
    let name: String
    let description: String

    init(id: Int, name: String, description: String = "") {
        self.id = id
        self.name = name
        self.description = description
    }
}

struct FurnitureInfo: Identifiable, Codable {
    let id: Int
    let name: String
    let position: String

    init(id: Int, name: String, position: String = "") {
        self.id = name
        self.name = name
        self.position = position
    }
}

struct WorkerInfo: Identifiable, Codable {
    let id: Int
    let name: String
    var isHired: Bool

    init(id: Int, name: String, isHired: Bool = false) {
        self.id = id
        self.name = name
        self.isHired = isHired
    }
}

enum TreeNode {
    case file(name: String, path: String, isDatabase: Bool)
    case table(name: String, parentDB: String)
    case record(id: Int, values: [String: String])
}
