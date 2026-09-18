#!/bin/bash

set -euo pipefail

# 将 Swift Package 打包成可双击启动的 macOS App。
# 产物位于 dist/CodexBar.app；签名为本机 ad-hoc 签名，仅供本地运行。

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/dist"
APP_DIR="$OUTPUT_DIR/CodexBar.app"
EXECUTABLE="$PROJECT_DIR/.build/release/CodexBar"

cd "$PROJECT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/CodexBar"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key><string>CodexBar</string>
    <key>CFBundleExecutable</key><string>CodexBar</string>
    <key>CFBundleIdentifier</key><string>com.local.codexbar</string>
    <key>CFBundleName</key><string>CodexBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.2.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "已生成：$APP_DIR"
echo "可运行：open \"$APP_DIR\""
