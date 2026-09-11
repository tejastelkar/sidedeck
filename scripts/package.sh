#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/SideDeck.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

INSTALL_APP=false
CREATE_DMG=true
APP_VERSION="1.2.0"
APP_BUILD="5"

for arg in "$@"; do
  case "$arg" in
    --install) INSTALL_APP=true ;;
    --app-only) CREATE_DMG=false ;;
    --help)
      echo "Usage: ./scripts/package.sh [--app-only] [--install]"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

echo "Compiling SideDeck..."
cd "$ROOT_DIR"
xcrun swift build -c release
BIN_DIR="$(xcrun swift build -c release --show-bin-path)"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$BIN_DIR/SideDeck" "$MACOS_DIR/SideDeck"
chmod +x "$MACOS_DIR/SideDeck"

# Copy Icon
if [[ -f "$ROOT_DIR/Resources/SideDeck.icns" ]]; then
  cp "$ROOT_DIR/Resources/SideDeck.icns" "$RESOURCES_DIR/SideDeck.icns"
fi

# Create Info.plist
cat << PLIST > "$CONTENTS_DIR/Info.plist"
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
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_BUILD</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>SideDeck uses Location permission only to display the name of the Wi-Fi network your Mac is currently connected to.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Tejas Telkar. All rights reserved.</string>
</dict>
</plist>
PLIST

echo "Codesigning SideDeck.app..."
/usr/bin/codesign --force --deep --sign - "$APP_DIR"

if [[ "$INSTALL_APP" == true ]]; then
  echo "Installing SideDeck.app to /Applications..."
  rm -rf "/Applications/SideDeck.app"
  ditto "$APP_DIR" "/Applications/SideDeck.app"
fi

if [[ "$CREATE_DMG" != true ]]; then
  echo "SideDeck app built successfully at $APP_DIR"
  exit 0
fi

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

DMG_OUTPUT="$BUILD_DIR/SideDeck-$APP_VERSION.dmg"
rm -f "$DMG_OUTPUT"

hdiutil create -ov -volname "SideDeck" -srcfolder "$STAGING_DIR" -format UDZO "$DMG_OUTPUT"
rm -rf "$STAGING_DIR"

echo "SideDeck packaged successfully at $DMG_OUTPUT"
