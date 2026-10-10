#!/usr/bin/env swift
//
//  Draws the Perch icon: a bird perched on the menu bar.
//
//  Two decisions worth keeping. The plate is Perch's own teal, #0E9BA8 --
//  the colour a calm reading is drawn in, the one on the README badges, and
//  a colour already validated for contrast and colour-vision deficiency in
//  Palette.swift. The icon used a generic blue that appeared nowhere else in
//  the app, so nothing on screen agreed with it.
//
//  And the load bars that used to sit behind the bird are gone. They were
//  white at 17% over a gradient: invisible at 128pt, and at 32pt they only
//  softened the one edge that has to survive -- the silhouette. An icon is
//  read at 16 points far more often than at 512, so the mark is now a bird,
//  a bar, and nothing else.
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

/// Perch's own colours. `skyMid` is #0E9BA8 and `beakColor` #CE7C00 exactly
/// -- the calm and warning colours from `Palette.swift`, not approximations,
/// so the icon and the menu bar it draws are the same two colours.
let skyTop    = NSColor(srgbRed: 0.23, green: 0.80, blue: 0.85, alpha: 1)   // lifted #0E9BA8
let skyMid    = NSColor(srgbRed: 0x0E / 255, green: 0x9B / 255, blue: 0xA8 / 255, alpha: 1)
let skyBottom = NSColor(srgbRed: 0.02, green: 0.21, blue: 0.29, alpha: 1)   // deep teal, not navy
let inkColor  = NSColor(srgbRed: 0.02, green: 0.16, blue: 0.22, alpha: 1)
let birdColor = NSColor.white
let beakColor = NSColor(srgbRed: 0xCE / 255, green: 0x7C / 255, blue: 0x00 / 255, alpha: 1)

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
    /// Scale about the plate's centre. The mark was drawn small inside its
    /// plate and read as timid beside the system icons, which fill theirs.
    let k: CGFloat = 1.12
    /// Drops the scene so the space above the bird and below the bar match.
    /// Measured off a render: it was 18% above and 33% below.
    let dy: CGFloat = -0.088
    func sx(_ x: CGFloat) -> CGFloat { 0.5 + (x - 0.5) * k }
    func sy(_ y: CGFloat) -> CGFloat { 0.5 + (y - 0.5) * k + dy }
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: r.minX + sx(x) * s, y: r.minY + sy(y) * s)
    }
    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: r.minX + sx(x) * s, y: r.minY + sy(y) * s,
               width: w * k * s, height: h * k * s)
    }

    // The perch: the menu bar the whole app lives on. Thicker than it was,
    // because it is now one of only two shapes and has to carry its half.
    let barH: CGFloat = 0.058
    let bar = NSBezierPath(roundedRect: box(0.140, 0.296, 0.720, barH),
                           xRadius: barH * k * s / 2, yRadius: barH * k * s / 2)
    birdColor.setFill()
    bar.fill()

    // Legs, short. A perched bird's legs are mostly hidden under it; the
    // long ones this had made it read as a wader standing in water.
    let legs = NSBezierPath()
    legs.lineWidth = 0.034 * k * s
    legs.lineCapStyle = .round
    legs.move(to: p(0.468, 0.368)); legs.line(to: p(0.468, 0.436))
    legs.move(to: p(0.560, 0.368)); legs.line(to: p(0.560, 0.436))
    birdColor.setStroke()
    legs.stroke()

    // Body and tail, built from two plain shapes rather than one clever
    // path. Three attempts at a single flowing outline each produced
    // something else at 128pt -- a paper dart, then a crescent -- because a
    // concave edge anywhere along the back reads as a raised wing. An oval
    // and a wedge cannot do that.
    birdColor.setFill()
    NSBezierPath(ovalIn: box(0.356, 0.430, 0.396, 0.276)).fill()

    let tail = NSBezierPath()
    // The tip stays below the line of the back. Above it, the eye reads the
    // tail as a raised wing instead, which was the fault in two earlier
    // attempts at this shape.
    tail.move(to: p(0.452, 0.640))
    tail.line(to: p(0.252, 0.654))                       // tip, swept back
    tail.line(to: p(0.424, 0.512))
    tail.close()
    tail.fill()

    // Head, set into the shoulders rather than balanced on top.
    let headR: CGFloat = 0.116
    NSBezierPath(ovalIn: box(0.636 - headR, 0.700 - headR, headR * 2, headR * 2)).fill()

    // Wing: a notch cut from the silhouette's own colour, not a grey slash
    // across it. The old one was a pale fill that read as a smudge at any
    // size below 128.
    if detailed {
        let wing = NSBezierPath()
        // Wholly inside the body, and a cut of the plate's own colour rather
        // than a pale tint: a wing fold, not a smudge.
        wing.move(to: p(0.452, 0.556))
        wing.curve(to: p(0.654, 0.508),
                   controlPoint1: p(0.520, 0.580), controlPoint2: p(0.598, 0.552))
        wing.curve(to: p(0.452, 0.556),
                   controlPoint1: p(0.600, 0.470), controlPoint2: p(0.506, 0.506))
        wing.close()
        skyBottom.withAlphaComponent(0.20).setFill()
        wing.fill()
    }

    // Beak: short and sharp. The old one was longer than the head was wide,
    // which is a seagull; Perch is a small bird on a bar.
    let beak = NSBezierPath()
    beak.move(to: p(0.728, 0.742))
    beak.line(to: p(0.838, 0.706))
    beak.line(to: p(0.728, 0.678))
    beak.close()
    beakColor.setFill()
    beak.fill()

    // Eye
    if detailed {
        inkColor.setFill()
        NSBezierPath(ovalIn: box(0.658, 0.726, 0.038, 0.038)).fill()
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
