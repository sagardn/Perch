import AppKit

/// Perch's menu bar.
///
/// Decides where every module's reading is drawn, in the one place that can:
/// either an item each, or all of them side by side in one combined item. A
/// module says only "show me" and never which of the two it is in, so the
/// switch in Settings is the only thing that chooses -- and a module moving
/// from Kit to Perch changes nothing about where it appears.
///
/// This replaces `CombinedView`, which built the combined item out of Kit's
/// widget views and the global module array. It could not survive a module
/// leaving that array, which is what blocked every migration behind it.
final class MonitorBar {

    static let shared = MonitorBar()

    /// One menu bar item drawing one module's reading.
    fileprivate final class Entry {
        let segment: MenuBarSegment
        let item: NSStatusItem

        init(segment: MenuBarSegment) {
            self.segment = segment
            self.item = NSStatusBar.system.statusItem(withLength: segment.width)
            // Unchanged from when these items were only the preview flag's:
            // the autosave name is where macOS remembers the position the
            // user dragged the item to, and renaming it would move them all.
            self.item.autosaveName = "PerchNative-\(segment.name)"
            self.item.button?.toolTip = segment.name
            self.item.button?.title = ""
            self.item.button?.target = self
            self.item.button?.action = #selector(self.press)
            self.item.button?.addSubview(segment.view)
            segment.onResize = { [weak self] in self?.fit() }
            self.fit()
        }

        func tick() {
            segment.refresh()
            fit()
        }

        private func fit() {
            let width = segment.width
            segment.view.setFrameOrigin(.zero)
            segment.view.setFrameSize(NSSize(width: width, height: CombinedBar.height))
            if abs(item.length - width) > 0.5 { item.length = width }
        }

        @objc fileprivate func press() {
            guard let frame = item.button?.window?.frame else { return }
            segment.activate(anchor: frame, offsetX: 0)
        }

        func tearDown() {
            segment.onResize = nil
            segment.view.removeFromSuperview()
            segment.detach()
            NSStatusBar.system.removeStatusItem(item)
        }
    }

    /// Every segment the menu bar has ever made, by module name.
    ///
    /// Kept across rebuilds rather than remade: a segment owns its popup and
    /// a popup owns its chart history, so a module that is taken out of the
    /// row and put back -- which is what switching modes is -- comes back
    /// with its charts intact.
    private var segments: [String: MenuBarSegment] = [:]

    /// The readings Perch has been asked to draw, in the order it was asked.
    private var requested: [String] = []

    private var entries: [String: Entry] = [:]
    private let combined = CombinedBar()
    private var timer: Timer?
    private var watchingSettings = false

    /// What was last put on screen, by name and in order.
    ///
    /// Compared on the tick, so switching a module on or off -- or turning
    /// off the last shape it was drawing -- rearranges the menu bar. There is
    /// no one notification that covers all of it: Kit's modules and Perch's
    /// are switched through different code, and a module can also go from
    /// having something to draw to having nothing without being switched off
    /// at all. Comparing a handful of names once a second costs nothing next
    /// to being wrong.
    private var built: [String] = []

    private init() {}

    // MARK: - What to show

    /// Draw this module's reading. Where it lands is this class's decision,
    /// not the module's.
    ///
    /// Idempotent: asking twice does not make a second item.
    func show(_ module: PopupContent) {
        if !requested.contains(module.title) { requested.append(module.title) }
        if segments[module.title] == nil {
            segments[module.title] = WidgetSegment(content: module)
        }
        present()
    }

    /// Take a module's reading out of the menu bar and let go of it.
    func hide(_ name: String) {
        requested.removeAll { $0 == name }
        entries[name]?.tearDown()
        entries[name] = nil
        // Dropped rather than kept: the module has been switched off, and a
        // popup held for a reading nobody asked for is a window and a timer
        // doing nothing.
        segments[name] = nil
        present()
    }

