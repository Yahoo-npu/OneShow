import SwiftUI
import WebKit

struct Browser: NSViewRepresentable { let web: WKWebView; func makeNSView(context: Context) -> WKWebView { web }; func updateNSView(_ view: WKWebView, context: Context) {} }
