#!/usr/bin/env swift
//
//  Draws the Perch icon: a bird perched on the menu bar, with the load graph
//  it watches rising behind it.
//
//  Run it from anywhere -- paths are resolved from this file's own location:
//
//      swift Tools/makeicon.swift
//
//  It writes the app's icon set:
//
//      Perch/.../Assets.xcassets/AppIcon.appiconset
//
//  Everything is drawn in unit coordinates and scaled, so every size in the set
//  is rendered natively rather than resampled from one big PNG, and the small
//  sizes can drop detail that would only turn to mush.
//
import AppKit

// MARK: - palette

let skyTop    = NSColor(srgbRed: 0.35, green: 0.72, blue: 1.00, alpha: 1)
let skyMid    = NSColor(srgbRed: 0.17, green: 0.40, blue: 0.88, alpha: 1)
let skyBottom = NSColor(srgbRed: 0.07, green: 0.12, blue: 0.40, alpha: 1)
let inkColor  = NSColor(srgbRed: 0.05, green: 0.09, blue: 0.30, alpha: 1)
let birdColor = NSColor.white
let beakColor = NSColor(srgbRed: 1.00, green: 0.73, blue: 0.22, alpha: 1)

// MARK: - the plate

/// The macOS icon shape is a superellipse -- continuous curvature into the
/// corners -- not a rounded rectangle, which reads visibly pinched next to the
/// system icons it sits beside.
func squircle(in r: NSRect, n: CGFloat = 4.7) -> NSBezierPath {
    let path = NSBezierPath()
    let a = r.width / 2, b = r.height / 2, cx = r.midX, cy = r.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = cy + b * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        if i == 0 { path.move(to: NSPoint(x: x, y: y)) } else { path.line(to: NSPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

// MARK: - the glyph

/// Bird, perch and graph, in unit coordinates inside the icon plate.
///
/// `detailed` is false for 16pt, where the wing, the eye and the graph are all
/// under a pixel wide and only muddy the silhouette.
func drawGlyph(in r: NSRect, detailed: Bool) {
    let s = r.width
    let dy: CGFloat = -0.048          // drops the whole scene to sit level in the plate
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: r.minX + x * s, y: r.minY + (y + dy) * s)
    }
    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: r.minX + x * s, y: r.minY + (y + dy) * s, width: w * s, height: h * s)
    }

    // the readout: the load graph rising behind the bird, off the perch
    if detailed {
        let colW: CGFloat = 0.092, gap: CGFloat = 0.038
        let heights: [CGFloat] = [0.140, 0.235, 0.330, 0.190, 0.285]
        var x = (1 - (colW * 5 + gap * 4)) / 2
        for h in heights {
            let rect = box(x, 0.350, colW, h)
            let radius = colW * s * 0.28
            NSColor.white.withAlphaComponent(0.17).setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            x += colW + gap
        }
    }

    // the perch: the menu bar the whole app lives on
    let barH: CGFloat = 0.050
    let bar = NSBezierPath(roundedRect: box(0.120, 0.300, 0.760, barH),
                           xRadius: barH * s / 2, yRadius: barH * s / 2)
    birdColor.setFill()
    bar.fill()

    // legs
    let legs = NSBezierPath()
    legs.lineWidth = 0.030 * s
    legs.lineCapStyle = .round
    legs.move(to: p(0.452, 0.362)); legs.line(to: p(0.452, 0.500))
    legs.move(to: p(0.540, 0.362)); legs.line(to: p(0.540, 0.500))
    birdColor.setStroke()
    legs.stroke()

    // body: one flowing teardrop -- chest to the right, tail swept back and up
    let body = NSBezierPath()
    body.move(to: p(0.556, 0.700))
    body.curve(to: p(0.372, 0.575), controlPoint1: p(0.492, 0.706), controlPoint2: p(0.412, 0.646))
    body.curve(to: p(0.248, 0.646), controlPoint1: p(0.326, 0.596), controlPoint2: p(0.286, 0.626))
    body.line(to: p(0.304, 0.542))
    body.curve(to: p(0.392, 0.504), controlPoint1: p(0.332, 0.528), controlPoint2: p(0.358, 0.514))
    body.curve(to: p(0.532, 0.480), controlPoint1: p(0.420, 0.482), controlPoint2: p(0.470, 0.468))
    body.curve(to: p(0.644, 0.606), controlPoint1: p(0.606, 0.492), controlPoint2: p(0.646, 0.544))
    body.curve(to: p(0.556, 0.700), controlPoint1: p(0.642, 0.656), controlPoint2: p(0.604, 0.694))
    body.close()
    birdColor.setFill()
    body.fill()

    // head
    let headR: CGFloat = 0.104
    NSBezierPath(ovalIn: box(0.574 - headR, 0.728 - headR, headR * 2, headR * 2)).fill()

    // wing: one soft cut so the profile still reads as a bird, not a blob
    if detailed {
        let wing = NSBezierPath()
        wing.move(to: p(0.344, 0.588))
        wing.curve(to: p(0.538, 0.548), controlPoint1: p(0.416, 0.612), controlPoint2: p(0.486, 0.586))
        wing.curve(to: p(0.344, 0.588), controlPoint1: p(0.480, 0.510), controlPoint2: p(0.386, 0.530))
        wing.close()
        skyBottom.withAlphaComponent(0.16).setFill()
        wing.fill()
    }

    // beak
    let beak = NSBezierPath()
    beak.move(to: p(0.656, 0.752))
    beak.line(to: p(0.800, 0.714))
    beak.line(to: p(0.656, 0.682))
    beak.close()
    beakColor.setFill()
    beak.fill()

    // eye
    if detailed {
        inkColor.setFill()
        NSBezierPath(ovalIn: box(0.600, 0.742, 0.034, 0.034)).fill()
    }
}

