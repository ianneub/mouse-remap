import Foundation

/// Mission Control, App Exposé and Show Desktop, triggered the way the Dock's
/// own hot corners do it: the private CoreDockSendNotification in
/// ApplicationServices. Synthesized F3/F11 key presses are unreliable for these.
enum DockAction: String {
  case missionControl = "com.apple.expose.awake"
  case appExpose = "com.apple.expose.front.awake"
  case showDesktop = "com.apple.showdesktop.awake"

  private typealias SendFn = @convention(c) (CFString, Int32) -> Void

  private static let send: SendFn? = {
    let path = "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
    guard let handle = dlopen(path, RTLD_LAZY), let sym = dlsym(handle, "CoreDockSendNotification") else {
      log("CoreDockSendNotification not found; Dock actions disabled")
      return nil
    }
    return unsafeBitCast(sym, to: SendFn.self)
  }()

  func perform() {
    DockAction.send?(rawValue as CFString, 0)
  }
}
