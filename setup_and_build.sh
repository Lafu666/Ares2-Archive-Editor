#!/bin/bash
# ============================================
#  阿瑞斯2积分计算器 - iOS 一键部署脚本
# ============================================
# 
# 这个脚本会:
# 1. 生成完整的 Xcode 工程
# 2. 编译并打包成 IPA
# 3. 输出可直接安装的 IPA 文件
#
# 使用方法:
#   chmod +x setup_and_build.sh
#   ./setup_and_build.sh
#
# 要求: macOS + Xcode 14+
# ============================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   🎮 阿瑞斯2积分计算器 - iOS 构建工具  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# --- 检查环境 ---
echo "🔍 检查构建环境..."

if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未检测到 Xcode"
    echo "   请先安装 Xcode (App Store 搜索下载)"
    echo "   安装完成后运行: sudo xcode-select --install"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo "   ✅ $XCODE_VERSION"

# --- 安装 XcodeGen ---
if ! command -v xcodegen &> /dev/null; then
    echo ""
    echo "📦 安装 XcodeGen (用于生成 Xcode 工程)..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "❌ 需要 Homebrew 来安装 XcodeGen"
        echo "   请先安装 Homebrew: https://brew.sh"
        echo "   然后运行: brew install xcodegen"
        exit 1
    fi
fi
echo "   ✅ XcodeGen 已就绪"

# --- 生成 Xcode 工程 ---
echo ""
echo "📁 生成 Xcode 工程文件..."
xcodegen generate --spec project.yml --project Ares2Calc.xcodeproj

if [ ! -d "Ares2Calc.xcodeproj" ]; then
    echo "❌ Xcode 工程生成失败"
    exit 1
fi
echo "   ✅ Ares2Calc.xcodeproj 已生成"

# --- 编译 ---
echo ""
echo "🔨 开始编译 (无签名模式)..."
echo "   这可能需要几分钟..."

BUILD_OUTPUT=$(xcodebuild \
    -project Ares2Calc.xcodeproj \
    -scheme Ares2Calc \
    -configuration Release \
    -sdk iphoneos \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    PROVISIONING_PROFILE="" \
    ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=NO \
    -destination 'generic/platform=iOS' \
    build 2>&1)

# 检查编译结果
if echo "$BUILD_OUTPUT" | grep -q "BUILD SUCCEEDED"; then
    echo "   ✅ 编译成功!"
elif echo "$BUILD_OUTPUT" | grep -q "error:"; then
    echo "   ❌ 编译失败"
    echo "$BUILD_OUTPUT" | grep "error:" | head -10
    echo ""
    echo "💡 提示: 如果编译失败，请尝试:"
    echo "   1. 打开 Xcode: open Ares2Calc.xcodeproj"
    echo "   2. 在 Signing & Capabilities 中选择你的开发者账号"
    echo "   3. 选择连接的 iOS 设备"
    echo "   4. 点击 ▶️ 运行"
    exit 1
else
    echo "   ⚠️  编译状态不明确，请查看完整输出"
    echo "$BUILD_OUTPUT" | tail -20
fi

# --- 查找编译产物 ---
echo ""
echo "📂 查找编译产物..."

APP_PATH=""
# 搜索 .app 目录
for d in $(find . -name "Ares2Calc.app" -type d 2>/dev/null); do
    if [ -f "$d/Ares2Calc" ]; then
        APP_PATH="$d"
        break
    fi
done

if [ -z "$APP_PATH" ]; then
    echo "   ⚠️ 未找到编译产物，尝试 Archive 方式..."
    
    xcodebuild \
        -project Ares2Calc.xcodeproj \
        -scheme Ares2Calc \
        -configuration Release \
        -sdk iphoneos \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGN_IDENTITY="" \
        ARCHS="arm64" \
        ONLY_ACTIVE_ARCH=NO \
        archive -archivePath "build/Ares2Calc.xcarchive" 2>&1 | tail -5
    
    APP_PATH="build/Ares2Calc.xcarchive/Products/Applications/Ares2Calc.app"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "   ❌ 找不到编译后的 .app 文件"
    echo ""
    echo "💡 备选方案: 请在 Xcode 中手动操作"
    echo "   1. open Ares2Calc.xcodeproj"
    echo "   2. 选择目标设备"
    echo "   3. Product → Archive"
    echo "   4. Distribute App → Ad Hoc 或 Development"
    exit 1
fi

echo "   ✅ 找到: $APP_PATH"

# --- 打包 IPA ---
echo ""
echo "📦 打包 IPA 文件..."

OUTPUT_DIR="$SCRIPT_DIR/output"
mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.ipa 2>/dev/null

PAYLOAD_DIR="$OUTPUT_DIR/Payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"

cp -r "$APP_PATH" "$PAYLOAD_DIR/"
chmod -R 755 "$PAYLOAD_DIR/Ares2Calc.app"

cd "$OUTPUT_DIR"
zip -r "阿瑞斯2积分计算器.ipa" "Payload/" -x ".*"
cd "$SCRIPT_DIR"

IPA_FILE="$OUTPUT_DIR/阿瑞斯2积分计算器.ipa"
if [ -f "$IPA_FILE" ]; then
    SIZE=$(ls -lh "$IPA_FILE" | awk '{print $5}')
    echo "   ✅ IPA 已生成: $IPA_FILE ($SIZE)"
else
    echo "   ❌ IPA 打包失败"
    exit 1
fi

# --- 完成 ---
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║              🎉 构建完成!               ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "📱 IPA 文件: $IPA_FILE"
echo ""
echo "📝 下一步 - 安装到手机:"
echo ""
echo "  【方式一】AltStore (推荐, 免费)"
echo "    1. 电脑下载 AltStore: https://altstore.io"
echo "    2. 手机连电脑, 安装 AltStore 到手机"
echo "    3. 手机上打开 AltStore → My Apps"
echo "    4. 点 + 号 → 选择上面的 IPA 文件"
echo "    5. 输入 Apple ID 密码完成签名安装"
echo ""
echo "  【方式二】Sideloadly (免费, 支持Win/Mac)"
echo "    1. 下载: https://sideloadly.io"
echo "    2. 手机连电脑, 打开 Sideloadly"
echo "    3. 拖入 IPA 文件"
echo "    4. 输入 Apple ID → Start"
echo ""
echo "  【方式三】有开发者账号 ($99/年)"
echo "    1. 用 Xcode 打开 Ares2Calc.xcodeproj"
echo "    2. 登录 Apple Developer 账号"
echo "    3. 选择设备 → Cmd+R 直接运行"
echo "    4. 或 Archive → App Store 发布"
echo ""
echo "  【方式四】免安装! 添加到主屏幕"
echo "    用手机 Safari 打开原网页"
echo "    → 点分享 → 添加到主屏幕"
echo "    → 效果和 App 一样!"
echo ""
echo "⚠️  免费 Apple ID 签名有效期 7 天"
echo "    AltStore 可自动续签 (需电脑开着)"
echo ""
