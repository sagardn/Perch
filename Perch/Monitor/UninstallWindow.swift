import AppKit

/// Remove an application or a command-line tool, and what it left behind.
///
/// Type a name, pick what you want gone, see every file that looks like its,
/// choose, and they go to the Bin. The matching and its confidence levels
/// are in `AppLeftovers` and `CommandLineTools`; this is the part somebody
/// looks at.
///
/// Two things it will not do. It does not delete -- everything Perch removes
/// itself goes to the Bin, so a wrong guess costs a trip to Finder rather
/// than somebody's data. And it never ticks a row it is not certain about: a
/// file matched only by a name is shown, labelled, and left for a person to
/// decide on.
///
/// The one exception is deliberate and is the reason the command is printed
/// in full before it runs. A tool Homebrew or npm installed is removed by
/// running *that manager's* uninstall command, because deleting
/// `Cellar/ripgrep` by hand leaves Homebrew's receipts claiming the formula
/// is still installed. Those files do not go to the Bin -- reinstalling is
/// how they come back -- so nothing runs without the exact command being
/// shown and agreed to.
final class UninstallWindow: NSWindow, NSWindowDelegate, ClosableWindow {

    var onClose: (() -> Void)?

    private enum Mode: Int { case apps, tools }

    private let modes = NSSegmentedControl(labels: [localized("Apps"),
                                                    localized("Command-line tools")],
                                           trackingMode: .selectOne,
                                           target: nil, action: nil)
    private let search = NSSearchField()
    private let appList = NSStackView()
    private let appScroll = NSScrollView()
    private let status = NSTextField(labelWithString: "")
    private let rows = NSStackView()
    private let scroll = NSScrollView()
    private let binButton = NSButton()

    /// Shown only for a tool a package manager owns.
    private let commandBox = NSStackView()
    private let commandLabel = NSTextField(labelWithString: "")
    private let runButton = NSButton()

    private var apps: [(name: String, bundleID: String, url: URL)] = []
    private var tools: [CommandLineTools.Tool] = []
    private var chosen: (name: String, bundleID: String, url: URL)?
    private var chosenTool: CommandLineTools.Tool?
    private var leftovers: [AppLeftovers.Item] = []
    private var selected: Set<URL> = []

    private var mode: Mode { Mode(rawValue: modes.selectedSegment) ?? .apps }

    /// The lower half is empty until something is picked, so until then it
    /// is given no height at all and the list above takes the window. A
    /// fixed split left five hundred points of nothing under a list that
    /// had to be scrolled -- visible in a render, invisible in the code.
    private var detailsEmpty: NSLayoutConstraint!
    private var detailsShown: NSLayoutConstraint!
    /// Hiding a view does not take its constraints away, so the command row
    /// is flattened as well as hidden.
    private var commandCollapsed: NSLayoutConstraint!

    private static var open: UninstallWindow?

