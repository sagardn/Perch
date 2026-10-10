//
//  SettingsShell.swift
//  Perch
//
//  The settings window's chrome, rebuilt in SwiftUI.
//
//  Why SwiftUI here: the old sidebar was a hand-rolled NSStackView of custom
//  MenuItem views, each tracking its own hover and selection state, inside a
//  scroll view sized by hand. Selection, keyboard navigation, search and the
//  sidebar material are all free in a List, and NavigationSplitView is what
//  macOS settings windows are made of now -- so this stops drifting further
//  from the platform with every release.
//
//  The module views themselves are untouched AppKit and are hosted as-is, so
//  each module can move to SwiftUI on its own schedule instead of in one
//  sweeping rewrite.
//

import SwiftUI

// MARK: - Model

/// What the shell draws, and the bridge to the notifications the rest of the
/// app already speaks.
final class SettingsModel: ObservableObject {

    struct Item: Identifiable, Hashable {
        let id: String          // the module name, or "Dashboard" / "Settings"
        let title: String
        let isModule: Bool
    }

    @Published var selection: String = "Dashboard"
    @Published var search: String = ""
    /// The AppKit view for the current selection. Resolved by SettingsWindow,
    /// which owns the module lookup.
    @Published var detail: NSView?
    @Published var moduleStates: [String: Bool] = [:]
    @Published var paused: Bool = Preferences.shared.bool("pause", default: false)

    let dashboard = Item(id: "Dashboard", title: localized("Dashboard"), isModule: false)
    let appSettings = Item(id: "Settings", title: localized("Settings"), isModule: false)
    private(set) var moduleItems: [Item] = []

