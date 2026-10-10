import AppKit

/// The pieces a settings pane is made of.
///
/// Independent of Kit's `PreferencesSection` / `PreferencesRow` and the
/// `switchView` / `selectView` / `buttonView` helpers on NSView. Same shape on
/// screen — a titled card of rows, label on the left, control on the right —
/// built with constraints rather than computed frames, so a long label wraps
/// or truncates instead of running under its control.
///
/// Rows take a closure instead of a target/selector pair. The old helpers
/// bound every control to an `@objc` method on the pane, which meant a pane
/// could not build a row without also declaring a method for it, and a typo in
/// a selector name was a crash at click time rather than an error at build
/// time.
enum Controls {

    /// A titled group of rows, drawn as one rounded card.
    ///
    /// `symbol` puts a tinted glyph before the title, the same tile the
    /// sidebar uses, so a long page can be scanned by shape before it is
    /// read. `footer` is a sentence under the card saying what the group is
    /// for -- the place for "why would I change this", which a label of two
    /// words cannot carry.
    static func section(_ title: String? = nil,
                        symbol: String? = nil,
                        tint: NSColor = .systemGray,
                        footer: String? = nil,
                        _ rows: [NSView]) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 7
        container.translatesAutoresizingMaskIntoConstraints = false

        if let title {
            let heading = NSTextField(labelWithString: title)
            if let symbol {
                heading.font = .systemFont(ofSize: 13, weight: .semibold)
                heading.textColor = .labelColor
                let header = NSStackView(views: [glyph(symbol, tint), heading])
                header.orientation = .horizontal
                header.alignment = .centerY
                header.spacing = 7
                container.addArrangedSubview(header)
            } else {
                heading.font = .systemFont(ofSize: 12, weight: .semibold)
                heading.textColor = .secondaryLabelColor
                container.addArrangedSubview(heading)
            }
        }

        let card = Card()
        card.orientation = .vertical
        card.spacing = 0
        card.edgeInsets = NSEdgeInsets(top: 3, left: 12, bottom: 3, right: 12)
        card.translatesAutoresizingMaskIntoConstraints = false

