import AppKit

/// Remove an application and what it left behind.
///
/// Type a name, pick the app, see every file that looks like its, choose,
/// and they go to the Bin. The matching and its confidence levels are in
/// `AppLeftovers`; this is the part somebody looks at.
///
/// Two things it will not do. It does not delete -- everything goes to the
/// Bin, so a wrong guess costs a trip to Finder rather than somebody's data.
/// And it never ticks a row it is not certain about: a file matched only by
/// the app's *name* is shown, labelled, and left for a person to decide on.
final class UninstallWindow: NSWindow, NSWindowDelegate, ClosableWindow {

    var onClose: (() -> Void)?

    private let search = NSSearchField()
    private let appList = NSStackView()
    private let appScroll = NSScrollView()
    private let status = NSTextField(labelWithString: "")
    private let rows = NSStackView()
    private let scroll = NSScrollView()
    private let binButton = NSButton()

    private var apps: [(name: String, bundleID: String, url: URL)] = []
    private var chosen: (name: String, bundleID: String, url: URL)?
    private var leftovers: [AppLeftovers.Item] = []
    private var selected: Set<URL> = []

    private static var open: UninstallWindow?

    static func present() {
        if let existing = open { existing.show(); return }
        let made = UninstallWindow()
        made.onClose = { UninstallWindow.open = nil }
        open = made
        made.show()
    }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
                   styleMask: [.closable, .titled, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: true)

        title = localized("Remove an app")
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        delegate = self

        let backdrop = NSVisualEffectView()
        backdrop.material = .sidebar
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        contentView = backdrop

        search.placeholderString = localized("Search installed apps…")
        search.target = self
        search.action = #selector(searchChanged)
        search.translatesAutoresizingMaskIntoConstraints = false

        for (stack, view) in [(appList, appScroll), (rows, scroll)] {
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 2
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.hasVerticalScroller = true
            view.drawsBackground = false
            view.translatesAutoresizingMaskIntoConstraints = false
            let flipped = FlippedBox()
            flipped.translatesAutoresizingMaskIntoConstraints = false
            flipped.addSubview(stack)
            view.documentView = flipped
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: flipped.topAnchor),
                stack.leadingAnchor.constraint(equalTo: flipped.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: flipped.trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: flipped.bottomAnchor),
                flipped.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -4),
            ])
        }

        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.translatesAutoresizingMaskIntoConstraints = false

        binButton.title = localized("Move to Bin")
        binButton.bezelStyle = .rounded
        binButton.target = self
        binButton.action = #selector(moveSelectedToBin)
        binButton.isEnabled = false
        binButton.translatesAutoresizingMaskIntoConstraints = false

        for view in [search, appScroll, status, scroll, binButton] { backdrop.addSubview(view) }

        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 32),
            search.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 16),
            search.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -16),

            appScroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 8),
            appScroll.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 14),
            appScroll.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -14),
            appScroll.heightAnchor.constraint(equalToConstant: 120),

            status.topAnchor.constraint(equalTo: appScroll.bottomAnchor, constant: 10),
            status.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 18),
            status.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -18),

            scroll.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 6),
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
        if apps.isEmpty { loadApps() }
        makeFirstResponder(search)
    }

    /// Everything in the Applications folders, by bundle.
    private func loadApps() {
        status.stringValue = localized("Looking…")
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var found: [(String, String, URL)] = []
            for folder in ["/Applications", "/Applications/Utilities",
                           fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path] {
                guard let names = try? fm.contentsOfDirectory(atPath: folder) else { continue }
                for name in names where name.hasSuffix(".app") {
                    let url = URL(fileURLWithPath: folder).appendingPathComponent(name)
                    guard let bundle = Bundle(url: url),
                          let id = bundle.bundleIdentifier else { continue }
                    found.append((String(name.dropLast(4)), id, url))
                }
            }
            let sorted = found.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
            DispatchQueue.main.async {
                self.apps = sorted
                // The lower half is empty until an app is picked; say what
                // would fill it rather than leaving a blank panel that reads
                // as something having failed.
                self.status.stringValue = localized("Pick an app to see what it left behind")
                self.searchChanged()
            }
        }
    }

    @objc private func searchChanged() {
        appList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let query = search.stringValue.trimmingCharacters(in: .whitespaces)
        let matches = query.isEmpty ? apps
            : apps.filter { $0.name.localizedCaseInsensitiveContains(query) }

        for app in matches.prefix(40) {
            let button = NSButton(title: app.name, target: self, action: #selector(appPicked(_:)))
            button.bezelStyle = .inline
            button.image = NSWorkspace.shared.icon(forFile: app.url.path)
            button.imagePosition = .imageLeading
            button.alignment = .left
            button.identifier = NSUserInterfaceItemIdentifier(app.bundleID)
            button.translatesAutoresizingMaskIntoConstraints = false
            appList.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: appList.widthAnchor).isActive = true
        }
    }

    @objc private func appPicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let app = apps.first(where: { $0.bundleID == id }) else { return }
        chosen = app
        selected.removeAll()
        status.stringValue = localized("Looking…")
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }

        DispatchQueue.global(qos: .userInitiated).async {
            let found = AppLeftovers.find(bundleID: app.bundleID, appName: app.name,
                                          includingBundle: app.url)
            DispatchQueue.main.async {
                self.leftovers = found
                self.selected = Set(found.filter(AppLeftovers.isTickedByDefault).map(\.url))
                self.redraw()
            }
        }
    }

    private func redraw() {
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let chosen else { return }

        guard !leftovers.isEmpty else {
            status.stringValue = localized("%0 left nothing behind that Perch can see", chosen.name)
            binButton.isEnabled = false
            return
        }

        let total = leftovers.reduce(Int64(0)) { $0 + $1.bytes }
        status.stringValue = localized("%0 — %1 items, %2 in total", chosen.name,
                                       String(leftovers.count), Readings.bytes(UInt64(total)))

        let home = FileManager.default.homeDirectoryForCurrentUser
        for item in leftovers {
            rows.addArrangedSubview(LeftoverRow(item, home: home,
                                                isTicked: selected.contains(item.url)) {
                [weak self] on in
                guard let self else { return }
                if on { self.selected.insert(item.url) } else { self.selected.remove(item.url) }
                self.updateBinButton()
            })
        }
        updateBinButton()
    }

    private func updateBinButton() {
        let count = selected.count
        binButton.isEnabled = count > 0
        binButton.title = count > 0 ? localized("Move %0 to Bin", String(count))
                                    : localized("Move to Bin")
    }

    @objc private func moveSelectedToBin() {
        let chosenItems = leftovers.filter { selected.contains($0.url) }
        guard !chosenItems.isEmpty, let app = chosen else { return }

        let bytes = chosenItems.reduce(Int64(0)) { $0 + $1.bytes }
        // The count and the size, because the decision is "is this the right
        // app" and the size is the only hint that it might not be.
        Alert.show(localized("Remove %0?", app.name),
                   localized("%0 items, %1, go to the Bin. Nothing is erased — everything can be put back from Finder.",
                             String(chosenItems.count), Readings.bytes(UInt64(bytes))),
                   style: .warning,
                   actionTitle: localized("Move to Bin")) { [weak self] in
            let removal = AppLeftovers.moveToBin(chosenItems)
            Notify.show(LargeFiles.message(for: removal), symbol: "trash")
            guard let self else { return }
            let moved = Set(removal.moved)
            self.leftovers.removeAll { moved.contains($0.url) }
            self.selected.subtract(moved)
            self.redraw()
        }
    }
}

