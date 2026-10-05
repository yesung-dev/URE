import AppKit

let points = NSSize(width: 640, height: 380)
let pixels = points

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(pixels.width),
    pixelsHigh: Int(pixels.height),
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
NSColor(calibratedRed: 0.965, green: 0.965, blue: 0.97, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: points)).fill()

let arrow = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)!
    .withSymbolConfiguration(.init(pointSize: 44, weight: .semibold))!
let tinted = NSImage(size: arrow.size, flipped: false) { rect in
    arrow.draw(in: rect)
    NSColor(calibratedWhite: 0.62, alpha: 1).set()
    rect.fill(using: .sourceAtop)
    return true
}
let arrowSize = tinted.size
// Measured against the Finder window: a mark at image (320, 86) from the top
// lands near (367, 162). The gap between the icons is near (267, 123).
let arrowCenter = NSPoint(x: 220, y: points.height - 47)
let arrowOrigin = NSPoint(
    x: arrowCenter.x - arrowSize.width / 2,
    y: arrowCenter.y - arrowSize.height / 2
)
tinted.draw(at: arrowOrigin, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Could not encode the disk image background.\n", stderr)
    exit(1)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: output)
