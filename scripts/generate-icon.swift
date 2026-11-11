import AppKit

// Run from the repository root: swift scripts/generate-icon.swift
// Vector artwork is redrawn at every macOS icon resolution.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
let iconset = assets.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    let tile = rounded(NSRect(x: 80, y: 80, width: 864, height: 864), 194)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x060b22, alpha: 0.32)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -15)
    shadow.set()
    color(0x172449).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [color(0x101a31), color(0x253865), color(0x51548c)])!
        .draw(in: tile, angle: 65)

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    // A quiet pool of teal light makes the dark tile feel dimensional.
    NSGradient(starting: color(0x4de6ce, alpha: 0.20), ending: color(0x4de6ce, alpha: 0))!
        .draw(fromCenter: NSPoint(x: 870, y: 120), radius: 0,
              toCenter: NSPoint(x: 870, y: 120), radius: 760, options: [])
    NSGraphicsContext.restoreGraphicsState()

    color(0xffffff, alpha: 0.16).setStroke()
    let rim = rounded(NSRect(x: 83, y: 83, width: 858, height: 858), 191)
    rim.lineWidth = 3
    rim.stroke()

    // Page-like inset, with enough negative space to read clearly in the Dock.
    let page = rounded(NSRect(x: 172, y: 218, width: 680, height: 588), 66)
    color(0x091326, alpha: 0.24).setFill()
    page.fill()
    color(0xc8dcff, alpha: 0.15).setStroke()
    page.lineWidth = 3
    page.stroke()

    let m = NSBezierPath()
    m.move(to: NSPoint(x: 258, y: 416))
    m.line(to: NSPoint(x: 258, y: 634))
    m.line(to: NSPoint(x: 369, y: 506))
    m.line(to: NSPoint(x: 480, y: 634))
    m.line(to: NSPoint(x: 480, y: 416))
    m.lineWidth = 56
    m.lineCapStyle = .round
    m.lineJoinStyle = .round
    color(0xf3f7ff).setStroke()
    m.stroke()

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 681, y: 646))
    arrow.line(to: NSPoint(x: 681, y: 420))
    arrow.move(to: NSPoint(x: 603, y: 494))
    arrow.line(to: NSPoint(x: 681, y: 416))
    arrow.line(to: NSPoint(x: 759, y: 494))
    arrow.lineWidth = 52
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    color(0x77f4d5).setStroke()
    arrow.stroke()

    // Small typesetting details below the Markdown monogram.
    color(0xc1d4ff, alpha: 0.28).setFill()
    rounded(NSRect(x: 234, y: 305, width: 288, height: 14), 7).fill()
    color(0x77f4d5, alpha: 0.55).setFill()
    rounded(NSRect(x: 548, y: 305, width: 76, height: 14), 7).fill()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let filename = "icon_\(points)x\(points)\(suffix).png"
        try drawIcon(size: points * scale).write(to: iconset.appendingPathComponent(filename))
    }
}
try drawIcon(size: 1024).write(to: assets.appendingPathComponent("AppIcon.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", assets.appendingPathComponent("AppIcon.icns").path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }
try FileManager.default.removeItem(at: iconset)
print("Generated Assets/AppIcon.icns and Assets/AppIcon.png")
