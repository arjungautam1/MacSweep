#!/bin/bash
set -e

echo "=================================================="
echo "🍎 Preparing MacSweep for Mac App Store Submission"
echo "=================================================="

# Check for entitlements
ENTITLEMENTS="MacSweep.entitlements"
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "❌ Missing $ENTITLEMENTS!"
    exit 1
fi

# 1. Compile release binary
echo "🔨 Compiling release binary for Apple Silicon (arm64)..."
swift build -c release --triple arm64-apple-macosx14.0

BIN_PATH="$(swift build -c release --triple arm64-apple-macosx14.0 --show-bin-path)/MacSweep"

APP_NAME="MacSweep"
APP_BUNDLE="${APP_NAME}.app"
PKG_NAME="MacSweep.pkg"

echo "📦 Assembling application bundle: $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacSweep</string>
    <key>CFBundleIdentifier</key>
    <string>com.macsweep.app</string>
    <key>CFBundleName</key>
    <string>MacSweep</string>
    <key>CFBundleDisplayName</key>
    <string>MacSweep</string>
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
    <string>Copyright © 2026 MacSweep. All rights reserved.</string>
</dict>
</plist>
EOF

# 2. Codesign for App Store (requires 3rd Party Mac Developer Application or Apple Distribution)
APP_SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep -E "Apple Distribution|3rd Party Mac Developer Application" | head -n 1 | awk -F'"' '{print $2}' || true)
INSTALLER_SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep -E "3rd Party Mac Developer Installer" | head -n 1 | awk -F'"' '{print $2}' || true)

if [ -n "$APP_SIGNING_IDENTITY" ]; then
    echo "🔏 Signing with Apple Distribution Certificate: $APP_SIGNING_IDENTITY..."
    codesign --force --deep --options runtime --entitlements "$ENTITLEMENTS" --sign "$APP_SIGNING_IDENTITY" "$APP_BUNDLE"
else
    echo "⚠️ No 'Apple Distribution' certificate found in Keychain."
    echo "🔏 Ad-hoc signing with App Sandbox entitlements for local testing..."
    codesign --force --deep --entitlements "$ENTITLEMENTS" --sign - "$APP_BUNDLE"
fi

# 3. Create .pkg for App Store Connect submission
echo "📦 Creating App Store installer package ($PKG_NAME)..."
rm -f "$PKG_NAME"

if [ -n "$INSTALLER_SIGNING_IDENTITY" ]; then
    productbuild --component "$APP_BUNDLE" /Applications --sign "$INSTALLER_SIGNING_IDENTITY" "$PKG_NAME"
    echo "✅ Signed App Store Package created: $PKG_NAME"
else
    productbuild --component "$APP_BUNDLE" /Applications "$PKG_NAME"
    echo "⚠️ Created unsigned package: $PKG_NAME (Sign with your 3rd Party Mac Developer Installer certificate before submitting)"
fi

echo "=================================================="
echo "✅ App Store Preparation Complete!"
echo "📍 App Bundle: $(pwd)/$APP_BUNDLE"
echo "📦 Installer PKG: $(pwd)/$PKG_NAME"
echo ""
echo "📤 To submit to Mac App Store:"
echo "   1. Open Apple Transporter app (free on Mac App Store)"
echo "   2. Drag and drop $PKG_NAME into Transporter"
echo "   3. Click 'Deliver' to upload to App Store Connect"
echo "=================================================="