// MARK: - rendering

/// Renders at exact pixel dimensions.
///
/// NSImage.lockFocus() draws into a context at the screen's backing scale, so
/// on a Retina display every size came out twice as large as asked for and the
/// asset catalog rejected the whole set. Drawing into an explicitly sized
/// bitmap rep, with its size in points equal to its size in pixels, pins it to
/// 1x.
func makeIcon(size: CGFloat) -> NSBitmapImageRep {
    let pixels = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high

    // Apple's grid: the plate is 824/1024 of the canvas, centred, with the
    // margin left to the shadow.
    let side = size * 0.8047
    let rect = NSRect(x: (size - side) / 2, y: (size - side) / 2 + size * 0.010,
                      width: side, height: side)
    let shape = squircle(in: rect)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.014)
    shadow.shadowBlurRadius = size * 0.028
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [skyTop, skyMid, skyBottom], atLocations: [0, 0.46, 1], colorSpace: .sRGB)!
        .draw(in: shape, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    // light falling from the top, rather than the old gloss ellipse
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.15), NSColor.white.withAlphaComponent(0)],
               atLocations: [0, 1], colorSpace: .sRGB)!
        .draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2),
              angle: -90)
    drawGlyph(in: rect, detailed: size >= 24)
    NSGraphicsContext.restoreGraphicsState()

    // hairline rim, so the edge stays crisp against a light wallpaper
    if size >= 24 {
        let rim = squircle(in: rect.insetBy(dx: size * 0.002, dy: size * 0.002))
        rim.lineWidth = size * 0.004
        NSColor.white.withAlphaComponent(0.16).setStroke()
        rim.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ size: CGFloat, to path: String) {
    guard let png = makeIcon(size: size).representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("failed to render \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
    } catch {
        FileHandle.standardError.write("failed to write \(path): \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

// MARK: - write both sets

// Tools/makeicon.swift -> the repository root
let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // Tools
    .deletingLastPathComponent()   // repo

// The merged app's asset catalog. The " 1" names are the second entry for a
//    size that the catalog lists at both 1x and 2x; they have to stay as Xcode
//    named them.
let appicon = root
    .appendingPathComponent("Perch/Supporting Files/Assets.xcassets/AppIcon.appiconset").path

let appiconVariants: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),        ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),        ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),     ("icon_256x256 1.png", 256),
    ("icon_256x256.png", 256),     ("icon_512x512 1.png", 512),
    ("icon_512x512.png", 512),     ("icon_512x512@2x.png", 1024),
]
for (name, size) in appiconVariants { write(size, to: "\(appicon)/\(name)") }
print("wrote AppIcon.appiconset (\(appiconVariants.count) sizes)")
