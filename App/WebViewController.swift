import UIKit
import WebKit
import SafariServices

// MARK: - 主题色（取自站点 CSS 变量）

enum Theme {
    /// hsl(220 10% 6%) —— 站点背景
    static let background = UIColor(red: 14 / 255, green: 15 / 255, blue: 17 / 255, alpha: 1)
    /// hsl(140 70% 55%) —— 站点主题色
    static let accent = UIColor(red: 0.235, green: 0.865, blue: 0.445, alpha: 1)
    static let primaryText = UIColor.white
    static let secondaryText = UIColor(white: 1, alpha: 0.55)
}

/// 用 WKWebView 把 https://lycl.top/ 包成一个原生 App 外壳。
final class WebViewController: UIViewController {

    // MARK: - 站点配置：换站点只需改这里

    private enum Site {
        static let home = URL(string: "https://lycl.top/")!
        /// 允许在 App 内打开的主机，子域自动放行
        static let hosts: [String] = ["lycl.top"]
    }

    // MARK: - 子视图

    private var webView: WKWebView!

    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .bar)
        view.progressTintColor = Theme.accent
        view.trackTintColor = .clear
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(white: 1, alpha: 0.12)
        button.layer.cornerRadius = 19
        button.alpha = 0
        button.isUserInteractionEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        return button
    }()

    private lazy var errorView: ErrorView = {
        let view = ErrorView()
        view.onRetry = { [weak self] in
            guard let self = self else { return }
            view.isHidden = true
            self.load(self.lastURL ?? Site.home)
        }
        return view
    }()

    private let refreshControl = UIRefreshControl()
    private var progressObservation: NSKeyValueObservation?
    private var canGoBackObservation: NSKeyValueObservation?

    /// 最近一次站内请求，用于失败后重试
    private var lastURL: URL?
    /// 首页只在布局完成后加载一次
    private var hasLoadedHome = false

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        configureWebView()
        configureLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 关键：必须等 WebView 拿到真实尺寸后再加载页面。
        // 若在 viewDidLoad 里直接 load，此时 bounds 仍是 .zero，
        // WKWebView 会按 0 宽计算 viewport，导致 width=device-width 失效、整页被放大，
        // 表现为：标题被裁切、顶部导航消失、卡片内容被撑变形。
        guard !hasLoadedHome, webView.bounds.width > 1 else { return }
        hasLoadedHome = true
        load(Site.home)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    deinit {
        progressObservation?.invalidate()
        canGoBackObservation?.invalidate()
    }

    // MARK: - 构建

    private func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        // 持久化 Cookie / localStorage，登录态不会每次重来
        configuration.websiteDataStore = .default()
        // 允许内联播放，避免视频/音频被迫全屏
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // 关掉 WebKit 的「字体自动放大」，避免窄视口下字号被二次放大导致排版变形
        let typographyFix = """
        (function () {
          var style = document.createElement('style');
          style.textContent = 'html{-webkit-text-size-adjust:100%!important;text-size-adjust:100%!important;}';
          document.documentElement.appendChild(style);
        })();
        """
        configuration.userContentController.addUserScript(
            WKUserScript(source: typographyFix, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )

        // 修复 Tailwind 透明度类在缺少 color-mix() 支持时的「纯色退化」，
        // 否则卡片背景会从 7% 淡绿变成 100% 不透明亮绿并盖住内容
        configuration.userContentController.addUserScript(
            WKUserScript(source: SitePatches.alphaFallback, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        // 修复渐变里的 `in oklab` 插值语法：旧版 WebKit 会整条丢弃 background-image，
        // 导致全站渐变（横幅渐隐、卡片光晕、按钮底色）全部消失
        configuration.userContentController.addUserScript(
            WKUserScript(source: SitePatches.gradientFallback, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )

        return configuration
    }

    /// 站点按 Safari 编写，套一层 Safari UA 兼容性最好
    private func safariUserAgent() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let patch = version.patchVersion > 0 ? "_\(version.patchVersion)" : ""
        let osVersion = "\(version.majorVersion)_\(version.minorVersion)\(patch)"
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        return "Mozilla/5.0 (\(device); CPU \(device) OS \(osVersion) like Mac OS X) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
            + "Version/\(version.majorVersion).\(version.minorVersion) Mobile/15E148 Safari/604.1"
    }

    private func configureWebView() {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = Theme.background
        webView.scrollView.backgroundColor = Theme.background
        webView.customUserAgent = safariUserAgent()
        if #available(iOS 15.0, *) {
            webView.underPageBackgroundColor = Theme.background
        }

        webView.scrollView.refreshControl = refreshControl
        refreshControl.tintColor = Theme.secondaryText
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            self?.updateProgress(Float(webView.estimatedProgress))
        }
        canGoBackObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
            self?.updateBackButton(visible: webView.canGoBack)
        }

        self.webView = webView
        view.addSubview(webView)
        view.addSubview(progressView)
        view.addSubview(backButton)
    }

    private func configureLayout() {
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),

            progressView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            backButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 12),
            backButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10),
            backButton.widthAnchor.constraint(equalToConstant: 38),
            backButton.heightAnchor.constraint(equalToConstant: 38),
        ])
    }

    // MARK: - 加载与交互

    private func load(_ url: URL) {
        lastURL = url
        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        request.timeoutInterval = 30
        webView.load(request)
    }

    @objc private func handleRefresh() {
        if webView.url == nil {
            load(lastURL ?? Site.home)
        } else {
            webView.reload()
        }
    }

    @objc private func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    private func updateProgress(_ value: Float) {
        if value > 0, value < 1 {
            progressView.alpha = 1
            progressView.setProgress(value, animated: true)
        } else if value >= 1 {
            UIView.animate(withDuration: 0.25, animations: {
                self.progressView.alpha = 0
            }, completion: { _ in
                self.progressView.setProgress(0, animated: false)
            })
        }
    }

    private func updateBackButton(visible: Bool) {
        backButton.isUserInteractionEnabled = visible
        UIView.animate(withDuration: 0.2) {
            self.backButton.alpha = visible ? 1 : 0
        }
    }

    private func isInternal(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return Site.hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    private func presentInSafari(_ url: URL) {
        guard presentedViewController == nil else { return }
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = Theme.accent
        safari.dismissButtonStyle = .close
        present(safari, animated: true)
    }

    /// 当前有弹窗时直接走失败回调，避免 "Attempt to present ... which is already presenting"
    private func presentSafely(_ controller: UIViewController, onFailure: @escaping () -> Void) {
        guard presentedViewController == nil else {
            onFailure()
            return
        }
        present(controller, animated: true)
    }

    // MARK: - 错误页

    private func showError(_ message: String) {
        if errorView.superview == nil {
            view.addSubview(errorView)
            NSLayoutConstraint.activate([
                errorView.topAnchor.constraint(equalTo: view.topAnchor),
                errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }
        errorView.show(message: message)
    }

    private func handleFailure(_ error: Error) {
        refreshControl.endRefreshing()
        let nsError = error as NSError
        // 用户主动取消 / 页面脚本 reload 造成的取消，都不该弹错误页
        guard nsError.code != NSURLErrorCancelled else { return }
        showError(friendlyMessage(for: nsError))
    }

    private func friendlyMessage(for error: NSError) -> String {
        switch error.code {
        case NSURLErrorNotConnectedToInternet:
            return "设备没有联网，请检查 Wi-Fi 或蜂窝数据后重试。"
        case NSURLErrorTimedOut:
            return "连接超时，指挥部暂时没有响应。请稍后重试。"
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
            return "无法连接到 lycl.top，请确认网络环境后再试。"
        case NSURLErrorNetworkConnectionLost:
            return "网络连接中断，请重新连接后重试。"
        case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
            return "安全连接失败，请检查网络环境或稍后重试。"
        default:
            return "页面加载失败（\(error.code)），请检查网络后重试。"
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        switch url.scheme?.lowercased() ?? "" {
        case "http", "https":
            if isInternal(url) {
                lastURL = url
                decisionHandler(.allow)
            } else {
                // 站外链接交给内置 Safari，不打断 App 内会话
                presentInSafari(url)
                decisionHandler(.cancel)
            }
        case "about", "blob", "data", "javascript", "file":
            decisionHandler(.allow)
        default:
            // tel: / mailto: / weixin: / alipays: 等交给系统处理
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshControl.endRefreshing()
        progressView.alpha = 0
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        handleFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // 系统回收了 Web 进程（内存吃紧），自动恢复
        if let url = webView.url ?? lastURL {
            load(url)
        }
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {

    /// target="_blank" / window.open 的新窗口：站内就地打开，站外交给 Safari
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        guard let url = navigationAction.request.url else { return nil }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isInternal(url) {
                self.lastURL = url
                webView.load(navigationAction.request)
            } else if url.scheme == "http" || url.scheme == "https" {
                self.presentInSafari(url)
            } else if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {

        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        presentSafely(alert, onFailure: completionHandler)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {

        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
        presentSafely(alert) { completionHandler(false) }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {

        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak alert] _ in
            completionHandler(alert?.textFields?.first?.text)
        })
        presentSafely(alert) { completionHandler(nil) }
    }
}