        for (index, row) in rows.enumerated() {
            if index > 0 { card.addArrangedSubview(separator()) }
            card.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -24).isActive = true
        }

        container.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true

        if let footer {
            let note = NSTextField(wrappingLabelWithString: footer)
            note.font = .systemFont(ofSize: 11)
            note.textColor = .secondaryLabelColor
            note.translatesAutoresizingMaskIntoConstraints = false
            container.addArrangedSubview(note)
            // Inset to the card's text, so it reads as a caption to the card
            // and not as a row that lost its background.
            note.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -24).isActive = true
            container.setCustomSpacing(5, after: card)
            let indent = note.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12)
            indent.priority = .defaultHigh
            indent.isActive = true
        }
        return container
    }

    /// The sidebar's tile, in AppKit: a white symbol on a rounded square.
    private static func glyph(_ symbol: String, _ tint: NSColor) -> NSView {
        let tile = TintTile(tint)
        tile.translatesAutoresizingMaskIntoConstraints = false

        let image = NSImageView()
        image.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))
        image.contentTintColor = .white
        image.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(image)

        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: 20),
            tile.heightAnchor.constraint(equalToConstant: 20),
            image.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
        ])
        return tile
    }

    /// One row: a label and its control.
    ///
    /// The control keeps its natural width and the label takes the rest, so a
    /// pop-up button is never squeezed and a long label is never hidden
    /// underneath one.
    ///
    /// `indented` is for a row that only means something while the row above
    /// it is on -- the combined bar's spacing under "Combine", the finger
    /// counts under the gesture. Set in and quieter, so it reads as part of
    /// that row rather than as one more setting of equal weight.
    ///
    /// `detail` is a line under the label for a setting whose name alone does
    /// not say what it changes. Used sparingly: a caption on every row is a
    /// page nobody reads, and the rows that need one stop standing out.
    static func row(_ label: String, _ control: NSView, indented: Bool = false,
                    detail: String? = nil) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: label)
        title.font = .systemFont(ofSize: 13)
        if indented { title.textColor = .secondaryLabelColor }
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let text: NSView
        if let detail {
            let caption = NSTextField(wrappingLabelWithString: detail)
            caption.font = .systemFont(ofSize: 11)
            caption.textColor = .secondaryLabelColor
            caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let stack = NSStackView(views: [title, caption])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 1
            stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            text = stack
        } else {
            text = title
        }
        text.translatesAutoresizingMaskIntoConstraints = false

        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)

        view.addSubview(text)
        view.addSubview(control)
        NSLayoutConstraint.activate([
            // 28, not 32: the controls are mini switches and small pop-ups,
            // 22pt at most, and 32 left the settings page a screen and a half
            // of mostly padding.
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            text.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indented ? 16 : 0),
            text.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            control.leadingAnchor.constraint(greaterThanOrEqualTo: text.trailingAnchor, constant: 12),
            control.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            // The row grows to whatever the control needs. Without these a
            // multi-line value -- the processor's cores and threads -- was
            // centred in a 32pt row and drawn straight over the row below it.
            control.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: 6),
            control.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -6),
            text.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: 6),
            text.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -6),
        ])
        return view
    }

    /// A row that is only a control, spanning the width.
    static func row(_ control: NSView) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(control)
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            control.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        return view
    }

    // MARK: - Controls

    static func toggle(_ on: Bool, _ changed: @escaping (Bool) -> Void) -> NSSwitch {
        let control = ActionSwitch()
        control.controlSize = .mini
        control.state = on ? .on : .off
        control.onChange = changed
        return control
    }

    /// `options` is (title, value); the value is what gets stored.
    static func choice(_ options: [(String, String)], selected: String,
                       _ changed: @escaping (String) -> Void) -> NSPopUpButton {
        let control = ActionPopUp()
        control.controlSize = .small
        control.values = options.map { $0.1 }
        control.onChange = changed
        for (title, value) in options {
            // Localised here rather than at every call site: a choice's
            // options are pairs of (what to show, what to store), and only
            // the first is ever read by a person. Doing it in one place is
            // also what stops half the pickers in an app being translated.
            //
            // `localized` falls back to its argument, so an option whose
            // title is a number -- the process counts are "5", "8", "12" --
            // passes through untouched and needs no key.
            control.addItem(withTitle: localized(title))
            if value == selected { control.select(control.lastItem) }
        }
        return control
    }

    /// A switch with a percentage beside it, for a threshold.
    ///
    /// The two belong together: a threshold with its switch off has no
    /// percentage worth reading, and one with no switch is a number that
    /// cannot be turned off. The stepper is disabled rather than hidden while
    /// the switch is off, so the row does not change width as it is used.
    static func threshold(on: Bool, value: Int,
                          suffix: String = "%",
                          range: ClosedRange<Int> = 1...100,
                          step: Int = 1,
                          _ changed: @escaping (Bool, Int) -> Void) -> NSView {
        let figure = NSTextField(labelWithString: "\(value)\(suffix)")
        figure.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize,
                                                 weight: .regular)
        figure.textColor = .secondaryLabelColor
        figure.alignment = .right
        figure.translatesAutoresizingMaskIntoConstraints = false

        let stepper = ActionStepper()
        stepper.minValue = Double(range.lowerBound)
        stepper.maxValue = Double(range.upperBound)
        stepper.increment = Double(max(1, step))
        stepper.integerValue = value
        stepper.controlSize = .small
        stepper.translatesAutoresizingMaskIntoConstraints = false

        let switcher = ActionSwitch()
        switcher.controlSize = .mini
        switcher.state = on ? .on : .off
        switcher.translatesAutoresizingMaskIntoConstraints = false

        stepper.isEnabled = on
        figure.textColor = on ? .labelColor : .tertiaryLabelColor

        switcher.onChange = { state in
            stepper.isEnabled = state
            figure.textColor = state ? .labelColor : .tertiaryLabelColor
            changed(state, stepper.integerValue)
        }
        stepper.onChange = { stepped in
            figure.stringValue = "\(stepped)\(suffix)"
            changed(switcher.state == .on, stepped)
        }

        let row = NSStackView(views: [figure, stepper, switcher])
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        // Wide enough for the longest figure the range can produce, so a
        // row does not change width as it is stepped.
        let widest = "\(range.upperBound)\(suffix)"
        figure.widthAnchor.constraint(
            equalToConstant: max(38, (widest as NSString).size(
                withAttributes: [.font: figure.font as Any]).width + 4)
        ).isActive = true
        return row
    }

    /// Which shapes a module draws in the menu bar, as tiles that show them.
    ///
    /// Replaces a switch per shape -- nine rows on the Disk page reading
    /// Name, Figure, Line chart, Bar chart, Ring, Gauge... -- which asked
    /// somebody to picture a "Gauge" in a menu bar before choosing one. Each
    /// tile draws the shape with the menu bar's own `MenuBarWidget`, fed a
    /// sample reading, so what is chosen is what appears.
    ///
    /// `label` is what the module puts in the menu bar -- "SSD", "CPU" -- so
    /// the Name tile shows that word and not a placeholder.
    ///
    /// `value` is the sample figure -- "62°" for a temperature reads as one,
    /// where "42%" would not -- and `title` is for a module that names its
    /// shapes in its own words.
    static func shapes(_ styles: [MenuBarStyle], shown: Set<MenuBarStyle>, label: String,
                       value: String = "42%",
                       title: @escaping (MenuBarStyle) -> String = { $0.title },
                       _ changed: @escaping (Set<MenuBarStyle>) -> Void) -> NSView {
        ShapePicker(styles, shown: shown, label: label, value: value, title: title,
                    changed: changed)
    }

    /// A colour well, its hex code, and a reset, for one of `PerchColors`.
    ///
    /// Both ways in because each is the natural one for somebody: the
    /// picker to find a colour, the code to match one they already have.
    /// They stay in step -- picking writes the code, typing moves the well.
    static func colour(_ which: PerchColors) -> NSView { ColourControl(which) }

    static func button(_ title: String, _ pressed: @escaping () -> Void) -> NSButton {
        let control = ActionButton()
        // Localised here for the same reason choice() is: a button's title is
        // only ever read by a person, and doing it at the five call sites is
        // how four of them end up translated.
        control.title = localized(title)
        control.bezelStyle = .rounded
        control.controlSize = .small
        control.onPress = pressed
        return control
    }

    /// Controls side by side at the end of a row: a status and the button
    /// that changes it, or a set of buttons that belong together.
    static func group(_ views: [NSView], spacing: CGFloat = 6) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = spacing
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    /// A small heading inside a card, over the rows it names -- a sensor
    /// family. Left-aligned and spaced out, so it reads as a heading and not
    /// as the right-aligned value `label` is for, which it was drawn as.
    static func subheading(_ text: String) -> NSView {
        let field = NSTextField(labelWithString: text.uppercased())
        field.font = .systemFont(ofSize: 10.5, weight: .semibold)
        field.textColor = .tertiaryLabelColor
        field.attributedStringValue = NSAttributedString(
            string: text.uppercased(),
            attributes: [.kern: 0.8, .font: field.font as Any,
                         .foregroundColor: NSColor.tertiaryLabelColor])
        field.translatesAutoresizingMaskIntoConstraints = false
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            field.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            field.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])
        return view
    }

    static func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 13)
        field.textColor = .secondaryLabelColor
        field.alignment = .right
        return field
    }

    private static func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}

