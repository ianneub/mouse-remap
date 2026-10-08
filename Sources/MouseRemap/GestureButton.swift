import Foundation
import IOKit.hid

/// Takes over the MX Master 3's thumb (gesture) button over Logitech's HID++ 2.0
/// protocol. The button sends no ordinary mouse event, so we ask the mouse to
/// "divert" it to us (feature REPROG_CONTROLS_V4) and act on its press reports.
///
/// The mouse forgets the divert whenever it reconnects, so it is re-sent each
/// time the device appears and whenever the mouse announces a reconnect
/// (feature WIRELESS_DEVICE_STATUS). Needs the Input Monitoring permission.
final class GestureButton {
  static let vendorID = 0x046D
  static let productID = 0xB023          // MX Master 3, Bluetooth
  static let controlID: UInt16 = 0x00C3  // "Mouse Gesture Button"
  static let action = DockAction.showDesktop

  private static let longReport: UInt8 = 0x11
  private static let bluetoothDevice: UInt8 = 0xFF
  private static let swID: UInt8 = 0x0A  // tags our requests; notifications use 0
  private static let reprogControls: UInt16 = 0x1B04
  private static let deviceStatus: UInt16 = 0x1D4B

  private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
  private var device: IOHIDDevice?
  private let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)

  /// Feature indexes on this connection, learned from the root feature.
  private var reprogIndex: UInt8?
  private var statusIndex: UInt8?
  private var pressed = false

  init() {
    IOHIDManagerSetDeviceMatching(manager, [
      kIOHIDVendorIDKey: Self.vendorID, kIOHIDProductIDKey: Self.productID,
      kIOHIDDeviceUsagePageKey: 0xFF43, kIOHIDDeviceUsageKey: 0x0202,  // HID++ collection
    ] as CFDictionary)
    let me = Unmanaged.passUnretained(self).toOpaque()
    IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, dev in
      Unmanaged<GestureButton>.fromOpaque(ctx!).takeUnretainedValue().attach(dev)
    }, me)
    IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, dev in
      Unmanaged<GestureButton>.fromOpaque(ctx!).takeUnretainedValue().detach(dev)
    }, me)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
  }

  /// Fails with kIOReturnNotPermitted until Input Monitoring is granted;
  /// safe to call again.
  func start() -> IOReturn {
    let rc = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    // A mouse matched while the open was still being refused got nothing
    // sent to it; claim the button now that we can talk to it.
    if rc == kIOReturnSuccess, let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
      devices.forEach(attach)
    }
    return rc
  }

  private func attach(_ dev: IOHIDDevice) {
    log("MX Master 3 connected")
    device = dev
    reprogIndex = nil
    statusIndex = nil
    pressed = false
    let me = Unmanaged.passUnretained(self).toOpaque()
    IOHIDDeviceRegisterInputReportCallback(dev, reportBuffer, 64, { ctx, _, _, _, _, report, length in
      let bytes = Array(UnsafeBufferPointer(start: report, count: length))
      Unmanaged<GestureButton>.fromOpaque(ctx!).takeUnretainedValue().received(bytes)
    }, me)
    lookUp(Self.reprogControls)
  }

  private func detach(_ dev: IOHIDDevice) {
    guard dev == device else { return }
    log("MX Master 3 disconnected")
    device = nil
  }

  // MARK: HID++ messages

  /// Root feature (index 0), function 0: getFeature(featureID) -> index.
  private func lookUp(_ feature: UInt16) {
    send(featureIndex: 0, function: 0, [UInt8(feature >> 8), UInt8(feature & 0xFF)])
  }

  /// REPROG_CONTROLS_V4 function 3: setCidReporting(cid, divert + divert-valid).
  private func divert() {
    guard let reprogIndex else { return }
    send(featureIndex: reprogIndex, function: 3,
         [UInt8(Self.controlID >> 8), UInt8(Self.controlID & 0xFF), 0x03])
  }

  private func send(featureIndex: UInt8, function: UInt8, _ params: [UInt8]) {
    guard let device else { return }
    var report = [UInt8](repeating: 0, count: 20)
    report[0] = Self.longReport
    report[1] = Self.bluetoothDevice
    report[2] = featureIndex
    report[3] = function << 4 | Self.swID
    report.replaceSubrange(4..<4 + params.count, with: params)
    let rc = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, CFIndex(Self.longReport), report, report.count)
    if rc != kIOReturnSuccess { log(String(format: "HID++ send failed: 0x%08x", rc)) }
  }

  private func received(_ r: [UInt8]) {
    guard r.count >= 8, r[0] == Self.longReport else { return }
    let index = r[2], function = r[3] >> 4, sw = r[3] & 0x0F

    if index == 0xFF {  // error reply: [.., 0xFF, failed index, failed fn|sw, error code]
      log(String(format: "HID++ error %d for feature index %d function %d", r[5], r[3], r[4] >> 4))
      return
    }

    if index == 0 && sw == Self.swID {
      // getFeature replies don't echo which feature was asked for, so the
      // lookups run one at a time: REPROG_CONTROLS_V4 first, then status.
      let found = r[4]
      if reprogIndex == nil {
        reprogIndex = found
        guard found != 0 else { log("mouse has no REPROG_CONTROLS_V4"); return }
        divert()
        lookUp(Self.deviceStatus)
      } else if statusIndex == nil {
        statusIndex = found
      }
      return
    }

    if index == reprogIndex && sw == Self.swID && function == 3 {
      log(String(format: "thumb button 0x%04x diverted", Self.controlID))
      return
    }

    if index == reprogIndex && sw == 0 && function == 0 {
      // divertedButtonsEvent: up to four held control IDs, zero-padded.
      let held = stride(from: 4, to: 12, by: 2).map { UInt16(r[$0]) << 8 | UInt16(r[$0 + 1]) }
      let isDown = held.contains(Self.controlID)
      if isDown && !pressed { Self.action.perform() }
      pressed = isDown
      return
    }

    if let statusIndex, statusIndex != 0, index == statusIndex && sw == 0 {
      log("mouse reconnected; re-diverting thumb button")
      divert()
    }
  }
}