    /// The window a module's reading is drawn in, for anchoring a popup.
    ///
    /// In combined mode every reading shares one window, which is the right
    /// answer: the popup hangs under the row the reading is in.
    func window(for name: String) -> NSWindow? {
        if let entry = entries[name] { return entry.item.button?.window }
        if combined.isShowing, segments[name] != nil { return combined.window }
        return nil
    }

    func isShowing(_ name: String) -> Bool {
        entries[name] != nil || (combined.isShowing && segments[name] != nil)
    }

    /// Open a module's popup as though its reading had been clicked.
    ///
    /// The keyboard shortcut and `--popup` both used to do this by posting a
    /// notification, which only the modules Kit still owns listen for. A
    /// module Perch draws has its popup here, so they ask here first and fall
    /// back to the notification for the ones that are still Kit's.
    @discardableResult
    func openPopup(for name: String) -> Bool {
        if let entry = entries[name] {
            entry.press()
            return true
        }
        return combined.press(on: name)
    }

    /// Route a press `x` points into the combined row, as a click would.
    /// Returns the module it opened.
    @discardableResult
    func press(atX x: CGFloat) -> String? { combined.press(atX: x) }

    /// Open or close the combined details popup. Returns whether it is now up.
    @discardableResult
    func toggleCombinedDetails() -> Bool { combined.toggleDetails() }

    /// The tiles the details popup is showing.
    var combinedDetailTiles: [String] { combined.detailTiles }

    /// What the menu bar is doing, for checking it from outside: the mode,
    /// the combined row, and the modules holding an item of their own with
    /// the width each one takes.
    var state: (combined: Bool, row: [CombinedLayout.Slot], own: [(String, CGFloat)]) {
        (combined.isShowing,
         combined.slots,
         entries.keys.sorted().map { ($0, entries[$0]?.segment.width ?? 0) })
    }

    /// Every registered module and what the menu bar makes of it: whether it
    /// is on, whether the hardware offers it, whether a segment was built,
    /// and how wide that segment says it is.
    ///
    /// For finding out why a module is not in the row, which is otherwise
    /// invisible -- a module with a segment reporting no width looks exactly
    /// like a module with no segment at all.
    var moduleReport: [String] {
        ModuleRegistry.shared.all.map { module in
            let segment = segments[module.moduleName]
            return [module.moduleName,
                    module.isEnabled ? "on" : "off",
                    module.isAvailable ? "available" : "unavailable",
                    segment == nil ? "no-segment"
                        : "\(segment!.isVisible ? "visible" : "hidden")+\(Int(segment!.width))"
            ].joined(separator: ":")
        }
    }

    // MARK: - Where to show it

    private var isCombined: Bool { Preferences.shared.combinedModules }

    /// Put every reading where the settings say it goes.
    ///
    /// Safe to call at any time and as often as needed -- it works out the
    /// difference between what is on screen and what should be, so the
    /// callers are free to be blunt about it.
    func present() {
        if isCombined {
            for (_, entry) in entries { entry.tearDown() }
            entries.removeAll()
            combined.tiles = { [weak self] in self?.tiles() ?? [] }
            combined.show()
            combined.setSegments(order())
        } else {
            combined.hide()
            let wanted = Set(showable())
            for (name, entry) in entries where !wanted.contains(name) {
                entry.tearDown()
                entries[name] = nil
            }
            for name in showable() where entries[name] == nil {
                guard let segment = segments[name] else { continue }
                entries[name] = Entry(segment: segment)
            }
        }
        built = wantedNames()
        syncTicking()
    }

    /// The readings Perch draws that have something to draw, in order.
    private func showable() -> [String] {
        requested.filter { segments[$0]?.isVisible ?? false }
    }

    /// What should be on screen, whichever mode is on.
    private func wantedNames() -> [String] {
        isCombined ? order().filter { $0.isVisible }.map { $0.name } : showable()
    }

