import UIKit
import WebKit
import UniformTypeIdentifiers

/// 用 WKWebView 加载内置 index.html 的壳页面。
/// 关键点：
/// 1) html 内嵌了 sql.js 的 wasm（base64），不联网、不读外部 .wasm，loadFileURL 即可运行。
/// 2) 存档加载走【原生 UIDocumentPickerViewController】——WKWebView 下程序化触发
///    <input type=file>.click() 常不弹文件选择器，故网页"加载"按钮与导航栏"打开"按钮
///    都改走原生选择器，选中后把文件字节以 base64 注入 JS 调用页面的 加载加密存档()。
/// 3) 拦截 <a download>.click() 的 blob 下载，转交原生分享面板（WKWebView 原生下载不可靠）。
/// 4) 实现 JS alert/confirm/prompt，并阻止 window.open 在 App 内跳走。
final class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, UIDocumentPickerDelegate {

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        WebViewMessageHandler.shared.presenter = self
        setupNavBar()
        setupWebView()
        loadIndex()
    }

    // MARK: - 导航栏

    private func setupNavBar() {
        title = "Ares2存档修改器"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "打开", style: .plain, target: self, action: #selector(openFileTapped))
    }

    @objc func openFileTapped() {
        presentDocumentPicker()
    }

    /// 弹出原生文件选择器（允许选任意文件，适配 .db/.dat/.bin 等非标准存档扩展名）
    func presentDocumentPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item])
        picker.allowsMultipleSelection = false
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            warn("读取文件失败")
            return
        }
        let name = url.lastPathComponent
        let b64 = data.base64EncodedString()
        // 注入到页面，调用全局 加载加密存档(ArrayBuffer, filename)
        let js = "window.__nativeOpenFile(\(jsJSON(b64)), \(jsJSON(name)));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - WebView

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let cc = WKUserContentController()
        cc.add(WebViewMessageHandler.shared, name: "saveBlob")
        cc.add(WebViewMessageHandler.shared, name: "openFile")
        // 在文档任何脚本执行前注入：文件打开桥 + "加载"按钮拦截 + 下载拦截
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
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
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

    // MARK: - 注入脚本：文件打开桥 + "加载"按钮拦截 + 下载拦截

    private static let saveShim: String = #"""
    (function(){
      if (window.__aresSaveShim) return; window.__aresSaveShim = true;

      // 原生文件打开桥：接收 {base64, filename}，解码成 ArrayBuffer 后调用页面的 加载加密存档()
      window.__nativeOpenFile = function(base64, filename){
        try {
          var bin = atob(base64);
          var bytes = new Uint8Array(bin.length);
          for (var i=0;i<bin.length;i++) bytes[i] = bin.charCodeAt(i);
          加载加密存档(bytes.buffer, filename);
        } catch(e){ console.error("[Ares2] nativeOpenFile failed:", e); }
      };

      // 拦截页面"加载"按钮(#按钮加载) 的点击——WKWebView 下程序化触发
      // <input type=file>.click() 常不弹文件选择器，改走原生 UIDocumentPickerViewController。
      // 用捕获阶段 + stopImmediatePropagation，在页面原 click 监听器之前拦截。
      document.addEventListener("click", function(e){
        if (e.target && e.target.closest && e.target.closest("#按钮加载")) {
          e.preventDefault();
          e.stopImmediatePropagation();
          try { webkit.messageHandlers.openFile.postMessage({}); } catch(ex){}
        }
      }, true);

      // 拦截 <a download>.click() 的 blob 下载，转交原生分享面板
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

    // MARK: - 工具

    /// 把任意 String 编码成合法的 JSON 字符串字面量（含两侧引号），用于安全拼接 JS。
    private func jsJSON(_ s: String) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: s, options: .fragmentsAllowed),
              let out = String(data: d, encoding: .utf8) else { return "\"\"" }
        return out
    }

    private func warn(_ msg: String) {
        let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "好", style: .default, handler: nil))
        present(a, animated: true)
    }
}
