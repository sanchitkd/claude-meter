#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
VERSION="1.2.0"          # W6.4 — single source of truth. Must match the git tag: git tag v$VERSION
BUILD="2"
swift build -c release
APP_DIR="$ROOT_DIR/.build/release/ClaudeMeter.app"
CONTENTS_DIR="$APP_DIR/Contents"; MACOS_DIR="$CONTENTS_DIR/MacOS"; RESOURCES_DIR="$CONTENTS_DIR/Resources"; PLIST="$CONTENTS_DIR/Info.plist"
rm -rf "$APP_DIR"; mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/ClaudeMeter" "$MACOS_DIR/ClaudeMeter"
cat > "$PLIST" <<PLIST
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
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
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
# codesign refuses to sign a bundle carrying "resource fork, Finder information, or similar
# detritus" — strip all of it first, or the build silently ships an UNSIGNED app that opens
# as "damaged" on every other Mac.
find "$APP_PATH" -name '.DS_Store' -delete 2>/dev/null || true
xattr -cr "$APP_PATH"
dot_clean -m "$APP_PATH" 2>/dev/null || true

codesign --force --deep --sign - "$APP_PATH"   # ad-hoc sign the whole bundle
codesign --verify --strict --verbose=2 "$APP_PATH"   # fail loudly rather than ship a broken archive

# ── W6.4: package the release archive HERE, not by hand ──────────────────────────
# `zip -r` and Finder's "Compress" both drop the _CodeSignature/ dir and resource forks
# from a signed .app — that is what shipped the "ClaudeMeter is damaged" build. `ditto`
# is the only Apple-blessed way to archive a bundle without corrupting the signature.
# --keepParent puts ClaudeMeter.app/ at the archive root (so it unzips to the app, not its
# guts); --sequesterRsrc keeps xattrs/forks in the archive's __MACOSX sidecar intact.
ZIP_PATH="$ROOT_DIR/.build/release/ClaudeMeter.app.zip"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

# The archive is what users actually download — re-verify the SIGNATURE SURVIVED packaging.
# Unzip to a scratch dir and codesign the extracted copy; a stripped archive fails here
# instead of in a user's Gatekeeper dialog.
VERIFY_DIR="$(mktemp -d)"
trap 'rm -rf "$VERIFY_DIR"' EXIT
ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
if ! codesign --verify --strict --verbose=2 "$VERIFY_DIR/ClaudeMeter.app"; then
  echo "FATAL: signature did NOT survive packaging — the archive is unsigned. NOT shipping." >&2
  exit 1
fi
echo "Packaged $ZIP_PATH ($(du -h "$ZIP_PATH" | cut -f1)) — signature verified post-archive."

echo "Built $APP_DIR (v$VERSION build $BUILD)"
echo "Tag must match:  git tag v$VERSION && git push origin v$VERSION"