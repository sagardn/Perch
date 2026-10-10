import AppKit

/// Perch's mark, drawn small enough for the menu bar.
///
/// It stands in for the app itself, and the only place it appears is the status
/// item that shows up while monitoring is paused — there is no reading to draw,
/// so the app says who is still there and gives the user something to click.
///
/// The geometry is the app icon's, from `Tools/makeicon.swift`, in the same
/// unit coordinates: a bird on the bar it watches. What is dropped is
/// everything the icon generator also drops below 32pt — the wing, the eye and
/// the load graph behind the bird are all under a pixel at this size and only
/// muddy the silhouette. Colour goes too: a menu bar image is a template, which
/// means one colour, and macOS inverts it for a dark bar and dims it when the
/// app is hidden. Drawing in `NSColor.textColor` instead would have missed both.
enum MenuBarIcon {

    /// 16×16, the size of a menu bar glyph beside 12pt text.
    static let size = CGSize(width: 16, height: 16)

    /// Made once. The image never changes — the template flag is what makes it
    /// follow the menu bar — so redrawing it per status-item update would be
    /// paying a bezier fill for the same pixels.
    static let image: NSImage = {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Perch"
        return image
    }()

    private static func draw(in rect: NSRect) {
        let s = rect.width
        // Lifts the scene off the bottom edge: the icon plate has padding the
        // menu bar does not, so without this the perch sits on the baseline.
        let dy: CGFloat = 0.06
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.minX + x * s, y: rect.minY + (y + dy) * s)
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: rect.minX + x * s, y: rect.minY + (y + dy) * s, width: w * s, height: h * s)
        }

        NSColor.black.setFill()
        NSColor.black.setStroke()

        // the perch
        let barH: CGFloat = 0.072
        NSBezierPath(roundedRect: box(0.120, 0.250, 0.760, barH),
                     xRadius: barH * s / 2, yRadius: barH * s / 2).fill()

        // legs. Thicker than the icon's, in proportion: 0.030 of 16pt is half a
        // point, which disappears entirely on a 1x display.
        let legs = NSBezierPath()
        legs.lineWidth = 0.055 * s
        legs.lineCapStyle = .round
        legs.move(to: p(0.452, 0.330)); legs.line(to: p(0.452, 0.470))
        legs.move(to: p(0.540, 0.330)); legs.line(to: p(0.540, 0.470))
        legs.stroke()

        // body: chest to the right, tail swept back and up
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
        body.fill()

        // head
        let headR: CGFloat = 0.104
        NSBezierPath(ovalIn: box(0.574 - headR, 0.728 - headR, headR * 2, headR * 2)).fill()

        // beak. Kept, unlike the wing and the eye: it is what turns a round
        // head into a bird facing right, and it is on the silhouette's edge
        // rather than inside it, so it survives at 16pt.
        let beak = NSBezierPath()
        beak.move(to: p(0.656, 0.752))
        beak.line(to: p(0.800, 0.714))
        beak.line(to: p(0.656, 0.682))
        beak.close()
        beak.fill()
    }
}
