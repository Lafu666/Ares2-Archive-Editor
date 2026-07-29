#!/usr/bin/env python3
"""
Ares2Calc IPA Builder
将网页应用打包成 iOS IPA 文件结构

使用方法:
  1. 在 Mac 上安装依赖: pip3 install lief
  2. 运行: python3 build_ipa.py
  3. 生成的 .ipa 文件可通过 AltStore/Sideloadly 等工具安装到 iOS 设备

注意: 此方法生成的是未签名的IPA壳，
      需要用AltStore/Sideloadly等工具签名后才能在设备上运行
"""

import os
import shutil
import zipfile
import hashlib
import json
import plistlib
from pathlib import Path
from datetime import datetime

# ========== 配置 ==========
APP_NAME = "阿瑞斯2积分计算器"
BUNDLE_ID = "com.sqiyue.ares2calc"
VERSION = "1.0"
MIN_IOS_VERSION = "14.0"
SRC_DIR = Path(__file__).parent
WEB_SRC = SRC_DIR.parent / "index.html"  # 网页文件位置
OUTPUT_DIR = SRC_DIR.parent / "output"
# ==========================

def create_payload_structure():
    """创建 IPA 的 Payload 目录结构"""
    payload_dir = OUTPUT_DIR / "Payload"
    app_dir = payload_dir / "Ares2Calc.app"
    
    # 清理旧文件
    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    
    app_dir.mkdir(parents=True, exist_ok=True)
    return app_dir

def write_info_plist(app_dir):
    """写入 Info.plist"""
    info = {
        "CFBundleDevelopmentRegion": "zh_CN",
        "CFBundleDisplayName": APP_NAME,
        "CFBundleExecutable": "Ares2Calc",
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": APP_NAME,
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": VERSION,
        "CFBundleVersion": "1",
        "LSRequiresIPhoneOS": True,
        "UILaunchStoryboardName": "LaunchScreen",
        "UIRequiredDeviceCapabilities": ["arm64"],
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
        "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationPortrait"],
        "NSAppTransportSecurity": {
            "NSAllowsArbitraryLoads": True
        },
        "MinimumOSVersion": MIN_IOS_VERSION,
        "UIDeviceFamily": [1, 2],  # iPhone and iPad
        "DTPlatformName": "iphoneos",
        "DTPlatformVersion": "17.0",
        "DTSdkName": "iphoneos17.0",
    }
    
    plist_path = app_dir / "Info.plist"
    with open(plist_path, 'wb') as f:
        plistlib.dump(info, f)
    print(f"  ✅ Info.plist 已创建")

def write_executable(app_dir):
    """创建一个最小的 iOS 可执行文件 stub"""
    # 这是一个 ARM64 的最小 Mach-O 可执行文件
    # 实际编译需要用 Xcode，这里提供一个占位方案
    # 用户需要用 Xcode 编译真正的可执行文件替换
    
    # 写入一个说明文件
    readme = """Ares2Calc iOS App

这是一个 WebView 壳应用，需要配合 Xcode 编译。

构建步骤:
1. 打开 Xcode 项目 (Ares2Calc.xcodeproj)
2. 选择你的开发者证书
3. 编译运行或归档导出 IPA

或者用命令行:
xcodebuild -project Ares2Calc.xcodeproj -scheme Ares2Calc -configuration Release archive -archivePath build/Ares2Calc.xcarchive
xcodebuild -exportArchive -archivePath build/Ares2Calc.xcarchive -exportPath build -exportOptionsPlist ExportOptions.plist
"""
    (app_dir / "BUILD_README.txt").write_text(readme)
    print(f"  ✅ 构建说明已创建")

def copy_web_assets(app_dir):
    """复制网页资源到 App 包内"""
    # 复制 index.html
    if WEB_SRC.exists():
        shutil.copy2(WEB_SRC, app_dir / "index.html")
        print(f"  ✅ index.html 已复制")
    else:
        print(f"  ⚠️ 找不到 index.html at {WEB_SRC}")
    
    # 创建 www 目录存放网页资源
    www_dir = app_dir / "www"
    www_dir.mkdir(exist_ok=True)
    
    if WEB_SRC.exists():
        shutil.copy2(WEB_SRC, www_dir / "index.html")

