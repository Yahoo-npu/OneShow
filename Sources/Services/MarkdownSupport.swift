import Foundation
import JavaScriptCore

enum MarkdownSupport {
    static func resource(_ name: String) -> String { guard let url = Bundle.main.url(forResource: name, withExtension: "js") else { return "" }; return (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
    static func prepare(_ source: String) -> [String: Any]? {
        guard let context = JSContext() else { return nil }
        context.evaluateScript(resource("marked.umd")); context.evaluateScript(resource("markdown"))
        return context.objectForKeyedSubscript("MojianMarkdown")?.objectForKeyedSubscript("prepare")?.call(withArguments: [source])?.toDictionary() as? [String: Any]
    }
    static func protectMasks(_ source: String, ranges: [NSRange]) -> String {
        guard let context = JSContext() else { return source }
        context.evaluateScript(resource("marked.umd")); context.evaluateScript(resource("markdown"))
        return context.objectForKeyedSubscript("MojianMarkdown")?.objectForKeyedSubscript("protectPrivacyMasks")?.call(withArguments: [source, ranges.map { [$0.location, $0.length] }])?.toString() ?? source
    }
    static func number(_ source: String) -> String {
        guard let context = JSContext() else { return source }
        context.evaluateScript(resource("marked.umd")); context.evaluateScript(resource("markdown"))
        return context.objectForKeyedSubscript("MojianMarkdown")?.objectForKeyedSubscript("numberHeadings")?.call(withArguments: [source])?.toString() ?? source
    }
    static func resolveImage(_ src: String, article: Article) -> URL? {
        let decoded = src.removingPercentEncoding ?? src
        if decoded.lowercased().hasPrefix("file:") { return URL(string: src) }
        if let scheme = URL(string: decoded)?.scheme, !scheme.isEmpty { return nil }
        let base = article.imageDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? article.sourcePath.map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
        var rootValue = ""
        let lines = article.body.components(separatedBy: .newlines)
        if lines.first == "---" {
            for line in lines.dropFirst() {
                if line == "---" { break }
                if line.hasPrefix("typora-root-url:") { rootValue = String(line.dropFirst("typora-root-url:".count)).trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
            }
        }
        var root = base
        if !rootValue.isEmpty {
            if rootValue.hasPrefix("/") { root = URL(fileURLWithPath: rootValue, isDirectory: true) }
            else if rootValue.hasPrefix("file:"), let url = URL(string: rootValue) { root = url }
            else if URL(string: rootValue)?.scheme == nil, let base { root = base.appendingPathComponent(rootValue, isDirectory: true) }
        }
        if decoded.hasPrefix("/") {
            if !rootValue.isEmpty, let root { return root.appendingPathComponent(String(decoded.dropFirst())).standardizedFileURL }
            return URL(fileURLWithPath: decoded)
        }
        guard let root else { return nil }; return root.appendingPathComponent(decoded).standardizedFileURL
    }
}
