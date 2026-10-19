#!/bin/bash
set -e

echo "🔨 Building MacSweeper with Swift Package Manager..."
swift build -c release

APP_DIR="MacSweeper.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating macOS Application Bundle: $APP_DIR..."
rm -rf "$APP_DIR" MacSweep.app
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary and AppIcon
BIN_PATH="$(swift build -c release --show-bin-path)/MacSweep"
cp "$BIN_PATH" "$MACOS_DIR/MacSweeper"

if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Generate Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
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
</dict>
</plist>
EOF

# Provide backwards-compatible symlink for MacSweep.app
ln -sf "MacSweeper.app" "MacSweep.app"

echo "✅ Successfully built $APP_DIR!"
echo "🚀 To launch: open $APP_DIR"
