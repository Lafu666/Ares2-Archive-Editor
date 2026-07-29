import UIKit
import WebKit

/// 用 WKWebView 加载内置 index.html 的壳页面。
/// 关键点：
/// 1) html 内嵌了 sql.js 的 wasm（base64），不联网、不读外部 .wasm，loadFileURL 即可运行。
/// 2) 拦截 <a download>.click() 的 blob 下载，转交原生分享面板（WKWebView 原生下载不可靠）。
/// 3) 实现 JS alert/confirm/prompt，并阻止 window.open 在 App 内跳走。
final class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        WebViewMessageHandler.shared.presenter = self
        setupWebView()
        loadIndex()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let cc = WKUserContentController()
        cc.add(WebViewMessageHandler.shared, name: "saveBlob")
        // 在文档任何脚本执行前注入，确保拦截到程序化 a.click()
        cc.addUserScript(WKUserScript(source: Self.saveShim,
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: true))
        config.userContentController = cc

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        view.backgroundColor = .systemBackground
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func loadIndex() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else {
            print("[Ares2] index.html not found in bundle")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    // MARK: - WKUIDelegate (JS 面板 / 新窗口)

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好", style: .default, handler: { _ in completionHandler() }))
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in completionHandler(false) }))
        a.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in completionHandler(true) }))
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { tf in tf.text = defaultText }
        a.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { _ in completionHandler(nil) }))
        a.addAction(UIAlertAction(title: "确定", style: .default, handler: { _ in
            completionHandler(a.textFields?.first?.text)
        }))
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // 阻止 window.open 弹新窗：在当前 webView 内加载
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let s = url.scheme ?? ""
            if s == "http" || s == "https" {
                UIApplication.shared.open(url)          // 外部链接交 Safari
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    // MARK: - 下载拦截脚本

    private static let saveShim: String = #"""
    (function(){
      if (window.__aresSaveShim) return; window.__aresSaveShim = true;
      // a.click() 解析到 HTMLElement.prototype.click，覆盖它以拦截程序化点击的 <a download blob:>
      var origClick = HTMLElement.prototype.click;
      HTMLElement.prototype.click = function(){
        try {
          var href = this.href || "";
          var dl = this.getAttribute && this.getAttribute("download");
          if (dl && href.indexOf("blob:") === 0) {
            var filename = dl;
            var self = this;
            fetch(href).then(function(r){ return r.blob(); }).then(function(blob){
              var fr = new FileReader();
              fr.onload = function(){
                try { webkit.messageHandlers.saveBlob.postMessage({filename: filename, data: fr.result}); }
                catch(e){ origClick.call(self); }
              };
              fr.onerror = function(){ origClick.call(self); };
              fr.readAsDataURL(blob);
            }).catch(function(){ origClick.call(self); });
            return;
          }
        } catch(e) {}
        return origClick.apply(this, arguments);
      };
    })();
    """#
}
