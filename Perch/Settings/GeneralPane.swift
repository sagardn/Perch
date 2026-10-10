import AppKit

/// The Settings pane: how Perch behaves, how the menu bar is arranged, how the
/// search and switcher work, and what to do with the settings themselves.
///
/// Replaces `Perch/Views/AppSettings.swift`. Every preference is read and
/// written through `Preferences`, under the same keys, so nothing a user has
/// set is lost.
///
/// Built as a list of rows with closures rather than a class of `@objc`
/// handlers. The pane it replaces carried twenty-two selector methods, a
/// stored property per control so those methods could find them again, and a
/// `setRowVisibility(_:newState:)` call per row addressed by *index* — change
/// the order of the rows and the wrong ones hide. Rows here hold their own
/// behaviour and visibility.
/// A stack whose coordinates start at the top.
///
/// An NSScrollView whose document view is not flipped puts the origin at the
/// bottom, so it opens showing the *end* of the content. The pane looked as
/// though it was clipping the app icon; it was scrolled past it. Four attempts
/// at the image view went nowhere because the image was never the problem.
private final class FlippedStack: NSStackView {
    override var isFlipped: Bool { true }
}

final class GeneralPane: NSStackView {

    private let prefs = Preferences.shared
    private let onRestartNeeded: () -> Void

    /// Rows whose visibility depends on another setting, kept by name.
    private var dependent: [String: NSView] = [:]
    private var accessibilityStatus: NSTextField?
    private var accessibilityButton: NSButton?
    private var launchAtLoginSwitch: ActionSwitch?

