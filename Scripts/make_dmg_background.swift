import AppKit

// The image is the Finder icon view, 72 dpi, one pixel per point.
// arrowX and arrowY use the same coordinates as create-dmg icon positions:
// origin at the top left, y growing downward.

let arguments = CommandLine.arguments
guard arguments.count == 6,
      let width = Int(arguments[2]),
      let height = Int(arguments[3]),
      let arrowX = Double(arguments[4]),
      let arrowY = Double(arguments[5]),
      width > 0, height > 0
else {
    fputs("usage: make_dmg_background.swift output.png width height arrowX arrowY\n", stderr)
    exit(1)
}

let points = NSSize(width: width, height: height)
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Could not create the disk image background.\n", stderr)
    exit(1)
}
rep.size = points

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedRed: 0.973, green: 0.973, blue: 0.976, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: points)).fill()

let arrow = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)!
    .withSymbolConfiguration(.init(pointSize: 40, weight: .semibold))!
let tinted = NSImage(size: arrow.size, flipped: false) { rect in
    arrow.draw(in: rect)
    NSColor(calibratedWhite: 0.55, alpha: 1).set()
    rect.fill(using: .sourceAtop)
    return true
}
let arrowSize = tinted.size
let origin = NSPoint(
    x: arrowX - arrowSize.width / 2,
    y: Double(height) - arrowY - arrowSize.height / 2
)
tinted.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Could not encode the disk image background.\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: arguments[1]))