    /// The combined row, in order.
    ///
    /// Registered modules first, by the position the user dragged them to,
    /// then any reading Perch was asked to draw that no registered module
    /// claims -- which today is the preview flag's modules, until each one
    /// takes over a registry entry of its own.
    private func order() -> [MenuBarSegment] {
        var ordered: [MenuBarSegment] = []
        var seen = Set<String>()

        // Paired with the registration index before sorting, because every
        // position is zero until somebody drags one and `sorted(by:)` is not
        // stable: on an untouched install the row would otherwise come out in
        // whatever order the sort happened to produce, and a different one
        // next launch.
        let registered = ModuleRegistry.shared.enabled.enumerated()
            .sorted { ($0.element.combinedPosition, $0.offset)
                    < ($1.element.combinedPosition, $1.offset) }
            .map { $0.element }

        for module in registered {
            guard let segment = segment(for: module) else { continue }
            ordered.append(segment)
            seen.insert(segment.name)
        }
        // A reading Perch draws whose name a registered module already
        // claims is left out: the two are the same module twice, and the
        // registered one is the one the user's settings and the popup
        // shortcut describe. This is only reachable with the preview flag
        // on, and it is the reason CPU appeared once rather than twice there.
        for name in requested where !seen.contains(name) {
            guard let segment = segments[name] else { continue }
            guard !ModuleRegistry.shared.all.contains(where: { $0.moduleName == name })
            else { continue }
            ordered.append(segment)
            seen.insert(name)
        }
        return ordered
    }

    /// This module's segment, made once and remembered.
    private func segment(for module: any PerchModule) -> MenuBarSegment? {
        if let cached = segments[module.moduleName] { return cached }

        let made: MenuBarSegment?
        switch module.menuBarPresence() {
        case .segment(let segment):   made = segment
        case .reading(let content):   made = WidgetSegment(content: content)
        case .none:                   made = nil
        }
        if let made { segments[module.moduleName] = made }
        return made
    }

    /// The tiles the combined details popup stacks.
    private func tiles() -> [(name: String, view: NSView)] {
        ModuleRegistry.shared.enabled.compactMap { module in
            module.makePortal().map { (module.moduleName, $0) }
        }
    }

    // MARK: - Settings

    /// Reacts to the three settings that change what the menu bar looks like.
    ///
    /// Added because none of them took effect: the combined switch did
    /// nothing until the app was relaunched, and spacing and separators did
    /// nothing until some widget happened to resize. `Preferences` posts on
    /// every write, so this is the whole of it.
    private func watchSettings() {
        guard !watchingSettings else { return }
        watchingSettings = true
        NotificationCenter.default.addObserver(
            forName: Preferences.didChange, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let key = note.object as? String else { return }
            switch key {
            case "CombinedModules":
                self.present()
            case "CombinedModules_spacing", "CombinedModules_separator":
                self.combined.relayout()
            default:
                break
            }
        }
    }

    // MARK: - The tick

    /// One timer for everything rather than one each: eight timers a second
    /// apart is eight wakeups where one will do.
    private func syncTicking() {
        if entries.isEmpty && !combined.isShowing {
            stopTicking()
        } else {
            startTicking()
        }
    }

    private func startTicking() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.entries.values.forEach { $0.tick() }
            self.combined.tick()
            if self.wantedNames() != self.built { self.present() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Lifecycle

    /// The readings Perch draws that no module has claimed yet, behind a flag:
    ///
    ///     defaults write com.sagar.perch nativeMonitor -bool true
    ///
    /// Each comes out from behind it as it takes over the registry entry of
    /// the module beside it, rather than sitting next to it.
    static var isPreviewEnabled: Bool {
        UserDefaults.standard.bool(forKey: "nativeMonitor")
    }

    /// Called at launch, after the modules have started.
    func start() {
        watchSettings()
        if Self.isPreviewEnabled {
            NativeModules.all.forEach { self.show($0) }
        }
        present()
    }

    func stop() {
        stopTicking()
        for (_, entry) in entries { entry.tearDown() }
        entries.removeAll()
        combined.hide()
    }
}
