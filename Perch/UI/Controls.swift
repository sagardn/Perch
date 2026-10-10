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
    static func section(_ title: String? = nil, _ rows: [NSView]) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 6
        container.translatesAutoresizingMaskIntoConstraints = false

        if let title {
            let heading = NSTextField(labelWithString: title)
            heading.font = .systemFont(ofSize: 12, weight: .semibold)
            heading.textColor = .secondaryLabelColor
            container.addArrangedSubview(heading)
        }

        let card = NSStackView()
        card.orientation = .vertical
        card.spacing = 0
        card.edgeInsets = NSEdgeInsets(top: 2, left: 10, bottom: 2, right: 10)
        card.wantsLayer = true
        card.layer?.cornerRadius = 8
        card.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.12).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        for (index, row) in rows.enumerated() {
            if index > 0 { card.addArrangedSubview(separator()) }
            card.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -20).isActive = true
        }

        container.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        return container
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
    static func row(_ label: String, _ control: NSView, indented: Bool = false) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let text = NSTextField(labelWithString: label)
        text.font = .systemFont(ofSize: 13)
        if indented { text.textColor = .secondaryLabelColor }
        text.lineBreakMode = .byTruncatingTail
        text.translatesAutoresizingMaskIntoConstraints = false
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

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
            control.addItem(withTitle: title)
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

    /// A colour well, its hex code, and a reset, for one of `PerchColors`.
    ///
    /// Both ways in because each is the natural one for somebody: the
    /// picker to find a colour, the code to match one they already have.
    /// They stay in step -- picking writes the code, typing moves the well.
    static func colour(_ which: PerchColors) -> NSView { ColourControl(which) }

    static func button(_ title: String, _ pressed: @escaping () -> Void) -> NSButton {
        let control = ActionButton()
        control.title = title
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
