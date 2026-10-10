//
//  popup-test.swift
//
//  Exercises the words the popups lead with.
//
//  Run:  cat Perch/UI/Palette.swift Perch/UI/Localized.swift \
//            Perch/Settings/Preferences.swift Perch/Monitor/MenuBarStyle.swift \
//            Perch/Monitor/MenuBarWidget.swift Perch/Monitor/Readings.swift \
//            Perch/Monitor/ProcessNetwork.swift Perch/UI/Alert.swift \
//            Perch/Launcher/Notify.swift Perch/Monitor/ProcessControl.swift \
//            Perch/Monitor/PopupSection.swift \
//            Perch/Monitor/PopupParts.swift Tools/popup-test.swift | swift -
//
//  The status line's word and its dot are worked out separately -- the word
//  here, the colour from `Severity` -- so the one thing worth asserting is
//  that they change at the same loads. A popup saying "Busy" beside a calm
//  dot is arguing with itself.
//
import AppKit

var failures = 0

func check(_ name: String, _ condition: Bool) {
    if condition {
        print("  ok   \(name)")
    } else {
        print("  FAIL \(name)")
        failures += 1
    }
}

print("StatusWords.load")

do {
    check("nothing running is idle", StatusWords.load(0) == "Idle")
    check("just under the idle line is idle", StatusWords.load(0.049) == "Idle")
    check("at the idle line it is light", StatusWords.load(0.05) == "Light load")
    check("a NaN prints a dash, not a word", StatusWords.load(.nan) == "—")

    // Every percent from 5 to 100: the word must name the tier the dot is
    // coloured for.
    let expected: [MenuBarReading.Severity: String] = [
        .calm: "Light load", .warning: "Busy", .critical: "Heavy load",
    ]
    var agree = true
    for percent in 5...100 {
        let load = Double(percent) / 100
        if StatusWords.load(load) != expected[MenuBarReading.Severity.of(load: load)] {
            print("       disagree at \(percent)%")
            agree = false
        }
    }
    check("the word changes where the colour does, 5-100%", agree)
}

print("\nSeverity.of(load:)")

do {
    // Severity now reads the load directly instead of comparing the ramp's
    // colour, so its boundaries are written twice. They must not drift: the
    // dot and the chart beside it are coloured by the two.
    var agree = true
    for percent in 0...100 {
        let load = Double(percent) / 100
        if MenuBarReading.Severity.of(load: load).tint !== LoadBand.of(load).color {
            print("       disagree at \(percent)%")
            agree = false
        }
    }
    check("severity and the ramp change colour at the same loads", agree)
}

print("\nSeverityBands")

do {
    typealias S = MenuBarReading.Severity
    // Each boundary from both sides.
    // Literal values, not read back from the bands: a typo in a threshold
    // must fail here rather than move both sides of the check together.
    for (name, bands, below, warning, belowCritical, critical) in [
        ("load", SeverityBands.load, 0.4999, 0.50, 0.7999, 0.80),
        ("disk", SeverityBands.disk, 0.8999, 0.90, 0.9499, 0.95),
        ("temperature", SeverityBands.temperature, 84.99, 85.0, 94.99, 95.0),
    ] {
        check("\(name): calm just below warning", S.of(below, on: bands) == .calm)
        check("\(name): still warning just below critical",
              S.of(belowCritical, on: bands) == .warning)
        check("\(name): warning at its threshold", S.of(warning, on: bands) == .warning)
        check("\(name): critical at its threshold", S.of(critical, on: bands) == .critical)
    }
    check("a NaN is calm, not a crash", S.of(.nan, on: .load) == .calm)
    check("the named helpers use the same bands",
          S.ofDisk(0.91) == .warning && S.ofTemperature(96) == .critical && S.of(load: 0.6) == .warning)
}

print("\nPerchColors hex")

do {
    check("full code", PerchColors.normalised("#0e9ba8") == "#0E9BA8")
    check("no hash", PerchColors.normalised("0E9BA8") == "#0E9BA8")
    check("short code expands", PerchColors.normalised("#f80") == "#FF8800")
    check("whitespace is trimmed", PerchColors.normalised("  #C9302C\n") == "#C9302C")
    check("not hex is refused", PerchColors.normalised("#GGGGGG") == nil)
    check("wrong length is refused", PerchColors.normalised("#12345") == nil)
    check("empty is refused", PerchColors.normalised("") == nil)
    check("a name is refused", PerchColors.normalised("red") == nil)

    // Every default survives the trip through NSColor and back, so the
    // field shows exactly what is stored and "reset" is detectable.
    for which in PerchColors.allCases {
        let color = PerchColors.color(fromHex: which.defaultHex)!
        check("\(which) round-trips", PerchColors.hex(of: color) == which.defaultHex)
    }
}

