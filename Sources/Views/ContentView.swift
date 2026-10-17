import SwiftUI

struct ContentView: View {
    @StateObject var library = ArticleLibrary()
    @StateObject var publisher = CSDNPublisher()
    @AppStorage("articleLibraryExpanded") var libraryExpanded = true
    @AppStorage("oneshowTheme") private var themeID = "iris"
    @State var showThemes = false
    var theme: AppTheme { AppTheme(rawValue: themeID) ?? .iris }
    @State var search = ""
    @State var mode = 1
    @State var showPublish = false
    @State var showWechat = false
    @State var showRed = false
    @State private var showPublishOptions = false
    @State var deleteConfirm = false
    let ink = Color(red: 0.16, green: 0.18, blue: 0.28)
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Image(nsImage: NSImage(contentsOf: Bundle.main.url(forResource: "OneShowB", withExtension: "icns") ?? URL(fileURLWithPath: "/")) ?? NSImage()).resizable().frame(width: 44, height: 44); Text("一休").font(.system(size: 26, weight: .bold, design: .rounded)); Text("OneShow").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.secondary) }.padding(.top, 12)
                Text("专注内容，从容分享。") .font(.system(size: 11)).foregroundStyle(.secondary)
                Button(action: { libraryExpanded = true; library.importFiles() }) { Label("导入 Markdown", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity).padding(.vertical, 7) }.buttonStyle(.borderedProminent)
                Button { withAnimation(.easeInOut(duration: 0.18)) { libraryExpanded.toggle() } } label: {
                    HStack { Image(systemName: libraryExpanded ? "chevron.down" : "chevron.right").frame(width: 10); Label("文章库", systemImage: "square.stack"); Spacer(); Text("\(library.articles.count)").foregroundStyle(.secondary) }
                        .font(.system(size: 12, weight: .semibold)).padding(.vertical, 8).frame(maxWidth: .infinity).contentShape(Rectangle())
                }.buttonStyle(.plain).help(libraryExpanded ? "收起文章库" : "展开文章库")
                if libraryExpanded {
                TextField("搜索文章", text: $search).textFieldStyle(.roundedBorder)
                ScrollView { VStack(spacing: 8) { ForEach(library.articles.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }) { a in
                    Button { library.selected = a.id } label: { VStack(alignment: .leading, spacing: 9) { Text(a.title).font(.system(size: 13, weight: .semibold)).lineLimit(2); HStack { Text("本地文档"); Spacer(); Text(a.updated, style: .date) }.font(.system(size: 10)).foregroundStyle(.secondary) }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(library.selected == a.id ? Color.white : Color.clear).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(library.selected == a.id ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)).contentShape(Rectangle()) }.buttonStyle(.plain)
                } } }
                }
                Spacer()
                Button { showThemes = true } label: {
                    HStack { Image(systemName: "paintpalette"); Text("主题色"); Spacer(); Circle().fill(theme.color).frame(width: 12, height: 12); Text(theme.name).foregroundStyle(.secondary) }.font(.system(size: 12)).padding(.vertical, 10).contentShape(Rectangle())
                }.buttonStyle(.plain).popover(isPresented: $showThemes, arrowEdge: .trailing) { themePicker }
                Divider()
                Label("CSDN / 公众号 / 小红书 · 网页登录", systemImage: "globe.asia.australia").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(22).frame(width: 240).background(theme.sidebar)
            VStack(spacing: 0) {
                HStack { VStack(alignment: .leading, spacing: 3) { Text("发布工作台").font(.system(size: 14, weight: .semibold)); Text("ONCE WRITTEN. WELL SHARED.").font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(.secondary) }; Spacer(); Menu { Button("导出原始 Markdown", action: library.export); Button("导出编号 Markdown", action: library.exportNumbered); Button("导出 CSDN 兼容版", action: library.exportCompatible) } label: { Image(systemName: "square.and.arrow.up") }.help("导出原文或兼容版"); Button { deleteConfirm = true } label: { Image(systemName: "trash") }.help("删除当前草稿"); Button { showPublishOptions.toggle() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "paperplane.fill")
                        Text("发布文章")
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 140, height: 38)
                    .background(theme.color)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("发布文章")
                .disabled(library.index == nil)
                .popover(isPresented: $showPublishOptions, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            showPublishOptions = false
                            showPublish = true
                            if let i = library.index { publisher.start(library.articles[i]) }
                        } label: {
                            Label("发布到 CSDN", systemImage: "paperplane").frame(maxWidth: .infinity, alignment: .leading).padding(10).contentShape(Rectangle())
                        }
                        Button {
                            showPublishOptions = false
                            showWechat = true
                        } label: {
                            Label("发布到微信公众号", systemImage: "text.bubble").frame(maxWidth: .infinity, alignment: .leading).padding(10).contentShape(Rectangle())
                        }
                        Button { showPublishOptions = false; showRed = true } label: {
                            Label("发布到小红书", systemImage: "photo.stack").frame(maxWidth: .infinity, alignment: .leading).padding(10).contentShape(Rectangle())
                        }
                    }.buttonStyle(.plain).padding(8).frame(width: 220)
                } }.padding(20)
                Divider()
                if let i = library.index {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack { Text("READY TO SHARE / 待发布").font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Color.accentColor); Spacer(); Text("\(library.articles[i].body.count) 字符").font(.system(size: 11)).foregroundStyle(.secondary) }
                        TextField("文章标题", text: $library.articles[i].title).textFieldStyle(.plain).font(.system(size: 28, weight: .bold, design: .rounded))
                        HStack { Label("Markdown", systemImage: "text.alignleft").font(.system(size: 11)).foregroundStyle(.secondary); Toggle("标题编号", isOn: Binding(get: { library.articles[i].numberHeadings == true }, set: { library.articles[i].numberHeadings = $0 })).toggleStyle(.switch).controlSize(.small).font(.system(size: 11)); Button(action: library.redactPrivacy) { Label("隐私抹除", systemImage: "lock.shield") }.buttonStyle(.bordered).font(.system(size: 11)).help("替换可识别的凭据、联系方式、个人路径、私有文档与仓库链接；原始文件不变"); if library.canUndoPrivacy { Button("撤销抹除", action: library.undoPrivacy).font(.system(size: 11)).help("恢复本次抹除前的标题和正文；关闭应用后无法撤销") }; Spacer(); Picker("视图", selection: $mode) { Text("编辑").tag(0); Text("双栏").tag(1); Text("预览").tag(2) }.pickerStyle(.segmented).frame(width: 205) }
                    }.padding(26)
                    Divider()
                    HStack(spacing: 0) {
                        if mode != 2 { TextEditor(text: $library.articles[i].body).font(.system(size: 13, design: .monospaced)).lineSpacing(6).padding(18).scrollContentBackground(.hidden).frame(maxWidth: .infinity).background(theme.editor) }
                        if mode == 1 { Divider() }
                        if mode != 0 { MarkdownPreview(article: library.articles[i]).frame(maxWidth: .infinity) }
                    }
                    HStack { Circle().fill(Color.accentColor).frame(width: 5, height: 5); Text(library.selected.flatMap { library.privacyReports[$0] } ?? library.notice); Spacer(); Text("Typora 高亮 · 图片预览 · ⌘O 导入") }.font(.system(size: 10)).foregroundStyle(.secondary).padding(13)
                } else { ContentUnavailableView("导入你的第一篇笔记", systemImage: "doc.badge.arrow.up", description: Text("在 Typora 完成写作后，点击左侧按钮导入 Markdown 文档")) }
            }.background(Color.white)
        }.foregroundStyle(ink).frame(minWidth: 1050, minHeight: 690).tint(theme.color).accentColor(theme.color).preferredColorScheme(.light)
        .onChange(of: library.articles) { library.save() }
        .alert("删除当前草稿？", isPresented: $deleteConfirm) { Button("取消", role: .cancel) {}; Button("删除", role: .destructive) { if let i = library.index { library.articles.remove(at: i); library.selected = library.articles.first?.id; library.save() } } } message: { Text("此操作无法撤销，请先导出需要保留的文章。") }
        .sheet(isPresented: $showPublish) { publishing }
        .sheet(isPresented: $showRed) { if let i = library.index { XiaohongshuPublishingView(article: library.articles[i], theme: theme) } }
        .sheet(isPresented: $showWechat) { if let i = library.index { WechatPublishingView(article: library.articles[i], theme: theme) } }
        .background { Button("") { libraryExpanded = true; library.importFiles() }.keyboardShortcut("o").hidden() }
    }
    var themePicker: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) { Text("选择你的主题色").font(.system(size: 17, weight: .semibold)); Text("让工作台带一点你的风格").font(.system(size: 12)).foregroundStyle(.secondary) }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(78)), count: 4), spacing: 18) {
                ForEach(AppTheme.allCases) { option in
                    Button { themeID = option.rawValue } label: {
                        VStack(spacing: 8) {
                            ZStack { Circle().fill(option.color).frame(width: 36, height: 36); if theme == option { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white) } }
                            Text(option.name).font(.system(size: 11)).foregroundStyle(.primary)
                        }.frame(width: 78).padding(.vertical, 8).background(theme == option ? option.color.opacity(0.09) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 12)).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(option.name + (theme == option ? "，已选中" : ""))
                }
            }
            Text("即时生效 · 自动记住选择").font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(24).frame(width: 414)
    }
    var publishing: some View {
        VStack(spacing: 0) {
            HStack { VStack(alignment: .leading, spacing: 5) { Text("分享你的下一篇好文章").font(.title2.bold()); Text("登录后自动填入标题与正文，并打开发布设置").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("关闭") { publisher.stop(); showPublish = false } }.padding(22)
            HStack { Image(systemName: "info.circle"); Text(publisher.status).font(.system(size: 12)); Spacer(); if publisher.busy { ProgressView().controlSize(.small) } }.padding(14).background(Color.accentColor.opacity(0.08))
            Browser(web: publisher.web)

        }.frame(width: 1100, height: 760).tint(theme.color).onDisappear { publisher.stop() }
    }
}