    static func present() {
        if let existing = open { existing.show(); return }
        let made = UninstallWindow()
        made.onClose = { UninstallWindow.open = nil }
        open = made
        made.show()
    }

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 580, height: 520),
                   styleMask: [.closable, .titled, .resizable, .fullSizeContentView],
                   backing: .buffered, defer: true)

        title = localized("Remove an app or tool")
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        delegate = self

        let backdrop = NSVisualEffectView()
        backdrop.material = .sidebar
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        contentView = backdrop

        modes.selectedSegment = 0
        modes.target = self
        modes.action = #selector(modeChanged)
        modes.translatesAutoresizingMaskIntoConstraints = false

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

        // Monospaced, and selectable: somebody who would rather run it in
        // their own shell should be able to take it out of here.
        commandLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        commandLabel.isSelectable = true
        commandLabel.lineBreakMode = .byTruncatingMiddle
        commandLabel.translatesAutoresizingMaskIntoConstraints = false

        runButton.title = localized("Run")
        runButton.bezelStyle = .rounded
        runButton.controlSize = .small
        runButton.target = self
        runButton.action = #selector(runCommand)
        runButton.translatesAutoresizingMaskIntoConstraints = false

        let copyButton = Controls.button("Copy") { [weak self] in
            guard let text = self?.commandLabel.stringValue, !text.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            Notify.show(localized("Command copied"), symbol: "doc.on.doc")
        }
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        commandBox.orientation = .horizontal
        commandBox.spacing = 8
        commandBox.alignment = .centerY
        commandBox.isHidden = true
        commandBox.translatesAutoresizingMaskIntoConstraints = false
        commandBox.addArrangedSubview(commandLabel)
        commandBox.addArrangedSubview(copyButton)
        commandBox.addArrangedSubview(runButton)

        binButton.title = localized("Move to Bin")
        binButton.bezelStyle = .rounded
        binButton.target = self
        binButton.action = #selector(moveSelectedToBin)
        binButton.isEnabled = false
        binButton.translatesAutoresizingMaskIntoConstraints = false

        for view in [modes, search, appScroll, status, scroll, commandBox, binButton] {
            backdrop.addSubview(view)
        }

        NSLayoutConstraint.activate([
            modes.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 30),
            modes.centerXAnchor.constraint(equalTo: backdrop.centerXAnchor),

            search.topAnchor.constraint(equalTo: modes.bottomAnchor, constant: 10),
            search.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 16),
            search.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -16),

            appScroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 8),
            appScroll.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 14),
            appScroll.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -14),
            appScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            appScroll.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -10),

            status.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 18),
            status.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -18),

            scroll.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 14),
            scroll.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -14),
            scroll.bottomAnchor.constraint(equalTo: commandBox.topAnchor, constant: -8),

            commandBox.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 18),
            commandBox.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -18),
            commandBox.bottomAnchor.constraint(equalTo: binButton.topAnchor, constant: -8),

            binButton.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -18),
            binButton.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -14),
        ])

        detailsEmpty = scroll.heightAnchor.constraint(equalToConstant: 0)
        // As tall as what is in it, and never more than a third of the
        // window. A fixed share gave one row the same height as twenty, and
        // the gap under it read as the list having failed to draw.
        detailsShown = scroll.heightAnchor.constraint(equalTo: rows.heightAnchor)
        detailsShown.priority = .defaultLow
        scroll.heightAnchor.constraint(lessThanOrEqualTo: backdrop.heightAnchor,
                                       multiplier: 0.38).isActive = true
        commandCollapsed = commandBox.heightAnchor.constraint(equalToConstant: 0)
        detailsEmpty.isActive = true
        commandCollapsed.isActive = true
    }

    /// Gives the lower half its height, or takes it away again.
    private func showDetails(_ shown: Bool) {
        detailsEmpty.isActive = !shown
        detailsShown.isActive = shown
    }

    private func showCommand(_ shown: Bool) {
        commandBox.isHidden = !shown
        commandCollapsed.isActive = !shown
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

    /// Switches to the tools list from outside.
    ///
    /// Exists for `--render uninstall:tools`, which is the only way to look
    /// at a list that takes a few seconds to fill and find out that it looks
    /// wrong -- every layout bug in the window above was found that way and
    /// none of them were visible in the code.
    func selectTools(picking name: String? = nil) {
        pendingPick = name
        modes.selectedSegment = Mode.tools.rawValue
        modeChanged()
    }

    /// A tool to pick as soon as the list has finished filling.
    private var pendingPick: String?

    // MARK: - The two lists

    @objc private func modeChanged() {
        search.stringValue = ""
        clearChoice()
        switch mode {
        case .apps:
            search.placeholderString = localized("Search installed apps…")
            status.stringValue = localized("Pick an app to see what it left behind")
            if apps.isEmpty { loadApps() } else { searchChanged() }
        case .tools:
            search.placeholderString = localized("Search command-line tools…")
            status.stringValue = localized("Pick a tool to see what it left behind")
            if tools.isEmpty { loadTools() } else { searchChanged() }
        }
    }

    /// Everything in the Applications folders, by bundle.
    private func loadApps() {
        search.placeholderString = localized("Search installed apps…")
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
                // The lower half is empty until something is picked; say what
                // would fill it rather than leaving a blank panel that reads
                // as something having failed.
                self.status.stringValue = localized("Pick an app to see what it left behind")
                self.searchChanged()
            }
        }
    }

    private func loadTools() {
        status.stringValue = localized("Looking…")
        DispatchQueue.global(qos: .userInitiated).async {
            let found = CommandLineTools.installed()
            DispatchQueue.main.async {
                self.tools = found
                self.status.stringValue = found.isEmpty
                    ? localized("No command-line tools found")
                    : localized("Pick a tool to see what it left behind")
                self.searchChanged()
            }
        }
    }

    @objc private func searchChanged() {
        appList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let query = search.stringValue.trimmingCharacters(in: .whitespaces)

        switch mode {
        case .apps:
            let matches = query.isEmpty ? apps
                : apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
            for app in matches.prefix(40) {
                add(title: NSAttributedString(string: app.name),
                    image: NSWorkspace.shared.icon(forFile: app.url.path),
                    id: app.bundleID, action: #selector(appPicked(_:)))
            }
        case .tools:
            let matches = query.isEmpty ? tools
                : tools.filter { $0.name.localizedCaseInsensitiveContains(query) }
            for tool in matches.prefix(60) {
                add(title: Self.toolTitle(tool),
                    image: NSImage(systemSymbolName: "terminal", accessibilityDescription: nil),
                    id: tool.location.path, action: #selector(toolPicked(_:)))
            }
            if let name = pendingPick, let tool = tools.first(where: { $0.name == name }) {
                pendingPick = nil
                pick(tool)
            }
        }
    }

    private func add(title: NSAttributedString, image: NSImage?, id: String,
                     action: Selector) {
        let button = NSButton(title: "", target: self, action: action)
        button.attributedTitle = title
        button.bezelStyle = .inline
        button.image = image
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.identifier = NSUserInterfaceItemIdentifier(id)
        button.translatesAutoresizingMaskIntoConstraints = false
        appList.addArrangedSubview(button)
        button.widthAnchor.constraint(equalTo: appList.widthAnchor).isActive = true
    }

    /// The name, then where it came from and how big it is, dimmer.
    ///
    /// Two tools can share a name across the two Homebrew prefixes, so the
    /// row has to say more than the name for the right one to be picked.
    private static func toolTitle(_ tool: CommandLineTools.Tool) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: tool.name,
            attributes: [.font: NSFont.systemFont(ofSize: 12),
                         .foregroundColor: NSColor.labelColor])
        var note = tool.kind.label
        if let detail = tool.detail, tool.isManaged { note += " \(detail)" }
        if tool.bytes > 0 { note += " · \(Readings.bytes(UInt64(tool.bytes)))" }
        text.append(NSAttributedString(
            string: "   \(note)",
            attributes: [.font: NSFont.systemFont(ofSize: 10),
                         .foregroundColor: NSColor.tertiaryLabelColor]))
        return text
    }

    // MARK: - Picking

    private func clearChoice() {
        chosen = nil
        chosenTool = nil
        leftovers = []
        selected.removeAll()
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        showCommand(false)
        showDetails(false)
        binButton.isEnabled = false
        binButton.title = localized("Move to Bin")
    }

    @objc private func appPicked(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let app = apps.first(where: { $0.bundleID == id }) else { return }
        clearChoice()
        chosen = app
        status.stringValue = localized("Looking…")

        DispatchQueue.global(qos: .userInitiated).async {
            let found = AppLeftovers.find(bundleID: app.bundleID, appName: app.name,
                                          includingBundle: app.url)
            DispatchQueue.main.async {
                guard self.chosen?.bundleID == app.bundleID else { return }
                self.show(found, name: app.name)
            }
        }
    }

    @objc private func toolPicked(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue,
              let tool = tools.first(where: { $0.location.path == path }) else { return }
        pick(tool)
    }

    private func pick(_ tool: CommandLineTools.Tool) {
        clearChoice()
        chosenTool = tool
        status.stringValue = localized("Looking…")

        if let command = tool.command {
            commandLabel.stringValue = command.text
            showCommand(true)
            runButton.isEnabled = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let found = CommandLineTools.leftovers(for: tool)
            DispatchQueue.main.async {
                guard self.chosenTool?.location == tool.location else { return }
                self.show(found, name: tool.name)
            }
        }
    }

    private func show(_ found: [AppLeftovers.Item], name: String) {
        showDetails(!found.isEmpty)
        leftovers = found
        selected = Set(found.filter(AppLeftovers.isTickedByDefault).map(\.url))
        redraw(name: name)
    }

    // MARK: - Drawing

    private var chosenName: String? { chosen?.name ?? chosenTool?.name }

    private func redraw(name: String? = nil) {
        rows.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let name = name ?? chosenName else { return }

        guard !leftovers.isEmpty else {
            // A managed tool with no stray files is the normal case, not a
            // dead end: its own command is still sitting above the button.
            status.stringValue = chosenTool?.isManaged == true
                ? localized("%0 is removed by the command below", name)
                : localized("%0 left nothing behind that Perch can see", name)
            binButton.isEnabled = false
            return
        }

        status.stringValue = Self.summary(of: leftovers, for: name)

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
        // "Move 1 to Bin" is worse than saying nothing about the number.
        binButton.title = count > 1 ? localized("Move %0 to Bin", String(count))
                                    : localized("Move to Bin")
    }

    /// What is on the list, in a line.
    ///
    /// One item is named rather than counted. Writing "1 items" is sloppy,
    /// and a singular form of the string would fix it only in the languages
    /// that have exactly two -- Russian and Polish need a third for 2-4.
    /// Naming the single item needs no plural anywhere.
    private static func summary(of items: [AppLeftovers.Item], for name: String) -> String {
        let total = UInt64(items.reduce(Int64(0)) { $0 + $1.bytes })
        if let only = items.first, items.count == 1 {
            return localized("%0 — %1, %2", name, only.name, Readings.bytes(total))
        }
        return localized("%0 — %1 items, %2 in total", name,
                         String(items.count), Readings.bytes(total))
    }

    // MARK: - Removing

    @objc private func moveSelectedToBin() {
        let chosenItems = leftovers.filter { selected.contains($0.url) }
        guard !chosenItems.isEmpty, let name = chosenName else { return }

        let bytes = UInt64(chosenItems.reduce(Int64(0)) { $0 + $1.bytes })
        // The count and the size, because the decision is "is this the right
        // thing" and the size is the only hint that it might not be.
        let detail: String
        if let only = chosenItems.first, chosenItems.count == 1 {
            detail = localized("%0, %1, goes to the Bin. Nothing is erased — it can be put back from Finder.",
                               only.name, Readings.bytes(bytes))
        } else {
            detail = localized("%0 items, %1, go to the Bin. Nothing is erased — everything can be put back from Finder.",
                               String(chosenItems.count), Readings.bytes(bytes))
        }
        Alert.show(localized("Remove %0?", name), detail,
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

    /// Hands the removal to the manager that did the installing.
    @objc private func runCommand() {
        guard let tool = chosenTool, let command = tool.command else { return }

        Alert.show(localized("Run %0?", command.text),
                   localized("Perch runs %0's own uninstaller. What that removes does not go to the Bin — installing it again is how it comes back.",
                             tool.kind.label),
                   style: .warning,
                   actionTitle: localized("Run")) { [weak self] in
            guard let self else { return }
            self.runButton.isEnabled = false
            self.status.stringValue = localized("Running %0…", command.text)

            CommandLineTools.run(command) { [weak self] result in
                guard let self else { return }
                self.runButton.isEnabled = true
                if result.succeeded {
                    Notify.show(localized("%0 removed", tool.name), symbol: "checkmark.circle")
                    self.showCommand(false)
                    // The manager has gone; the dotfiles it never knew about
                    // have not, so the list is rebuilt rather than cleared.
                    self.tools.removeAll { $0 == tool }
                    self.searchChanged()
                    self.chosenTool = nil
                    self.redraw(name: tool.name)
                } else {
                    // Its own words. "Cannot uninstall, it is required by
                    // ..." is the useful part and no summary of ours beats it.
                    Alert.show(localized("%0 could not be removed", tool.name),
                               Self.tail(of: result.output), style: .warning)
                    self.status.stringValue = Self.summary(of: self.leftovers, for: tool.name)
                }
            }
        }
    }

    /// The end of the output, which is where a package manager puts the
    /// reason it refused.
    private static func tail(of output: String, limit: Int = 1200) -> String {
        guard !output.isEmpty else { return localized("It said nothing about why.") }
        guard output.count > limit else { return output }
        return "…" + String(output.suffix(limit))
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
