import AppKit

/// What the AI assistants are holding, and what can go.
///
/// The tools stay installed and stay signed in; this is about what they have
/// accumulated behind them. Caches, logs and downloaded updates arrive
/// ticked because the tool rebuilds them without noticing. Conversations and
/// memory arrive unticked, however large they are: somebody who resumes old
/// sessions loses them, and that is their call rather than a default.
///
/// Everything goes to the Bin. `AIAssistants` decides what is offered at
/// all, by an allowlist of names, so nothing here can reach a credential.
final class AICleanupWindow: NSWindow, NSWindowDelegate, ClosableWindow {

    var onClose: (() -> Void)?

    private let status = NSTextField(labelWithString: "")
    private let rows = NSStackView()
    private let scroll = NSScrollView()
    private let binButton = NSButton()

    private var tools: [AIAssistants.Tool] = []
    private var selected: Set<URL> = []

    private static var open: AICleanupWindow?

    static func present() {
        if let existing = open { existing.show(); return }
        let made = AICleanupWindow()
        made.onClose = { AICleanupWindow.open = nil }
        open = made
        made.show()
    }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 580, height: 520),
                   styleMask: [.closable, .titled, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: true)

        title = localized("Clean up AI assistants")
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        delegate = self

        let backdrop = NSVisualEffectView()
        backdrop.material = .sidebar
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        contentView = backdrop

        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false

        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 2
        rows.translatesAutoresizingMaskIntoConstraints = false

        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let flipped = FlippedCleanupBox()
        flipped.translatesAutoresizingMaskIntoConstraints = false
        flipped.addSubview(rows)
        scroll.documentView = flipped

        binButton.title = localized("Move to Bin")
        binButton.bezelStyle = .rounded
        binButton.target = self
        binButton.action = #selector(moveSelectedToBin)
        binButton.isEnabled = false
        binButton.translatesAutoresizingMaskIntoConstraints = false

        for view in [status, scroll, binButton] { backdrop.addSubview(view) }

        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: flipped.topAnchor),
            rows.leadingAnchor.constraint(equalTo: flipped.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: flipped.trailingAnchor),
            rows.bottomAnchor.constraint(equalTo: flipped.bottomAnchor),
            flipped.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -4),

            status.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 36),
            status.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 18),
            status.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -18),

            scroll.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 14),
            scroll.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -14),
            scroll.bottomAnchor.constraint(equalTo: binButton.topAnchor, constant: -10),

            binButton.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -18),
            binButton.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -14),
        ])
    }

    func windowWillClose(_ notification: Notification) {
        let onClose = self.onClose
        DispatchQueue.main.async { onClose?() }
    }

    func show() {
        setIsVisible(true)
        makeKeyAndOrderFront(nil)
        center()
        NSApp.activate(ignoringOtherApps: true)
        if tools.isEmpty { load() }
    }

    /// Scans off the main thread: it stats every file under half a dozen
    /// directories, and ~/.codex alone held 2.4 GB of them.
    func load() {
        status.stringValue = localized("Looking…")
        DispatchQueue.global(qos: .userInitiated).async {
            let found = AIAssistants.find()
            DispatchQueue.main.async {
                self.tools = found
                self.selected = Set(found.flatMap(\.items)
                    .filter { $0.kind.isTickedByDefault }
                    .map(\.url))
                self.redraw()
            }
        }
    }

    private func redraw() {
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !tools.isEmpty else {
            status.stringValue = localized("No AI assistants found on this Mac")
            binButton.isEnabled = false
            return
        }

        let total = UInt64(tools.reduce(Int64(0)) { $0 + $1.bytes })
        status.stringValue = localized("%0 across %1 assistants", Readings.bytes(total),
                                       String(tools.count))

        let home = FileManager.default.homeDirectoryForCurrentUser
        for tool in tools {
            rows.addArrangedSubview(ToolHeader(tool))
            for item in tool.items {
                rows.addArrangedSubview(AIItemRow(item, home: home,
                                                  isTicked: selected.contains(item.url)) {
                    [weak self] on in
                    guard let self else { return }
                    if on { self.selected.insert(item.url) } else { self.selected.remove(item.url) }
                    self.updateBinButton()
                })
            }
        }
        updateBinButton()
    }

    private func updateBinButton() {
        let chosen = allItems.filter { selected.contains($0.url) }
        binButton.isEnabled = !chosen.isEmpty
        let bytes = UInt64(chosen.reduce(Int64(0)) { $0 + $1.bytes })
        binButton.title = chosen.isEmpty
            ? localized("Move to Bin")
            // The size, not the count: freeing 1.2 GB is the decision, and
            // "Move 9 to Bin" says nothing about whether it is worth it.
            : localized("Move %0 to Bin", Readings.bytes(bytes))
    }

    private var allItems: [AIAssistants.Item] { tools.flatMap(\.items) }

    @objc private func moveSelectedToBin() {
        let chosen = allItems.filter { selected.contains($0.url) }
        guard !chosen.isEmpty else { return }

        let bytes = UInt64(chosen.reduce(Int64(0)) { $0 + $1.bytes })
        let conversations = chosen.filter { $0.kind == .conversations }

        // Said plainly, because it is the one thing here that does not come
        // back on its own. Caches and logs are rebuilt; a conversation is
        // not.
        let detail = conversations.isEmpty
            ? localized("%0 goes to the Bin. The assistants stay installed and signed in, and rebuild what they need.",
                        Readings.bytes(bytes))
            : localized("%0 goes to the Bin, including conversation history. The assistants stay installed and signed in, but old sessions will not be there to resume.",
                        Readings.bytes(bytes))

        Alert.show(localized("Clean up %0?", Readings.bytes(bytes)), detail,
                   style: .warning,
                   actionTitle: localized("Move to Bin")) { [weak self] in
            let removal = AIAssistants.moveToBin(chosen)
            Notify.show(LargeFiles.message(for: removal), symbol: "trash")
            guard let self else { return }
            let moved = Set(removal.moved)
            self.tools = self.tools.compactMap { tool in
                let kept = tool.items.filter { !moved.contains($0.url) }
                return kept.isEmpty ? nil : AIAssistants.Tool(name: tool.name, items: kept)
            }
            self.selected.subtract(moved)
            self.redraw()
        }
    }
}

