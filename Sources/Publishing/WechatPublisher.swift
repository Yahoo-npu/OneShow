import SwiftUI
import WebKit

enum WechatTheme: String, CaseIterable, Identifiable {
    case classic, journal, forest, minimal
    var id: String { rawValue }
    var name: String { switch self { case .classic: return "经典蓝 · 技术"; case .journal: return "暖杏 · 随笔"; case .forest: return "松绿 · 知识"; case .minimal: return "墨黑 · 极简" } }
}

@MainActor final class WechatPublisher: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var status = "正在准备公众号文章…"
    @Published var busy = false
    @Published var html = ""
    @Published var warnings: [String] = []
    @Published var localImages = 0
    let backend: WKWebView
    private let worker: WKWebView
    private var ready = false
    private var pending: (Article, AppTheme, WechatTheme)?
    private var revision = 0
    private var plain = ""
    private var title = ""
    private var automation: Task<Void, Never>?
    private var autoAttempted = false
    private var autoEnabled = false
    private var openingEditor = false
    private var checkingPage = false
    func start(_ article: Article, theme: AppTheme, layout: WechatTheme) {
        autoEnabled = true; autoAttempted = false; openingEditor = false
        render(article, theme: theme, layout: layout)
        status = "正在打开公众号，登录后将自动进入编辑器并填入。"
        openBackend()
        automation?.cancel()
        automation = Task { [weak self] in
            for _ in 0..<600 {
                guard !Task.isCancelled else { return }
                self?.advance()
                try? await Task.sleep(for: .seconds(1))
            }
            if self?.autoEnabled == true { self?.autoEnabled = false; self?.status = "自动填入等待已结束，请关闭窗口后重新点击发布。" }
        }
    }
    func stop() { autoEnabled = false; automation?.cancel(); automation = nil }
    private func advance() {
        guard autoEnabled, !busy, !html.isEmpty, !checkingPage, !backend.isLoading else { return }
        guard backend.url?.host == "mp.weixin.qq.com" else { return }
        checkingPage = true
        editorScript("oneShowWechatState()") { [weak self] value, error in
            guard let self else { return }
            self.checkingPage = false
            guard self.autoEnabled, error == nil, let state = value as? [String: Any] else { return }
            if state["found"] as? Bool == true {
                guard !self.autoAttempted else { return }
                self.autoAttempted = true
                self.status = "正在自动填入标题与正文…"
                self.fillEditor()
            } else if !self.openingEditor {
                self.openingEditor = true
                self.editorScript("oneShowWechatOpenEditor()") { value, _ in
                    if value as? String == "login" { self.openingEditor = false; self.status = "请扫码登录，登录后将自动打开图文编辑器并填入。" }
                }
            }
        }
    }
    override init() {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .default()
        backend = WKWebView(frame: .zero, configuration: config)
        let isolated = WKWebViewConfiguration(); isolated.websiteDataStore = .nonPersistent()
        worker = WKWebView(frame: .zero, configuration: isolated)
        super.init(); worker.navigationDelegate = self; backend.navigationDelegate = self; backend.uiDelegate = self
        let scripts = ["marked.umd", "markdown", "preview", "highlight", "wechat"].map { MarkdownSupport.resource($0) }.joined(separator: "\n")
        worker.loadHTMLString("<!doctype html><meta charset='utf-8'><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline';\"><script>\(scripts)</script>", baseURL: nil)
    }
    func render(_ article: Article, theme: AppTheme, layout: WechatTheme = .classic) {
        revision += 1; pending = (article, theme, layout); busy = true; html = ""; warnings = []
        if ready { convert(article, theme: theme, layout: layout, revision: revision) }
    }
    private func convert(_ article: Article, theme: AppTheme, layout: WechatTheme, revision: Int) {
        worker.callAsyncJavaScript("return makeWechatArticle(source, accent, layout)", arguments: ["source":article.displayBody, "accent":theme.hex, "layout":layout.rawValue], in: nil, in: .page) { result in Task { @MainActor in
            guard revision == self.revision else { return }
            self.busy = false
            switch result {
            case .success(let value):
                guard let result = value as? [String: Any], let html = result["html"] as? String else { self.status = "公众号格式转换未返回有效结果"; return }
                self.html = html; self.plain = result["text"] as? String ?? ""; self.title = article.title
                self.localImages = result["localImages"] as? Int ?? 0
                if self.localImages > 0 { self.warnings.append("\(self.localImages) 张本地图片已显示为占位，请在公众号编辑器上传替换。") }
                let external = result["externalImages"] as? Int ?? 0
                if external > 0 { self.warnings.append("\(external) 张外部图片需在微信后台确认转存结果；本软件不上传或验证微信图片素材。") }
                if article.title.count > 64 { self.warnings.append("标题较长，请在公众号后台检查标题长度限制。") }
                self.status = "排版已准备好，正在等待公众号编辑器…"
            case .failure(let error): self.status = "转换失败：\(error.localizedDescription)"
            }
        } }
    }
    func openBackend() {
        if backend.url?.host != "mp.weixin.qq.com" { backend.load(URLRequest(url: URL(string: "https://mp.weixin.qq.com/")!)) }
    }
    func fillEditor() {
        guard !html.isEmpty, !busy else { return }
        guard backend.url?.host == "mp.weixin.qq.com" else { status = "请先扫码登录，并在公众号后台打开新的图文编辑器。"; return }
        // Operate only on visible editing controls. Never save or publish automatically.
        let script = MarkdownSupport.resource("wechat-editor") + "\nreturn oneShowWechatPreflight()"
        busy = true
        backend.callAsyncJavaScript(script, arguments: ["articleTitle":title,"articleHTML":html,"articlePlain":plain], in: nil, in: .page) { result in Task { @MainActor in
            self.busy = false
            switch result { case .success(let value):
                if let data = value as? [String: Any], data["nativePaste"] as? Bool == true { self.nativeFill(); return }
                self.autoEnabled = false; self.automation?.cancel()
                self.status = value as? String ?? "未获得编辑器结果"; case .failure(let error):
                self.autoEnabled = false; self.automation?.cancel(); self.status = "自动填入失败：\(error.localizedDescription)。请关闭窗口后重新点击发布。" }
        } }
    }
    private func editorScript(_ call: String, completion: @escaping (Any?, Error?) -> Void) {
        backend.evaluateJavaScript(MarkdownSupport.resource("wechat-editor") + "\n" + call, completionHandler: completion)
    }
    private func nativeFill() {
        busy = true
        let clipboard = NSPasteboard.general
        let saved = clipboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem(); for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }; return copy
        } ?? []
        var ownedChange = clipboard.changeCount
        func put(_ body: Bool) {
            let item = NSPasteboardItem(); item.setString(body ? self.plain : self.title, forType: .string)
            if body { item.setString(self.html, forType: .html) }
            clipboard.clearContents(); clipboard.writeObjects([item]); ownedChange = clipboard.changeCount
        }
        func finish(_ message: String) {
            self.autoEnabled = false; self.automation?.cancel()
            if clipboard.changeCount == ownedChange { clipboard.clearContents(); clipboard.writeObjects(saved) }
            self.busy = false; self.status = message
        }
        func paste(_ which: String, done: @escaping () -> Void) {
            guard self.autoEnabled else { finish("已停止自动填入。"); return }
            self.backend.window?.makeFirstResponder(self.backend)
            self.editorScript("oneShowWechatFocus('\(which)')") { focused, error in
                guard error == nil, focused as? Bool == true else { finish("未能聚焦编辑区，请关闭窗口后重新点击发布。"); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    guard self.autoEnabled else { finish("已停止自动填入。"); return }
                    let accepted = NSApp.sendAction(NSSelectorFromString("paste:"), to: self.backend.window?.firstResponder, from: nil)
                    guard accepted else { finish("网页未接受原生粘贴，请关闭窗口后重新点击发布。"); return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: done)
                }
            }
        }
        put(false)
        paste("title") {
            self.editorScript("oneShowWechatState()") { value, _ in
                guard let state = value as? [String: Any], state["title"] as? String == self.title,
                      (state["body"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    finish("标题粘贴回读不一致，请检查网页，必要时手动填写。"); return
                }
                put(true)
                paste("body") {
                    @MainActor func verify(_ remaining: Int) {
                        self.editorScript("oneShowWechatConfirmFormat(); oneShowWechatState()") { value, _ in
                            guard self.autoEnabled else { finish("已停止自动填入。"); return }
                            let normalize: (String) -> String = { $0.replacingOccurrences(of: "[\\s\\u200b-\\u200d\\ufeff]+", with: "", options: .regularExpression) }
                            if let state = value as? [String: Any], state["title"] as? String == self.title,
                               normalize(state["body"] as? String ?? "") == normalize(self.plain) {
                                self.autoEnabled = false
                                self.automation?.cancel()
                                finish("标题与正文已自动填入。请检查图片和封面，在微信页面完成最终发表。")
                            } else if remaining > 0 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { verify(remaining - 1) }
                            } else {
                                self.autoEnabled = false
                                self.automation?.cancel()
                                finish("微信未确认完整接收正文，请检查网页提示。关闭窗口后可重新尝试。")
                            }
                        }
                    }
                    verify(20)
                }
            }
        }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if webView === backend, navigationAction.targetFrame == nil, let url = navigationAction.request.url, url.scheme == "https" { backend.load(navigationAction.request) }
        return nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === worker { ready = true; if let (article, theme, layout) = pending { convert(article, theme: theme, layout: layout, revision: revision) } }
        else if webView === backend { if autoEnabled { advance() } }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if webView === worker { busy = false }
        status = "页面加载失败：\(error.localizedDescription)。请关闭窗口后重新点击发布。"
    }

}

