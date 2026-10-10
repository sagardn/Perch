import AppKit
import IOKit
import Metal
import UniformTypeIdentifiers

/// What this Mac is: the facts that do not change while Perch runs.
///
/// Read once and cached, because every one of them is a `sysctl`, an IOKit
/// registry walk or a disk query, and none of them can change without a
/// reboot — except uptime, which is computed from the boot time rather than
/// stored.
///
/// Written against public APIs: `sysctlbyname` for the processor and memory,
/// `IOPlatformExpertDevice` for the model and serial, `NSScreen` for the
/// display, `URLResourceValues` for the volume, `MTLCreateSystemDefaultDevice`
/// for the GPU. Nothing here is private and nothing needs a permission.
enum DeviceInfo {

    // MARK: - Model

    struct Model {
        /// The marketing name, when macOS knows one: "MacBook Air 13\" (M2)".
        let name: String
        /// The hardware identifier: "Mac14,2".
        let identifier: String
        /// Four-digit year, when it can be determined.
        let year: Int?
        let icon: NSImage?
    }

    static let model: Model = {
        let identifier = platformString("model") ?? "Unknown"
        let name = marketingName() ?? identifier
        // Apple puts the year in the marketing name for older Macs; Apple
        // Silicon names carry the chip instead, so a missing year is normal
        // and shown as Unknown rather than guessed at.
        let year = name.range(of: #"\b20\d{2}\b"#, options: .regularExpression)
            .flatMap { Int(name[$0]) }
        return Model(name: name, identifier: identifier, year: year, icon: modelIcon())
    }()

    /// The readable name: "MacBook Air (M2, 2022)".
    ///
    /// Published in the device tree at `IODeviceTree:/product`, not on
    /// IOPlatformExpertDevice, which carries only the identifier. Falling back
    /// to the identifier would show a user "Mac14,2" where they expect the
    /// name of their Mac.
    private static func marketingName() -> String? {
        let name = entryString("IODeviceTree:/product", "product-name")
        return (name?.isEmpty ?? true) ? nil : name
    }

    /// A string property on a device-tree entry addressed by path.
    private static func entryString(_ path: String, _ key: String) -> String? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, path)
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        guard let raw = IORegistryEntryCreateCFProperty(entry, key as CFString,
                                                        kCFAllocatorDefault, 0)?
                .takeRetainedValue() else { return nil }
        if let data = raw as? Data {
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        }
        return raw as? String
    }

    /// The picture of this Mac that Finder and About This Mac show.
    ///
    /// macOS ships them in CoreTypes.bundle, named after the model --
    /// `com.apple.macbookair-13-2022-midnight.icns`. There is no public call
    /// that maps a model identifier to one, so the marketing name is matched
    /// against the file names: "MacBook Air (M2, 2022)" yields `macbookair`
    /// and `2022`, which together pick the right family and year. The colour
    /// is not determined -- several files differ only by it and any of them
    /// shows the right machine. A generic Mac icon is the fallback, which is
    /// what an unrecognised model gets rather than nothing.
    private static func modelIcon() -> NSImage? {
        let resources = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources"
        let name = (marketingName() ?? "").lowercased()
        let words = name.components(separatedBy: CharacterSet.alphanumerics.inverted)
                        .filter { !$0.isEmpty }
        // The family is the words before the first bracket -- "macbook air"
        // becomes "macbookair" -- and the year is the only other part of the
        // name that appears in the file names. The chip ("m2") does not, which
        // is why requiring every word matched nothing.
        let family = words.prefix(while: { Int($0) == nil && $0.count > 1 && !$0.hasPrefix("m") || $0 == "macbook" })
                          .joined()
        let year = words.first { $0.count == 4 && Int($0) != nil }

        if !family.isEmpty,
           let files = try? FileManager.default.contentsOfDirectory(atPath: resources) {
            let candidates = files.filter { file in
                let lower = file.lowercased()
                guard lower.hasSuffix(".icns"), lower.contains(family) else { return false }
                return year.map { lower.contains($0) } ?? true
            }
            if let best = candidates.sorted().first,
               let image = NSImage(contentsOfFile: "\(resources)/\(best)") {
                return image
            }
        }
        guard let type = UTType("com.apple.mac") else { return nil }
        let generic = NSWorkspace.shared.icon(for: type)
        return generic.size.width > 0 ? generic : nil
    }

    /// A string property from the platform expert — model, serial, and the
    /// product name on Apple Silicon.
    private static func platformString(_ key: String) -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let raw = IORegistryEntryCreateCFProperty(service, key as CFString,
                                                        kCFAllocatorDefault, 0)?
                .takeRetainedValue() else { return nil }
        if let data = raw as? Data {
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        }
        return raw as? String
    }

    static let serialNumber: String? = platformString("IOPlatformSerialNumber")

    // MARK: - Operating system

    struct OS {
        let name: String
        let version: String
        let build: String
    }

    static let os: OS = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return OS(name: macOSName(v.majorVersion),
                  version: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
                  build: platformBuild() ?? "")
    }()

    private static func macOSName(_ major: Int) -> String {
        switch major {
        case 26...: return "macOS Tahoe"
        case 15: return "macOS Sequoia"
        case 14: return "macOS Sonoma"
        case 13: return "macOS Ventura"
        default: return "macOS"
        }
    }

    private static func platformBuild() -> String? {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    // MARK: - Processor

    struct CPU {
        let name: String?
        let physicalCores: Int?
        let logicalCores: Int?
        /// Apple Silicon reports its cores split by kind.
        let efficiencyCores: Int?
        let performanceCores: Int?
    }

    static let cpu: CPU = CPU(
        name: sysctlString("machdep.cpu.brand_string"),
        physicalCores: sysctlInt("hw.physicalcpu"),
        logicalCores: sysctlInt("hw.logicalcpu"),
        efficiencyCores: sysctlInt("hw.perflevel1.physicalcpu"),
        performanceCores: sysctlInt("hw.perflevel0.physicalcpu")
    )

    // MARK: - Memory

    /// Total physical memory in bytes.
    static let memory: Int64 = Int64(ProcessInfo.processInfo.physicalMemory)

    // MARK: - Graphics

    /// The Metal device's name with its core count: "Apple M2 (8 cores)".
    ///
    /// The count is not on MTLDevice; it is `gpu-core-count` on the
    /// AGXAccelerator service, which exists only on Apple Silicon — an Intel
    /// Mac gets the name alone rather than a wrong number.
    static let gpu: String? = {
        guard let name = MTLCreateSystemDefaultDevice()?.name else { return nil }
        guard let cores = gpuCoreCount() else { return name }
        return "\(name) (\(cores) cores)"
    }()

    private static func gpuCoreCount() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("AGXAccelerator"),
                                           &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            if let count = IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString,
                                                           kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int {
                return count
            }
        }
        return nil
    }

    // MARK: - Storage

    struct Volume {
        let name: String
        let capacity: Int64
    }

    static let volumes: [Volume] = {
        // Root file systems only. "Internal" is also true of a mounted disk
        // image on an internal disk, which put a 2.5 GB scratch volume in the
        // list beside the boot drive.
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey,
                                      .volumeIsInternalKey, .volumeIsRootFileSystemKey]
        guard let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                                 options: [.skipHiddenVolumes])
        else { return [] }
        return mounted.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsInternal == true,
                  values.volumeIsRootFileSystem == true,
                  let name = values.volumeName,
                  let capacity = values.volumeTotalCapacity else { return nil }
            return Volume(name: name, capacity: Int64(capacity))
        }
    }()

    /// The physical storage device, as opposed to the volume on it.
    ///
    /// "Macintosh HD" is a volume; "APPLE SSD AP0256Z" is the drive. Neither
    /// the old pane nor the first version of this one showed the drive at all,
    /// is what "SSD information not showing" was about -- the row named the
    /// volume and stopped.
    ///
    /// Read from `Device Characteristics` on IOBlockStorageDevice. Mounted
    /// disk images show up there too and are filtered out: they are not
    /// hardware.
    struct Drive {
        let name: String
        /// "Solid State" or "Rotational".
        let medium: String
    }

    static let drives: [Drive] = {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOBlockStorageDevice"),
                                           &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var found: [Drive] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            guard let characteristics = IORegistryEntryCreateCFProperty(
                    service, "Device Characteristics" as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? [String: Any],
                  let product = (characteristics["Product Name"] as? String)?
                    .trimmingCharacters(in: .whitespaces),
                  !product.isEmpty,
                  // A mounted .dmg is an IOBlockStorageDevice with no medium.
                  let medium = characteristics["Medium Type"] as? String,
                  !medium.isEmpty
            else { continue }

            let vendor = (characteristics["Vendor Name"] as? String)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            let name = vendor.isEmpty || product.hasPrefix(vendor) ? product : "\(vendor) \(product)"
            found.append(Drive(name: name, medium: medium))
        }
        return found
    }()

    // MARK: - Display

    struct Display {
        let name: String
        let pixelWidth: Int
        let pixelHeight: Int
        let refreshHz: Int
        /// Diagonal in inches, from the panel's physical size.
        let inches: Int?
    }

    static var displays: [Display] {
        NSScreen.screens.map { screen in
            let frame = screen.frame
            let scale = screen.backingScaleFactor
            var inches: Int?
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                let mm = CGDisplayScreenSize(number)
                if mm.width > 0 && mm.height > 0 {
                    inches = Int((sqrt(mm.width * mm.width + mm.height * mm.height) / 25.4).rounded())
                }
            }
            return Display(name: screen.localizedName,
                           pixelWidth: Int(frame.width * scale),
                           pixelHeight: Int(frame.height * scale),
                           refreshHz: screen.maximumFramesPerSecond,
                           inches: inches)
        }
    }

    // MARK: - Uptime

    /// When the machine last booted, from `kern.boottime`.
    static let bootDate: Date? = {
        var timeval = timeval()
        var size = MemoryLayout<Foundation.timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &timeval, &size, nil, 0) == 0, timeval.tv_sec != 0 else { return nil }
        return Date(timeIntervalSince1970: Double(timeval.tv_sec))
    }()

    // MARK: - sysctl

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let value = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func sysctlInt(_ name: String) -> Int? {
        var value: Int = 0
        var size = MemoryLayout<Int>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0, value > 0 else { return nil }
        return value
    }
}