// MARK: - Surfaces

/// A section's card.
///
/// Its colours are set in `updateLayer` rather than once at creation, which
/// is what the plain layer it replaces did: a CGColor is resolved against the
/// appearance at the moment it is made, so switching to Dark Mode left every
/// card the light-mode grey until the pane was rebuilt.
private final class Card: NSStackView {
    override var wantsUpdateLayer: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override func updateLayer() {
        super.updateLayer()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.14).cgColor
            layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        }
    }
}

/// The rounded, tinted square behind a section's symbol.
private final class TintTile: NSView {
    private let tint: NSColor

    init(_ tint: NSColor) {
        self.tint = tint
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5.5
        layer?.cornerCurve = .continuous
    }
    required init?(coder: NSCoder) { fatalError("not used") }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = tint.cgColor
        }
    }
}

// MARK: - Controls that carry their own action

/// Target/action is an Objective-C mechanism and forces every control's
/// handler onto the view that built it. These three keep their own closure,
/// which is what lets a pane be a list of rows rather than a list of rows plus
/// a parallel list of @objc methods.
final class ActionSwitch: NSSwitch {
    var onChange: ((Bool) -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.target = self
        self.action = #selector(fire)
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    @objc private func fire() { onChange?(state == .on) }
}

final class ActionPopUp: NSPopUpButton {
    var onChange: ((String) -> Void)?
    /// Parallel to the menu items: what each title means when stored.
    var values: [String] = []
    convenience init() { self.init(frame: .zero, pullsDown: false) }
    override init(frame: NSRect, pullsDown: Bool) {
        super.init(frame: frame, pullsDown: pullsDown)
        self.target = self
        self.action = #selector(fire)
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    @objc private func fire() {
        guard values.indices.contains(indexOfSelectedItem) else { return }
        onChange?(values[indexOfSelectedItem])
    }
}

final class ActionStepper: NSStepper {
    var onChange: ((Int) -> Void)?
    convenience init() { self.init(frame: .zero) }
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.valueWraps = false
        self.autorepeat = true
        self.target = self
        self.action = #selector(fire)
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    @objc private func fire() { onChange?(integerValue) }
}

final class ActionButton: NSButton {
    var onPress: (() -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        self.target = self
        self.action = #selector(fire)
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    @objc private func fire() { onPress?() }
}

/// See `Controls.colour`.
private final class ColourControl: NSStackView, NSTextFieldDelegate {

