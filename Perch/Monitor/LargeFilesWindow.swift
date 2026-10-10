import AppKit

/// The twenty biggest things in the folders somebody asked about.
///
/// A list and a Reveal button, and no delete button anywhere. Perch finds
/// them; Finder removes them, where the confirmation and the undo already
/// live. See `LargeFiles` for why that split is deliberate rather than
/// unfinished.
final class LargeFilesWindow: NSWindow, NSWindowDelegate, ClosableWindow {

    var onClose: (() -> Void)?

    private let status = NSTextField(labelWithString: "")
    private let rows = NSStackView()
    private let scroll = NSScrollView()
    private let filter = NSPopUpButton()
    private let binButton = NSButton()

    /// Everything the last scan found, unfiltered.
    private var found: [LargeFiles.Item] = []
    /// What is ticked. By URL rather than by index, because the list
    /// reorders when the filter changes and an index would then point at a
    /// different file than the one somebody ticked.
    private var selected: Set<URL> = []
    private var showing: LargeFiles.Category?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                   styleMask: [.closable, .titled, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: true)

        title = localized("Largest files")
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        delegate = self

        let backdrop = NSVisualEffectView()
        backdrop.material = .sidebar
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        contentView = backdrop

        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false

        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 2
        rows.translatesAutoresizingMaskIntoConstraints = false

        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = rows
        scroll.translatesAutoresizingMaskIntoConstraints = false

        filter.controlSize = .small
        filter.target = self
        filter.action = #selector(filterChanged)
        filter.addItem(withTitle: localized("Everything"))
        for category in LargeFiles.Category.allCases {
            filter.addItem(withTitle: category.title)
        }
        filter.translatesAutoresizingMaskIntoConstraints = false

        binButton.title = localized("Move to Bin")
        binButton.bezelStyle = .rounded
        binButton.controlSize = .regular
        binButton.target = self
        binButton.action = #selector(moveSelectedToBin)
        binButton.isEnabled = false
        binButton.translatesAutoresizingMaskIntoConstraints = false

        backdrop.addSubview(status)
        backdrop.addSubview(filter)
        backdrop.addSubview(scroll)
        backdrop.addSubview(binButton)

        NSLayoutConstraint.activate([
            status.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 34),
            status.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 18),
            status.trailingAnchor.constraint(lessThanOrEqualTo: filter.leadingAnchor,
                                             constant: -10),

