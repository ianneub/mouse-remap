import CoreGraphics
import Foundation

/// Rewrites the mouse's own events before apps see them:
/// - the main wheel scrolls the traditional way while the trackpad stays
///   natural (macOS has one setting for both);
/// - a middle click opens Mission Control instead of reaching the app.
/// Needs the Accessibility permission.
final class EventTap {
  private var tap: CFMachPort?
  /// Tags the scroll events we post, so the tap doesn't flip them back.
  private static let marker: Int64 = 0x4D52_4D50  // "MRMP"

  func start() -> Bool {
    let types: [CGEventType] = [.scrollWheel, .otherMouseDown, .otherMouseUp, .otherMouseDragged]
    let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
    let me = Unmanaged.passUnretained(self).toOpaque()
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: mask,
      callback: { _, type, event, refcon in
        let me = Unmanaged<EventTap>.fromOpaque(refcon!).takeUnretainedValue()
        return me.handle(type, event)
      },
      userInfo: me
    ) else { return false }
    self.tap = tap
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
  }

  private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      // macOS switches a slow tap off; switch it straight back on.
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      log("event tap was disabled (\(type.rawValue)); re-enabled")

    case .scrollWheel:
      // Our own replacements (below) come back through the tap; let them pass.
      if event.getIntegerValueField(.eventSourceUserData) == Self.marker { break }
      // Trackpads and Magic Mice tag every scroll with a gesture or momentum
      // phase; a wheel never does.
      let isWheel = event.getIntegerValueField(.scrollWheelEventScrollPhase) == 0
        && event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0
      let lines = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
      guard isWheel && naturalScrolling && lines != 0 else { break }
      // Rewriting the deltas in place doesn't stick on macOS 27, so swallow
      // the notch and post a fresh line-scroll the other way. The thumb
      // wheel's sideways delta is carried over unchanged.
      let sideways = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
      guard let flipped = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2,
                                  wheel1: Int32(-lines), wheel2: Int32(sideways), wheel3: 0)
      else { break }
      flipped.location = event.location
      flipped.flags = event.flags
      flipped.setIntegerValueField(.eventSourceUserData, value: Self.marker)
      flipped.post(tap: .cgSessionEventTap)
      return nil

    case .otherMouseDown, .otherMouseUp, .otherMouseDragged:
      // Button 2 is the wheel click. Swallow the whole click so the app under
      // the pointer never sees a stray down or up.
      if event.getIntegerValueField(.mouseEventButtonNumber) == 2 {
        if type == .otherMouseDown { DockAction.missionControl.perform() }
        return nil
      }

    default:
      break
    }
    return Unmanaged.passUnretained(event)
  }

  /// System Settings › Mouse/Trackpad › Natural scrolling (on when unset).
  /// Only then does the wheel need flipping.
  private var naturalScrolling: Bool {
    UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
  }
}
