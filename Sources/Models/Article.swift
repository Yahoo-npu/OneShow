import Foundation

struct Article: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var body: String
    var tags = "Swift, macOS"
    var summary = ""
    var updated = Date()
    var sourcePath: String?
    var imageDirectory: String?
    var numberHeadings: Bool?
    var privacyPreviewSource: String?
    var privacyPreviewBody: String?
    var displayBody: String {
        let text = body == privacyPreviewSource ? (privacyPreviewBody ?? body) : body
        return numberHeadings == true ? MarkdownSupport.number(text) : text
    }
}
