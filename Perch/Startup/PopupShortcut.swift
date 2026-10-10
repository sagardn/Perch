import AppKit

/// The keyboard shortcut that opens a module's popup.
///
/// A shortcut is stored as a list of key codes with the modifiers first, in a
/// fixed order, because that is the shape the settings page records when
/// somebody presses a combination. Assembling it the same way on the way back
/// in is the whole of the matching, so the order is load-bearing: a shortcut
/// assembled in a different order never matches the one that was stored, and
/// the symptom is a shortcut that silently does nothing.
enum PopupShortcut {

    /// Virtual key codes for the modifier keys, in the order a stored
    /// shortcut lists them.
    ///
    /// Control, shift, command, option. Not a sorted order and not the order
    /// they appear on the keyboard -- it is the order the recorder wrote, and
    /// it is written down here because it cannot be derived.
    static let control: UInt16 = 59
    static let shift: UInt16 = 60
    static let command: UInt16 = 55
    static let option: UInt16 = 58

    /// The stored form of whatever is currently held down.
    static func keyCodes(modifiers: NSEvent.ModifierFlags,
                         keyCode: UInt16) -> [UInt16] {
        var codes: [UInt16] = []
        if modifiers.contains(.control) { codes.append(control) }
        if modifiers.contains(.shift) { codes.append(shift) }
        if modifiers.contains(.command) { codes.append(command) }
        if modifiers.contains(.option) { codes.append(option) }
        codes.append(keyCode)
        return codes
    }
}

extension AppDelegate {

    /// Watch for popup shortcuts, but only while one is actually set.
    ///
    /// A global keyDown monitor is a system-wide keylogger as far as macOS is
    /// concerned, so asking for one is what makes it offer Perch an Input
    /// Monitoring prompt. Arming it unconditionally meant that dialog at
    /// every launch, for a feature almost nobody uses. The local monitor
    /// stays armed: it sees only this app's own events and needs no
    /// permission.
    @objc internal func syncPopupKeyMonitor() {
        if popupKeyLocalMonitor == nil {
            popupKeyLocalMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.keyDown, .flagsChanged]) { [weak self] event in
                    self?.handleKeyEvent(event)
                    return event
                }
        }

        let anyShortcutSet = ModuleRegistry.shared.all.contains { !$0.popupShortcut.isEmpty }

        switch (anyShortcutSet, popupKeyGlobalMonitor) {
        case (true, nil):
            popupKeyGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.keyDown, .flagsChanged]) { [weak self] event in
                    self?.handleKeyEvent(event)
                }
        case (false, let monitor?):
            NSEvent.removeMonitor(monitor)
            popupKeyGlobalMonitor = nil
        default:
            break
        }
    }

    internal func handleKeyEvent(_ event: NSEvent) {
        let pressed = PopupShortcut.keyCodes(modifiers: event.modifierFlags,
                                             keyCode: event.keyCode)

        guard let module = ModuleRegistry.shared.all.first(where: {
            $0.isEnabled && $0.popupShortcut == pressed
        }), let window = module.menuBarWindow else { return }

        if MonitorBar.shared.openPopup(for: module.moduleName) { return }

        // No "widget" key in the payload. It exists so that clicking a
        // *different* widget of the same module reopens the popup rather than
        // toggling it shut, and a module has one keyboard shortcut -- so there
        // is no other widget for the press to have come from.
        NotificationCenter.default.post(name: .togglePopup, object: nil, userInfo: [
            "module": module.moduleName,
            "origin": window.frame.origin,
            "center": window.frame.width / 2
        ])
    }
}
