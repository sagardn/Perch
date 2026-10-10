import Foundation
import SystemConfiguration
import CoreWLAN
import Darwin

/// Connection details for the network submenu.
enum NetworkInfo {

    struct Details {
        var primaryInterface: String?
        var router: String?
        var dns: [String] = []
        var localIP: String?
        var wifiInterface: String?
        var ssid: String?
        var ssidBlocked = false      // nil because of permission, not absence
        var rssi: Int?
        var txRate: Double?
        var channel: Int?
        var macAddress: String?
    }

    static func current() -> Details {
        var details = Details()

        if let store = SCDynamicStoreCreate(nil, "perch" as CFString, nil, nil),
           let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString)
                        as? [String: Any] {
            details.primaryInterface = global["PrimaryInterface"] as? String
            details.router = global["Router"] as? String
            if let service = global["PrimaryService"] as? String,
               let dns = SCDynamicStoreCopyValue(
                    store, "State:/Network/Service/\(service)/DNS" as CFString) as? [String: Any],
               let servers = dns["ServerAddresses"] as? [String] {
                details.dns = servers
            }
        }

        details.localIP = ipv4(for: details.primaryInterface ?? "en0") ?? ipv4(for: "en0")

        // Wi-Fi radio details. ssid() returns nil without Location permission
        // on macOS 14+, which is indistinguishable from "not on Wi-Fi" unless
        // we check whether the radio is actually up.
        if let wifi = CWWiFiClient.shared().interface() {
            details.wifiInterface = wifi.interfaceName
            details.macAddress = wifi.hardwareAddress()
            details.rssi = wifi.rssiValue() == 0 ? nil : wifi.rssiValue()
            details.txRate = wifi.transmitRate() == 0 ? nil : wifi.transmitRate()
            details.channel = wifi.wlanChannel()?.channelNumber
            details.ssid = wifi.ssid()
            details.ssidBlocked = (details.ssid == nil && wifi.powerOn())
        }
        return details
    }

    /// Signal strength in words; dBm alone means little to most people.
    static func signalQuality(_ rssi: Int) -> String {
        switch rssi {
        case (-50)...:    return "excellent"
        case (-60)..<(-50): return "good"
        case (-70)..<(-60): return "fair"
        default:          return "weak"
        }
    }

    /// How full to draw the Wi-Fi glyph's arcs, for `NSImage(systemSymbolName:
    /// variableValue:)`. Steps rather than a continuous ramp so the glyph
    /// agrees with `signalQuality`: the symbol has three arcs, and a reading
    /// called "fair" must never draw the same as one called "good".
    static func signalLevel(_ rssi: Int) -> Double {
        switch signalQuality(rssi) {
        case "excellent": return 1
        case "good":      return 0.67
        case "fair":      return 0.34
        default:          return 0.01   // the dot alone, never an empty glyph
        }
    }

    /// The one-word state the Network popup leads with.
    enum Health: Equatable {
        /// The link is up and no probe has answered or failed yet. Without
        /// it, the first second after launch claimed "No internet".
        case checking
        case online
        /// Up, but the probe got no answer: captive portal, dead router.
        case noInternet
        case offline
    }

    static func health(isUp: Bool, isReachable: Bool, probed: Bool) -> Health {
        guard isUp else { return .offline }
        guard probed else { return .checking }
        return isReachable ? .online : .noInternet
    }

    private static func ipv4(for interface: String) -> String? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return nil }
        defer { freeifaddrs(head) }

        var pointer = head
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            guard String(cString: current.pointee.ifa_name) == interface,
                  let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host,
                              socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            return String(cString: host)
        }
        return nil
    }

    // MARK: - Public IP

    private(set) static var publicIP: String?
    private static var fetching = false

    /// Deliberately on demand, never automatic: finding the public IP means
    /// contacting an outside server, and that should be the user's choice
    /// rather than something the menu does quietly in the background.
    static func lookUpPublicIP(completion: @escaping (String?) -> Void) {
        if let publicIP { completion(publicIP); return }
        // echoip (github.com/mpolden/echoip): MIT, self-hostable, and not the
        // upstream endpoint this fork was cut from.
        guard !fetching, let url = URL(string: "https://ifconfig.co/ip") else { return }
        fetching = true

        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        URLSession.shared.dataTask(with: request) { data, _, _ in
            fetching = false
            let text = data.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            publicIP = text
            DispatchQueue.main.async { completion(text) }
        }.resume()
    }
}