do {
    // Stored under the user's key and read back as the colour.
    let which = PerchColors.calm
    let before = UserDefaults.standard.string(forKey: which.key)
    defer { UserDefaults.standard.set(before, forKey: which.key) }

    which.set(hex: "#123456")
    check("a choice is stored and used", which.hex == "#123456"
          && PerchColors.hex(of: NSColor.perchCalm) == "#123456")
    check("the same choice is the same colour object", NSColor.perchCalm === NSColor.perchCalm)
    which.set(hex: "nonsense")
    check("a bad code restores the default", which.hex == which.defaultHex && !which.isCustom)
    which.set(hex: which.defaultHex)
    check("choosing the default stores nothing",
          UserDefaults.standard.string(forKey: which.key) == nil)
}

do {
    // The menu bar switch. On unless somebody turns it off.
    let key = "menubar_coloured"
    let before = UserDefaults.standard.object(forKey: key)
    defer { UserDefaults.standard.set(before, forKey: key) }

    UserDefaults.standard.removeObject(forKey: key)
    check("the menu bar is coloured by default", PerchColors.menuBarColoured)
    PerchColors.menuBarColoured = false
    check("switching it off is remembered", !PerchColors.menuBarColoured)
    PerchColors.menuBarColoured = true
    check("and on again", PerchColors.menuBarColoured)
}

// MARK: - The force-quit menu on a process row

print("\nProcessRow context menu")

/// A right-click somewhere inside the row.
func rightClick(in view: NSView) -> NSEvent {
    NSEvent.mouseEvent(with: .rightMouseDown,
                       location: NSPoint(x: view.bounds.midX, y: view.bounds.midY),
                       modifierFlags: [], timestamp: 0, windowNumber: 0,
                       context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
}

do {
    let row = ProcessRow()
    row.layoutSubtreeIfNeeded()
    row.set(name: "Google Chrome", pid: 4321, value: "330 MB")

    let menu = row.menu(for: rightClick(in: row))
    check("a row with a live pid offers a menu", menu != nil)
    check("with both Quit and Force Quit", menu?.items.count == 2)
    // Quit first: the top item is where a fast hand lands, and of the two it
    // is the one that lets the process save.
    check("Quit is offered before Force Quit",
          menu?.items.first?.title.hasPrefix("Quit") == true
            && menu?.items.last?.title.contains("Force") == true)
    check("both name the process",
          menu?.items.allSatisfy { $0.title.contains("Google Chrome") } == true)
    check("both are wired to something",
          menu?.items.allSatisfy { $0.action != nil } == true)
    check("and to different things",
          menu?.items.first?.action != menu?.items.last?.action)
    check("targeting the row, not whatever is first responder",
          menu?.items.allSatisfy { $0.target as? NSView === row } == true)
}

do {
    // An empty slot: the lists are built for more rows than are usually
    // filled, and a menu on one would act on pid 0 -- every process in the
    // group.
    let row = ProcessRow()
    row.layoutSubtreeIfNeeded()
    check("an unfilled row offers no menu at all",
          row.menu(for: rightClick(in: row)) == nil)
}

do {
    // The row must answer the click itself. Its children are labels, and a
    // label has no menu and does not pass the question up -- so if hit
    // testing reaches one, right-clicking the process name does nothing,
    // which is the part of the row anybody would aim at.
    let row = ProcessRow()
    row.layoutSubtreeIfNeeded()
    row.set(name: "Discord Helper (Renderer)", pid: 777, value: "147 MB")
    let onTheName = NSPoint(x: 40, y: row.bounds.midY)
    check("a click on the name lands on the row, not a label",
          row.hitTest(onTheName) === row)
    check("and one outside it lands nowhere",
          row.hitTest(NSPoint(x: -20, y: row.bounds.midY)) == nil)
}

print(failures == 0 ? "\nall passed" : "\n\(failures) failed")
exit(failures == 0 ? 0 : 1)
