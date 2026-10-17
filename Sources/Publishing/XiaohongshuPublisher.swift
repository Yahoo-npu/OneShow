import SwiftUI
import WebKit
import UniformTypeIdentifiers

@MainActor final class XiaohongshuPublisher: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var images: [NSImage] = []
    @Published var status = "正在排版…"
    @Published var busy = true
    @Published var showingBackend = false
    let backend: WKWebView
    private var imageHandler: MarkdownPreview.Coordinator?
    private var article: Article?
    private var folder: URL?
    private var files: [URL] = []
    private var generation = 0
    private var monitoring: Task<Void, Never>?
    override init() {
        backend = WKWebView(frame: .zero)
        super.init()
        backend.uiDelegate = self
    }
    // Keep the rendering web view at its fixed point size, independent of preview zoom.
    func prepare(_ article: Article, accent: String) {
        if let folder { try? FileManager.default.removeItem(at: folder) }; folder = nil
        generation += 1; images = []; files = []; busy = true; self.article = article
        let handler = MarkdownPreview.Coordinator(article); imageHandler = handler
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(handler, forURLScheme: "mojian-image")
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 800), configuration: config)
        activeRenderer = web; web.navigationDelegate = self
        pendingAccent = accent
        let scripts = ["marked.umd", "markdown", "preview", "highlight", "wechat", "cards"].map { MarkdownSupport.resource($0) }.joined(separator: "\n")
        web.loadHTMLString("""
        <!doctype html><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: http: mojian-image:; script-src 'unsafe-inline'; style-src 'unsafe-inline'"><style>
        *{box-sizing:border-box}html,body{margin:0;width:600px;height:800px;overflow:hidden;background:#fffdf8;color:#283338;font:17px -apple-system;line-height:1.85}header{position:absolute;top:27px;left:48px;right:48px;display:flex;justify-content:space-between;gap:20px;font-size:11px;color:var(--accent);border-bottom:1px solid #ddd;padding-bottom:12px}#title{overflow:hidden;white-space:nowrap;text-overflow:ellipsis;max-width:380px}.viewport{position:absolute;left:48px;top:84px;width:504px;height:650px;overflow:hidden}#paper{width:504px;height:650px;column-width:504px;column-gap:96px;column-fill:auto;overflow-wrap:anywhere}#paper>*{margin-top:0;margin-bottom:18px}h1,h2,h3,h4,h5,h6{line-height:1.45;color:var(--accent);break-after:avoid}h1{font-size:31px}h2{font-size:25px}h3{font-size:21px}img{max-width:100%;max-height:590px;object-fit:contain;height:auto;zoom:1!important}pre,blockquote,table,figure,img{break-inside:avoid}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f0f2f4;border-radius:12px;padding:16px;font:12px/1.7 Menlo}code{font-family:Menlo;font-size:.85em}p{orphans:3;widows:3}blockquote{margin-left:0;padding:10px 18px;border-left:3px solid var(--accent);background:#f2f3f2}mark{background:#ffe28a;color:inherit}table{border-collapse:collapse;width:100%;font-size:13px}td,th{border:1px solid #ccc;padding:6px}a{color:var(--accent)}footer{position:absolute;bottom:25px;left:48px;right:48px;display:flex;justify-content:space-between;font-size:11px;color:#8b9396}.missing{border:1px dashed #b67f45;padding:12px;color:#92612f}
        </style><header><span id="title"></span><span>ONESHOW</span></header><div class="viewport"><main id="paper"></main></div><footer><span>一休 · OneShow</span><span id="page"></span></footer><script>\(scripts)</script>
        """, baseURL: nil)
    }
    private var activeRenderer: WKWebView?
    private var pendingAccent = "#5558aa"
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === activeRenderer, let article else { return }
        let revision = generation
        webView.callAsyncJavaScript("return await makeCards(source, title, accent)", arguments: ["source":article.displayBody, "title":article.title, "accent":pendingAccent], in: nil, in: .page) { result in Task { @MainActor in
            guard revision == self.generation else { return }
            do {
                let value = try result.get() as? [String: Any]
                guard let count = value?["count"] as? Int, count > 0, count <= 100 else { throw NSError(domain: "图片页数过多，请拆分文章后重试", code: 1) }
                let missing = value?["missing"] as? Int ?? 0
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("OneShow-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                self.folder = folder
                for index in 0..<count {
                    guard revision == self.generation else { return }
                    _ = try await webView.evaluateJavaScript("showCard(\(index), \(count))")
                    try await Task.sleep(for: .milliseconds(100))
                    let config = WKSnapshotConfiguration(); config.rect = NSRect(x: 0, y: 0, width: 600, height: 800); config.snapshotWidth = 1080
                    let image = try await webView.takeSnapshot(configuration: config)
                    guard revision == self.generation else { return }
                    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1080, pixelsHigh: 1440, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw NSError(domain: "图片转换失败", code: 2) }
                    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
                    image.draw(in: NSRect(x: 0, y: 0, width: 1080, height: 1440), from: .zero, operation: .copy, fraction: 1)
                    NSGraphicsContext.restoreGraphicsState()
                    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "PNG 转换失败", code: 3) }
                    let file = folder.appendingPathComponent(String(format: "%03d.png", index + 1))
                    try png.write(to: file); self.files.append(file); self.images.append(image)
                    self.status = "正在生成 \(index + 1) / \(count) 张图片…"
                }
                self.busy = false
                self.status = "已生成 \(count) 张 1080 × 1440 图片" + (missing > 0 ? "；\(missing) 张原图加载失败，请修复后重新生成。" : "，可预览后发布。")
            } catch { self.busy = false; self.status = "生成失败：\(error.localizedDescription)" }
        } }
    }
    func export() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true; panel.prompt = "导出图片"
        guard panel.runModal() == .OK, let root = panel.url else { return }
        do {
            let target = root.appendingPathComponent("OneShow-图文-" + String(UUID().uuidString.prefix(8)))
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            for file in files { try FileManager.default.copyItem(at: file, to: target.appendingPathComponent(file.lastPathComponent)) }
            NSWorkspace.shared.activateFileViewerSelecting([target]); status = "图片已按页码导出。"
        } catch { status = "导出失败：\(error.localizedDescription)" }
    }
    func publish() {
        showingBackend = true
        backend.load(URLRequest(url: URL(string: "https://creator.xiaohongshu.com/publish/publish?target=image")!))
        status = "请登录并选择上传图文；点击上传图片时将自动选择本次生成的图片。最后请在网页确认发布。"
        monitoring?.cancel()
        monitoring = Task { [weak self] in
            for _ in 0..<600 {
                guard !Task.isCancelled, let self else { return }
                if self.backend.url?.host == "creator.xiaohongshu.com", let title = self.article?.title {
                    self.backend.callAsyncJavaScript("""
                    const field = [...document.querySelectorAll('input[placeholder],textarea[placeholder]')].find(e => /标题/.test(e.placeholder) && e.getBoundingClientRect().width > 0);
                    if (field && !field.value && !field.dataset.oneshowFilled) {
                      const setter = Object.getOwnPropertyDescriptor(field.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype, 'value').set;
                      setter.call(field, title); field.dispatchEvent(new Event('input', {bubbles:true})); field.dispatchEvent(new Event('change', {bubbles:true})); field.dataset.oneshowFilled = 'true';
                    }
                    """, arguments: ["title":title], in: nil, in: .page) { _ in }
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        guard webView.url?.host == "creator.xiaohongshu.com", frame.request.url?.host == "creator.xiaohongshu.com", parameters.allowsMultipleSelection, !files.isEmpty else {
            let panel = NSOpenPanel(); panel.allowsMultipleSelection = parameters.allowsMultipleSelection
            completionHandler(panel.runModal() == .OK ? panel.urls : nil); return
        }
        completionHandler(files)
        status = "已将图片交给网页上传，请检查上传结果、标题与配文后确认发布。"
    }
    func stop() { monitoring?.cancel(); monitoring = nil; generation += 1; activeRenderer?.stopLoading(); backend.stopLoading(); if let folder { try? FileManager.default.removeItem(at: folder) }; folder = nil }
}

struct XiaohongshuPublishingView: View {
    let article: Article
    let theme: AppTheme
    @StateObject private var publisher = XiaohongshuPublisher()
    @State private var palette = "#5558aa"
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) { Text("发布到小红书").font(.title3.bold()); Text("把笔记变成可分享的图文 · 3:4").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if !publisher.showingBackend {
                    Picker("排版", selection: $palette) { Text("鸢尾紫").tag("#5558aa"); Text("松石绿").tag("#26765e"); Text("暖杏棕").tag("#a65f36"); Text("简约黑").tag("#242424") }.frame(width: 170).disabled(publisher.busy)
                    Button("导出图片") { publisher.export() }.disabled(publisher.busy || publisher.images.isEmpty)
                    Button("发布到小红书") { publisher.publish() }.buttonStyle(.borderedProminent).disabled(publisher.busy || publisher.images.isEmpty)
                }
                Button("关闭") { publisher.stop(); dismiss() }
            }.padding(20)
            HStack { if publisher.busy { ProgressView().controlSize(.small) }; Text(publisher.status).font(.caption); Spacer() }.padding(.horizontal, 20).padding(.bottom, 12)
            Divider()
            if publisher.showingBackend { Browser(web: publisher.backend) }
            else { ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 330))], spacing: 24) {
                ForEach(Array(publisher.images.enumerated()), id: \.offset) { index, image in
                    VStack { Image(nsImage: image).resizable().aspectRatio(3/4, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: .black.opacity(0.08), radius: 8); Text("第 \(index + 1) 页").font(.caption).foregroundStyle(.secondary) }
                }
            }.padding(28) }.background(Color(nsColor: .windowBackgroundColor)) }
        }.frame(width: 1100, height: 790).tint(theme.color)
        .onAppear { publisher.prepare(article, accent: palette) }
        .onChange(of: palette) { publisher.prepare(article, accent: palette) }
        .onDisappear { publisher.stop() }
    }
}
