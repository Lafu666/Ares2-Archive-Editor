import SwiftUI

/// 进度对话框视图
///
/// 用于显示文件处理、导出等操作的进度。
/// 可作为全屏内容使用，也可作为浮层 overlay 使用。
struct ProgressDialogView: View {

    /// 进度值 (0-100)
    let progress: Int

    /// 进度描述文字
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: Double(progress), total: 100)
                .progressViewStyle(.linear)
                .frame(maxWidth: 240)

            Text("\(progress)%")
                .font(.headline)
                .monospacedDigit()

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
                .lineLimit(3)
        }
        .padding(28)
        .background(.regularMaterial)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

#Preview {
    ProgressDialogView(progress: 65, message: "正在解压ZIP文件...")
        .padding(40)
}
