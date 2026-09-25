// The app's icon, drawn rather than exported: Brau's mark — B in Morse,
// –··· (Logomark in Design.swift, the same proportions) — near-black on a
// white plate. A Dock icon has to be an opaque square whether the mark wants
// a background or not.

import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let ink = NSColor(red: 0.08, green: 0.08, blue: 0.075, alpha: 1)
let paper = NSColor.white

/// The mark (see Logomark): dots 90 across, a dash of 270, 45 between —
/// `fraction` of the plate wide and centred on it.
func mark(in plate: NSRect, fraction: CGFloat) {
    let parts: [CGFloat] = [270, 90, 90, 90]
    let width = parts.reduce(0, +) + 45 * CGFloat(parts.count - 1)
    let scale = plate.width * fraction / width
    let h = 90 * scale
    var x = plate.midX - width * scale / 2
    ink.setFill()
    for part in parts {
        NSBezierPath(roundedRect: NSRect(x: x, y: plate.midY - h / 2, width: part * scale, height: h), xRadius: h / 2, yRadius: h / 2).fill()
        x += (part + 45) * scale
    }
}

func draw(_ size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    // Apple's grid: the shape takes 824 of 1024, and its corners are 22.37%.
    let s = size / 1024
    let plate = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let radius = 824 * 0.2237 * s
    let shape = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)

    // A soft shadow under the plate, the way every icon on the Dock has one.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.set()
    paper.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    mark(in: plate, fraction: 0.56)
    return image
}

func write(_ image: NSImage, to url: URL, pixels: Int) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff)
    else { return }
    // The bitmap is asked for at the pixel size, whatever the screen thinks.
    let sized = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    sized.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sized)
    NSGraphicsContext.current?.imageInterpolation = .high
    rep.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = sized.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: url)
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let image = draw(CGFloat(pixels))
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        write(image, to: out.appendingPathComponent(name), pixels: pixels)
    }
}
print("drew: \(out.path)")