/// One assistant's name, with what it is holding in total.
private final class ToolHeader: NSView {

    init(_ tool: AIAssistants.Tool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        icon.contentTintColor = .systemPink
        icon.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: tool.name)
        name.font = .systemFont(ofSize: 12, weight: .semibold)
        name.translatesAutoresizingMaskIntoConstraints = false

        let size = NSTextField(labelWithString: Readings.bytes(UInt64(tool.bytes)))
        size.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        size.textColor = .secondaryLabelColor
        size.translatesAutoresizingMaskIntoConstraints = false

        for view in [icon, name, size] { addSubview(view) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 26),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            name.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            size.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 8),
            size.firstBaselineAnchor.constraint(equalTo: name.firstBaselineAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}

/// One store: what it is, what kind, how big.
private final class AIItemRow: NSView {

    private let item: AIAssistants.Item
    private let ticked: (Bool) -> Void

    init(_ item: AIAssistants.Item, home: URL, isTicked: Bool,
         ticked: @escaping (Bool) -> Void) {
        self.item = item
        self.ticked = ticked
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let tick = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        tick.state = isTicked ? .on : .off
        tick.target = self
        tick.action = #selector(tickChanged(_:))
        tick.translatesAutoresizingMaskIntoConstraints = false

        let label = NSStackView()
        label.orientation = .vertical
        label.alignment = .leading
        label.spacing = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: item.name)
        name.font = .systemFont(ofSize: 12)
        name.toolTip = item.url.path
        name.translatesAutoresizingMaskIntoConstraints = false

        let note = NSTextField(labelWithString: item.kind.label)
        note.font = .systemFont(ofSize: 10)
        // A directory called `cache` under a line reading "cache" says
        // nothing twice.
        note.isHidden = item.kind.label.caseInsensitiveCompare(item.name) == .orderedSame
        // Conversations are the row somebody has to think about, so they are
        // the row that is coloured.
        note.textColor = item.kind == .conversations ? .systemOrange : .tertiaryLabelColor
        note.translatesAutoresizingMaskIntoConstraints = false

        label.addArrangedSubview(name)
        label.addArrangedSubview(note)

        let size = NSTextField(labelWithString: Readings.bytes(UInt64(item.bytes)))
        size.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        size.textColor = .secondaryLabelColor
        size.alignment = .right
        size.translatesAutoresizingMaskIntoConstraints = false

        let reveal = Controls.button("Reveal") { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.activateFileViewerSelecting([self.item.url])
        }
        reveal.translatesAutoresizingMaskIntoConstraints = false

        for view in [tick, label, size, reveal] { addSubview(view) }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 38),
            tick.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            tick.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: tick.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: size.leadingAnchor, constant: -8),
            size.trailingAnchor.constraint(equalTo: reveal.leadingAnchor, constant: -8),
            size.centerYAnchor.constraint(equalTo: centerYAnchor),
            size.widthAnchor.constraint(equalToConstant: 70),
            reveal.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            reveal.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    @objc private func tickChanged(_ sender: NSButton) { ticked(sender.state == .on) }

    required init?(coder: NSCoder) { fatalError("not used") }
}

private final class FlippedCleanupBox: NSView {
    override var isFlipped: Bool { true }
}
