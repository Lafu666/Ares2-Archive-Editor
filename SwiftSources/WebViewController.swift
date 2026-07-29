import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!
    private var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "阿瑞斯2积分计算器"
        view.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
        
        setupNavigationBar()
        setupWebView()
        setupActivityIndicator()
        loadLocalHTML()
    }
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.barTintColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
        navigationController?.navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 1.0),
            .font: UIFont.boldSystemFont(ofSize: 17)
        ]
        
        // 刷新按钮
        let refresh = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshTapped))
        refresh.tintColor = UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 1.0)
        navigationItem.rightBarButtonItem = refresh
        
        // 返回首页按钮
        let home = UIBarButtonItem(image: UIImage(systemName: "house.fill"), style: .plain, target: self, action: #selector(homeTapped))
        home.tintColor = UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 1.0)
        navigationItem.leftBarButtonItem = home
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // 启用本地存储
        config.websiteDataStore = .default()
        
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
        webView.isOpaque = false
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        
        // 隐藏滚动条
        webView.scrollView.showsVerticalScrollIndicator = false
        
        view.addSubview(webView)
    }
    
    private func setupActivityIndicator() {
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 1.0)
        activityIndicator.center = view.center
        activityIndicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        view.addSubview(activityIndicator)
    }
    
    private func loadLocalHTML() {
        // 优先加载 bundle 中的 HTML
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html") {
            let baseURL = URL(fileURLWithPath: Bundle.main.resourcePath ?? "")
            do {
                let htmlContent = try String(contentsOfFile: htmlPath, encoding: .utf8)
                webView.loadHTMLString(htmlContent, baseURL: baseURL)
            } catch {
                loadRemoteFallback()
            }
        } else if let wwwPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "www") {
            let baseURL = URL(fileURLWithPath: Bundle.main.path(forResource: "www", ofType: nil) ?? "")
            do {
                let htmlContent = try String(contentsOfFile: wwwPath, encoding: .utf8)
                webView.loadHTMLString(htmlContent, baseURL: baseURL)
            } catch {
                loadRemoteFallback()
            }
        } else {
            loadRemoteFallback()
        }
    }
    
    private func loadRemoteFallback() {
        // 本地文件不可用时加载远程
        let url = URL(string: "https://4067ecd5.sqiyue-github-io.pages.dev/")!
        webView.load(URLRequest(url: url))
    }
    
    @objc private func refreshTapped() {
        if webView.url == nil {
            loadLocalHTML()
        } else {
            webView.reload()
        }
    }
    
    @objc private func homeTapped() {
        loadLocalHTML()
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        print("WebView error: \(error.localizedDescription)")
    }
}
