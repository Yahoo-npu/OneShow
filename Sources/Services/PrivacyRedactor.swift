import Foundation

struct PrivacyRedactor {
    struct Result { let text: String; let count: Int; let maskedRanges: [NSRange] }
    static func redact(_ source: String) -> Result {
        let original = source as NSString
        var ranges: [NSRange] = []
        func collect(_ pattern: String, group: Int = 0) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            for match in regex.matches(in: source, range: NSRange(location: 0, length: original.length)) {
                let range = match.range(at: group)
                guard range.location != NSNotFound, range.length > 0 else { continue }
                let text = original.substring(with: range)
                // Already-masked fields remain unchanged and are not counted again.
                if text.contains(where: { $0 != "*" && !$0.isWhitespace }) { ranges.append(range) }
            }
        }
        let field = #"(?:(?:[a-z][a-z0-9]*[_-])*(?:api(?:[_-]?(?:key|token|secret))?|(?:access|refresh|auth|bearer|private|public|secret|signing|client|encryption)[_-]?(?:key|token|secret)|token|key|secret|password|passwd|pwd|authorization|cookie|x-api-key)|密码|口令|密钥|令牌)"#
        let value = #"(?:\"\"\"([\s\S]*?)\"\"\"|'''([\s\S]*?)'''|`([^`\r\n]*)`|\"([^\"\r\n]*)\"|'([^'\r\n]*)'|([^\s,;}\]\r\n]+))"#
        // Capture only the value; keep variable names, quotes, and Markdown/code fences.
        let assignment = #"(?im)(?<![\w?&/])"# + field + #"\s*[\"']?\s*\]?\s*[:=：]\s*"# + value
        for group in 1...6 { collect(assignment, group: group) }
        collect(#"(?im)--(?:api[-_]?(?:key|token)|token|key|secret|password)(?:=|\s+)(?:\"([^\"]+)\"|'([^']+)'|([^\s]+))"#, group: 1)
        collect(#"(?im)--(?:api[-_]?(?:key|token)|token|key|secret|password)(?:=|\s+)(?:\"([^\"]+)\"|'([^']+)'|([^\s]+))"#, group: 2)
        collect(#"(?im)--(?:api[-_]?(?:key|token)|token|key|secret|password)(?:=|\s+)(?:\"([^\"]+)\"|'([^']+)'|([^\s]+))"#, group: 3)
        collect(#"(?i)\b(?:Bearer|Basic)\s+([A-Za-z0-9+/_.=\-]+)"#, group: 1)
        collect(#"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----[\s\S]*?-----END (?:[A-Z0-9]+ )*PRIVATE KEY-----"#)
        collect(#"\b(?:sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[A-Z0-9]{16}|LTAI[A-Za-z0-9]{16,}|eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)\b"#)
        collect(#"(?im)^\s*(?:Cookie|Set-Cookie|Authorization)\s*:\s*([^\r\n]+)"#, group: 1)
        collect(#"(?i)https?://([^\s/@:]+:[^\s/@]+)@"#, group: 1)
        collect(#"(?i)[?&](?:api|key|password|passwd|token|access_token|refresh_token|api_key|secret|signature|sign|x-amz-signature|x-amz-credential|x-oss-signature|ossaccesskeyid)\s*=([^&#\s<>\"')]+)"#, group: 1)
        collect(#"(?i)https?://(?:[a-z0-9-]+\.)?(?:feishu\.cn|larksuite\.com)/(?:wiki|docx|docs|sheets|base|file)/[^\s<>\"')]+"#)
        collect(#"(?i)https?://(?:github\.com|gitlab\.com)/[^\s/<>]+/[^\s<>\"')]+"#)
        collect(#"(?i)(?:/Users/|/home/)([^/\s<>\"'`]+)"#, group: 1)
        collect(#"(?i)[A-Z]:\\Users\\([^\\\s<>\"'`]+)"#, group: 1)
        collect(#"(?i)\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b"#)
        collect(#"(?<![\d])(?:\+?86[ -]?)?1[3-9]\d{9}(?![\d])"#)
        collect(#"(?<![A-Za-z0-9])\d{17}[0-9Xx](?![A-Za-z0-9])"#)
        collect(#"(?<![\d.])(?:10\.(?:\d{1,3}\.){2}\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})(?![\d.])"#)
        collect(#"(?im)(?:作者|姓名|联系人|负责人)\s*[:：]\s*([^\s，,。；;<>`]+)"#, group: 1)
        // Merge overlapping detectors to mask each original character only once.
        var merged: [NSRange] = []
        for range in ranges.sorted(by: { $0.location < $1.location }) {
            if let last = merged.last, range.location < NSMaxRange(last) {
                merged[merged.count - 1] = NSUnionRange(last, range)
            } else { merged.append(range) }
        }
        var output = "", cursor = 0
        var maskedRanges: [NSRange] = []
        for range in merged {
            output += original.substring(with: NSRange(location: cursor, length: range.location - cursor))
            let text = original.substring(with: range)
            let stars = text.map { $0.isNewline ? String($0) : "*" }.joined()
            maskedRanges.append(NSRange(location: output.utf16.count, length: stars.utf16.count))
            output += stars; cursor = NSMaxRange(range)
        }
        output += original.substring(from: cursor)
        return Result(text: output, count: merged.count, maskedRanges: maskedRanges)
    }
}
