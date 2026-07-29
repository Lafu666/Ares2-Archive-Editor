# 阿瑞斯工具箱 iOS版 - 游戏存档编辑器

> AresToolbox for iOS —— 一款专为「阿瑞斯」游戏打造的存档编辑器，支持在 iPhone / iPad 上直接解包、解密、编辑并重新打包游戏存档。

<p align="center">
  <strong>SwiftUI</strong> · <strong>iOS 17.0+</strong> · <strong>Swift 5.9</strong> · <strong>XcodeGen</strong>
</p>

---

## 目录

- [项目简介](#项目简介)
- [功能特性](#功能特性)
- [项目结构](#项目结构)
- [环境要求](#环境要求)
- [本地构建](#本地构建)
- [GitHub Actions 自动构建](#github-actions-自动构建)
  - [未签名 IPA 构建](#未签名-ipa-构建build-ipayml)
  - [签名 IPA 构建](#签名-ipa-构建build-signed-ipayml)
  - [所需密钥配置](#所需密钥配置)
- [代码签名说明](#代码签名说明)
- [许可证](#许可证)

---

## 项目简介

**阿瑞斯工具箱**是一款 iOS 原生应用，使用 SwiftUI 构建。它可以让玩家在移动设备上便捷地编辑「阿瑞斯」游戏的存档文件，无需依赖电脑端工具。

应用核心能力包括：解压游戏存档 ZIP 包、自动定位并解密 `GameWorld.db` 数据库、以可视化方式浏览与修改游戏数据（背包、工人、地图、天赋、家具等），最终将修改后的数据重新加密打包为可用的存档文件。

---

## 功能特性

### 存档处理

- **ZIP 解包/打包**：基于 [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) 实现游戏存档的解压与重新压缩
- **数据库解密/加密**：自动识别并使用 XOR 密钥解密 `GameWorld.db`，编辑完成后重新加密
- **一键导入导出**：支持从「文件」App 导入存档，编辑后导出回原位置

### 数据库编辑

- **树形目录浏览**：以数据库 → 表的层级结构展示所有数据表
- **数据增删改查**：支持对任意表、任意行/列进行编辑
- **全局搜索**：跨表搜索关键字，快速定位数据
- **编辑历史**：记录修改操作，便于回溯

### 游戏数据编辑模块

内置以下编辑模块（对应游戏内各类数据）：

| 模块 | 说明 |
| --- | --- |
| 背包 | 编辑物品数量，支持按分类浏览 |
| 雇佣 | 管理雇佣的工人 |
| 哈士奇 | 编辑哈士奇宠物数据 |
| 增益效果 | 修改当前生效的 Buff |
| 当前人物坐骑 | 修改坐骑状态 |
| 工人 | 管理 NPC 工人列表 |
| 场景地图 | 解锁 / 修改场景地图状态 |
| 天赋 | 编辑天赋技能等级 |
| 场景建筑 | 修改场景中的建筑数据 |
| 改造 | 编辑改造相关数据 |
| 家具 | 管理家具数量 |
| 奖杯次数 | 修改奖杯计数 |
| 研究 | 编辑科技研究进度 |
| 挑战 | 修改挑战记录 |

### 资源与工具

- **物品分类**：内置物品 ID 与名称映射，支持按分类筛选
- **地图名称映射**：场景 ID 与中文名称对照
- **时间转换**：`.NET Ticks` / `Windows 文件时间` 与 `Date` 互转，方便编辑时间相关字段

---

## 项目结构

```
AresToolbox/
├── project.yml                    # XcodeGen 项目配置文件
├── ExportOptions.plist            # xcodebuild 导出签名 IPA 的配置
├── README.md                      # 项目说明文档
├── .gitignore                     # Git 忽略规则
├── .github/
│   └── workflows/
│       ├── build-ipa.yml          # 未签名 IPA 构建工作流
│       └── build-signed-ipa.yml   # 签名 IPA 构建工作流
└── AresToolbox/
    ├── Core/
    │   ├── AssetLoaderUtil.swift    # 资源文件加载工具
    │   ├── Constants.swift          # 全局常量（密钥、表名、分类等）
    │   ├── DatabaseManager.swift    # SQLite3 数据库操作管理器
    │   ├── FileProcessor.swift      # 存档解压/解密/加密/打包
    │   └── TimeConversionUtil.swift # .NET Ticks 时间转换工具
    ├── Models/
    │   └── DataModels.swift         # 数据模型定义
    └── Resources/
        ├── 地图.txt
        ├── 天赋技能.txt
        ├── 已分类ID.txt
        └── 物品ID22.txt
```

> 注意：`AresToolbox.xcodeproj` 由 XcodeGen 根据 `project.yml` 自动生成，**不纳入版本控制**，请勿手动提交。

---

## 环境要求

| 依赖 | 最低版本 | 说明 |
| --- | --- | --- |
| macOS | 14.0+ | 推荐 macOS Sequoia 15+ |
| Xcode | 16.0+ | 需包含 iOS 17 SDK，XcodeGen 生成的项目格式需要 Xcode 16 |
| iOS 部署目标 | 17.0+ | 使用了 SwiftUI 新特性 |
| Swift | 5.9 | 项目配置的 Swift 版本 |
| XcodeGen | 最新版 | 通过 Homebrew 安装：`brew install xcodegen` |

---

## 本地构建

### 1. 安装依赖

```bash
# 安装 XcodeGen
brew install xcodegen
```

### 2. 克隆并生成项目

```bash
git clone <仓库地址>
cd AresToolbox

# 根据 project.yml 生成 .xcodeproj
xcodegen generate
```

### 3. 打开项目并构建

```bash
# 使用 Xcode 打开
open AresToolbox.xcodeproj
```

或在命令行直接构建：

```bash
# 解析 Swift Package 依赖
xcodebuild -resolvePackageDependencies \
  -project AresToolbox.xcodeproj \
  -scheme AresToolbox

# 构建未签名 IPA（用于本地测试）
xcodebuild build \
  -project AresToolbox.xcodeproj \
  -scheme AresToolbox \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO
```

### 4. 手动打包未签名 IPA

```bash
# 定位 .app
APP_PATH=$(find build/Build/Products -name "AresToolbox.app" -type d | head -1)

# 创建 Payload 目录并打包
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -qry AresToolbox-unsigned.ipa Payload
```

> 未签名 IPA 无法直接安装到非越狱设备。如需安装，请使用 [TrollStore](https://github.com/opa334/TrollStore) 或进行签名（见下文）。

---

## GitHub Actions 自动构建

本项目提供两个 GitHub Actions 工作流，分别用于构建未签名与签名的 IPA。

### 未签名 IPA 构建（build-ipa.yml）

**触发方式：**

- 推送到 `main` / `master` 分支
- 创建 Pull Request
- 推送标签（如 `v1.0.0`、`release-1.0`）时构建并创建 GitHub Release
- 手动触发（Actions 页面 → Run workflow），可勾选是否创建 Release

**工作流程：**

1. 检出代码
2. 选择 Xcode（`sudo xcode-select -s /Applications/Xcode.app`）
3. 安装 XcodeGen（`brew install xcodegen`）
4. 生成 Xcode 项目（`xcodegen generate`）
5. 解析 SPM 依赖（`xcodebuild -resolvePackageDependencies`）
6. 构建未签名的 .app（`CODE_SIGNING_ALLOWED=NO`）
7. 定位 `.app`，创建 `Payload` 目录并打包为 `.ipa`
8. 上传 IPA 作为构建产物（Artifact，保留 30 天）
9. 上传构建日志
10. 在标签推送或手动勾选时，创建 GitHub Release 并附带 IPA

**产物获取：**

构建完成后，前往仓库的 **Actions** 页面 → 选择对应的运行记录 → 下拉到 **Artifacts** 区域 → 下载 `AresToolbox-unsigned-ipa`。

### 签名 IPA 构建（build-signed-ipa.yml）

**触发方式：**

- 仅支持**手动触发**（Actions 页面 → Build Signed IPA → Run workflow）
- 触发时可选择导出方式：`development` / `ad-hoc` / `app-store` / `enterprise`

**工作流程：**

1. 校验必需的 GitHub Secrets 是否已配置
2. 检出代码、选择 Xcode、安装 XcodeGen 并生成项目
3. 创建临时钥匙串并解锁
4. 从 Secret 解码 `.p12` 证书并导入钥匙串
5. 从 Secret 解码 `.mobileprovision` 描述文件并安装
6. 使用 `xcodebuild archive` 构建已签名的 Archive
7. 根据所选导出方式动态生成 `ExportOptions.plist`
8. 使用 `xcodebuild -exportArchive` 导出签名 IPA
9. 上传签名 IPA 作为构建产物
10. 清理临时钥匙串与描述文件（安全清理）

**产物获取：**

构建完成后，在对应运行记录的 **Artifacts** 区域下载 `AresToolbox-signed-ipa`。签名后的 IPA 可通过 Xcode、[Sideloadly](https://sideloadly.io/) 等方式安装到真实设备。

---

## 所需密钥配置

签名构建工作流需要以下 GitHub Secrets（在仓库 **Settings → Secrets and variables → Actions** 中配置）：

| Secret 名称 | 说明 | 获取方式 |
| --- | --- | --- |
| `BUILD_CERTIFICATE_BASE64` | 开发者证书 `.p12` 文件的 Base64 编码 | 在钥匙串访问中导出证书为 `.p12`，然后执行 `base64 -i certificate.p12 | pbcopy` |
| `BUILD_PROVISIONING_PROFILE_BASE64` | 描述文件 `.mobileprovision` 的 Base64 编码 | 在 Apple Developer 后台下载描述文件，执行 `base64 -i profile.mobileprovision \| pbcopy` |
| `KEYCHAIN_PASSWORD` | 临时钥匙串的密码 | 任意自定义字符串，如 `my-secret-keychain-password` |

### 生成 Base64 编码的示例

```bash
# 证书
base64 -i certificate.p12 | pbcopy

# 描述文件
base64 -i profile.mobileprovision | pbcopy
```

> 描述文件的 Bundle ID 必须与项目一致（`com.ares.toolbox`），且证书与描述文件需匹配同一开发者团队。

---

## 代码签名说明

本项目在 `project.yml` 中默认配置了：

```yaml
CODE_SIGNING_ALLOWED: NO
CODE_SIGN_IDENTITY: ""
DEVELOPMENT_TEAM: ""
```

这意味着：

- **本地构建**与**未签名工作流**生成的 IPA **不包含有效签名**，无法直接安装到非越狱的 iOS 设备
- 未签名 IPA 适用于：通过 TrollStore 安装、越狱设备安装、或后续使用个人证书手动签名
- 如需安装到普通设备，请使用**签名构建工作流**（`build-signed-ipa.yml`），并提供有效的开发者证书与描述文件

### ExportOptions.plist

项目根目录下的 [`ExportOptions.plist`](./ExportOptions.plist) 用于 `xcodebuild -exportArchive` 导出签名 IPA。其中包含以下占位符，使用前请替换为你的实际信息：

- `teamID`：替换为你的 Apple Developer Team ID
- `provisioningProfiles` 中的 `UUID` 与 `name`：替换为你的描述文件信息

> 注意：签名构建工作流会在运行时**动态生成** `ExportOptions.plist`，自动从描述文件中提取 Team ID 与 UUID，因此手动修改此文件主要供本地导出使用。

---

## 许可证

本项目仅供学习和个人使用。请勿将修改后的游戏存档用于破坏他人游戏体验或违反游戏服务条款的行为。使用者需自行承担相关风险。
