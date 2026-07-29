import UIKit
import WebKit

/// JS ↔ 原生 消息中枢：
/// - `openFile`：网页"加载"按钮被点击时触发，转交 ViewController 弹出原生文件选择器。
/// - `saveBlob`：保存/导出时把 blob 落成临时文件并弹出系统分享面板（存储到文件 App / AirDrop…）。
final class WebViewMessageHandler: NSObject, WKScriptMessageHandler {
    static let shared = WebViewMessageHandler()
    weak var presenter: ViewController?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        switch message.name {
        case "openFile":
            // 文件选择器必须在主线程 present
            DispatchQueue.main.async { self.presenter?.presentDocumentPicker() }
        case "saveBlob":
            handleSaveBlob(message)
        default:
            break
        }
    }

    private func handleSaveBlob(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let dataURL = body["data"] as? String,
              let filename = body["filename"] as? String,
              let data = Self.data(fromDataURL: dataURL)
        else { return }

        let safeName = filename.replacingOccurrences(of: "/", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
        do { try data.write(to: url) } catch { return }

        DispatchQueue.main.async { self.presentShareSheet(for: url) }
    }

    private func presentShareSheet(for url: URL) {
        guard let presenter = presenter else { return }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                    y: presenter.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
    }

    private static func data(fromDataURL dataURL: String) -> Data? {
        guard let comma = dataURL.firstIndex(of: ",") else { return nil }
        let base64 = String(dataURL[dataURL.index(after: comma)...])
        return Data(base64Encoded: base64)
    }
}
