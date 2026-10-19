#!/bin/bash
set -e

echo "================================================"
echo "🍏 Building MacSweeper DMG for Apple Silicon Mac"
echo "================================================"

# 1. Compile for Apple Silicon (arm64)
echo "🔨 Compiling release binary for Apple Silicon (arm64)..."
swift build -c release --triple arm64-apple-macosx14.0

BIN_PATH="$(swift build -c release --triple arm64-apple-macosx14.0 --show-bin-path)/MacSweep"

APP_NAME="MacSweeper"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="MacSweeper-AppleSilicon.dmg"

echo "📦 Assembling application bundle: $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Icon
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Generate Info.plist
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacSweeper</string>
    <key>CFBundleIdentifier</key>
    <string>com.macsweeper.app</string>
    <key>CFBundleName</key>
    <string>MacSweeper</string>
    <key>CFBundleDisplayName</key>
    <string>MacSweeper</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 MacSweeper. All rights reserved.</string>
</dict>
</plist>
EOF

# Code signing: use Developer ID Application if available, else ad-hoc sign for Apple Silicon execution
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | awk -F'"' '{print $2}' || true)

if [ -n "$SIGNING_IDENTITY" ]; then
    echo "🔏 Signing with Developer ID: $SIGNING_IDENTITY..."
    codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
else
    echo "🔏 Ad-hoc signing bundle for Apple Silicon ARM64 execution..."
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

# 2. Package into DMG
echo "💿 Packaging into $DMG_NAME..."
STAGING_DIR="build/dmg_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -sf /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_NAME" "MacSweep-AppleSilicon.dmg"
hdiutil create \
    -volname "MacSweeper" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

rm -rf "$STAGING_DIR"

# Backwards compatible copy
cp "$DMG_NAME" "MacSweep-AppleSilicon.dmg"

echo "================================================"
echo "✅ DMG Built Successfully!"
echo "📍 Location: $(pwd)/$DMG_NAME"
echo "📏 Size: $(ls -lh "$DMG_NAME" | awk '{print $5}')"
echo "🖥️ Architecture: Apple Silicon (arm64)"
echo "🚀 To test: open $DMG_NAME"
echo "================================================"