def create_app_icon(app_dir):
    """创建 App 图标占位（实际需要用 Xcode 的 asset catalog）"""
    # 创建一个简单的 icon 提示
    icon_info = {
        "images": [
            {"idiom": "iphone", "size": "20x20", "scale": "2x"},
            {"idiom": "iphone", "size": "20x20", "scale": "3x"},
            {"idiom": "iphone", "size": "29x29", "scale": "2x"},
            {"idiom": "iphone", "size": "29x29", "scale": "3x"},
            {"idiom": "iphone", "size": "40x40", "scale": "2x"},
            {"idiom": "iphone", "size": "40x40", "scale": "3x"},
            {"idiom": "iphone", "size": "60x60", "scale": "2x"},
            {"idiom": "iphone", "size": "60x60", "scale": "3x"},
            {"idiom": "ipad", "size": "20x20", "scale": "1x"},
            {"idiom": "ipad", "size": "20x20", "scale": "2x"},
            {"idiom": "ipad", "size": "29x29", "scale": "1x"},
            {"idiom": "ipad", "size": "29x29", "scale": "2x"},
            {"idiom": "ipad", "size": "40x40", "scale": "1x"},
            {"idiom": "ipad", "size": "40x40", "scale": "2x"},
            {"idiom": "ipad", "size": "76x76", "scale": "1x"},
            {"idiom": "ipad", "size": "76x76", "scale": "2x"},
            {"idiom": "ipad", "size": "83.5x83.5", "scale": "2x"},
            {"idiom": "ios-marketing", "size": "1024x1024", "scale": "1x"},
        ],
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }
    
    asset_dir = app_dir / "Assets.xcassets" / "AppIcon.appiconset"
    asset_dir.mkdir(parents=True, exist_ok=True)
    
    with open(asset_dir / "Contents.json", 'w') as f:
        json.dump(icon_info, f, indent=2)
    
    print(f"  ✅ AppIcon 占位已创建 (需要在 Xcode 中替换真实图标)")

def create_launch_screen(app_dir):
    """创建启动屏 Storyboard"""
    launch_storyboard = """<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0">
    <device id="retina6_12" orientation="portrait"/>
    <dependencies>
        <deployment identifier="iOS"/>
    </dependencies>
    <scenes>
        <scene sceneID="launch">
            <objects>
                <viewController id="vc1">
                    <view key="view" contentMode="scaleToFill" id="v1">
                        <rect key="frame" x="0" y="0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <label text="阿瑞斯2" textAlignment="center" translatesAutoresizingMaskIntoConstraints="NO" id="lbl1">
                                <rect key="frame" x="0" y="380" width="393" height="40"/>
                                <fontDescription type="boldSystem" pointSize="32"/>
                                <color key="textColor" red="0.914" green="0.271" blue="0.376" alpha="1"/>
                            </label>
                            <label text="积分计算器" textAlignment="center" translatesAutoresizingMaskIntoConstraints="NO" id="lbl2">
                                <rect key="frame" x="0" y="425" width="393" height="30"/>
                                <fontDescription type="system" pointSize="20"/>
                                <color key="textColor" white="0.8" alpha="1"/>
                            </label>
                        </subviews>
                        <color key="backgroundColor" red="0.10" green="0.10" blue="0.18" alpha="1"/>
                        <constraints>
                            <constraint firstItem="lbl1" firstAttribute="centerX" secondItem="v1" secondAttribute="centerX"/>
                            <constraint firstItem="lbl1" firstAttribute="centerY" secondItem="v1" secondAttribute="centerY" constant="-40"/>
                            <constraint firstItem="lbl1" firstAttribute="width" secondItem="v1" secondAttribute="width"/>
                            <constraint firstItem="lbl2" firstAttribute="top" secondItem="lbl1" secondAttribute="bottom" constant="5"/>
                            <constraint firstItem="lbl2" firstAttribute="centerX" secondItem="v1" secondAttribute="centerX"/>
                            <constraint firstItem="lbl2" firstAttribute="width" secondItem="v1" secondAttribute="width"/>
                        </constraints>
                    </view>
                </viewController>
            </objects>
        </scene>
    </scenes>
</document>"""
    
    (app_dir / "LaunchScreen.storyboard").write_text(launch_storyboard)
    print(f"  ✅ LaunchScreen.storyboard 已创建")

