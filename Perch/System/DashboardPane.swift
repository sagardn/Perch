import AppKit

/// What this Mac is, at a glance.
///
/// Replaces `Perch/Views/Dashboard.swift`. Reads `DeviceInfo` rather than
/// Kit's `SystemKit`, builds its rows from `Controls`, and uses Perch's own
/// `localized` — so the pane depends on nothing from Kit while every one of
/// the 42 translations still applies.
///
/// Values are read once. All of them except uptime are fixed until the Mac
/// reboots, and uptime is computed from the boot date on a timer rather than
/// polled from the system.
final class DashboardPane: NSStackView {

    private let uptime = Controls.label("")
    private var ticker: Timer?

    init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 0))
        self.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        // Flipped, so the pane opens at the top of its content rather than
        // scrolled to the end of it.
        let column = FlippedColumn()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 18
        column.edgeInsets = NSEdgeInsets(top: 44, left: 18, bottom: 18, right: 18)
        column.translatesAutoresizingMaskIntoConstraints = false

        let sections = [identity(), hardware(), provenance(), running()]
        for section in sections {
            column.addArrangedSubview(section)
            section.widthAnchor.constraint(
                equalTo: column.widthAnchor,
                constant: -(column.edgeInsets.left + column.edgeInsets.right)).isActive = true
        }

        scroll.documentView = column
        column.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true

        self.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(equalTo: self.heightAnchor).isActive = true

        refreshUptime()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    deinit { ticker?.invalidate() }

    /// Uptime is the one value that moves, so it ticks only while the pane is
    /// on screen.
    func viewWillAppear() {
        refreshUptime()
        ticker?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.refreshUptime() }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func viewDidDisappear() {
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - Sections

    private func identity() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let icon = DeviceInfo.model.icon {
            let copy = NSImage(size: NSSize(width: 160, height: 160), flipped: false) { rect in
                icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                          respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
                return true
            }
            let view = NSImageView(image: copy)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalToConstant: 160).isActive = true
            view.heightAnchor.constraint(equalToConstant: 160).isActive = true
            stack.addArrangedSubview(view)
        }

        let name = NSTextField(labelWithString: DeviceInfo.model.name)
        name.font = .systemFont(ofSize: 20, weight: .semibold)
        stack.addArrangedSubview(name)

        let os = DeviceInfo.os
        let line = NSTextField(labelWithString: "\(os.name) \(os.version) (\(os.build))")
        line.font = .systemFont(ofSize: 13)
        line.textColor = .secondaryLabelColor
        line.isSelectable = true
        stack.addArrangedSubview(line)

        return stack
    }

    private func hardware() -> NSView {
        Controls.section(nil, [
            Controls.row(localized("Processor"), multiline(processor)),
            Controls.row(localized("Memory"),
                         Controls.label(ByteCountFormatter.string(fromByteCount: DeviceInfo.memory,
                                                                  countStyle: .memory))),
            Controls.row(localized("Graphics"), Controls.label(DeviceInfo.gpu ?? localized("Unknown"))),
            Controls.row(localized("Disks"), multiline(disks)),
            Controls.row(localized("Display"), multiline(displays)),
        ])
    }

    private func provenance() -> NSView {
        Controls.section(nil, [
            Controls.row(localized("Model identifier"), Controls.label(DeviceInfo.model.identifier)),
            Controls.row(localized("Production year"),
                         Controls.label(DeviceInfo.model.year.map(String.init) ?? localized("Unknown"))),
            Controls.row(localized("Serial number"),
                         selectable(DeviceInfo.serialNumber ?? localized("Unknown"))),
        ])
    }

    private func running() -> NSView {
        Controls.section(nil, [Controls.row(localized("Uptime"), uptime)])
    }

    // MARK: - Values

    private var processor: String {
        let cpu = DeviceInfo.cpu
        guard cpu.name != nil || cpu.physicalCores != nil else { return localized("Unknown") }

        var lines: [String] = []
        if let name = cpu.name { lines.append(name) }

        var counts: [String] = []
        if let cores = cpu.physicalCores { counts.append(localized("Number of cores", "\(cores)")) }
        if let threads = cpu.logicalCores { counts.append(localized("Number of threads", "\(threads)")) }
        if !counts.isEmpty { lines.append(counts.joined(separator: ", ")) }

        if let efficiency = cpu.efficiencyCores {
            lines.append(localized("Number of e-cores", "\(efficiency)"))
        }
        if let performance = cpu.performanceCores {
            lines.append(localized("Number of p-cores", "\(performance)"))
        }
        return lines.joined(separator: "\n")
    }

    /// The volume, then the drive it is on.
    private var disks: String {
        var lines = DeviceInfo.volumes.map {
            "\($0.name) (\(ByteCountFormatter.string(fromByteCount: $0.capacity, countStyle: .file)))"
        }
        lines += DeviceInfo.drives.map { "\($0.name) (\($0.medium))" }
        return lines.isEmpty ? localized("Unknown") : lines.joined(separator: "\n")
    }

    private var displays: String {
        let screens = DeviceInfo.displays
        guard !screens.isEmpty else { return localized("Unknown") }
        return screens.map { screen in
            var line = screen.name
            if let inches = screen.inches { line += " (\(inches)\")" }
            line += "\n\(screen.pixelWidth)x\(screen.pixelHeight), \(screen.refreshHz)Hz"
            return line
        }.joined(separator: "\n")
    }

    private func refreshUptime() {
        guard let boot = DeviceInfo.bootDate else {
            uptime.stringValue = localized("Unknown")
            return
        }
        let seconds = Int(Date().timeIntervalSince(boot))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if days > 0 || hours > 0 { parts.append("\(hours)h") }
        parts.append("\(minutes)m")
        uptime.stringValue = parts.joined(separator: " ")
    }

    // MARK: - Fields

    /// A right-aligned value that may run to several lines.
    private func multiline(_ text: String) -> NSTextField {
        let field = Controls.label(text)
        field.maximumNumberOfLines = 0
        field.lineBreakMode = .byWordWrapping
        field.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return field
    }

    private func selectable(_ text: String) -> NSTextField {
        let field = Controls.label(text)
        field.isSelectable = true
        return field
    }
}

/// Top-left origin, so a scrolling column opens at its beginning.
private final class FlippedColumn: NSStackView {
    override var isFlipped: Bool { true }
}