    private let which: PerchColors
    private let well = NSColorWell()
    private let field = NSTextField()
    private let reset = ActionButton()

    init(_ which: PerchColors) {
        self.which = which
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 6
        alignment = .centerY
        translatesAutoresizingMaskIntoConstraints = false

        well.colorWellStyle = .minimal
        well.color = which.color
        well.target = self
        well.action = #selector(picked)
        well.translatesAutoresizingMaskIntoConstraints = false

        field.stringValue = which.hex
        field.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        field.controlSize = .small
        field.alignment = .center
        field.placeholderString = which.defaultHex
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false

        reset.image = NSImage(systemSymbolName: "arrow.counterclockwise",
                              accessibilityDescription: "Restore the default colour")
        reset.isBordered = false
        reset.toolTip = "Restore \(which.defaultHex)"
        reset.onPress = { [weak self] in self?.apply(nil) }
        reset.translatesAutoresizingMaskIntoConstraints = false

        for view in [reset, field, well] { addArrangedSubview(view) }
        NSLayoutConstraint.activate([
            // Measured: "#WWWWWW" in the small monospaced face is 58pt, and
            // the field's own insets need the rest.
            field.widthAnchor.constraint(equalToConstant: 72),
            well.widthAnchor.constraint(equalToConstant: 38),
            well.heightAnchor.constraint(equalToConstant: 22),
            reset.widthAnchor.constraint(equalToConstant: 18),
        ])
        sync()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func picked() {
        // A colour with no sRGB form -- a pattern from the picker's image tab
        // -- is ignored rather than stored as a guess.
        guard let hex = PerchColors.hex(of: well.color) else { return }
        apply(hex)
    }

    /// Return or leaving the field. A code that is not a colour puts the
    /// current one back rather than storing nothing.
    func controlTextDidEndEditing(_ notification: Notification) {
        guard let clean = PerchColors.normalised(field.stringValue) else {
            NSSound.beep()
            sync()
            return
        }
        apply(clean)
    }

    private func apply(_ hex: String?) {
        which.set(hex: hex)
        sync()
    }

    private func sync() {
        field.stringValue = which.hex
        // Only when it differs: setting a well's colour while its panel is
        // dragging restarts the drag.
        if PerchColors.hex(of: well.color) != which.hex { well.color = which.color }
        // Hidden rather than disabled: a greyed arrow on every row read as
        // clutter. It is the leftmost item and the row is pinned at its
        // trailing edge, so nothing else moves when it comes and goes.
        reset.isHidden = !which.isCustom
    }
}

// MARK: - Shape picker

/// See `Controls.shapes`.
private final class ShapePicker: NSView {

    private var shown: Set<MenuBarStyle>
    private let changed: (Set<MenuBarStyle>) -> Void
    private var tiles: [ShapeTile] = []

    /// Three across: the settings column is 520-1,100pt wide, and at three
    /// the narrowest tile still holds "Traffic chart" and its preview.
    private static let columns = 3

    init(_ styles: [MenuBarStyle], shown: Set<MenuBarStyle>, label: String, value: String,
         title: (MenuBarStyle) -> String, changed: @escaping (Set<MenuBarStyle>) -> Void) {
        self.shown = shown
        self.changed = changed
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let sample = Self.sample(label: label, value: value)
        tiles = styles.map { style in
            ShapeTile(style, title: title(style), sample: sample, isOn: shown.contains(style))
        }
        for tile in tiles {
            tile.onToggle = { [weak self, weak tile] in
                guard let self, let tile else { return }
                self.toggle(tile)
            }
        }

        let grid = NSStackView()
        grid.orientation = .vertical
        grid.spacing = 8
        grid.alignment = .leading
        grid.translatesAutoresizingMaskIntoConstraints = false
        for start in stride(from: 0, to: tiles.count, by: Self.columns) {
            let slice = Array(tiles[start..<min(start + Self.columns, tiles.count)])
            let row = NSStackView(views: slice)
            row.orientation = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually
            row.translatesAutoresizingMaskIntoConstraints = false
            grid.addArrangedSubview(row)
            // A short last row keeps the column width rather than stretching
            // two tiles across three columns' worth of room.
            let share = CGFloat(slice.count) / CGFloat(Self.columns)
            let gaps = CGFloat(Self.columns - slice.count) * 8
            row.widthAnchor.constraint(equalTo: grid.widthAnchor, multiplier: share,
                                       constant: -gaps * share).isActive = true
        }
        addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor),
            grid.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// The last shape refuses to go: a module with nothing in the menu bar
    /// is a module turned off, and that is the switch at the top of the page.
    private func toggle(_ tile: ShapeTile) {
        if shown.contains(tile.style) {
            guard shown.count > 1 else { NSSound.beep(); return }
            shown.remove(tile.style)
        } else {
            shown.insert(tile.style)
        }
        for tile in tiles { tile.isOn = shown.contains(tile.style) }
        changed(shown)
    }

