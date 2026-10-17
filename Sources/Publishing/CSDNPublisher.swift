import SwiftUI
import WebKit

@MainActor final class CSDNPublisher: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var status = "正在打开 CSDN Markdown 编辑器…"
    @Published var busy = false
    let web: WKWebView = { let config = WKWebViewConfiguration(); config.websiteDataStore = .default(); return WKWebView(frame: .zero, configuration: config) }()
    private var task: Task<Void, Never>?
    private var run = UUID()
    override init() { super.init(); web.navigationDelegate = self }
    func stop() { run = UUID(); task?.cancel(); task = nil; busy = false }
    func start(_ article: Article) {
        stop(); let id = run
        guard let prepared = MarkdownSupport.prepare(article.displayBody), let body = prepared["body"] as? String else { status = "Markdown 格式转换失败，请重新打开应用。"; return }
        let localCount = (prepared["localImages"] as? [String])?.count ?? 0
        let warning = localCount > 0 ? " 另有 \(localCount) 张本地图片需在网页上传替换。" : ""
        busy = true; status = "正在打开 Markdown 编辑器，登录后自动填入…" + warning
        web.load(URLRequest(url: URL(string: "https://editor.csdn.net/md/")!))
        task = Task { [weak self] in
            guard let self else { return }
            do {
                var ready = false
                for _ in 0..<600 {
                    guard self.run == id, !Task.isCancelled else { return }
                    if self.web.url?.host == "editor.csdn.net", !self.web.isLoading,
                       let state = try? await self.script("return oneShowCSDNRead()") as? [String: Any], state["ready"] as? Bool == true { ready = true; break }
                    try await Task.sleep(for: .seconds(1))
                }
                guard self.run == id else { return }
                guard ready else { self.busy = false; self.status = "等待登录或编辑器超时，请关闭后重新点击发布。"; return }
                self.status = "正在替换旧内容并填入当前文章…" + warning
                self.web.window?.makeFirstResponder(self.web)
                let mode = try await self.script("return oneShowCSDNFill(title, body)", arguments: ["title":article.title, "body":body]) as? String
                guard self.run == id else { return }
                if mode == "paste" {
                    try await Task.sleep(for: .milliseconds(200))
                    guard self.run == id else { return }
                    let clipboard = NSPasteboard.general
                    let original = (clipboard.pasteboardItems ?? []).map { item in item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in item.data(forType: type).map { (type, $0) } } }
                    clipboard.clearContents(); clipboard.setString(body, forType: .string); let owned = clipboard.changeCount
                    let accepted = NSApp.sendAction(#selector(NSText.paste(_:)), to: self.web.window?.firstResponder, from: nil)
                    try? await Task.sleep(for: .milliseconds(700))
                    if clipboard.changeCount == owned {
                        clipboard.clearContents()
                        let restored = original.map { values -> NSPasteboardItem in let item = NSPasteboardItem(); for (type, data) in values { item.setData(data, forType: type) }; return item }
                        clipboard.writeObjects(restored)
                    }
                    guard self.run == id else { return }
                    guard accepted else { self.busy = false; self.status = "网页未接收粘贴，请关闭窗口后重试。"; return }
                } else if mode != "verify" { self.busy = false; self.status = "编辑器未就绪，请关闭后重试。"; return }
                for _ in 0..<20 {
                    try await Task.sleep(for: .milliseconds(500))
                    guard self.run == id, !Task.isCancelled else { return }
                    let result = try await self.script("return oneShowCSDNPublish(title, body)", arguments: ["title":article.title, "body":body]) as? String
                    guard self.run == id else { return }
                    if result == "opened" { self.busy = false; self.status = "标题和正文已核对，已自动点击「发布文章」。请在网页完善标签等必填项并确认最终发布。" + warning; return }
                }
                self.busy = false; self.status = "未能确认正文或发布入口，已停止自动操作，请检查网页。" + warning
            } catch {
                guard self.run == id else { return }
                self.busy = false; self.status = "自动填入失败：\(error.localizedDescription)。请关闭后重试。"
            }
        }
    }
    private func script(_ call: String, arguments: [String: Any] = [:]) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            web.callAsyncJavaScript(MarkdownSupport.resource("csdn-editor") + "\n" + call, arguments: arguments, in: nil, in: .page) { result in continuation.resume(with: result) }
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        stop(); status = "页面加载失败：\(error.localizedDescription)"
    }
}
