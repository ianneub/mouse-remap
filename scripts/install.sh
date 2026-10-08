#!/bin/bash
# Build, install to ~/Applications, and (re)start via a LaunchAgent so the
# remap comes up at login. Log: ~/Library/Logs/MouseRemap.log
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh
DEST="$HOME/Applications/MouseRemap.app"
LABEL=com.ianneub.mouse-remap
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x MouseRemap 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$DEST"
cp -R build/MouseRemap.app "$DEST"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/MouseRemap</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/MouseRemap.log</string>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/MouseRemap.log</string>
</dict>
</plist>
PLIST
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "installed $DEST; running under launchd as $LABEL"