/// One leftover: what it is, where, how big, and how sure we are.
private final class LeftoverRow: NSView {

    private let item: AppLeftovers.Item
    private let ticked: (Bool) -> Void

    init(_ item: AppLeftovers.Item, home: URL, isTicked: Bool,
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
        name.lineBreakMode = .byTruncatingMiddle
        name.toolTip = item.url.path
        name.translatesAutoresizingMaskIntoConstraints = false

        // Where it is, and -- for anything less than certain -- why it is
        // here at all. A row somebody is asked to judge has to say what the
        // judgement is about.
        let note: String
        switch item.confidence {
        case .certain:  note = folder(item.url, home: home)
        case .likely:   note = "\(folder(item.url, home: home)) · \(localized("probably this app"))"
        case .possible: note = "\(folder(item.url, home: home)) · \(localized("matched by name only"))"
        }
        let where_ = NSTextField(labelWithString: note)
        where_.font = .systemFont(ofSize: 10)
        where_.textColor = item.confidence == .possible ? .systemOrange : .tertiaryLabelColor
        where_.lineBreakMode = .byTruncatingHead
        where_.translatesAutoresizingMaskIntoConstraints = false

        label.addArrangedSubview(name)
        label.addArrangedSubview(where_)

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
            tick.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
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
        where_.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func folder(_ url: URL, home: URL) -> String {
        let parent = url.deletingLastPathComponent().path
        guard parent.hasPrefix(home.path) else { return parent }
        let trimmed = String(parent.dropFirst(home.path.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? "~" : trimmed
    }

    @objc private func tickChanged(_ sender: NSButton) { ticked(sender.state == .on) }

    required init?(coder: NSCoder) { fatalError("not used") }
}

/// Top-down layout inside a scroll view.
private final class FlippedBox: NSView {
    override var isFlipped: Bool { true }
}