    /// A reading that every shape can draw, busy enough to look like one.
    private static func sample(label: String, value: String) -> MenuBarReading {
        let history = (0..<24).map { 0.35 + 0.25 * sin(Double($0) / 3) }
        var rates = MenuBarReading.Pair("98 KB/s", "1.2 MB/s")
        rates.speeds = .init(upload: 98_000, download: 1_200_000)
        return MenuBarReading(
            label: label, load: 0.42, value: value,
            history: history,
            bars: [0.35, 0.6, 0.25, 0.5],
            segments: [.init(0.42, .perchCalm)],
            pair: .init("120 GB", "60 GB"),
            rates: rates,
            mirrored: .init(up: history.map { $0 * 0.4 }, down: history))
    }
}

/// One shape: a strip of menu bar with the shape drawn in it, and its name.
private final class ShapeTile: NSView {

    let style: MenuBarStyle
    var onToggle: (() -> Void)?
    var isOn: Bool { didSet { needsDisplay = true; check.isHidden = !isOn; updateLayer() } }

    private let widget = MenuBarWidget()
    private let title = NSTextField(labelWithString: "")
    private let check = NSImageView()
    private var hovering = false { didSet { updateLayer() } }

    init(_ style: MenuBarStyle, title name: String, sample: MenuBarReading, isOn: Bool) {
        self.style = style
        self.isOn = isOn
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1.5

        let strip = MenuStrip()
        strip.translatesAutoresizingMaskIntoConstraints = false

        widget.styles = [style]
        widget.content = sample
        widget.translatesAutoresizingMaskIntoConstraints = false
        strip.addSubview(widget)

        title.stringValue = name
        title.font = .systemFont(ofSize: 11.5, weight: .medium)
        title.alignment = .center
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false

        check.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 13, weight: .semibold))
        check.contentTintColor = .controlAccentColor
        check.isHidden = !isOn
        check.translatesAutoresizingMaskIntoConstraints = false

        for view in [strip, title, check] { addSubview(view) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 74),
            strip.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            strip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            strip.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            strip.heightAnchor.constraint(equalToConstant: 34),
            widget.centerXAnchor.constraint(equalTo: strip.centerXAnchor),
            widget.centerYAnchor.constraint(equalTo: strip.centerYAnchor),
            widget.heightAnchor.constraint(equalToConstant: MenuBarMetrics.height),
            title.topAnchor.constraint(equalTo: strip.bottomAnchor, constant: 6),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            check.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            check.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.checkBox)
        setAccessibilityLabel(name)

        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var wantsUpdateLayer: Bool { true }

    /// Colours resolved here, against the current appearance, for the same
    /// reason `Card` does it: a CGColor made once keeps its first appearance.
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = (isOn ? NSColor.controlAccentColor.withAlphaComponent(0.10)
                                           : NSColor.quaternaryLabelColor
                                               .withAlphaComponent(hovering ? 0.22 : 0.10)).cgColor
            layer?.borderColor = (isOn ? NSColor.controlAccentColor
                                       : NSColor.separatorColor.withAlphaComponent(0.4)).cgColor
        }
        title.textColor = isOn ? .labelColor : .secondaryLabelColor
    }

    override func accessibilityValue() -> Any? { isOn ? 1 : 0 }
    override func accessibilityPerformPress() -> Bool { onToggle?(); return true }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onToggle?() }
    }
}

/// The menu bar's own ground, so a shape is judged against what it will sit on.
private final class MenuStrip: NSView {
    override var wantsUpdateLayer: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
    }
    required init?(coder: NSCoder) { fatalError("not used") }
    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        }
    }
}