            filter.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -18),
            filter.centerYAnchor.constraint(equalTo: status.centerYAnchor),

            scroll.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 14),
            scroll.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -14),
            scroll.bottomAnchor.constraint(equalTo: binButton.topAnchor, constant: -10),
            rows.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -4),

            binButton.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -18),
            binButton.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -14),
        ])
    }

    /// The one on screen, if any.
    ///
    /// Kept so a second click brings the same window forward instead of
    /// opening another, and dropped on close so the next click gets a fresh
    /// scan rather than a list from ten minutes ago.
    ///
    /// Here rather than on `DiskCleanup` because that type is compiled by
    /// disk-test, and naming a window from it drags AppKit and half the view
    /// layer into a suite about arithmetic -- which it did, until this moved.
    private static var open: LargeFilesWindow?

    static func present() {
        if let existing = open {
            existing.show()
            return
        }
        let made = LargeFilesWindow()
        made.onClose = { LargeFilesWindow.open = nil }
        open = made
        made.show()
    }

    func windowWillClose(_ notification: Notification) {
        let onClose = self.onClose
        DispatchQueue.main.async { onClose?() }
    }

    /// Shows the window and starts a scan.
    func show() {
        setIsVisible(true)
        makeKeyAndOrderFront(nil)
        center()
        NSApp.activate(ignoringOtherApps: true)
        rescan()
    }

    private func rescan() {
        status.stringValue = localized("Looking…")
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let roots = LargeFiles.defaultRoots(
            home: FileManager.default.homeDirectoryForCurrentUser)

        // Off the main thread: a Pictures folder can hold a hundred thousand
        // files, and the window has already been shown so there is something
        // to look at while it works.
        DispatchQueue.global(qos: .userInitiated).async {
            let found = LargeFiles.scan(roots: roots)
            DispatchQueue.main.async { self.present(found) }
        }
    }

    private func present(_ items: [LargeFiles.Item]) {
        found = items
        // Selections from a previous scan are dropped rather than carried:
        // a ticked file that is no longer in the list is a file somebody
        // cannot see and might still delete.
        selected.removeAll()
        redraw()
    }

    @objc private func filterChanged() {
        let index = filter.indexOfSelectedItem - 1
        showing = index >= 0 && index < LargeFiles.Category.allCases.count
            ? LargeFiles.Category.allCases[index] : nil
        redraw()
    }

    private var filtered: [LargeFiles.Item] {
        guard let showing else { return found }
        return found.filter { $0.category == showing }
    }

    private func redraw() {
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !found.isEmpty else {
            // Nothing found usually means permission, not an empty disk --
            // the folders this looks in are the ones macOS guards.
            status.stringValue = localized("Nothing found. macOS may not have let Perch look — the folders it searches are the ones it guards.")
            binButton.isEnabled = false
            return
        }

        let items = filtered
        let total = items.reduce(Int64(0)) { $0 + $1.bytes }
        status.stringValue = localized("%0 items, %1 in total",
                                       String(items.count), Readings.bytes(UInt64(total)))

        for item in items {
            rows.addArrangedSubview(LargeFileRow(item, isTicked: selected.contains(item.url)) {
                [weak self] on in
                guard let self else { return }
                if on { self.selected.insert(item.url) } else { self.selected.remove(item.url) }
                self.updateBinButton()
            })
        }
        updateBinButton()
    }

    private func updateBinButton() {
        // Counts only what is both ticked and on screen, so a filter cannot
        // hide a file that the button is about to move.
        let onScreen = Set(filtered.map(\.url))
        let count = selected.intersection(onScreen).count
        binButton.isEnabled = count > 0
        binButton.title = count > 0
            ? localized("Move %0 to Bin", String(count))
            : localized("Move to Bin")
    }

    @objc private func moveSelectedToBin() {
        let onScreen = Set(filtered.map(\.url))
        let chosen = found.filter { selected.contains($0.url) && onScreen.contains($0.url) }
        guard !chosen.isEmpty else { return }

        let bytes = chosen.reduce(Int64(0)) { $0 + $1.bytes }
        Alert.show(localized("Move %0 items to the Bin?", String(chosen.count)),
                   localized("%0 will be freed once the Bin is emptied. Until then everything can be put back from Finder.",
                             Readings.bytes(UInt64(bytes))),
                   style: .warning,
                   actionTitle: localized("Move to Bin")) { [weak self] in
            let removal = LargeFiles.moveToBin(chosen)
            Notify.show(LargeFiles.message(for: removal), symbol: "trash")
            guard let self else { return }
            // Drop what actually moved and leave what did not, so a second
            // press retries only the failures.
            let moved = Set(removal.moved)
            self.found.removeAll { moved.contains($0.url) }
            self.selected.subtract(moved)
            self.redraw()
        }
    }
}

/// One file: icon, name, size, and the way to it.
private final class LargeFileRow: NSView {

    private let item: LargeFiles.Item
    private let ticked: (Bool) -> Void

    init(_ item: LargeFiles.Item, isTicked: Bool, ticked: @escaping (Bool) -> Void) {
        self.item = item
        self.ticked = ticked
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let tick = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        tick.state = isTicked ? .on : .off
        tick.target = self
        tick.action = #selector(tickChanged(_:))
        tick.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.image = NSWorkspace.shared.icon(forFile: item.url.path)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: item.name)
        name.font = .systemFont(ofSize: 12)
        name.lineBreakMode = .byTruncatingMiddle
        name.toolTip = item.url.path
        name.translatesAutoresizingMaskIntoConstraints = false

        let size = NSTextField(labelWithString: Readings.bytes(UInt64(item.bytes)))
        size.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        size.textColor = .secondaryLabelColor
        size.alignment = .right
        size.translatesAutoresizingMaskIntoConstraints = false

        // Reveal, not Delete. The removing happens where the confirmation and
        // the undo already are.
        let reveal = Controls.button("Reveal") { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.activateFileViewerSelecting([self.item.url])
        }
        reveal.translatesAutoresizingMaskIntoConstraints = false

        for view in [tick, icon, name, size, reveal] { addSubview(view) }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 26),

            tick.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            tick.centerYAnchor.constraint(equalTo: centerYAnchor),

            icon.leadingAnchor.constraint(equalTo: tick.trailingAnchor, constant: 2),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 7),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            name.trailingAnchor.constraint(lessThanOrEqualTo: size.leadingAnchor, constant: -8),

            size.trailingAnchor.constraint(equalTo: reveal.leadingAnchor, constant: -8),
            size.centerYAnchor.constraint(equalTo: centerYAnchor),
            size.widthAnchor.constraint(equalToConstant: 70),

            reveal.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            reveal.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    @objc private func tickChanged(_ sender: NSButton) {
        ticked(sender.state == .on)
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
