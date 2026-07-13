#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
swift build -c release
APP_DIR="$ROOT_DIR/.build/release/ClaudeMeter.app"
CONTENTS_DIR="$APP_DIR/Contents"; MACOS_DIR="$CONTENTS_DIR/MacOS"; RESOURCES_DIR="$CONTENTS_DIR/Resources"; PLIST="$CONTENTS_DIR/Info.plist"
rm -rf "$APP_DIR"; mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/ClaudeMeter" "$MACOS_DIR/ClaudeMeter"
cat > "$PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>ClaudeMeter</string>
    <key>CFBundleIdentifier</key><string>com.sanchitkd.ClaudeMeter</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Claude Meter</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
chmod +x "$MACOS_DIR/ClaudeMeter"
APP_PATH=".build/release/ClaudeMeter.app"
mkdir -p "$APP_PATH/Contents/Resources"
cp assets/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
xattr -cr "$APP_PATH"
codesign --force --sign - "$APP_PATH"      # ad-hoc sign whole bundle ($APP_PATH = your .build/release/ClaudeMeter.app)
echo "Built $APP_DIR"
