# MouseRemap

A tiny headless macOS app that does exactly three things for a Logitech
MX Master 3 connected over Bluetooth:

| Control | Does |
|---|---|
| Main scroll wheel | Scrolls the traditional way, while the trackpad keeps natural scrolling |
| Wheel click | Opens Mission Control |
| Thumb (gesture) button | Opens Show Desktop |

No configuration, no UI, no Logitech software. To change what a button does,
edit the code (see below) and reinstall.

## How it works

- **Scroll wheel and wheel click:** a `CGEventTap` sees mouse events before
  apps do. Wheel scrolls (no gesture or momentum phase, unlike a trackpad) are
  swallowed and re-posted in the opposite direction; editing the event in
  place doesn't stick on macOS 27.
- **Thumb button:** it sends no ordinary mouse event, so the app speaks
  Logitech's HID++ 2.0 protocol to the mouse and asks it to divert control
  `0x00C3` (REPROG_CONTROLS_V4). The mouse forgets this when it reconnects, so
  it is re-sent whenever the mouse appears or reports a reconnect.
- **Mission Control / Show Desktop** are triggered with the Dock's private
  `CoreDockSendNotification`, as hot corners do.

## Requirements

- macOS 15 or later (built and tested on macOS 27)
- Logitech MX Master 3 over Bluetooth (product ID `0xB023`). Other Logitech
  HID++ mice should work after changing `productID` in `GestureButton.swift`.
- Swift 6 toolchain (Command Line Tools are enough)

## Install

```sh
scripts/install.sh
```

This builds `MouseRemap.app`, copies it to `~/Applications`, and starts it at
login via a LaunchAgent. Then grant it, in System Settings › Privacy & Security:

- **Device Control and Data Access** (called *Accessibility* before macOS 27)
- **Input Monitoring**

If MouseRemap isn't listed, add `~/Applications/MouseRemap.app` with **+**
(⌘⇧G to type the path). After granting Input Monitoring, restart it once:

```sh
launchctl kickstart -k gui/$(id -u)/com.ianneub.mouse-remap
```

The log is `~/Library/Logs/MouseRemap.log`.

### Keeping permissions across rebuilds

macOS ties both permissions to the app's code signature. An ad-hoc signed
build gets a new signature every rebuild, so you'd have to grant them again
each time. `scripts/build-app.sh` signs with a self-signed identity named
**MouseRemap Local Signing** when your login keychain has one. To create it:

```sh
cat > /tmp/cs.cnf <<'CNF'
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=MouseRemap Local Signing
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout /tmp/cs.key -out /tmp/cs.pem -config /tmp/cs.cnf
openssl pkcs12 -export -inkey /tmp/cs.key -in /tmp/cs.pem -out /tmp/cs.p12 \
  -passout pass:temp -name "MouseRemap Local Signing" \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1
security import /tmp/cs.p12 -k ~/Library/Keychains/login.keychain-db \
  -P temp -T /usr/bin/codesign
rm /tmp/cs.key /tmp/cs.p12
```

(The legacy PKCS#12 options are needed because the keychain can't read
OpenSSL 3's default format.) `security find-identity -p codesigning` will
call it "not trusted"; that's fine for local signing.

## Customizing

- Button actions: `GestureButton.action` (thumb button) and the
  `otherMouseDown` case in `EventTap.swift` (wheel click). Available actions
  are in `DockActions.swift`: Mission Control, App Exposé, Show Desktop.
- Icon: `swift scripts/make-icon.swift` redraws `Resources/AppIcon.icns`.

## Uninstall

```sh
launchctl bootout gui/$(id -u)/com.ianneub.mouse-remap
rm ~/Library/LaunchAgents/com.ianneub.mouse-remap.plist
rm -rf ~/Applications/MouseRemap.app
```

## License

MIT. See [LICENSE](LICENSE).
