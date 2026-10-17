# GitHub 发布指南

## 首次建库

本次仅准备源码与交付包，不创建远程仓库、不上传或推送。历史 `outputs/`、`work/`、`.build/`、`dist/` 保留本地但不纳入 Git。不要使用强制添加绕过忽略规则。

首次公开前选定项目许可，并在根目录加入对应 `LICENSE`；当前未代替维护者选择许可。保留 marked 的第三方声明。核对图标等素材的授权范围。

```sh
git init
git add .
git diff --cached --stat
git diff --cached
# 检查待提交内容后再提交、创建远程仓库并推送。
```

## 版本与验证

1. 更新 `Config/Info.plist` 的显示版本和构建号，更新 `CHANGELOG.md`。
2. 执行 `zsh scripts/test.sh` 和 `zsh scripts/build.sh`。
3. 检查原生界面、已有文章库升级读取、本地预览和平台填入；不要公开发布测试文章。
4. 执行 `zsh scripts/package.sh`。上传 `dist/release/` 中对应架构的 ZIP 到 GitHub Release。
5. 公告中说明系统和架构、签名公证状态、平台适配的实测范围。

GitHub Actions 在 macOS runner 执行测试和构建，上传临时签名应用的 ZIP 为工作流产物；不会自动创建 Release 或公开文章。工作流添加到 GitHub 后才会运行，本次未执行远程 CI。

正式面向大众分发时，应配置 Developer ID 签名和 Apple 公证。证书、私钥、密码放入受限的 CI secrets，不能加入源码。

需要独立的干净源码包时，运行 `python3 scripts/source-archive.py`。脚本按明确目录清单打包，不包含本地账户数据、历史安装包或调试目录。解压后即可作为 GitHub 仓库根目录。