    init() {
        self.moduleItems = ModuleRegistry.shared.all
            .filter { $0.isAvailable }
            .map { Item(id: $0.moduleName,
                        title: localized($0.moduleName),
                        isModule: true) }
        self.moduleStates = Dictionary(uniqueKeysWithValues:
            ModuleRegistry.shared.all.map { ($0.moduleName, $0.isEnabled) })

        NotificationCenter.default.addObserver(
            self, selector: #selector(externalModuleToggle), name: .toggleModule, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(externalPause), name: .pause, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var filteredModules: [Item] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return moduleItems }
        return moduleItems.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    /// Whether the current selection is a module, and whether it can preview.
    var selectedModule: (any PerchModule)? {
        ModuleRegistry.shared.named(selection)
    }

    // MARK: Intents

    /// Selection goes out as the same notification the old sidebar posted, so
    /// "open module X" from a menu bar click and a click in here take one path.
    func select(_ id: String) {
        NotificationCenter.default.post(name: .openModuleSettings, object: nil,
                                        userInfo: ["module": id])
    }

    func setEnabled(_ name: String, _ enabled: Bool) {
        moduleStates[name] = enabled
        NotificationCenter.default.post(name: .toggleModule, object: nil,
                                        userInfo: ["module": name, "state": enabled])
    }

    func togglePreview() {
        guard let module = selectedModule, module.hasPreview else { return }
        NotificationCenter.default.post(name: .togglePreview, object: nil,
                                        userInfo: ["module": module.moduleName])
    }

    func togglePause() {
        paused.toggle()
        Preferences.shared.set("pause", paused)
        NotificationCenter.default.post(name: .pause, object: nil, userInfo: ["state": paused])
    }

    @objc private func externalModuleToggle(_ notification: Notification) {
        guard let name = notification.userInfo?["module"] as? String,
              let state = notification.userInfo?["state"] as? Bool else { return }
        DispatchQueue.main.async { self.moduleStates[name] = state }
    }

    @objc private func externalPause() {
        let state = Preferences.shared.bool("pause", default: false)
        DispatchQueue.main.async { self.paused = state }
    }
}

// MARK: - Icons

/// One tinted tile per row, the way System Settings labels its own sidebar.
///
/// This replaces the modules' bundled bitmap icons: they were flat monochrome
/// PNGs of varying weight drawn at whatever size they happened to be, so the
/// column never lined up and nothing distinguished one row from the next but
/// the word beside it. SF Symbols are vector, come in matching weights, follow
/// the system font metrics, and pick up the colour per module -- which is what
/// makes a ten-row sidebar scannable.
struct Glyph {
    let symbol: String
    let color: Color

    /// The first symbol the running system actually has. SF Symbol names come
    /// and go between releases, so a missing one would otherwise render as a
    /// blank tile.
    private static func available(_ names: [String]) -> String {
        for name in names where NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
            return name
        }
        return "circle.grid.2x2"
    }

    static func named(_ id: String) -> Glyph {
        switch id {
        case "Dashboard":
            return Glyph(symbol: available(["square.grid.2x2.fill"]), color: .indigo)
        case "Settings":
            return Glyph(symbol: available(["gearshape.fill"]), color: .gray)
        case "CPU":
            return Glyph(symbol: available(["cpu.fill", "cpu"]), color: .blue)
        case "GPU":
            return Glyph(symbol: available(["display", "tv"]), color: .purple)
        case "RAM":
            return Glyph(symbol: available(["memorychip.fill", "memorychip"]), color: .green)
        case "Disk":
            return Glyph(symbol: available(["internaldrive.fill", "internaldrive"]), color: .orange)
        case "Sensors":
            return Glyph(symbol: available(["thermometer.medium", "thermometer"]), color: .red)
        case "Network":
            return Glyph(symbol: available(["network"]), color: .teal)
        default:
            return Glyph(symbol: available(["circle.grid.2x2.fill"]), color: .secondary)
        }
    }
}

private struct GlyphTile: View {
    let glyph: Glyph
    var size: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(glyph.color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: glyph.symbol)
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - Hosting an AppKit view

/// Puts a module's existing NSView in the detail pane. The view is swapped
/// rather than rebuilt, because modules keep their settings views alive and
/// expect to hand back the same instance.
private struct HostedView: NSViewRepresentable {
    let view: NSView?

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let current = container.subviews.first
        guard current !== view else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        guard let view else { return }

        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

// MARK: - Glass

/// The window's ground: Liquid Glass where the system has it, vibrancy
/// everywhere else.
///
/// The window itself has to be non-opaque for either to show -- a titled
/// window composites over solid black by default, which is what made the
/// popups look like flat panels before the same fix.
private struct GlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 0
            glass.contentView = NSView()
            return glass
        }
        let effect = NSVisualEffectView()
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        return effect
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

// MARK: - Shell

struct SettingsShellView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 216, max: 280)
        } detail: {
            HostedView(view: model.detail)
                .frame(minWidth: 520, minHeight: 420)
                .background(GlassBackdrop().ignoresSafeArea())
                .toolbar { toolbarItems }
        }
        .navigationTitle(model.selectedModule.map { localized($0.moduleName) }
                         ?? localized(model.selection))
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: selectionBinding) {
                Section {
                    row(model.dashboard)
                    row(model.appSettings)
                }
                Section(localized("Modules")) {
                    ForEach(model.filteredModules) { item in
                        row(item)
                    }
                }
            }
            .listStyle(.sidebar)
            // Ten modules is enough that typing beats hunting.
            .searchable(text: $model.search,
                        placement: .sidebar,
                        prompt: localized("Search"))

            Divider()
            actionBar
        }
    }

    /// Selecting a row posts the notification; the window answers by setting
    /// `detail`, which is what actually moves the selection.
    private var selectionBinding: Binding<String?> {
        Binding(get: { model.selection },
                set: { if let id = $0, id != model.selection { model.select(id) } })
    }

    private func row(_ item: SettingsModel.Item) -> some View {
        HStack(spacing: 9) {
            GlyphTile(glyph: .named(item.id))
            Text(item.title)
                .lineLimit(1)
            if item.isModule {
                Spacer(minLength: 4)
                // Enabling a module no longer means selecting it first.
                Toggle("", isOn: Binding(
                    get: { model.moduleStates[item.id] ?? false },
                    set: { model.setEnabled(item.id, $0) }))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .help(localized("Toggle the module"))
            }
        }
        .padding(.vertical, 3)
        .tag(item.id)
    }

    /// Five identical grey glyphs in a row told you nothing about which one
    /// quits the app and which one asks for money. Now the donation carries a
    /// word, the destructive action goes red under the pointer, pausing reads
    /// as a state rather than a button, and every one of them has a hit area
    /// you can see before you click it.
    private var actionBar: some View {
        HStack(spacing: 4) {
            if AppLinks.donationURL != nil {
                FooterButton(symbol: "heart.fill",
                             label: localized("Support"),
                             help: localized("Support the application"),
                             tint: .pink) {
                    if let url = AppLinks.donationURL { NSWorkspace.shared.open(url) }
                }
            }

            Spacer(minLength: 0)

            FooterButton(symbol: "ant.fill",
                         help: localized("Report a bug")) {
                if let url = AppLinks.issuesURL { NSWorkspace.shared.open(url) }
            }
            FooterButton(symbol: model.paused ? "play.fill" : "pause.fill",
                         help: localized("Pause the Perch"),
                         tint: model.paused ? .orange : nil,
                         isOn: model.paused) {
                model.togglePause()
            }
            FooterButton(symbol: "power",
                         help: localized("Close application"),
                         hoverTint: .red) {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if let module = model.selectedModule, module.hasPreview {
                // An icon, not the word "Preview": it sits beside the enable
                // switch, and a toolbar full of prose reads as a form.
                Button {
                    model.togglePreview()
                } label: {
                    Image(systemName: "eye")
                }
                .help(localized("Preview"))
            }
        }
        ToolbarItem(placement: .primaryAction) {
            if let module = model.selectedModule {
                Toggle(localized("Toggle the module"), isOn: Binding(
                    get: { model.moduleStates[module.moduleName] ?? false },
                    set: { model.setEnabled(module.moduleName, $0) }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .help(localized("Toggle the module"))
            }
        }
    }
}

// MARK: - Footer button

/// A footer action with a visible hit area, hover feedback and an optional
/// label. The old row had none of the three: bare 33pt images with a tracking
/// area that set no state.
private struct FooterButton: View {
    let symbol: String
    var label: String?
    let help: String
    /// Resting colour, for an action worth spotting (the heart).
    var tint: Color?
    /// Colour under the pointer, for an action worth hesitating over (quit).
    var hoverTint: Color?
    /// Draws the button as engaged, for pause.
    var isOn: Bool = false
    let action: () -> Void

    @State private var hovering = false

    private var foreground: Color {
        if hovering, let hoverTint { return hoverTint }
        if let tint { return tint }
        return hovering ? .primary : .secondary
    }

    private var background: Color {
        if isOn { return (tint ?? .accentColor).opacity(0.18) }
        return hovering ? Color.primary.opacity(0.08) : .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                if let label {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        // Refuses to be compressed by its siblings. "Support"
                        // fits the sidebar; "Поддержать" does not, and without
                        // this it arrives as "Поддерж…" -- a truncation that
                        // only appears in a language nobody here reads.
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, label == nil ? 7 : 9)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(background)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
