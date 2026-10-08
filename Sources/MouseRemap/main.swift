import ApplicationServices
import Foundation
import IOKit.hid

// MX Master 3 remaps, nothing more:
//   main wheel      -> traditional scroll direction (trackpad stays natural)
//   wheel click     -> Mission Control
//   thumb button    -> Show Desktop
// Runs headless under launchd (scripts/install.sh).

func log(_ message: String) {
  FileHandle.standardError.write("\(Date().formatted(.iso8601)) \(message)\n".data(using: .utf8)!)
}

let eventTap = EventTap()
let gestureButton = GestureButton()
var tapStarted = false
var hidStarted = false

/// Starts each half once its permission is granted. Asks once at launch, then
/// polls, so granting in System Settings takes effect without a restart.
func startWhenPermitted(prompt: Bool) {
  if !tapStarted && AXIsProcessTrustedWithOptions(
    [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt] as CFDictionary) {
    tapStarted = eventTap.start()
    log(tapStarted ? "scroll + wheel-click remap active" : "event tap creation failed")
  }
  if !hidStarted {
    // IOHIDCheckAccess keeps answering "denied" after the grant until the
    // process restarts, so just retry the open itself.
    if prompt && IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeUnknown {
      IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
    let rc = gestureButton.start()
    hidStarted = rc == kIOReturnSuccess
    if hidStarted { log("thumb button remap active") }
    else if prompt { log(String(format: "HID open failed: 0x%08x", rc)) }
  }
}

startWhenPermitted(prompt: true)
if !tapStarted { log("waiting for Accessibility permission") }
if !hidStarted { log("waiting for Input Monitoring permission") }
Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { timer in
  startWhenPermitted(prompt: false)
  if tapStarted && hidStarted { timer.invalidate() }
}
CFRunLoopRun()
