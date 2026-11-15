#!/usr/bin/env swift
// Draws the Lights Bridge app icon and writes Resources/AppIcon.png (1024 px) and
// Resources/AppIcon.icns. Run from anywhere:  swift scripts/make-icon.swift
// Uses only AppKit/CoreGraphics and the system `iconutil`.
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func offset(_ p: NSPoint, _ d: NSPoint, _ k: CGFloat) -> NSPoint { NSPoint(x: p.x + d.x * k, y: p.y + d.y * k) }

/// Fills an ellipse with a radial gradient: `stops` are (location 0...1, color), center to edge.
func fillRadialEllipse(center: NSPoint, rx: CGFloat, ry: CGFloat, stops: [(CGFloat, NSColor)]) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let cg = CGGradient(colorsSpace: space, colors: stops.map { $0.1.cgColor } as CFArray,
                        locations: stops.map { $0.0 })!
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.scaleBy(x: 1, y: ry / rx)
    ctx.drawRadialGradient(cg, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: rx, options: [])
    ctx.restoreGState()
}

/// Draws the whole icon in 1024 x 1024 coordinates into the current context.
/// `k` is output pixels per unit; it only scales shadow sizes (NSShadow ignores the CTM).
func drawIcon(k: CGFloat) {
    // Tile: Big Sur style rounded square, 824 px centered on the canvas, with a soft drop shadow.
    let tileRect = NSRect(x: 100, y: 100, width: 824, height: 824)
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
    shadow.shadowOffset = NSSize(width: 0, height: -12 * k)
    shadow.shadowBlurRadius = 24 * k
    shadow.set()
    color(0x0A0D18).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()

    // Background: deep navy at the top to near black at the bottom.
    NSGradient(colors: [color(0x1F2F60), color(0x0E1530), color(0x040509)],
               atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
        .draw(in: tileRect, angle: -90)

    // ---- Geometry: everything hangs off one pivot and one axis angle. ----
    let axisDeg: CGFloat = -45                            // fixture points down-right
    let axisRad = axisDeg * .pi / 180
    let dir = NSPoint(x: cos(axisRad), y: sin(axisRad))   // along the axis
    let perp = NSPoint(x: -sin(axisRad), y: cos(axisRad)) // 90 degrees counter-clockwise from it
    let pivot = NSPoint(x: 335, y: 655)                   // barrel origin; local +x is `dir`

    // Fixture dimensions in its own frame (x along the axis, y across it).
    let barrelBack: CGFloat = -140, barrelFront: CGFloat = 100, barrelHalf: CGFloat = 80
    let lensX: CGFloat = 108, lensRX: CGFloat = 16, lensRY: CGFloat = 72

    func world(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: pivot.x + dir.x * x + perp.x * y, y: pivot.y + dir.y * x + perp.y * y)
    }

    // Beam: edges start exactly at the lens ends and spread +/- `spread` about the axis
    // until they reach the floor line. The pool is fitted to those two hit points.
    let lensC = world(lensX, 0)
    let rimW: CGFloat = 4   // rim thickness; the beam starts at the outer ends of the rim
    let lensTop = world(lensX, lensRY + rimW), lensBottom = world(lensX, -(lensRY + rimW))
    let spread: CGFloat = 6 * .pi / 180
    let floorY: CGFloat = 305
    func hit(from p: NSPoint, angle: CGFloat) -> NSPoint {
        let d = NSPoint(x: cos(angle), y: sin(angle))
        let t = (floorY - p.y) / d.y
        return NSPoint(x: p.x + d.x * t, y: floorY)
    }
    let hitRight = hit(from: lensTop, angle: axisRad + spread)      // shallower edge, lands farther right
    let hitLeft = hit(from: lensBottom, angle: axisRad - spread)    // steeper edge, lands farther left
    let floorC = NSPoint(x: (hitLeft.x + hitRight.x) / 2, y: floorY)
    let floorRX = (hitRight.x - hitLeft.x) / 2
    let floorRY: CGFloat = floorRX * 0.27

    // Beam cone, fading toward the floor.
    let cone = NSBezierPath()
    cone.move(to: lensTop)
    cone.line(to: hitRight)
    cone.curve(to: hitLeft,
               controlPoint1: NSPoint(x: hitRight.x, y: floorY - floorRY * 1.33),
               controlPoint2: NSPoint(x: hitLeft.x, y: floorY - floorRY * 1.33))
    cone.line(to: lensBottom)
    cone.close()
    NSGraphicsContext.saveGraphicsState()
    cone.addClip()
    NSGradient(colors: [color(0xFFE9BE, 0.95), color(0xFFC067, 0.5), color(0xFFB347, 0)],
               atLocations: [0, 0.5, 1], colorSpace: .sRGB)!
        .draw(from: NSPoint(x: lensC.x, y: lensC.y), to: NSPoint(x: lensC.x, y: floorY),
              options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation])
    NSGraphicsContext.restoreGraphicsState()

    // Pool of light: a soft radial ellipse, wider than the beam footprint so it hides the join.
    fillRadialEllipse(center: floorC, rx: floorRX * 1.22, ry: floorRY * 1.7, stops: [
        (0, color(0xFFEFCF, 1)), (0.3, color(0xFFCC7A, 0.8)),
        (0.62, color(0xFFB347, 0.3)), (1, color(0xFFB347, 0)),
    ])

    // ---- Yoke and stand. The pivot is the barrel's midpoint on its centerline. ----
    // Far arm, U bottom, stem and base are drawn behind the barrel; the near arm and knob in front.
    let pm = world((barrelBack + barrelFront) / 2, 0)
    let armDrop: CGFloat = barrelHalf / cos(axisRad) + 44  // from pivot to U bottom
    let uBottom = pm.y - armDrop
    let farX = pm.x - 84                                   // far arm, shifted for a 3/4 view
    let strokeW: CGFloat = 26
    func stroke(_ pts: [NSPoint], _ c: NSColor) {
        let path = NSBezierPath()
        path.lineWidth = strokeW
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: pts[0])
        for q in pts.dropFirst() { path.line(to: q) }
        c.setStroke()
        path.stroke()
    }
    let stemX = (pm.x + farX) / 2
    let stemBottom = uBottom - 52
    stroke([NSPoint(x: farX, y: pm.y), NSPoint(x: farX, y: uBottom)], color(0x565B6B))      // far arm
    stroke([NSPoint(x: farX, y: uBottom), NSPoint(x: pm.x, y: uBottom)], color(0x6C7182))   // bottom of the U
    stroke([NSPoint(x: stemX, y: uBottom), NSPoint(x: stemX, y: stemBottom)], color(0x6C7182))
    color(0x565B6B).setFill()
    NSBezierPath(roundedRect: NSRect(x: stemX - 56, y: stemBottom - 24, width: 112, height: 26),
                 xRadius: 13, yRadius: 13).fill()

    // ---- Fixture, drawn in its own frame via one affine transform about the pivot. ----
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: pivot.x, yBy: pivot.y)
    t.rotate(byDegrees: axisDeg)
    t.concat()

    // Rear cap.
    let capW: CGFloat = 26
    let cap = NSBezierPath(roundedRect: NSRect(x: barrelBack - capW + 8, y: -(barrelHalf - 14),
                                               width: capW, height: (barrelHalf - 14) * 2),
                           xRadius: 10, yRadius: 10)
    color(0x2B2E38).setFill()
    cap.fill()

    // Barrel: one rounded rectangle, lit from the upper side (+y).
    let barrelRect = NSRect(x: barrelBack, y: -barrelHalf, width: barrelFront - barrelBack, height: barrelHalf * 2)
    let barrel = NSBezierPath(roundedRect: barrelRect, xRadius: 24, yRadius: 24)
    NSGradient(colors: [color(0x23262F), color(0x464B5A), color(0x7C8294)],
               atLocations: [0, 0.55, 1], colorSpace: .sRGB)!.draw(in: barrel, angle: 90)

    // Cooling rings and a single highlight, clipped to the barrel.
    NSGraphicsContext.saveGraphicsState()
    barrel.addClip()
    color(0x15171E, 0.7).setFill()
    for x0 in [CGFloat(-108), CGFloat(-72)] {
        NSBezierPath(rect: NSRect(x: x0, y: -barrelHalf, width: 18, height: barrelHalf * 2)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    // Soft specular band across the upper third of the barrel; ends before the front lip.
    NSGraphicsContext.saveGraphicsState()
    barrel.addClip()
    NSBezierPath(roundedRect: NSRect(x: barrelBack - 30, y: barrelHalf * 0.34, width: (barrelFront - 22) - (barrelBack - 30),
                                     height: barrelHalf * 0.66 + 10), xRadius: 30, yRadius: 30).addClip()
    NSGradient(colors: [color(0xFFFFFF, 0), color(0xFFFFFF, 0.14), color(0xFFFFFF, 0.05)],
               atLocations: [0, 0.45, 1], colorSpace: .sRGB)!
        .draw(in: NSRect(x: barrelBack - 30, y: barrelHalf * 0.34, width: 300, height: barrelHalf * 0.66 + 10), angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // Front lip.
    let lip = NSBezierPath(roundedRect: NSRect(x: barrelFront - 8, y: -barrelHalf, width: 22, height: barrelHalf * 2),
                           xRadius: 6, yRadius: 6)
    color(0x9096A8).setFill()
    lip.fill()

    // Lens: bright ellipse with a thin rim, perpendicular to the axis.
    let rim = NSBezierPath(ovalIn: NSRect(x: lensX - lensRX - rimW, y: -lensRY - rimW, width: (lensRX + rimW) * 2, height: (lensRY + rimW) * 2))
    color(0xC9CDD9).setFill()
    rim.fill()
    let lens = NSBezierPath(ovalIn: NSRect(x: lensX - lensRX, y: -lensRY, width: lensRX * 2, height: lensRY * 2))
    NSGraphicsContext.saveGraphicsState()
    lens.addClip()
    NSGradient(colors: [color(0xFFFDF2), color(0xFFE6B0), color(0xFFBC5C)],
               atLocations: [0, 0.5, 1], colorSpace: .sRGB)!
        .draw(in: lens.bounds, relativeCenterPosition: NSPoint(x: 0.2, y: 0.1))
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()   // fixture frame

    // Near yoke arm, in front of the barrel, ending in the pivot knob on the barrel's centerline.
    stroke([NSPoint(x: pm.x, y: uBottom), pm], color(0x8A90A2))
    color(0xB4B9C7).setFill()
    NSBezierPath(ovalIn: NSRect(x: pm.x - 19, y: pm.y - 19, width: 38, height: 38)).fill()
    color(0x6C7182).setFill()
    NSBezierPath(ovalIn: NSRect(x: pm.x - 7, y: pm.y - 7, width: 14, height: 14)).fill()

    NSGraphicsContext.restoreGraphicsState()   // tile clip
}

/// Renders the icon at `pixels` x `pixels` (vector re-draw, not a resize, so small sizes stay crisp).
func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    let k = CGFloat(pixels) / 1024
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = NSAffineTransform()
    scale.scale(by: k)
    scale.concat()
    drawIcon(k: k)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: url)
}

