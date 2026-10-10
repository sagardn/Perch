import AppKit

/// The Network popup: a one-line verdict, the rates and their history, then
/// the connection's detail and the processes using the link.
///
/// Ordered by how often each part is the reason the popup was opened. "Am I
/// online" first, as a sentence rather than two UP pills and a latency row
/// spread down the page; the hardware detail last, folded away, since a MAC
/// address is looked up once and then never again.
///
/// All of it reads from `NetworkMonitor`, `NetworkInfo` and `ProcessNetwork`,
/// which between them touch nothing but public APIs and `nettop`.
final class NetworkModule: PopupContent {

    let title = "Network"

    // Rows held so a refresh can set their text rather than rebuild the view.
    private let status = StatusLine()
    private let downloadReading = BigReading(caption: localized("Download"), symbol: "arrow.down",
                                             tint: .systemIndigo)
    private let uploadReading = BigReading(caption: localized("Upload"), symbol: "arrow.up",
                                           tint: .perchAmber)
    private let chart = SplitTrafficChart()
    private let peaks = PeakLegend()
    private let reachability = ValueRow(localized("Probes answered"))
    private let strip = ReachabilityStrip()

    private let latency = ValueRow(localized("Latency · jitter"))
    private let signal = SignalRow()
    // Only shown when the name is missing for want of Location permission:
    // otherwise the status line already says it, and a row repeating it is
    // the duplication this layout was made to remove.
    private let ssidBlocked = ValueRow(localized("Wi-Fi name"))
    private let localIP = ValueRow(localized("Local IP"))
    private let interfaceName = ValueRow(localized("Interface"))
    // Since launch, which is what the counter measures: the baseline is
    // taken on the first sample and nothing resets it. "Total" alone did
    // not say since when.
    private let sinceLaunch = ValueRow(localized("Sent · received since launch"))

    private let processRows = (0..<8).map { _ in ProcessRow() }

    private let detailsToggle = DisclosureButton(key: "Network_popupDetails")
    private let macAddress = ValueRow(localized("Physical address"))
    private let router = ValueRow(localized("Router"))
    private let dns = ValueRow(localized("DNS"))
    private let channel = ValueRow(localized("Channel · link rate"))
    private var detailRows: [NSView] { [macAddress, router, dns, channel] }

    /// Ticks since the popup opened, used to throttle the two expensive jobs
    /// away from the one-second refresh.
    private var ticks = 0
    private var cachedDetails = NetworkInfo.Details()

    /// The tile, once something has asked for it.
    private var tile: NetworkTile?

    /// The link changes this module is watching, if any are switched on.
    private let alerts = NetworkAlerts()

    /// Ticks the menu bar reading has taken. Separate from `ticks`, which
    /// only moves while the popup is open -- the alerts have to keep working
    /// when it is shut, which is when a link is most likely to change.
    private var samples = 0

    // MARK: - PopupContent

    func makeView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(status)
        stack.setCustomSpacing(12, after: status)

        // Upload first, as everywhere else: the menu bar, the chart and the
        // totals all lead with it.
        let headline = headlinePair(uploadReading, downloadReading)
        stack.addArrangedSubview(headline)
        stack.setCustomSpacing(12, after: headline)

        stack.addArrangedSubview(chart)
        stack.setCustomSpacing(4, after: chart)
        stack.addArrangedSubview(peaks)
        stack.setCustomSpacing(10, after: peaks)

        stack.addArrangedSubview(reachability)
        stack.setCustomSpacing(4, after: reachability)
        stack.addArrangedSubview(strip)
        stack.setCustomSpacing(14, after: strip)

        stack.addArrangedSubview(SectionHeader(localized("Connection")))
        for row in [latency, signal, ssidBlocked, localIP, interfaceName, sinceLaunch] {
            stack.addArrangedSubview(row)
        }

        stack.addArrangedSubview(SectionHeader(localized("Top processes")))
        stack.addArrangedSubview(ProcessHeader())
        for row in processRows {
            row.isHidden = true
            stack.addArrangedSubview(row)
        }

        detailsToggle.install(in: stack, rows: detailRows)
        // The channel row has a condition of its own -- it means nothing off
        // Wi-Fi -- which the fold showing every row would override.
        detailsToggle.onToggle = { [weak self] _ in
            guard let self else { return }
            self.refreshInterface(NetworkMonitor.shared)
        }

