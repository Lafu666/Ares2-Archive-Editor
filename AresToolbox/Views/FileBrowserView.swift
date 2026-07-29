import SwiftUI
import UniformTypeIdentifiers

/// 文件浏览器视图
///
/// 使用系统文件选择器（fileImporter）让用户选择 .zip 存档文件，
/// 并展示最近访问过的文件列表。
struct FileBrowserView: View {

    @ObservedObject var viewModel: AppViewModel

    /// 是否显示系统文件选择器
    @State private var showFileImporter = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // 图标和说明
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("选择存档文件")
                    .font(.title2.bold())

                Text("请选择游戏存档压缩包（.zip）文件")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 选择文件按钮
            Button {
                showFileImporter = true
            } label: {
                Label("选择文件", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)

            // 最近访问的文件
            if !viewModel.recentFiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近访问")
                        .font(.headline)

                    List(viewModel.recentFiles, id: \.self) { fileName in
                        Label(fileName, systemImage: "doc.zipper")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: 220)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            // 返回主菜单
            Button("返回主菜单") {
                viewModel.state = .mainMenu
            }
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("文件浏览")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.selectArchive(at: url)
                }
            case .failure(let error):
                viewModel.errorMessage = "选择文件失败: \(error.localizedDescription)"
                viewModel.showError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        FileBrowserView(viewModel: AppViewModel())
    }
}