// MARK: Main

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let resources = scriptURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("LightsBridge-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }

try writePNG(render(pixels: 1024), to: resources.appendingPathComponent("AppIcon.png"))
for base in [16, 32, 128, 256, 512] {
    try writePNG(render(pixels: base), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try writePNG(render(pixels: base * 2), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

// Optional review copies:  swift scripts/make-icon.swift <review-dir>
if CommandLine.arguments.count > 1 {
    let dir = URL(fileURLWithPath: CommandLine.arguments[1])
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try writePNG(render(pixels: 1024), to: dir.appendingPathComponent("icon-v2-1024.png"))
    // Strip of the 128, 64, 32 and 16 px renders side by side, enlarged 4x with nearest neighbor.
    let sizes = [128, 64, 32, 16], zoom = 4, gap = 24
    let width = sizes.reduce(0) { $0 + $1 * zoom + gap } + gap, height = 128 * zoom + gap * 2
    let strip = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: strip)
    NSGraphicsContext.current?.imageInterpolation = .none
    color(0x8E8E93).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    var x = gap
    for px in sizes {
        let rep = render(pixels: px)
        rep.draw(in: NSRect(x: x, y: gap, width: px * zoom, height: px * zoom), from: .zero, operation: .sourceOver,
                 fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.none.rawValue])
        x += px * zoom + gap
    }
    NSGraphicsContext.restoreGraphicsState()
    try writePNG(strip, to: dir.appendingPathComponent("icon-v2-small.png"))
}

let icns = resources.appendingPathComponent("AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", "-o", icns.path, iconset.path]
try p.run(); p.waitUntilExit()
guard p.terminationStatus == 0 else { print("iconutil failed"); exit(1) }
print("Wrote \(resources.path)/AppIcon.png and AppIcon.icns")
