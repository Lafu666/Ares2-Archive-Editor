#!/bin/bash
# 本地构建 unsigned IPA 脚本 (iOS 17+)
set -euo pipefail

PROJECT_NAME="DecryptEditor"
CONFIG="${1:-Release}"
IOS_VERSION="17.0"
PROJECT_DIR="ios"
SCHEME="$PROJECT_NAME"
BUILD_DIR="build/Build"
IPA_EXPORT_PATH="build/ipa"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_prereqs() {
    if ! xcodebuild -version &>/dev/null; then
        error "Xcode not found. Install Xcode 15+ first."
        exit 1
    fi
    xcrun --sdk iphoneos --show-sdk-path &>/dev/null || {
        error "iOS SDK not found."
        exit 1
    }
}

generate_project() {
    info "Generating Xcode project..."
    python3 "$PROJECT_DIR/generate_project.py"
}

build_app() {
    info "Building .app (unsigned, Configuration: $CONFIG, iOS $IOS_VERSION)..."

    xcodebuild clean build \
        -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIG" \
        -sdk iphoneos \
        -derivedDataPath "$BUILD_DIR" \
        IPHONEOS_DEPLOYMENT_TARGET="$IOS_VERSION" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGN_STYLE=Manual \
        | xcpretty
}

package_ipa() {
    info "Packaging unsigned IPA..."

    rm -rf "$IPA_EXPORT_PATH"
    mkdir -p "$IPA_EXPORT_PATH/Payload"

    APP_PATH=$(find "$BUILD_DIR" -name "*.app" -type d | head -1)
    if [ -z "$APP_PATH" ]; then
        error ".app bundle not found in $BUILD_DIR"
        exit 1
    fi
    info "Found .app: $APP_PATH"

    cp -R "$APP_PATH" "$IPA_EXPORT_PATH/Payload/"

    local ipa_name="${PROJECT_NAME}-iOS17-${CONFIG}.ipa"
    cd "$IPA_EXPORT_PATH"
    zip -qr "../$ipa_name" Payload/
    cd ..

    info "IPA: $ipa_name ($(du -h "$ipa_name" | cut -f1))"
}

verify_ipa() {
    local ipa_file=$(ls *.ipa 2>/dev/null | head -1)
    if [ -z "$ipa_file" ]; then
        error "IPA file not found!"
        exit 1
    fi
    info "IPA verification:"
    unzip -l "$ipa_file" | grep -E "Payload.*\.app/" | head -5
    info "Done!"
}

cleanup() {
    rm -rf "$BUILD_DIR" "$IPA_EXPORT_PATH"
}

main() {
    echo "================================================"
    echo "  iOS Unsigned IPA Builder (iOS 17+)"
    echo "  Project: $PROJECT_NAME  |  Config: $CONFIG"
    echo "================================================"

    check_prereqs
    generate_project
    build_app
    package_ipa
    verify_ipa
    cleanup

    echo ""
    info "Build complete! IPA in build/"
}

trap 'echo ""; error "Build failed at line $LINENO"' ERR
main
