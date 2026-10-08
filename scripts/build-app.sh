#!/bin/bash
# Build MouseRemap.app into ./build (release).
# Signed with the self-signed "MouseRemap Local Signing" identity in the login
# keychain, so the Accessibility and Input Monitoring grants survive rebuilds.
# Without it the build is ad-hoc signed, and macOS drops both grants on every
# rebuild that changes the binary.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN=$(swift build -c release --show-bin-path)
APP=build/MouseRemap.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/MouseRemap" "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.ianneub.mouse-remap</string>
  <key>CFBundleName</key><string>MouseRemap</string>
  <key>CFBundleExecutable</key><string>MouseRemap</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
IDENTITY="MouseRemap Local Signing"
if ! security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
  echo "warning: no \"$IDENTITY\" identity; ad-hoc signing (permissions reset each rebuild)" >&2
  IDENTITY=-
fi
codesign --force --sign "$IDENTITY" --identifier com.ianneub.mouse-remap "$APP"
echo "built $APP"
