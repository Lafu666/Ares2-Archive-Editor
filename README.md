# Ares2存档修改器 — iOS WebView 壳工程

把 `Ares2存档修改器.html` 用 WKWebView 包成原生 iOS App 的工程。HTML 已内嵌
sql.js 的 wasm（base64），完全离线运行；壳里额外处理了 iOS 上不可靠的 blob 下载，
转成系统分享面板（可"存储到文件 App"）。部署目标 iOS 14.0，兼容 iOS 14 ~ iOS 18（含 iOS 17）。

> **两种打包方式：** ① GitHub Actions 云端自动构建（推荐，无需 Mac）；② 本地 Xcode 手动打包。
> 详见下文。两种方式最终都要解决"签名"才能装到 iPhone——见末尾"关于签名与安装"。

## 目录结构
```
Ares2SaveEditor/
├── .github/workflows/build.yml       # GitHub Actions 自动构建流水线
├── scripts/sign-and-export.sh        # 可选：真签名导出脚本
├── Ares2SaveEditor.xcodeproj/        # Xcode 工程文件
└── Ares2SaveEditor/
    ├── AppDelegate.swift             # 程序入口，创建窗口
    ├── ViewController.swift          # WKWebView + 下载拦截 + JS 面板
    ├── WebViewMessageHandler.swift   # 接收 JS 的保存请求 → 分享面板
    ├── Info.plist
    ├── index.html                    # 你的存档修改器（已内置）
    └── Assets.xcassets/              # App 图标 + 强调色
```

---

## 方式一：GitHub Actions 自动构建（推荐，无需 Mac）

把整个 `Ares2SaveEditor` 文件夹推到你的 GitHub 仓库（或 Fork），流水线会在 GitHub
免费的 macOS runner 上用 Xcode 编译出 arm64 二进制并打包成 ipa。

### A. 默认：未签名 ipa（零配置，立刻可用）
1. 把工程推到 GitHub。
2. 仓库 **Actions** 页 → 选 `Build IPA` → **Run workflow**。
3. 约 5–8 分钟构建完成 → 点进本次运行 → 滚到底 **Artifacts** 区下载
   `Ares2SaveEditor-unsigned-ipa`（解压得到 `Ares2SaveEditor-unsigned.ipa`）。
4. 该 ipa **未签名**，需用 [Sideloadly](https://sideloadly.io) 或
   [AltStore](https://altstore.io) 用你自己的 Apple ID 重签后安装到 iOS 17（见末尾）。

### B. 可选：真签名 ipa（需付费开发者账号 $99/年）
配好以下 **Secrets**（仓库 Settings → Secrets and variables → Actions → New secret），
再到 **Variables** 里加一个 `ENABLE_SIGNING = true`，流水线会自动签名导出可直装 ipa：

| Secret | 说明 |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | 开发者证书 `.p12` 的 base64：`base64 -i cert.p12 \| pbcopy` |
| `P12_PASSWORD` | `.p12` 的导出密码 |
| `BUILD_PROVISION_BASE64` | `.mobileprovision` 的 base64：`base64 -i xxx.mobileprovision \| pbcopy` |
| `KEYCHAIN_PASSWORD` | 任意字符串（runner 临时钥匙串密码） |
| `APP_BUNDLE_ID` | 与描述文件匹配的 Bundle ID，如 `com.你.saveeditor` |

> 描述文件需包含你的设备 UDID（Development/Ad Hoc 类型），否则该设备装不上。

### 触发方式
- **手动**：Actions → Run workflow。
- **自动**：`git tag v1.0 && git push --tags` → 自动构建并把 ipa 附到 GitHub Release。

---

## 方式二：本地 Xcode 打包（Xcode 14+ / macOS 12+）

### A. 图形界面（推荐）
1. 把整个 `Ares2SaveEditor` 文件夹拷到 Mac，双击 `Ares2SaveEditor.xcodeproj`。
2. 左侧选中目标 `Ares2SaveEditor` → `Signing & Capabilities`：
   - `Team` 选你的开发者账号（免费 Apple ID 可真机调试，但**不能导出可分发的 ipa**）。
   - `Bundle Identifier` 改成你自己的，如 `com.你的名字.saveeditor`。
3. 顶部设备选 `Any iOS Device (arm64)` 或连真机 → 菜单 `Product → Archive`。
4. Archive 完成弹出 Organizer → `Distribute App` →
   - `Ad Hoc` / `Development`：导出可 sideload 的 .ipa（需付费开发者账号）。
   - `App Store Connect`：上架用。

### B. 命令行
```bash
xcodebuild archive \
  -project Ares2SaveEditor.xcodeproj \
  -scheme Ares2SaveEditor \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Ares2SaveEditor.xcarchive

xcodebuild -exportArchive \
  -archivePath build/Ares2SaveEditor.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist
```
`ExportOptions.plist` 示例（method 按需改 development/ad-hoc/app-store）：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>development</string>
  <key>teamID</key><string>你的TeamID</string>
</dict></plist>
```

---

## 关于签名与安装（iOS 17）

iOS 只能安装**已签名**的 App。未签名 ipa 必须重签，三种途径：

- **免费 Apple ID + Sideloadly/AltStore 自签**：最多 3 个 App，**7 天有效期**，到期需重签。
  适合自用试玩。iOS 17 完全支持。
- **付费开发者账号**：签名有效期 1 年，可装更多 App。方式一 B 或方式二可自动/手动产出直装 ipa。
- **企业证书 / 超签**：第三方分发，自行评估风险。

> 存档修改器需访问游戏存档文件。App 的 Documents 目录已在"文件"App 中可见
> （Info.plist 已开启 `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`），
> 可通过"文件"App 把存档拷进/拷出 App 沙盒。

## 功能说明
- 打开存档：点页面里的"选择文件"，WKWebView 会弹出系统文件选择器。
- 保存/导出：点"保存/导出"会弹出系统分享面板 → 选"存储到'文件'"即可存档。

## 换图标
替换 `Assets.xcassets/AppIcon.appiconset/icon-1024.png`（1024x1024 PNG，无透明通道）即可。
