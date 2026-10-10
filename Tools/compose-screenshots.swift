#!/usr/bin/env swift
//
//  compose-screenshots.swift
//
//  Builds the README's screenshot plates from raw window captures.
//
//  Kept in the repo rather than done by hand in an image editor so the plates
//  can be regenerated when the UI changes: same padding, same corner radius,
//  same background every time, and the captures stay the only input.
//
//  Usage:
//    swift Tools/compose-screenshots.swift out.png caption=path [caption=path ...]
//
//  All shots are drawn at one common height, so every window appears at the
//  same scale -- a collage where each pane has its own zoom level is the
//  clearest sign a screenshot plate was assembled by hand.
//

import AppKit

// MARK: - Arguments

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: compose-screenshots.swift out.png caption=path ...\n".data(using: .utf8)!)
    exit(2)
}
let outputPath = args[0]
let shots: [(caption: String, path: String)] = args.dropFirst().compactMap {
    guard let eq = $0.firstIndex(of: "=") else { return nil }
    return (String($0[$0.startIndex..<eq]), String($0[$0.index(after: eq)...]))
}

// MARK: - Layout

let plateHeight: CGFloat = 900     // the tallest window is drawn this tall
let gap: CGFloat = 44
let padding: CGFloat = 72
let captionHeight: CGFloat = 64
let radius: CGFloat = 26

let images: [(caption: String, image: NSImage)] = shots.compactMap {
    guard let image = NSImage(contentsOfFile: $0.path) else {
        FileHandle.standardError.write("cannot read \($0.path)\n".data(using: .utf8)!)
        return nil
    }
    return ($0.caption, image)
}
guard !images.isEmpty else { exit(1) }

// One scale factor for every shot, taken from the tallest.
//
// Scaling each window to a common *height* is the tempting version and it is
// wrong: a short wide pane then gets magnified and a tall narrow one shrunk, so
// the same 13pt label appears at three different sizes across one plate. A
// shared factor keeps every pixel at the same density and lets the windows
// differ in height, which is what they actually do on screen.
let tallest = images.map { $0.image.size.height }.max() ?? plateHeight
let scale = plateHeight / tallest
let sizes: [NSSize] = images.map {
    NSSize(width: ($0.image.size.width * scale).rounded(),
           height: ($0.image.size.height * scale).rounded())
}
let widths = sizes.map { $0.width }

let canvasWidth = padding * 2 + widths.reduce(0, +) + gap * CGFloat(images.count - 1)
let canvasHeight = padding * 2 + plateHeight + captionHeight
let canvas = NSSize(width: canvasWidth.rounded(), height: canvasHeight.rounded())

// MARK: - Draw

// Draw into an explicit bitmap rather than NSImage.lockFocus(): lockFocus
// renders at the current display's backing scale, so the same command produced
// a 3682px plate on a Retina Mac and an 1841px one elsewhere. Pixels are
// spelled out here, so the output is identical wherever it runs.
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: rep) else {
    FileHandle.standardError.write("cannot create bitmap\n".data(using: .utf8)!)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

// Flat, not a gradient. A smooth gradient across two thousand pixels gives
// PNG nothing to compress -- the first version of this plate was 9.7 MB, most
// of it background. Flat colour puts the same plate under 2 MB.
NSColor(calibratedRed: 0.063, green: 0.071, blue: 0.094, alpha: 1).setFill()
NSRect(origin: .zero, size: canvas).fill()

var x = padding
for (index, pair) in images.enumerated() {
    let width = widths[index]
    // Tops aligned, captions on one baseline: windows hang from a shelf rather
    // than floating at unrelated heights.
    let top = padding + captionHeight + plateHeight
    let frame = NSRect(x: x, y: top - sizes[index].height,
                       width: width, height: sizes[index].height)
    let rounded = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)

    // Shadow first, cast by a filled shape; the image then covers the fill.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shadow.shadowBlurRadius = 46
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    NSColor.black.setFill()
    rounded.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    rounded.addClip()
    pair.image.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    // A hairline edge keeps the window from bleeding into the background.
    NSColor.white.withAlphaComponent(0.10).setStroke()
    rounded.lineWidth = 2
    rounded.stroke()

    // Shrink the caption until it fits on one line. A caption wider than its
    // pane wraps, and a wrapped caption is then clipped by the rect it is drawn
    // in -- which is how the first plate shipped with "SEARCH" cut in half.
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineBreakMode = .byClipping
    let text = pair.caption.uppercased()
    var pointSize: CGFloat = 27
    var caption = NSAttributedString()
    while pointSize >= 14 {
        caption = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: pointSize, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.62),
            .kern: pointSize * 0.09,
            .paragraphStyle: style
        ])
        if caption.size().width <= width { break }
        pointSize -= 1
    }
    let captionSize = caption.size()
    caption.draw(in: NSRect(x: x, y: padding + (captionHeight - captionSize.height) / 2,
                            width: width, height: captionSize.height + 4))

    x += width + gap
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode png\n".data(using: .utf8)!)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("wrote \(outputPath) at \(Int(canvas.width))x\(Int(canvas.height))")
} catch {
    FileHandle.standardError.write("failed to write \(outputPath): \(error)\n".data(using: .utf8)!)
    exit(1)
}
