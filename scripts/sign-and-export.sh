#!/bin/bash
# 可选真签名导出脚本：在 GitHub Actions 的 macOS runner 上导入
# 开发者证书 + 描述文件，对 .app 重新签名并导出可直装的 ipa。
# 依赖 Secrets：BUILD_CERTIFICATE_BASE64 / P12_PASSWORD /
#              BUILD_PROVISION_BASE64 / KEYCHAIN_PASSWORD / APP_BUNDLE_ID
set -e

BUNDLE_ID="${BUNDLE_ID:-com.ares2.saveeditor}"
KEYCHAIN="build.keychain"

echo "==> 创建临时钥匙串"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

echo "==> 导入开发者证书 (.p12)"
echo "$CERT_BASE64" | base64 -d > cert.p12
security import cert.p12 -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

echo "==> 安装描述文件"
PROF_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROF_DIR"
echo "$PROVISION_BASE64" | base64 -d > "$PROF_DIR/build.mobileprovision"

# 解码描述文件，可靠地提取 UUID / TeamID / 名称
security cms -D -i "$PROF_DIR/build.mobileprovision" > /tmp/prof.plist
UUID=$(/usr/libexec/PlistBuddy -c 'Print :UUID' /tmp/prof.plist)
TEAM_ID=$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' /tmp/prof.plist)
PROF_NAME=$(/usr/libexec/PlistBuddy -c 'Print :Name' /tmp/prof.plist)
IDENTITY=$(security find-identity -v -p codesigning "$KEYCHAIN" | grep -oE '\([0-9A-F]+\)' | tr -d '()' | head -1)
echo "Signing identity: $IDENTITY"
echo "TeamID: $TEAM_ID"
echo "Provisioning UUID: $UUID  Name: $PROF_NAME"

echo "==> Archive (signed)"
xcodebuild archive \
  -project Ares2SaveEditor.xcodeproj \
  -scheme Ares2SaveEditor \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Ares2SaveEditor.xcarchive \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  PROVISIONING_PROFILE="$UUID"

echo "==> 写 ExportOptions.plist"
cat > ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>${BUNDLE_ID}</key>
    <dict>
      <key>identifier</key>
      <string>${UUID}</string>
      <key>name</key>
      <string>${PROF_NAME}</string>
    </dict>
  </dict>
</dict>
</plist>
EOF

echo "==> Export IPA"
mkdir -p build/ipa
xcodebuild -exportArchive \
  -archivePath build/Ares2SaveEditor.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist

echo "==> 清理钥匙串"
security delete-keychain "$KEYCHAIN" || true

ls -lh build/ipa/*.ipa
echo "签名导出完成。"
