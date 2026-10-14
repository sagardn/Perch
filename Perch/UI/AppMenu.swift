import AppKit

/// The menu a right-click gives, on a menu bar reading or inside a popup.
///
/// Perch had no right-click anywhere: the only way out of the app was a
/// power button in the corner of the Settings window, which somebody has to
/// find before they can use it. Every other menu bar app answers a
/// right-click with Quit, and that is where people look first.
///
/// Deliberately three items. A menu bar app's context menu is not a place to
/// put features -- it is the place somebody goes when they want the window
/// they cannot find, or the app gone.
enum AppMenu {

    /// `module` is the settings page to open, or nil for the Dashboard.
    static func make(for module: String? = nil) -> NSMenu {
        let menu = NSMenu()

        let settings = NSMenuItem(title: localized("Settings") + "…",
                                  action: #selector(Target.openSettings(_:)),
                                  keyEquivalent: ",")
        settings.target = target
        settings.representedObject = module
        menu.addItem(settings)

        let paused = Preferences.shared.bool("pause", default: false)
        let pause = NSMenuItem(title: paused ? localized("Resume") : localized("Pause"),
                               action: #selector(Target.togglePause),
                               keyEquivalent: "")
        pause.target = target
        menu.addItem(pause)

        menu.addItem(.separator())

        // No confirmation. Quitting a menu bar app loses nothing -- every
        // setting is already written -- and an "are you sure" on the one
        // thing somebody opened the menu for is noise.
        let quit = NSMenuItem(title: localized("Quit Perch"),
                              action: #selector(Target.quit), keyEquivalent: "q")
        quit.target = target
        menu.addItem(quit)

        return menu
    }

    /// Menu items need a target that outlives the menu. A menu built on the
    /// stack and shown with `popUp` is gone by the time the action fires, so
    /// the target cannot be the thing that built it.
    private static let target = Target()

    private final class Target: NSObject {
        @objc func openSettings(_ sender: NSMenuItem) {
            NotificationCenter.default.post(
                name: .toggleSettings, object: nil,
                userInfo: ["module": (sender.representedObject as? String) ?? "Dashboard"])
        }

        @objc func togglePause() {
            let paused = Preferences.shared.bool("pause", default: false)
            Preferences.shared.set("pause", !paused)
            NotificationCenter.default.post(name: .pause, object: nil)
        }

        @objc func quit() { NSApp.terminate(nil) }
    }
}
