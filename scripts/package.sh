#!/bin/zsh
set -euo pipefail

ROOT_DIR="/Users/tejastelkar/Desktop/sidedeck"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/SideDeck.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

echo "Compiling SideDeck..."
cd "$ROOT_DIR"
xcrun swift build -c release

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$ROOT_DIR/.build/arm64-apple-macosx/release/SideDeck" "$MACOS_DIR/SideDeck"
chmod +x "$MACOS_DIR/SideDeck"

# Copy Icon
if [[ -f "$ROOT_DIR/Resources/SideDeck.icns" ]]; then
  cp "$ROOT_DIR/Resources/SideDeck.icns" "$RESOURCES_DIR/SideDeck.icns"
fi

# Create Info.plist
cat << 'PLIST' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SideDeck</string>
    <key>CFBundleIconFile</key>
    <string>SideDeck</string>
    <key>CFBundleIdentifier</key>
    <string>com.tejastelkar.sidedeck</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SideDeck</string>
    <key>CFBundleDisplayName</key>
    <string>SideDeck</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Tejas Telkar. All rights reserved.</string>
</dict>
</plist>
PLIST

echo "Codesigning SideDeck.app..."
/usr/bin/codesign --force --deep --sign - "$APP_DIR"

echo "Creating DMG package..."
STAGING_DIR="$BUILD_DIR/dmg_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

ditto "$APP_DIR" "$STAGING_DIR/SideDeck.app"
ln -s /Applications "$STAGING_DIR/Applications"

if [[ -f "$RESOURCES_DIR/SideDeck.icns" ]]; then
  cp "$RESOURCES_DIR/SideDeck.icns" "$STAGING_DIR/.VolumeIcon.icns"
  /usr/bin/SetFile -a C "$STAGING_DIR" 2>/dev/null || true
fi

DMG_OUTPUT="$BUILD_DIR/SideDeck-1.0.dmg"
rm -f "$DMG_OUTPUT"

hdiutil create -ov -volname "SideDeck" -srcfolder "$STAGING_DIR" -format UDZO "$DMG_OUTPUT"
rm -rf "$STAGING_DIR"

echo "SideDeck packaged successfully at $DMG_OUTPUT"