        return stack
    }

    func willShow() {
        ticks = 0
        cachedDetails = NetworkInfo.current()
        NetworkMonitor.shared.probe()
    }

    func didHide() {
        // Otherwise a reopen would report a rate averaged over the minutes
        // the popup spent shut.
        ProcessNetwork.reset()
    }

    /// The rates, the traffic chart, and the name. Not the six that measure
    /// a share of something: a link has no percentage to be at -- the rate it
    /// is carrying is not a fraction of anything the machine can know, since
    /// nothing reports what the link could carry.
    var defaultMenuBarStyles: [MenuBarStyle] { [.rates] }
    var menuBarStyles: [MenuBarStyle] { [.label, .rates, .trafficChart] }

    /// The tile, built once.
    func makeTile() -> NetworkTile {
        if let tile { return tile }
        let made = NetworkTile()
        made.update(NetworkMonitor.shared, interface: cachedDetails.primaryInterface)
        tile = made
        return made
    }

    func willStop() { alerts.withdrawAll() }

    func menuBarContent() -> MenuBarReading? {
        // Sampling lives here so the rates keep moving with the popup shut.
        let monitor = NetworkMonitor.shared
        monitor.sample()
        samples += 1

        // The link's own details are an SCDynamicStore read and, on Wi-Fi, a
        // CoreWLAN one. Every fifteen seconds with the popup shut is enough
        // to notice a change; the popup refreshes them faster while it is up.
        if samples % 15 == 1 { cachedDetails = NetworkInfo.current() }
        alerts.check(link: monitor.link, details: cachedDetails)

        if let tile, tile.window?.isVisible == true {
            tile.update(monitor, interface: monitor.link.interface
                                 ?? cachedDetails.primaryInterface)
        }

        return MenuBarReading(
            label: "NET",
            value: Readings.rate(monitor.rates.download),
            rates: speedTinted(monitor.rates),
            mirrored: .init(up: monitor.uploadHistory, down: monitor.downloadHistory))
    }

    /// Upload and download, brighter the faster each goes.
    private func speedTinted(_ rates: NetworkMonitor.Rates) -> MenuBarReading.Pair {
        var pair = MenuBarReading.Pair(Readings.rate(rates.upload),
                                       Readings.rate(rates.download))
        pair.speeds = .init(upload: rates.upload, download: rates.download)
        return pair
    }

    func refresh() {
        let monitor = NetworkMonitor.shared
        ticks += 1

        // Networked, so far less often than the tick.
        if ticks % 5 == 0 { monitor.probe() }
        // Spawns nettop, which costs ~0.43s of wall time and a fifth of a
        // core each run. Every four seconds, not every two.
        if ticks % 4 == 0 { refreshProcesses() }
        // SCDynamicStore and CoreWLAN are not free either.
        if ticks % 5 == 1 { cachedDetails = NetworkInfo.current() }

        downloadReading.set(bytesPerSecond: monitor.rates.download)
        uploadReading.set(bytesPerSecond: monitor.rates.upload)

        chart.upper = monitor.uploadHistory
        chart.lower = monitor.downloadHistory
        peaks.set(upper: monitor.uploadHistory.max() ?? 0,
                  lower: monitor.downloadHistory.max() ?? 0)

        let probes = monitor.connectivityHistory
        strip.results = probes
        reachability.value = probes.isEmpty
            ? "—" : "\(probes.filter { $0 }.count) of \(probes.count)"

        latency.value = monitor.latency.map { latency in
            let jitter = monitor.jitter.map { String(format: " · %.1f ms", $0) } ?? ""
            return String(format: "%.0f ms", latency) + jitter
        } ?? "—"
        sinceLaunch.value = "↑ \(Readings.bytes(monitor.sessionUpload))"
            + "   ↓ \(Readings.bytes(monitor.sessionDownload))"

        refreshInterface(monitor)
    }

    // MARK: - Sections

    private func refreshInterface(_ monitor: NetworkMonitor) {
        let details = cachedDetails
        let name = monitor.link.interface ?? details.primaryInterface ?? "—"

        let onWiFi = details.wifiInterface == name && details.rssi != nil
        signal.isHidden = !onWiFi
        ssidBlocked.isHidden = !(onWiFi && details.ssid == nil && details.ssidBlocked)
        // ssid() returns nil without Location permission, which is
        // indistinguishable from "not on Wi-Fi" unless the radio is known to
        // be up -- NetworkInfo already made that call.
        ssidBlocked.value = "Hidden — allow Location"

        let medium: String
        if onWiFi, let rssi = details.rssi {
            interfaceName.value = "Wi-Fi (\(name))"
            signal.set(rssi: rssi)
            medium = details.ssid.map { "Wi-Fi “\($0)”" } ?? "Wi-Fi"
        } else {
            interfaceName.value = name
            // Any other physical en* is a cable: NetworkMonitor only picks
            // physical interfaces, and Wi-Fi was ruled out above.
            medium = name.hasPrefix("en") ? "Ethernet" : name
        }

        let health = NetworkInfo.health(isUp: monitor.link.isUp,
                                        isReachable: monitor.link.isReachable,
                                        probed: !monitor.connectivityHistory.isEmpty)
        setStatus(health, medium: medium, latency: monitor.latency)

        macAddress.value = details.macAddress ?? "—"
        localIP.value = details.localIP ?? "—"
        router.value = details.router ?? "—"
        dns.value = details.dns.isEmpty ? "—" : details.dns.prefix(2).joined(separator: ", ")
        channel.isHidden = !onWiFi || !detailsToggle.isOpen
        channel.value = [details.channel.map { "\($0)" },
                         details.txRate.map { String(format: "%.0f Mbps", $0) }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func setStatus(_ health: NetworkInfo.Health, medium: String, latency: Double?) {
        switch health {
        case .checking:
            status.set("Checking…", tint: .tertiaryLabelColor, details: [medium])
        case .online:
            status.set("Online", tint: .perchCalm,
                       details: [medium] + [latency.map { String(format: "%.0f ms", $0) }]
                           .compactMap { $0 })
        case .noInternet:
            status.set("No internet", tint: .perchWarning, details: [medium])
        case .offline:
            // No medium: the interface it last used is not necessarily the
            // one it will come back on.
            status.set("Offline", tint: .perchCritical, details: [])
        }
    }

    private func refreshProcesses() {
        let wanted = min(NetworkSettings.processCount, processRows.count)
        guard wanted > 0 else {
            processRows.forEach { $0.isHidden = true }
            return
        }
        ProcessNetwork.top(wanted) { [weak self] entries in
            guard let self else { return }
            for (index, row) in self.processRows.enumerated() {
                if index < entries.count {
                    row.set(entries[index])
                    row.isHidden = false
                } else {
                    row.isHidden = true
                }
            }
        }
    }
}

// MARK: - Reachability strip

/// One thin bar, a slot per probe, newest at the right.
///
/// Replaces a three-row grid of squares that reserved its full height from
/// the first probe: three answers drew as three dots above a blank band. A
/// single strip sized for the whole history is the same information in a
/// sixth of the height, and an unfilled track says "not probed yet" rather
/// than leaving empty space to be read as nothing at all.
private final class ReachabilityStrip: NSView {

    var results: [Bool] = [] { didSet { needsDisplay = true } }

    /// Matches `NetworkMonitor.connectivityLimit`, so a full history fills
    /// the strip exactly.
    private let slots = 120

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PopupMetrics.contentWidth),
            heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3)
        NSColor.labelColor.withAlphaComponent(0.08).setFill()
        track.fill()

        NSGraphicsContext.saveGraphicsState()
        track.addClip()
        let width = bounds.width / CGFloat(slots)
        let shown = results.suffix(slots)
        let start = slots - shown.count
        for (offset, ok) in shown.enumerated() {
            // A hair of overlap, so neighbouring slots of one colour join
            // into a solid run instead of a comb of antialiased seams.
            let rect = NSRect(x: CGFloat(start + offset) * width, y: 0,
                              width: width + 0.5, height: bounds.height)
            (ok ? NSColor.perchCalm : NSColor.perchCritical).setFill()
            rect.fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

// MARK: - Signal row

/// The Wi-Fi glyph filled to the signal, then the word and the dBm.
private final class SignalRow: NSView {

    private let glyph = NSImageView()
    private let value = NSTextField(labelWithString: "—")

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: localized("Signal"))
        name.font = .systemFont(ofSize: 11)
        name.textColor = .secondaryLabelColor
        name.translatesAutoresizingMaskIntoConstraints = false

        value.font = .systemFont(ofSize: 11, weight: .medium)
        value.alignment = .right
        value.translatesAutoresizingMaskIntoConstraints = false

        glyph.symbolConfiguration = .init(pointSize: 11, weight: .semibold)
        glyph.translatesAutoresizingMaskIntoConstraints = false

        for view in [name, glyph, value] { addSubview(view) }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: PopupMetrics.contentWidth),
            heightAnchor.constraint(equalToConstant: 18),
            name.leadingAnchor.constraint(equalTo: leadingAnchor),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
            value.trailingAnchor.constraint(equalTo: trailingAnchor),
            value.centerYAnchor.constraint(equalTo: centerYAnchor),
            glyph.trailingAnchor.constraint(equalTo: value.leadingAnchor, constant: -5),
            glyph.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func set(rssi: Int) {
        let quality = NetworkInfo.signalQuality(rssi)
        glyph.image = NSImage(systemSymbolName: "wifi",
                              variableValue: NetworkInfo.signalLevel(rssi),
                              accessibilityDescription: "\(quality) signal")
        // Only a weak signal earns a colour: it is the one reading here that
        // explains a slow connection, and tinting the good ones too would
        // make the warning just another colour on the page.
        glyph.contentTintColor = quality == "weak" ? .perchWarning : .secondaryLabelColor
        value.stringValue = "\(quality.capitalized)  \(rssi) dBm"
    }
}
