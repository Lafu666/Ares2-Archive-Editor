import UIKit
import WebKit

/// 接收 JS postMessage 的 {filename, dataURL}，把 blob 落成临时文件并弹出系统分享面板，
/// 让用户“存储到文件 App / AirDrop / ...”。
final class WebViewMessageHandler: NSObject, WKScriptMessageHandler {
    static let shared = WebViewMessageHandler()
    weak var presenter: UIViewController?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "saveBlob",
              let body = message.body as? [String: Any],
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