def create_export_options():
    """创建导出 IPA 的配置文件"""
    export_options = {
        "method": "development",  # development / ad-hoc / app-store
        "teamID": "",  # 填入你的 Apple Developer Team ID
        "signingStyle": "automatic",
        "signingCertificate": "Apple Development",
        "provisioningProfiles": {
            BUNDLE_ID: "Ares2Calc Development Profile"
        }
    }
    
    with open(OUTPUT_DIR / "ExportOptions.plist", 'wb') as f:
        plistlib.dump(export_options, f)
    print(f"  ✅ ExportOptions.plist 已创建")

def create_xcode_project():
    """生成 Xcode 项目文件（使用 pbxproj 格式）"""
    # 由于 pbxproj 格式非常复杂，这里生成一个简化的版本
    # 推荐使用 XcodeGen (https://github.com/yonaskolb/XcodeGen) 来生成
    
    xcodegen_config = """name: Ares2Calc
options:
  bundleIdPrefix: com.sqiyue
  deploymentTarget:
    iOS: "14.0"

settings:
  base:
    ENABLE_BITCODE: NO

targets:
  Ares2Calc:
    type: application
    platform: iOS
    sources:
      - path: Ares2Calc
    resources:
      - path: Ares2Calc/index.html
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.sqiyue.ares2calc
        PRODUCT_NAME: 阿瑞斯2积分计算器
        MARKETING_VERSION: "1.0"
        INFOPLIST_FILE: Ares2Calc/Info.plist
        LAUNCHSCREEN_STORYBOARD_NAME: LaunchScreen
"""
    
    (SRC_DIR / "project.yml").write_text(xcodegen_config)
    print(f"  ✅ XcodeGen project.yml 已创建")

def package_ipa():
    """将所有文件打包成 .ipa"""
    ipa_path = OUTPUT_DIR.parent / "阿瑞斯2积分计算器.ipa"
    
    with zipfile.ZipFile(ipa_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        payload_dir = OUTPUT_DIR / "Payload"
        for root, dirs, files in os.walk(payload_dir):
            for file in files:
                file_path = Path(root) / file
                arcname = file_path.relative_to(OUTPUT_DIR)
                zf.write(file_path, arcname)
    
    size_mb = os.path.getsize(ipa_path) / (1024 * 1024)
    print(f"\n📦 IPA 已打包: {ipa_path}")
    print(f"   文件大小: {size_mb:.2f} MB")
    return ipa_path

def main():
    print("=" * 50)
    print("  🎮 阿瑞斯2积分计算器 - IPA 构建工具")
    print("=" * 50)
    print()
    
    print("📁 创建 Payload 结构...")
    app_dir = create_payload_structure()
    
    print("\n📝 写入配置文件...")
    write_info_plist(app_dir)
    write_executable(app_dir)
    
    print("\n🌐 复制网页资源...")
    copy_web_assets(app_dir)
    
    print("\n🎨 创建图标和启动屏...")
    create_app_icon(app_dir)
    create_launch_screen(app_dir)
    
    print("\n⚙️ 创建构建配置...")
    create_export_options()
    create_xcode_project()
    
    print("\n📦 打包 IPA...")
    ipa_path = package_ipa()
    
    print("\n" + "=" * 50)
    print("  ✅ 构建完成!")
    print("=" * 50)
    print()
    print("⚠️  重要提示:")
    print("  由于当前环境无法直接编译 iOS 可执行文件,")
    print("  生成的 IPA 包含完整的网页资源和配置,")
    print("  但缺少编译后的原生二进制文件。")
    print()
    print("🔧 推荐的完整构建方式:")
    print()
    print("  方式一: 使用 Xcode (推荐)")
    print("  1. 将 ios-app/ 文件夹拷贝到 Mac")
    print("  2. 安装 XcodeGen: brew install xcodegen")
    print("  3. cd ios-app && xcodegen generate")
    print("  4. 用 Xcode 打开 .xcodeproj 并编译")
    print()
    print("  方式二: 使用 AltStore / Sideloadly")
    print("  1. 下载现成的 WebView 壳 App")
    print("  2. 替换其中的 index.html 为本项目的网页")
    print("  3. 用 AltStore 签名安装到手机")
    print()
    print("  方式三: 使用 GitHub Actions 自动构建")
    print("  项目中已包含 GitHub Actions 工作流配置")
    print("  推送代码到 GitHub 即可自动构建 IPA")
    print()

if __name__ == "__main__":
    main()
