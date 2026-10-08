// Draws the app icon and writes Resources/AppIcon.icns and docs/icon.png
// (the README's copy; GitHub can't show .icns).
// Run: swift scripts/make-icon.swift   (from the repo root)
import AppKit

func draw(_ px: Int) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let ctx = NSGraphicsContext.current!.cgContext
  let s = CGFloat(px) / 1024  // design on a 1024 grid
  ctx.scaleBy(x: s, y: s)

  // Tile: Apple's 824pt rounded square inside the 1024 canvas, with a soft drop shadow.
  let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
  let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor(white: 0, alpha: 0.35).cgColor)
  ctx.addPath(tilePath); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
  ctx.restoreGState()
  ctx.saveGState()
  ctx.addPath(tilePath); ctx.clip()
  let bg = CGGradient(colorsSpace: nil, colors: [
    NSColor(srgbRed: 0.40, green: 0.45, blue: 1.00, alpha: 1).cgColor,
    NSColor(srgbRed: 0.22, green: 0.16, blue: 0.68, alpha: 1).cgColor,
  ] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
  ctx.restoreGState()

  // Swap arrows: two arcs circling the mouse, each ending in an arrowhead.
  let center = CGPoint(x: 512, y: 512), radius: CGFloat = 300
  // Drawn opaque inside a translucent layer so arc and head don't double up.
  ctx.setAlpha(0.55); ctx.beginTransparencyLayer(auxiliaryInfo: nil)
  ctx.setStrokeColor(NSColor.white.cgColor)
  ctx.setFillColor(NSColor.white.cgColor)
  ctx.setLineWidth(34); ctx.setLineCap(.round)
  for (start, end) in [(CGFloat.pi * 0.62, CGFloat.pi * 1.30), (CGFloat.pi * 1.62, CGFloat.pi * 2.30)] {
    ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    ctx.strokePath()
    let tip = CGPoint(x: center.x + radius * cos(end), y: center.y + radius * sin(end))
    let dir = end + .pi / 2  // tangent, direction of travel
    let back = dir + .pi
    let head = CGMutablePath()
    head.move(to: CGPoint(x: tip.x + 46 * cos(dir), y: tip.y + 46 * sin(dir)))
    head.addLine(to: CGPoint(x: tip.x + 50 * cos(back + 0.9), y: tip.y + 50 * sin(back + 0.9)))
    head.addLine(to: CGPoint(x: tip.x + 50 * cos(back - 0.9), y: tip.y + 50 * sin(back - 0.9)))
    head.closeSubpath()
    ctx.addPath(head); ctx.fillPath()
  }
  ctx.endTransparencyLayer(); ctx.setAlpha(1)

  // Mouse body.
  let body = CGRect(x: 512 - 150, y: 512 - 215, width: 300, height: 430)
  let bodyPath = CGPath(roundedRect: body, cornerWidth: 150, cornerHeight: 150, transform: nil)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor(white: 0, alpha: 0.30).cgColor)
  ctx.addPath(bodyPath); ctx.setFillColor(NSColor.white.cgColor); ctx.fillPath()
  ctx.restoreGState()
  ctx.saveGState()
  ctx.addPath(bodyPath); ctx.clip()
  let shade = CGGradient(colorsSpace: nil, colors: [
    NSColor(white: 1, alpha: 1).cgColor, NSColor(srgbRed: 0.86, green: 0.87, blue: 0.94, alpha: 1).cgColor,
  ] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(shade, start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: [])
  // Button split, from the top down to the wheel.
  ctx.setStrokeColor(NSColor(srgbRed: 0.70, green: 0.72, blue: 0.82, alpha: 1).cgColor)
  ctx.setLineWidth(8)
  ctx.move(to: CGPoint(x: 512, y: body.maxY)); ctx.addLine(to: CGPoint(x: 512, y: 560)); ctx.strokePath()
  ctx.restoreGState()

  // Scroll wheel, the star of the show.
  let wheel = CGRect(x: 512 - 26, y: 560, width: 52, height: 110)
  ctx.addPath(CGPath(roundedRect: wheel, cornerWidth: 26, cornerHeight: 26, transform: nil))
  ctx.setFillColor(NSColor(srgbRed: 1.00, green: 0.70, blue: 0.20, alpha: 1).cgColor)
  ctx.fillPath()

  NSGraphicsContext.restoreGraphicsState()
  return rep
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
    try draw(size * scale).representation(using: .png, properties: [:])!
      .write(to: iconset.appendingPathComponent(name))
  }
}
try fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try p.run(); p.waitUntilExit()
try fm.createDirectory(atPath: "docs", withIntermediateDirectories: true)
try draw(512).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/icon.png"))
print("wrote Resources/AppIcon.icns and docs/icon.png")