struct WechatPublishingView: View {
    let article: Article
    let theme: AppTheme
    @StateObject private var publisher = WechatPublisher()
    @AppStorage("wechatLayout") private var layout: WechatTheme = .classic
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("发布到微信公众号").font(.title2.bold())
                    Text("登录后自动打开图文编辑器并填入内容").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("排版主题", selection: $layout) { ForEach(WechatTheme.allCases) { Text($0.name).tag($0) } }.frame(width: 230).disabled(publisher.busy)
                Button("关闭") { publisher.stop(); dismiss() }
            }.padding(20)
            HStack {
                if publisher.busy { ProgressView().controlSize(.small) } else { Image(systemName: "info.circle") }
                Text(publisher.status).font(.system(size: 12))
                Spacer()
            }.padding(12).background(theme.color.opacity(0.08))
            if !publisher.warnings.isEmpty {
                Text(publisher.warnings.joined(separator: "  ")).font(.system(size: 11)).foregroundStyle(.secondary).padding(10).frame(maxWidth: .infinity, alignment: .leading)
            }
            Browser(web: publisher.backend)
        }.frame(width: 1100, height: 790).tint(theme.color)
        .onAppear { publisher.start(article, theme: theme, layout: layout) }
        .onDisappear { publisher.stop() }
        .onChange(of: layout) { publisher.start(article, theme: theme, layout: layout) }
    }
}
