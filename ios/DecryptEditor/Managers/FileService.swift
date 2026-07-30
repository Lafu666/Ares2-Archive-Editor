import Foundation

class FileService: ObservableObject {
    @Published var currentFolderContents: [URL] = []
    @Published var isLoading = false
    @Published var canGoBack = false

    private var navigationStack: [URL] = []
    private let documentsDir: URL
    private let fileManager = FileManager.default

    var currentDirectoryName: String {
        navigationStack.last?.lastPathComponent ?? "文档"
    }

    init() {
        documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        createDefaultDirectories()
    }

    private func createDefaultDirectories() {
        let subdirs = ["Databases", "Exports", "Imports", "Backups"]
        for dir in subdirs {
            let url = documentsDir.appendingPathComponent(dir)
            if !fileManager.fileExists(atPath: url.path) {
                try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }

    func loadDocuments() {
        isLoading = true
        let currentDir = navigationStack.last ?? documentsDir
        do {
            let contents = try fileManager.contentsOfDirectory(at: currentDir, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey])
            currentFolderContents = contents.sorted { a, b in
                let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if aIsDir != bIsDir { return aIsDir && !bIsDir }
                return a.lastPathComponent < b.lastPathComponent
            }
            canGoBack = navigationStack.count > 0
        } catch {
            currentFolderContents = []
        }
        isLoading = false
    }

    func navigateTo(_ url: URL) {
        navigationStack.append(url)
        loadDocuments()
    }

    func goBack() {
        guard !navigationStack.isEmpty else { return }
        navigationStack.removeLast()
        loadDocuments()
    }

    func importFile(from sourceURL: URL) {
        let targetDir = documentsDir.appendingPathComponent("Imports")
        try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        let targetURL = targetDir.appendingPathComponent(sourceURL.lastPathComponent)

        if fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }

        guard sourceURL.startAccessingSecurityScopedResource() else { return }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        try? fileManager.copyItem(at: sourceURL, to: targetURL)
        loadDocuments()
    }

    func findDatabaseFiles() -> [URL] {
        var results: [URL] = []
        let enumerator = fileManager.enumerator(at: documentsDir, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "db" || url.pathExtension == "sqlite" {
                results.append(url)
            }
        }
        return results
    }
}
