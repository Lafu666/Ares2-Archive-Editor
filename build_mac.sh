#!/bin/bash
set -e

echo "🎮 阿瑞斯2积分计算器 - iOS 构建脚本"
echo "=================================="
echo ""

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 未找到 Xcode，请先安装 Xcode"
    exit 1
fi

# 检查 XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 正在安装 XcodeGen..."
    brew install xcodegen
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

echo "📁 生成 Xcode 项目..."
xcodegen generate

echo ""
echo "🔨 编译项目..."
xcodebuild \
    -project Ares2Calc.xcodeproj \
    -scheme Ares2Calc \
    -configuration Release \
    -sdk iphoneos \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=NO \
    build 2>&1 | tail -5

# 查找编译产物
APP_PATH=$(find build -name "Ares2Calc.app" -type d 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    # 尝试 Release 目录
    APP_PATH=$(find build/Release-iphoneos -name "Ares2Calc.app" -type d 2>/dev/null | head -1)
fi

if [ -n "$APP_PATH" ]; then
    echo ""
    echo "📦 打包 IPA..."
    mkdir -p build/Payload
    cp -r "$APP_PATH" build/Payload/
    chmod -R 755 build/Payload/Ares2Calc.app
    
    cd build
    zip -r "../阿瑞斯2积分计算器.ipa" Payload/
    cd ..
    
    echo ""
    echo "✅ 构建完成!"
    echo "📱 IPA 文件: $(pwd)/阿瑞斯2积分计算器.ipa"
    echo ""
    echo "📝 下一步:"
    echo "   1. 用 AltStore / Sideloadly 签名安装"
    echo "   2. 或导入 Xcode 选择设备直接运行"
    ls -la "阿瑞斯2积分计算器.ipa"
else
    echo ""
    echo "❌ 编译失败，请检查错误信息"
    echo ""
    echo "🔧 备选方案: 直接在 Xcode 中打开项目"
    echo "   open Ares2Calc.xcodeproj"
    echo "   然后选择设备 -> Cmd+R 运行"
fi
