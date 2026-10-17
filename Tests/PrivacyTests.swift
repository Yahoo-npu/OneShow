import Foundation
@main struct PrivacyTests {
    static func main() {
        func check(_ source: String, _ expected: String) {
            let result = PrivacyRedactor.redact(source)
            precondition(result.text == expected, "Unexpected result for test: \(source) => \(result.text)")
            precondition(result.text.count == source.count, "Character count changed")
            precondition(PrivacyRedactor.redact(result.text).text == result.text, "Not idempotent")
        }
        check("api = \"abcdef\"", "api = \"******\"")
        check("API_KEY='abc123'", "API_KEY='******'")
        check("const apiKey = \"abc123\";", "const apiKey = \"******\";")
        check("token: `中文密钥`", "token: `****`")
        check("OPENAI_API_KEY=abc123", "OPENAI_API_KEY=******")
        check("SECRET_KEY: abc123", "SECRET_KEY: ******")
        check("{\"key\":\"abcdef\",\"token\":\"123456\"}", "{\"key\":\"******\",\"token\":\"******\"}")
        check("headers[\"X-API-Key\"] = \"abc123\"", "headers[\"X-API-Key\"] = \"******\"")
        check("curl --api-key abc123 --token='123456'", "curl --api-key ****** --token='******'")
        check("Authorization: Bearer abc123", "Authorization: *************")
        check("作者：张三", "作者：**")
        check("/Users/alice/a.md", "/Users/*****/a.md")
        check("联系 demo@example.org", "联系 ****************")
        check("https://example.org/a?token=abc123&size=100", "https://example.org/a?token=******&size=100")
        check("```python\napi_key = \"abc123\"\n```", "```python\napi_key = \"******\"\n```")
        check("password = \"👨‍👩‍👧‍👦你好\"", "password = \"***\"")
        check("普通 Markdown\n==高亮==\n![图](https://example.org/a.png)", "普通 Markdown\n==高亮==\n![图](https://example.org/a.png)")
        let source = "Password: `sample-password-123`\nCookie: a=abc; b=def\n13800000000\n110101199001011234\n10.1.2.3\nhttps://team.feishu.cn/wiki/ExampleSecret\nhttps://github.com/team/repo\n-----BEGIN PRIVATE KEY-----\nprivate-material\n-----END PRIVATE KEY-----"
        let result = PrivacyRedactor.redact(source)
        for secret in ["sample-password", "a=abc", "13800000000", "110101199001011234", "10.1.2.3", "ExampleSecret", "team/repo", "private-material"] { precondition(!result.text.contains(secret)) }
        precondition(result.text.count == source.count)
        precondition(PrivacyRedactor.redact(result.text).count == 0)
        print("通过：等长星号、Unicode字符、API/token/key、代码与JSON、请求头、命令行、凭据、路径与重复处理。")
    }
}
