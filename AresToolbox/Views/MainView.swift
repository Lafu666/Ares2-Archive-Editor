import SwiftUI

/// 应用根视图
///
/// 根据 ViewModel 的状态在不同界面之间切换，
/// 并统一管理进度浮层和弹窗提示。
struct MainView: View {

    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        NavigationStack {
            content
        }
        .overlay {
            // 导出等操作时的进度浮层（不覆盖 .processing 全屏状态）
            if viewModel.isProcessing && viewModel.state != .processing {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressDialogView(
                        progress: viewModel.progress,
                        message: viewModel.progressMessage
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isProcessing)
        .alert("提示", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("代码查询", isPresented: $viewModel.showCodeQueryAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("没必要")
        }
        .alert("导出成功", isPresented: $viewModel.showExportSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("存档已导出到:\n\(viewModel.exportedFilePath)")
        }
    }

    // MARK: - 内容视图

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .mainMenu:
            mainMenuContent
        case .fileBrowser:
            FileBrowserView(viewModel: viewModel)
        case .processing:
            processingContent
        case .tableEditor:
            TableEditorView(viewModel: viewModel)
        case .normalEdit:
            EditOptionsView(viewModel: viewModel)
        }
    }

    // MARK: - 主菜单

    private var mainMenuContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // 应用标题
            VStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("阿瑞斯工具箱")
                    .font(.largeTitle.bold())

                Text("游戏存档编辑器")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 功能按钮
            VStack(spacing: 16) {
                Button {
                    viewModel.state = .fileBrowser
                } label: {
                    Label("处理存档", systemImage: "doc.zipper")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(14)
                }

                Button {
                    viewModel.showCodeQueryAlert = true
                } label: {
                    Label("代码查询", systemImage: "magnifyingglass")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Text("版本 1.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - 处理中

    private var processingContent: some View {
        VStack {
            Spacer()
            ProgressDialogView(
                progress: viewModel.progress,
                message: viewModel.progressMessage
            )
            .padding(.horizontal, 40)
            Spacer()
        }
    }
}

#Preview {
    MainView()
}
