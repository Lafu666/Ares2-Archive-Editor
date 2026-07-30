import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @EnvironmentObject var fileService: FileService
    @State private var showFilePicker = false
    @State private var searchText = ""
    @State private var selectedFile: URL?

    var body: some View {
        NavigationStack {
            List {
                if fileService.currentFolderContents.isEmpty && !fileService.isLoading {
                    emptyStateView
                } else {
                    fileListSection
                }
            }
            .searchable(text: $searchText, prompt: "搜索文件")
            .navigationTitle("文件浏览器")
            .toolbar { toolbarContent }
            .refreshable { fileService.loadDocuments() }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    for url in urls {
                        fileService.importFile(from: url)
                    }
                }
            }
            .sheet(item: $selectedFile) { url in
                FileDetailView(fileURL: url)
            }
        }
        .onAppear { fileService.loadDocuments() }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("没有文件")
                .font(.headline)
            Text("点击 + 导入文件")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var fileListSection: some View {
        ForEach(filteredFiles, id: \.path) { url in
            Button {
                if url.hasDirectoryPath {
                    fileService.navigateTo(url)
                } else if url.pathExtension == "db" || url.pathExtension == "sqlite" {
                    selectedFile = url
                }
            } label: {
                FileRow(url: url)
            }
        }
        .onDelete { indexSet in
            for i in indexSet {
                if i < filteredFiles.count {
                    try? FileManager.default.removeItem(at: filteredFiles[i])
                }
            }
            fileService.loadDocuments()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showFilePicker = true } label: {
                Image(systemName: "plus")
            }
        }
        if fileService.canGoBack {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { fileService.goBack() } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text(fileService.currentDirectoryName)
                    }
                }
            }
        }
    }

    private var filteredFiles: [URL] {
        let contents = fileService.currentFolderContents
        if searchText.isEmpty { return contents }
        return contents.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
    }
}

struct FileRow: View {
    let url: URL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? NSNumber {
                    Text("\(ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if url.pathExtension == "db" {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        if url.hasDirectoryPath { return "folder" }
        switch url.pathExtension {
        case "db", "sqlite": return "cylinder"
        case "zip", "gz": return "archivebox"
        case "json", "xml", "txt": return "doc.text"
        default: return "doc"
        }
    }

    private var iconColor: Color {
        if url.hasDirectoryPath { return .blue }
        switch url.pathExtension {
        case "db", "sqlite": return .purple
        case "zip", "gz": return .orange
        default: return .gray
        }
    }
}

struct FileDetailView: View {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            DatabaseView(fileURL: fileURL)
                .navigationTitle(fileURL.lastPathComponent)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("关闭") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    FileBrowserView()
        .environmentObject(FileService())
}