    init(width: CGFloat, onRestartNeeded: @escaping () -> Void = {}) {
        self.onRestartNeeded = onRestartNeeded
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 0))
        self.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let column = FlippedStack()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 14
        // 44 at the top, not 18: the shell's window has a transparent title
        // bar that the detail view scrolls under, and at 18 the app icon came
        // out sliced in half by it.
        column.edgeInsets = NSEdgeInsets(top: 44, left: 18, bottom: 18, right: 18)
        column.translatesAutoresizingMaskIntoConstraints = false

        // Each section is pinned to the column's width. Without this a stack
        // with .leading alignment gives every card its natural width, so the
        // cards came out ~380pt wide inside a 1,100pt pane and labels
        // truncated while most of the pane sat empty.
        let sections = [identity(), general(), menuBar(), colours(), searchAndSwitcher(), backup()]
        for section in sections {
            column.addArrangedSubview(section)
            section.widthAnchor.constraint(equalTo: column.widthAnchor,
                                           constant: -(column.edgeInsets.left + column.edgeInsets.right)
                                          ).isActive = true
        }

        // The column *is* the document, and only its width is tied to the
        // scroll view. Wrapping it in a container pinned on all four edges
        // forced the content to the height of the visible area -- the stack
        // then had less room than its subviews needed and clipped the first
        // one, which is why the app icon arrived as the bottom third of
        // itself. A scrolling column must be free to be taller than its
        // clip view; that is the entire point of it.
        scroll.documentView = column
        column.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true

        self.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(equalTo: self.heightAnchor).isActive = true

        syncDependentRows()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Called when the pane comes back on screen: the two states that can
    /// change behind its back.
    func viewWillAppear() {
        syncAccessibility()
        launchAtLoginSwitch?.state = LoginItem.isEnabled ? .on : .off
    }

    // MARK: - Sections

    /// Icon, name and version on one line, with the update button at its end.
    ///
    /// A row rather than the centred 96pt icon over three lines it replaces,
    /// which took 200pt -- a fifth of the window -- before the first setting.
    private func identity() -> NSView {
        let icon = NSImageView()
        icon.image = Self.appIcon(40)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 40).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let name = NSTextField(labelWithString: "Perch")
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        let version = NSTextField(labelWithString: Version.current.map { "Version \($0)" } ?? "")
        version.font = .systemFont(ofSize: 11)
        version.textColor = .secondaryLabelColor
        version.isSelectable = true

        let words = NSStackView(views: [name, version])
        words.orientation = .vertical
        words.alignment = .leading
        words.spacing = 1

        let update = Controls.button("Check for update") { [weak self] in self?.checkForUpdate() }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let row = NSStackView(views: [icon, words, spacer, update])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func general() -> NSView {
        // Switches first, then the two menus, so like controls line up.
        Controls.section(localized("General"), [
            Controls.row(localized("Start at login"), launchAtLoginToggle()),
            Controls.row(localized("Show in Dock"), Controls.toggle(prefs.dockIcon) { [weak self] on in
                self?.prefs.dockIcon = on
                NSApp.setActivationPolicy(on ? .regular : .accessory)
            }),
            Controls.row(localized("Check for updates"), Controls.choice(
                [("Never", "Never"), ("Once per hour", "Once per hour"),
                 ("Once per day", "Once per day"), ("Once per week", "Once per week"),
                 ("Silent", "Silent")],
                selected: prefs.updateInterval) { [weak self] value in
                    self?.prefs.updateInterval = value
                }),
            Controls.row(localized("Temperature unit"), Controls.choice(
                [("System", "system"), ("Celsius", "celsius"), ("Fahrenheit", "fahrenheit")],
                selected: prefs.temperatureUnits) { [weak self] value in
                    self?.prefs.temperatureUnits = value
                }),
        ])
    }

    private func menuBar() -> NSView {
        let spacing = Controls.row(localized("Spacing"), Controls.choice(
            [("None", "none"), ("Small", "small"), ("Normal", "normal"), ("Large", "large")],
            selected: prefs.combinedSpacing) { [weak self] value in
                self?.prefs.combinedSpacing = value
            }, indented: true)
        let separator = Controls.row(localized("Separators"), Controls.toggle(prefs.combinedSeparator) { [weak self] on in
            self?.prefs.combinedSeparator = on
        }, indented: true)
        let details = Controls.row(localized("One popup for all"), Controls.toggle(prefs.combinedPopup) { [weak self] on in
            self?.prefs.combinedPopup = on
        }, indented: true)
        dependent["combined.spacing"] = spacing
        dependent["combined.separator"] = separator
        dependent["combined.details"] = details

        // Combine first, so the rows that only exist while it is on sit
        // directly under it rather than under the unrelated position switch.
        return Controls.section(localized("Menu bar"), [
            Controls.row(localized("Combine modules into one item"),
                         Controls.toggle(prefs.combinedModules) { [weak self] on in
                             self?.prefs.combinedModules = on
                             self?.syncDependentRows()
                         }),
            spacing, separator, details,
            Controls.row(localized("Keep item positions"),
                         Controls.toggle(prefs.keepMenuBarPositions) { [weak self] on in
                             self?.prefs.keepMenuBarPositions = on
                         }),
        ])
    }

    /// The three load colours, everywhere they are used at once: the menu
    /// bar figures, the popups' status dots, bars and charts. Amber is also
    /// the upload series, which the label says rather than leaving a user
    /// to wonder why their arrows changed.
    private func colours() -> NSView {
        Controls.section(localized("Colours"), [
            Controls.row(localized("Colour the menu bar"),
                         Controls.toggle(PerchColors.menuBarColoured) { PerchColors.menuBarColoured = $0 }),
            Controls.row(localized("Normal"), Controls.colour(.calm)),
            Controls.row(localized("Busy · upload and write"), Controls.colour(.warning)),
            Controls.row(localized("Critical"), Controls.colour(.critical)),
        ])
    }

    private func searchAndSwitcher() -> NSView {
        let status = Controls.label(Self.accessibilityState)
        accessibilityStatus = status
        let allow = Controls.button("Allow…") { [weak self] in
            Launcher.shared.grantAccessibility()
            self?.syncAccessibility()
        }
        accessibilityButton = allow

        // Two fingers is not offered: macOS makes a two-finger tap a secondary
        // click and the pair Smart Zoom, so TapRecognizer refuses anything
        // below three. A row for it would be a switch that cannot turn on.
        let fingerRows = [3, 4].map { count -> NSView in
            // Two whole keys rather than a word slotted into a sentence:
            // "Three" and "-finger double tap" are not separable in every
            // language, and the version that indexed an array of words could
            // not be translated at all.
            let label = count == 3 ? localized("Three-finger double tap")
                                   : localized("Four-finger double tap")
            let row = Controls.row(label,
                                   Controls.toggle(Prefs.gestureFingerCounts.contains(count)) { [weak self] on in
                                       self?.setGestureFinger(count, on)
                                   }, indented: true)
            dependent["gesture.\(count)"] = row
            return row
        }

        let section = Controls.section(localized("Search & switcher"), [
            Controls.row(localized("Open where the pointer is"),
                         Controls.toggle(Prefs.openAtPointer) { Prefs.openAtPointer = $0 }),
            Controls.row(localized("Close when it loses focus"),
                         Controls.toggle(Prefs.hideOnOutsideClick) { Prefs.hideOnOutsideClick = $0 }),
            Controls.row(localized("⌃Tab cycles your marked apps"),
                         Controls.toggle(Prefs.cycleHotkeyEnabled) {
                             Prefs.cycleHotkeyEnabled = $0
                             Launcher.shared.applyCycleHotkey()
                         }),
            Controls.row(localized("Trackpad gesture opens the search"),
                         Controls.toggle(Prefs.gestureEnabled) { [weak self] on in
                             Prefs.gestureEnabled = on
                             Launcher.shared.applyGesture(userAsked: true)
                             self?.syncDependentRows()
                         }),
        ] + fingerRows + [
            // The state and the way to change it on one row, rather than a
            // status row and a full-width button bar under it.
            Controls.row(localized("Window control"), Controls.group([status, allow])),
        ])
        syncAccessibility()
        return section
    }

    /// Export, import and reset on one row: three actions on one file, not
    /// three settings. Not titled "Settings", which the page already is.
    private func backup() -> NSView {
        let reset = Controls.button("Reset…") { [weak self] in self?.reset() }
        // The title, not contentTintColor: a rounded push button ignores the
        // tint, and the first attempt came out the same grey as its siblings.
        reset.attributedTitle = NSAttributedString(string: localized("Reset…"), attributes: [
            .foregroundColor: NSColor.systemRed,
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        ])
        return Controls.section(localized("Backup"), [
            Controls.row(localized("Your settings"), Controls.group([
                Controls.button("Export…") { [weak self] in self?.export() },
                Controls.button("Import…") { [weak self] in self?.importSettings() },
                reset,
            ])),
        ])
    }

    // MARK: - Behaviour

    /// The app icon drawn into a bitmap of exactly `side` points.
    ///
    /// Neither `imageScaling` nor setting the image's `size` fixed this: the
    /// asset catalogue hands back a 1024pt image whose representations are
    /// drawn at their own size, and every scaling mode still produced the
    /// bottom third of the icon in a 96pt box. Rasterising it once at the size
    /// it is displayed at removes the question.
    private static func appIcon(_ side: CGFloat) -> NSImage? {
        guard let source = NSImage(named: NSImage.Name("AppIcon")) else { return nil }
        let size = NSSize(width: side, height: side)
        return NSImage(size: size, flipped: false) { rect in
            source.draw(in: rect,
                        from: .zero,
                        operation: .sourceOver,
                        fraction: 1,
                        respectFlipped: true,
                        hints: [.interpolation: NSImageInterpolation.high])
            return true
        }
    }

    /// The button goes once there is nothing left to allow.
    private func syncAccessibility() {
        accessibilityStatus?.stringValue = Self.accessibilityState
        accessibilityButton?.isHidden = WindowControl.isTrusted
    }

    private static var accessibilityState: String {
        if WindowControl.isTrusted { return localized("Allowed") }
        return WindowControl.wasRevoked ? localized("Allowed, but stale since the update")
                                        : localized("Not allowed")
    }

    private func launchAtLoginToggle() -> NSSwitch {
        let control = Controls.toggle(LoginItem.isEnabled) { [weak self] on in
            LoginItem.isEnabled = on
            // Refused for a bundle running out of a build folder, so the
            // switch must not sit there claiming it took.
            if on && !LoginItem.isEnabled {
                self?.launchAtLoginSwitch?.state = .off
                Alert.show("Move Perch to /Applications first",
                           "Perch is running from \(Bundle.main.bundleURL.deletingLastPathComponent().path). "
                           + "A login item pointing there starts a copy that the next build replaces, "
                           + "which makes macOS ask for Accessibility again at every login.")
            }
        }
        launchAtLoginSwitch = control as? ActionSwitch
        return control
    }

    /// Turning every finger count off would leave the gesture listening for
    /// nothing, so the last one on refuses to go off.
    private func setGestureFinger(_ count: Int, _ on: Bool) {
        var counts = Prefs.gestureFingerCounts
        if on {
            counts.insert(count)
        } else {
            guard counts.count > 1 else {
                syncDependentRows()
                Alert.show("Keep at least one",
                           "Turn the trackpad gesture off instead if you do not want it.")
                return
            }
            counts.remove(count)
        }
        Prefs.gestureFingerCounts = counts
        Launcher.shared.applyGesture()
    }

    /// Rows that only mean something while another setting is on.
    private func syncDependentRows() {
        let combined = prefs.combinedModules
        for name in ["combined.spacing", "combined.separator", "combined.details"] {
            dependent[name]?.isHidden = !combined
        }
        let gesture = Prefs.gestureEnabled
        for count in [3, 4] {
            let row = dependent["gesture.\(count)"]
            row?.isHidden = !gesture
            if let toggle = row?.subviews.compactMap({ $0 as? ActionSwitch }).first {
                toggle.state = Prefs.gestureFingerCounts.contains(count) ? .on : .off
            }
        }
    }

    private func checkForUpdate() {
        appUpdater.check { [weak self] result in
            DispatchQueue.main.async {
                guard self != nil else { return }
                let window = UpdateWindow(updater: appUpdater)
                switch result {
                case .success(.available(let release)): window.offer(release)
                case .success(.upToDate):               window.reportUpToDate()
                case .failure(let error):               window.report(error)
                }
            }
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Perch settings.plist"
        panel.allowedContentTypes = [.propertyList]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try prefs.exportAll().write(to: url)
        } catch {
            Alert.show("Could not save the settings", error: error)
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.propertyList]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let count = try prefs.importAll(Data(contentsOf: url))
            Alert.show("Imported \(count) settings",
                       "Perch needs to restart for all of them to take effect.",
                       actionTitle: "Restart now") { [weak self] in self?.onRestartNeeded() }
        } catch {
            Alert.show("That is not a Perch settings file", error: error)
        }
    }

    private func reset() {
        Alert.show("Reset every setting?",
                   "Perch will go back to its defaults and restart. This cannot be undone.",
                   style: .warning,
                   actionTitle: "Reset") { [weak self] in
            self?.prefs.resetAll()
            self?.onRestartNeeded()
        }
    }
}
