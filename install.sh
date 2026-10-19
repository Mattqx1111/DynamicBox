#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

chmod +x package_app.sh
./package_app.sh

pkill -9 -f "DynamicBox" 2>/dev/null || true
pkill -9 -f "NotchBox Pro.app/Contents/MacOS/NotchBox" 2>/dev/null || true
pkill -9 -f "NotchBox" 2>/dev/null || true
sleep 0.5

rm -rf "/Applications/NotchBox Pro.app"
rm -f "$HOME/Library/LaunchAgents/com.notchbox.pro.plist"

DEST="/Applications/DynamicBox.app"
rm -rf "$DEST"
cp -R DynamicBox.app "$DEST"
chmod -R 755 "$DEST"
touch "$DEST"

LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.dynamicbox.app.plist"
mkdir -p "$HOME/Library/LaunchAgents"

cat << 'EOF' > "$LAUNCH_AGENT"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dynamicbox.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/DynamicBox.app/Contents/MacOS/DynamicBox</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

open "$DEST"
