# 架构

`OneShowApp` 组合 `ContentView`，文章模型通过 `Article.displayBody` 提供标题编号和隐私星号保护后的显示正文。`ArticleLibrary` 负责现有 JSON 数据存储、导入与导出；存储位置与 Codable 字段保持兼容。

本地 `MarkdownPreview` 使用非持久 WebKit 渲染环境，加载离线 `marked.umd.js`、`markdown.js`、`highlight.js` 与 `preview.js`。先解析 Markdown、过滤 HTML，再为代码块构建带颜色的文本节点；未知语言不着色。原始编辑文本不改变。自定义 URL scheme 解析文章所在目录的本地图片，网络图片保留访问。

`highlight.js` 是本项目自有的轻量模块，并非第三方 Highlight.js 库。公众号、小红书与本地预览共用同一词法分析实现；不同画布可选择深色或浅色代码配色，避免多个实现漂移。

每个平台的原生协调器在 `Sources/Publishing/`，网页适配在 `Resources/`。平台 WebKit 使用持久会话；用于公众号转换的 worker 禁止网络加载。发布自动化可在窗口关闭时取消。CSDN 在新一轮流程中替换旧正文，仅内容回读一致后点击编辑器第一步发布按钮，不自动提交设置对话框。

主题采用稳定枚举标识与十六进制强调色；侧栏和编辑区基于强调色使用低透明度底色，旧主题标识不变。公众号文章主题与应用主题独立。

测试涵盖 Markdown 转换、标题编号、隐私掩码、代码 token 原文保真、安全节点构建和平台自动化判定。模拟 DOM 测试不证明第三方网站端到端可用；发布适配需要实际页面验证。
