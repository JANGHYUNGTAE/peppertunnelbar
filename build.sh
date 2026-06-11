#!/bin/bash
# Builds TunnelBar.app (a menu-bar-only app) from the Swift package.
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
echo "▶ swift build (-c $CONFIG)…"
swift build -c "$CONFIG"

BIN=".build/$CONFIG/TunnelBar"
APP="TunnelBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TunnelBar"
[ -f icon/AppIcon.icns ] && cp icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>TunnelBar</string>
  <key>CFBundleDisplayName</key>     <string>TunnelBar</string>
  <key>CFBundleIdentifier</key>      <string>com.peppercode.tunnelbar</string>
  <key>CFBundleExecutable</key>      <string>TunnelBar</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <key>CFBundleIconFile</key>        <string>AppIcon</string>
  <key>CFBundleShortVersionString</key> <string>1.0</string>
  <key>CFBundleVersion</key>         <string>1</string>
  <key>LSMinimumSystemVersion</key>  <string>14.0</string>
  <key>LSUIElement</key>             <true/>
  <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS treats it as a stable local app.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "✅ Built $(pwd)/$APP"
echo "   실행:  open '$(pwd)/$APP'"
