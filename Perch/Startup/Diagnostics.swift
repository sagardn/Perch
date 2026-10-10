import AppKit

/// The launch arguments that drive the UI so a machine can look at it.
///
/// Every one of these exists because the thing it reaches cannot be reached
/// any other way without a person at the keyboard. Opening a popup means
/// clicking a menu bar item, which needs UI-scripting permission a terminal
/// or a CI runner does not have. Moving the combined-mode switch and watching
/// the menu bar rearrange *without a restart* cannot be done by writing the
/// preference and launching, because that only ever tests the launch path --
/// which is the one that already worked. And a pane with a broken constraint
/// looks exactly like a correct one in every assertion that does not draw it.
///
/// They are diagnostics, not a scripting interface: each one logs what it
/// did, and `--render` quits when it is finished.
extension AppDelegate {

    internal func runDiagnostics(_ arguments: LaunchArguments) {
        if let popup = arguments.popup { openPopup(popup) }
        if !arguments.menuBarSteps.isEmpty { applyMenuBarSteps(arguments.menuBarSteps) }
        if let render = arguments.render { renderAndQuit(render) }
    }

    // MARK: - --popup

    /// `--popup <name> [seconds]` opens one popup, pane or panel.
    ///
    /// Not only modules: the launcher's search panel, the settings window's
    /// panes and the support window are all reachable here, because the
    /// README plates include them and none of them can be opened from a
    /// script either.
    private func openPopup(_ request: LaunchArguments.PopupRequest) {
        let wanted = request.name.lowercased()

        DispatchQueue.main.asyncAfter(deadline: .now() + request.delay) {
            switch wanted {
            case "search":
                Launcher.shared.showSearch()

            case "support":
                self.ensureSupportWindow().show()

            case "settings", "dashboard":
                // `.toggleSettings` already carries the pane to open. Posting
                // `.openModuleSettings` separately raced the window's own
                // restore and landed on whichever module was last selected.
                NotificationCenter.default.post(
                    name: .toggleSettings, object: nil,
                    userInfo: ["module": wanted == "settings" ? "Settings" : "Dashboard"])

            default:
                self.openModulePopup(named: wanted)
            }
        }
    }

