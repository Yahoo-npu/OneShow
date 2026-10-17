import SwiftUI
import UniformTypeIdentifiers

@MainActor final class ArticleLibrary: ObservableObject {
    @Published var articles: [Article] = []
    @Published var privacyReports: [UUID: String] = [:]
    @Published var privacyBackups: [UUID: (original: Article, redacted: Article)] = [:]
    @Published var selected: UUID?
    @Published var notice = "所有修改自动保存到本机"
    let file: URL
    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Mojian")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("articles.json")
        if let data = try? Data(contentsOf: file), let decoded = try? JSONDecoder().decode([Article].self, from: data) { articles = decoded }
        else { articles = [Article(title: "让写作回归专注", body: sample)] }
        selected = articles.first?.id
    }
    var index: Int? { articles.firstIndex { $0.id == selected } }
    func save() { do { try JSONEncoder().encode(articles).write(to: file, options: .atomic); notice = "已自动保存 · 本机" } catch { notice = "保存失败：\(error.localizedDescription)" } }
    func importFiles() {
        let p = NSOpenPanel(); p.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, .plainText]; p.allowsMultipleSelection = true
        if p.runModal() == .OK { for u in p.urls { do { let body = try String(contentsOf: u, encoding: .utf8); let title = body.components(separatedBy: .newlines).first(where: { $0.hasPrefix("# ") }).map { String($0.dropFirst(2)) } ?? u.deletingPathExtension().lastPathComponent; let a = Article(title: title, body: body, sourcePath: u.path, numberHeadings: true); articles.insert(a, at: 0); selected = a.id } catch { notice = "导入失败：\(error.localizedDescription)" } }; save() }
    }
    var canUndoPrivacy: Bool {
        guard let i = index, let backup = privacyBackups[articles[i].id] else { return false }
        return articles[i].title == backup.redacted.title && articles[i].body == backup.redacted.body
    }
    func redactPrivacy() {
        guard let i = index else { return }
        let original = articles[i]
        let title = PrivacyRedactor.redact(original.title), body = PrivacyRedactor.redact(original.body)
        let count = title.count + body.count
        guard count > 0 else { privacyReports[original.id] = "未发现规则可识别的隐私信息；发布前仍需人工检查"; return }
        articles[i].title = title.text; articles[i].body = body.text; articles[i].updated = Date()
        articles[i].privacyPreviewSource = body.text
        articles[i].privacyPreviewBody = MarkdownSupport.protectMasks(body.text, ranges: body.maskedRanges)
        privacyBackups[original.id] = (original, articles[i])
        privacyReports[original.id] = "已去隐私化处理 \(count) 处 · 可撤销 · 请检查剩余内容"
        save()
    }
    func undoPrivacy() {
        guard canUndoPrivacy, let i = index, let backup = privacyBackups[articles[i].id] else { return }
        articles[i].title = backup.original.title; articles[i].body = backup.original.body
        articles[i].privacyPreviewSource = backup.original.privacyPreviewSource
        articles[i].privacyPreviewBody = backup.original.privacyPreviewBody
        privacyBackups.removeValue(forKey: articles[i].id)
        privacyReports[articles[i].id] = "已撤销隐私抹除"; save()
    }
    func exportNumbered() {
        guard let i = index else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = articles[i].title + "-编号版.md"
        if panel.runModal() == .OK, let url = panel.url {
            do { try MarkdownSupport.number(articles[i].body).write(to: url, atomically: true, encoding: .utf8) } catch { notice = error.localizedDescription }
        }
    }
    func exportCompatible() {
        guard let i = index, let prepared = MarkdownSupport.prepare(articles[i].displayBody), let body = prepared["body"] as? String else { notice = "格式转换失败"; return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = articles[i].title + "-CSDN兼容版.md"
        if panel.runModal() == .OK, let url = panel.url {
            do { try body.write(to: url, atomically: true, encoding: .utf8); notice = "已导出兼容版；本地图片发布前需上传" } catch { notice = error.localizedDescription }
        }
    }
    func export() { guard let i = index else { return }; let p = NSSavePanel(); p.nameFieldStringValue = articles[i].title + ".md"; if p.runModal() == .OK, let u = p.url { do { try articles[i].body.write(to: u, atomically: true, encoding: .utf8) } catch { notice = error.localizedDescription } } }
}
