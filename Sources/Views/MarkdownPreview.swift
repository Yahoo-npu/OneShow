import SwiftUI
import WebKit

struct MarkdownPreview: NSViewRepresentable {
    let article: Article
    @AppStorage("oneshowTheme") private var themeID = "iris"
    var theme: AppTheme { AppTheme(rawValue: themeID) ?? .iris }
    class Coordinator: NSObject, WKURLSchemeHandler, WKNavigationDelegate {
        var article: Article
        var loaded = false
        var resetScroll = true
        var themeHex = "#5558AA"
        init(_ article: Article) { self.article = article }
        func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
            guard let address = urlSchemeTask.request.url,
                  let src = URLComponents(url: address, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "src" })?.value,
                  let file = MarkdownSupport.resolveImage(src, article: article), file.isFileURL else {
                urlSchemeTask.didFailWithError(NSError(domain: "Mojian.Image", code: 1)); return
            }
            let types = ["png":"image/png", "jpg":"image/jpeg", "jpeg":"image/jpeg", "gif":"image/gif", "webp":"image/webp", "bmp":"image/bmp", "heic":"image/heic", "tiff":"image/tiff"]
            guard let mime = types[file.pathExtension.lowercased()], let bytes = try? Data(contentsOf: file), NSImage(data: bytes) != nil else { urlSchemeTask.didFailWithError(NSError(domain: "Mojian.Image", code: 2)); return }
            urlSchemeTask.didReceive(URLResponse(url: address, mimeType: mime, expectedContentLength: bytes.count, textEncodingName: nil)); urlSchemeTask.didReceive(bytes); urlSchemeTask.didFinish()
        }
        func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded = true; update(webView) }
        func update(_ web: WKWebView) {
            guard loaded else { return }
            web.callAsyncJavaScript("document.documentElement.style.setProperty('--accent', accent); updatePreview(source); if (reset) window.scrollTo(0, 0)", arguments: ["source":article.displayBody, "reset":resetScroll, "accent":themeHex], in: nil, in: .page) { _ in }; resetScroll = false
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url, ["http","https","mailto"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
    }
    func makeCoordinator() -> Coordinator { let coordinator = Coordinator(article); coordinator.themeHex = theme.hex; return coordinator }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent(); config.setURLSchemeHandler(context.coordinator, forURLScheme: "mojian-image")
        let web = WKWebView(frame: .zero, configuration: config); web.navigationDelegate = context.coordinator
        let js = MarkdownSupport.resource("marked.umd") + "\n" + MarkdownSupport.resource("markdown") + "\n" + MarkdownSupport.resource("highlight") + "\n" + MarkdownSupport.resource("preview")
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: http: mojian-image:; style-src 'unsafe-inline'; script-src 'unsafe-inline';"><style>
        body{margin:0;color:#293b3b;background:#fff;font:15px -apple-system,BlinkMacSystemFont,sans-serif;line-height:1.85}#paper{padding:28px 32px;overflow-wrap:anywhere}h1{font-size:30px}h2{font-size:23px}h3{font-size:19px}h1,h2,h3,h4{line-height:1.5;margin:1.3em 0 .6em}p{margin:1em 0}mark{background:#fff0a6;color:inherit;padding:2px 4px;border-radius:3px}img{max-width:100%;height:auto;vertical-align:middle;border-radius:6px}pre{background:#1f292e;color:#b5e0cf;padding:18px;border-radius:10px;overflow-x:auto;line-height:1.65}code{font:13px Menlo,monospace}p code,li code{background:color-mix(in srgb,var(--accent) 7%,white);padding:3px 5px;border-radius:4px}blockquote{border-left:3px solid var(--accent);margin:1em 0;padding:4px 18px;background:color-mix(in srgb,var(--accent) 6%,white);color:#52606a}table{border-collapse:collapse;display:block;overflow-x:auto}th,td{border:1px solid #d9e2dc;padding:8px 14px}th{background:color-mix(in srgb,var(--accent) 7%,white)}a{color:var(--accent)}.image-error{padding:14px;margin:16px 0;border:1px dashed #cb9e63;background:#fff9ef;border-radius:8px;font-size:12px;color:#805e33}
        </style></head><body><main id="paper"></main><script>\(js)</script></body></html>
        """
        web.loadHTMLString(html, baseURL: nil); return web
    }
    func updateNSView(_ web: WKWebView, context: Context) {
        if context.coordinator.article != article || context.coordinator.themeHex != theme.hex { context.coordinator.themeHex = theme.hex; context.coordinator.resetScroll = context.coordinator.article.id != article.id; context.coordinator.article = article; context.coordinator.update(web) }
    }
}