    private func openModulePopup(named wanted: String) {
        guard let module = ModuleRegistry.shared.all.first(where: {
            $0.moduleName.lowercased() == wanted
        }) else {
            Log.error("--popup: no module named \(wanted)")
            return
        }

        // A module Perch draws owns its own popup and opens it directly.
        if MonitorBar.shared.openPopup(for: module.moduleName) { return }

        let screen = NSScreen.main?.visibleFrame ?? .zero
        NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: [
            "module": module.moduleName,
            "origin": CGPoint(x: screen.maxX - 40, y: screen.maxY),
            "center": CGFloat(0)
        ])
    }

    // MARK: - --menu-bar

    /// `--menu-bar <step>[,<step>...]`, three seconds apart.
    ///
    /// Spaced out, and that is the point rather than politeness: one launch
    /// can move the switch and then say what the menu bar did about it, which
    /// is the whole question. The mode is written through `Preferences`, the
    /// identical path the switch in Settings takes.
    private func applyMenuBarSteps(_ steps: [String]) {
        for (index, step) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3 + Double(index) * 3) {
                self.applyMenuBarStep(step)
            }
        }
    }

    private func applyMenuBarStep(_ step: String) {
        /// The part after a step's prefix: `spacing:wide` is `wide`.
        func payload(_ prefix: String) -> String { String(step.dropFirst(prefix.count)) }

        switch step {
        case "combined", "individual":
            Preferences.shared.combinedModules = (step == "combined")
            NSLog("Perch: menu bar set to \(step)")

        case "row":
            reportMenuBar()

        case "details":
            let opened = MonitorBar.shared.toggleCombinedDetails()
            let tiles = MonitorBar.shared.combinedDetailTiles
            NSLog("Perch: combined details \(opened ? "opened" : "closed")"
                  + "; tiles: \(tiles.isEmpty ? "(none)" : tiles.joined(separator: " "))")

        case _ where step.hasPrefix("shapes:"):
            applyShapes(payload("shapes:"))

        case _ where step.hasPrefix("spacing:"):
            Preferences.shared.combinedSpacing = payload("spacing:")
            NSLog("Perch: combined spacing set to \(Preferences.shared.combinedSpacing)")

        case _ where step.hasPrefix("separator:"):
            Preferences.shared.combinedSeparator = step.hasSuffix("on")
            NSLog("Perch: combined separator"
                  + " \(Preferences.shared.combinedSeparator ? "on" : "off")")

        case _ where step.hasPrefix("on:") || step.hasPrefix("off:"):
            let on = step.hasPrefix("on:")
            switchModule(named: payload(on ? "on:" : "off:"), on: on)

        case _ where step.hasPrefix("press:"):
            guard let x = Double(payload("press:")) else {
                Log.error("--menu-bar press: expected a number of points")
                return
            }
            let opened = MonitorBar.shared.press(atX: CGFloat(x)) ?? "nothing"
            NSLog("Perch: a press at \(x) in the combined row opened \(opened)")

        default:
            Log.error("--menu-bar: expected combined, individual, row, details,"
                      + " spacing:<name>, separator:<on|off>, on:<module>,"
                      + " off:<module>, shapes:<module>=<shape>+<shape>"
                      + " or press:<x>")
        }
    }

    private func reportMenuBar() {
        let state = MonitorBar.shared.state
        let row = state.row
            .map { "\($0.name)@\(Int($0.x))+\(Int($0.width))" }
            .joined(separator: " ")
        let own = state.own.map { "\($0.0)+\(Int($0.1))" }.joined(separator: " ")
        NSLog("Perch: menu bar is \(state.combined ? "combined" : "individual")"
              + "; row: \(row.isEmpty ? "(none)" : row)"
              + "; own items: \(own.isEmpty ? "(none)" : own)")
        NSLog("Perch: modules: " + MonitorBar.shared.moduleReport.joined(separator: " "))
    }

    /// `shapes:CPU=mini+line_chart`
    ///
    /// Plus signs rather than commas, because commas already separate the
    /// steps of the argument this is part of.
    private func applyShapes(_ assignment: String) {
        // Empty components kept, so `shapes:CPU=` can say "nothing".
        let parts = assignment.split(separator: "=", maxSplits: 1,
                                     omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            Log.error("--menu-bar shapes: expected <module>=<shape>+<shape>")
            return
        }

        guard let module = moduleName(matching: String(parts[0])) else {
            Log.error("--menu-bar shapes: no module named \(parts[0])")
            return
        }

        let shapes = parts[1].split(separator: "+")
            .compactMap { MenuBarStyle(rawValue: String($0)) }
        MenuBarStyles.store(shapes, for: module)
        NSLog("Perch: \(module) now shows "
              + (shapes.isEmpty ? "nothing"
                                : shapes.map(\.rawValue).joined(separator: " ")))
    }

    private func switchModule(named name: String, on: Bool) {
        guard let module = ModuleRegistry.shared.all.first(where: {
            $0.moduleName.lowercased() == name.lowercased()
        }) else {
            Log.error("--menu-bar: no module named \(name)")
            return
        }
        module.isEnabled = on
        NSLog("Perch: \(module.moduleName) switched \(on ? "on" : "off")")
    }

    /// A module's canonical name from however it was typed.
    private func moduleName(matching typed: String) -> String? {
        ModuleRegistry.shared.all.first {
            $0.moduleName.lowercased() == typed.lowercased()
        }?.moduleName
    }

    // MARK: - --render

    /// `--render settings:<Module> <path>` · `--render setup:<n> <path>`
    /// · `--render setup:window <path>` · `--render window:<pane> <path>`
    ///
    /// Writes a PNG and quits. A view renders into a bitmap without needing to
    /// be on screen, so the first two work with the screen locked; `window:`
    /// is the exception and says why below.
    private func renderAndQuit(_ request: LaunchArguments.RenderRequest) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            let subject = request.subject

            if subject == "uninstall" {
                self.renderWindow(of: UninstallWindow.self, to: request.path,
                                  after: 6, present: UninstallWindow.present)
            } else if subject == "files" {
                self.renderLargeFiles(to: request.path)
            } else if subject == "setup:window" {
                self.renderSetupWindow(to: request.path)
            } else if subject.hasPrefix("setup:") {
                self.renderSetupPage(Int(subject.dropFirst("setup:".count)) ?? 0,
                                     to: request.path)
            } else if subject.hasPrefix("settings:") {
                self.renderSettingsPane(String(subject.dropFirst("settings:".count)),
                                        to: request.path)
            } else if subject.hasPrefix("window:") {
                self.renderSettingsWindow(String(subject.dropFirst("window:".count)),
                                          to: request.path)
            } else {
                Log.error("--render: expected settings:<Module>, setup:<n>,"
                          + " setup:window or window:<pane>")
                NSApp.terminate(nil)
            }
        }
    }

    /// A module's settings pane.
    private func renderSettingsPane(_ name: String, to path: String) {
        defer { NSApp.terminate(nil) }

        // Perch's own module first where there is one: the point of this is to
        // look at the page being written.
        let own = NativeModules.all.first {
            $0.title.lowercased() == name.lowercased()
        } as? (any PerchModule)
        guard let module = own ?? ModuleRegistry.shared.all.first(where: {
            $0.moduleName.lowercased() == name.lowercased()
        }), let pane = module.makeSettingsPage() else {
            Log.error("--render: no settings page for \(name)")
            return
        }

        // Laid out tall and then trimmed to what the content actually took. A
        // pane built as a column of sections reports no fitting height of its
        // own until it has been given a width, and a pane clipped to a guess
        // hides the section at the bottom -- which is what the first version
        // of this did.
        pane.appearance = NSAppearance(named: .aqua)
        pane.frame = NSRect(x: 0, y: 0, width: 540, height: 1400)
        pane.layoutSubtreeIfNeeded()
        let used = pane.subviews.map(\.frame.height).max() ?? 1400
        pane.frame = NSRect(x: 0, y: 0, width: 540, height: min(used + 8, 1400))
        pane.layoutSubtreeIfNeeded()

        write(pane, to: path, describedAs: "\(name) settings, \(Int(pane.frame.height))pt tall")
    }

    /// The whole first-run window: the page, the hairline and the two
    /// buttons under it.
    ///
    /// `setup:<n>` renders a page without the frame around it, so until this
    /// existed the footer had never been looked at by anyone -- the window is
    /// shown once per installation, and whoever sees it is not the person who
    /// would notice the buttons were in the wrong place.
    ///
    /// Cached rather than captured off the window server, unlike
    /// `window:<pane>`: every part of this window is AppKit, so the draw path
    /// sees all of it, and cacheDisplay needs no Screen Recording permission.
    /// That holds only while it stays AppKit. A SwiftUI subview added to any
    /// setup page would come back missing from this image, silently, in
    /// exactly the way the settings sidebar did.
    private func renderSetupWindow(to path: String) {
        defer { NSApp.terminate(nil) }
        let chrome = makeSetupChrome()
        chrome.appearance = NSAppearance(named: .aqua)
        chrome.frame = NSRect(x: 0, y: 0, width: 700, height: 440)
        chrome.layoutSubtreeIfNeeded()
        write(chrome, to: path, describedAs: "the setup window")
    }

    /// A page of the first-run window.
    ///
    /// Sized by the window rather than by its content -- a fixed 700x380
    /// inside a 700x440 window -- so unlike a settings pane it is given that
    /// frame outright and not measured.
    ///
    /// Same AppKit-only caveat as `setup:window` above.
    private func renderSetupPage(_ index: Int, to path: String) {
        defer { NSApp.terminate(nil) }
        guard let page = makeSetupPage(index) else {
            Log.error("--render: no setup page \(index)")
            return
        }
        page.appearance = NSAppearance(named: .aqua)
        page.frame = NSRect(x: 0, y: 0, width: 700, height: 380)
        page.layoutSubtreeIfNeeded()
        write(page, to: path, describedAs: "setup page \(index)")
    }

    /// The settings window itself, sidebar and all.
    ///
    /// Captured off the window server rather than by drawing the view, and
    /// that is not a preference. `cacheDisplay` walks the AppKit draw path,
    /// and the sidebar is a SwiftUI `List` inside an `NSHostingController`
    /// whose rows are composited layers -- so a cached capture of this window
    /// comes back with the search field and the bottom bar present and every
    /// sidebar row missing. Which looks exactly like a sidebar that failed to
    /// populate, and cost an hour of looking for a bug that was not there.
    ///
    /// `CGWindowListCreateImage` with `optionIncludingWindow` captures this
    /// one window and nothing else on screen -- not the desktop, not other
    /// apps. It needs Screen Recording permission; without it the call
    /// returns nothing and this says so rather than writing a blank PNG.
    private func renderSettingsWindow(_ pane: String, to path: String) {
        let window = ensureSettingsWindow()
        window.open(module: pane.isEmpty ? nil : pane)

        // Two seconds: SwiftUI lays out its rows a turn or two of the run
        // loop after the window is first shown, and capturing sooner gets the
        // window before its content.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            defer { NSApp.terminate(nil) }

            let id = CGWindowID(window.windowNumber)
            guard window.windowNumber > 0,
                  let image = CGWindowListCreateImage(
                    .null, .optionIncludingWindow, id, [.boundsIgnoreFraming]),
                  image.width > 1 else {
                Log.error("--render: could not capture the settings window."
                          + " This needs Screen Recording permission"
                          + " (System Settings ▸ Privacy & Security ▸ Screen Recording).")
                return
            }

            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                Log.error("--render: could not encode a PNG of the settings window")
                return
            }
            do {
                try png.write(to: URL(fileURLWithPath: path))
                NSLog("Perch: rendered the settings window showing \(window.title)"
                      + " to \(path), \(image.width)x\(image.height)")
            } catch {
                Log.error("--render: could not write \(path):"
                          + " \(error.localizedDescription)")
            }
        }
    }

    /// The large-files window, after its scan has finished.
    ///
    /// Longer wait than the settings window because this one walks the disk
    /// before it has anything to draw -- capturing at two seconds reliably
    /// photographs the word "Looking…".
    private func renderLargeFiles(to path: String) {
        renderWindow(of: LargeFilesWindow.self, to: path, after: 12,
                     present: LargeFilesWindow.present)
    }

    /// Captures one of Perch's own windows once it has settled.
    private func renderWindow<W: NSWindow>(of type: W.Type, to path: String,
                                           after seconds: TimeInterval,
                                           present: () -> Void) {
        present()

        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            defer { NSApp.terminate(nil) }
            guard let window = NSApp.windows.first(where: { $0 is W }),
                  window.windowNumber > 0,
                  let image = CGWindowListCreateImage(
                    .null, .optionIncludingWindow,
                    CGWindowID(window.windowNumber), [.boundsIgnoreFraming]),
                  image.width > 1 else {
                Log.error("--render files: could not capture the window")
                return
            }
            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: URL(fileURLWithPath: path))
            NSLog("Perch: rendered \(type) to \(path), "
                  + "\(image.width)x\(image.height)")
        }
    }

    private func write(_ view: NSView, to path: String, describedAs what: String) {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            Log.error("--render: could not make a bitmap for \(what)")
            return
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            Log.error("--render: could not encode a PNG for \(what)")
            return
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            NSLog("Perch: rendered \(what) to \(path)")
        } catch {
            Log.error("--render: could not write \(path): \(error.localizedDescription)")
        }
    }
}
