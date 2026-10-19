#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "Building DynamicBox..."

SWIFTUI_MACRO=""
CANDIDATE_PATHS=(
  "$(xcode-select -p 2>/dev/null)/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib"
  "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib"
  "/Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib"
)

for p in "${CANDIDATE_PATHS[@]}"; do
  if [ -f "$p" ]; then
    SWIFTUI_MACRO="$p"
    break
  fi
done

SWIFT_FLAGS=(-O -framework Cocoa -framework SwiftUI -framework UniformTypeIdentifiers -framework Carbon -framework AVFoundation)
if [ -n "$SWIFTUI_MACRO" ]; then
  SWIFT_FLAGS+=(-load-plugin-library "$SWIFTUI_MACRO")
fi

swiftc "${SWIFT_FLAGS[@]}" Sources/*.swift -o DynamicBox

APP_BUNDLE="DynamicBox.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp DynamicBox "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/DynamicBox"

if [ -f "assets/AppIcon.icns" ]; then
  cp "assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi
if [ -f "assets/DND.shortcut" ]; then
  cp "assets/DND.shortcut" "$APP_BUNDLE/Contents/Resources/"
fi

cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DynamicBox</string>
    <key>CFBundleIdentifier</key>
    <string>com.dynamicbox.app</string>
    <key>CFBundleName</key>
    <string>DynamicBox</string>
    <key>CFBundleDisplayName</key>
    <string>DynamicBox</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>DynamicBox accesses media information to display currently playing music, video, and audio playback.</string>
</dict>
</plist>
EOF

echo "DynamicBox.app packaged successfully."
