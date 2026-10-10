import Foundation

/// What an application has left around the system.
///
/// The removal is the easy part; the matching is where an uninstaller does
/// harm. "Delete everything with the app's name in it" is how a tool removes
/// `~/Library/Application Support/Notes` because somebody dragged in an app
/// called Notes, and the damage is not noticed until the data is wanted.
///
/// So matching is by **bundle identifier** wherever possible, which is unique
/// by construction, and anything matched more loosely is reported at lower
/// confidence and left unticked. The person decides; the app never guesses on
/// their behalf.
enum AppLeftovers {

    /// How sure we are that a file belongs to the app being removed.
    enum Confidence: Int, Comparable {
        /// The identifier, exactly: `com.maker.thing` or
        /// `com.maker.thing.plist`. Nothing else can own this.
        case certain = 2
        /// A child identifier -- `com.maker.thing.helper` -- which belongs to
        /// the same app in every scheme anybody uses, but is a guess.
        case likely = 1
        /// The app's *name*. `Application Support/Notes` may be the app's, or
        /// may be a folder somebody made. Never ticked by default.
        case possible = 0

        static func < (a: Confidence, b: Confidence) -> Bool { a.rawValue < b.rawValue }
    }

    struct Item: Equatable {
        let url: URL
        let bytes: Int64
        let confidence: Confidence

        var name: String { url.lastPathComponent }
    }

    /// The directories an app scatters itself across.
    ///
    /// `Saved Application State` and `Cookies` are absent because macOS does
    /// not let an app read them without Full Disk Access -- they would always
    /// come back empty and look like the app had left nothing there.
    static func searchRoots(home: URL) -> [URL] {
        ["Library/Application Support", "Library/Caches", "Library/Preferences",
         "Library/Containers", "Library/Group Containers", "Library/Logs",
         "Library/HTTPStorages", "Library/WebKit", "Library/LaunchAgents",
         "Library/Application Scripts"].map { home.appendingPathComponent($0) }
    }

    /// Whether `filename` belongs to the app, and how sure that is.
    ///
    /// nil means no -- and no is the common answer, which is the point. A
    /// `~/Library/Preferences` holds seven hundred files and an uninstaller
    /// that matches loosely will find a dozen of them for any app you name.
    /// Suffixes that are a file type rather than part of an identifier.
    ///
    /// Only these are stripped before matching, and the reason is sharp:
    /// `deletingPathExtension` on `com.maker.thing.helper` removes `.helper`,
    /// leaving `com.maker.thing` -- so a helper's data was being matched as
    /// *certain* and ticked without anybody choosing it. The last dotted
    /// component of a bundle identifier is a sub-identifier, not an
    /// extension, and nothing in Foundation can tell them apart.
    static let fileSuffixes: Set<String> = [
        "plist", "savedstate", "log", "lock", "db", "sqlite", "sqlite3",
        "json", "sfl2", "sfl3", "binarycookies", "asl", "crash", "ips",
    ]

    private static func stripSuffix(_ filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        guard fileSuffixes.contains(ext) else { return filename }
        return (filename as NSString).deletingPathExtension
    }

    static func match(filename: String, bundleID: String, appName: String) -> Confidence? {
        let base = stripSuffix(filename)

        guard !bundleID.isEmpty else { return nameOnly(base: base, appName: appName) }

        // com.maker.thing, com.maker.thing.plist, com.maker.thing.savedState
        if base == bundleID || filename == bundleID { return .certain }

        // com.maker.thing.helper -- a child of the identifier, not merely a
        // string starting with it. The dot is what makes
        // "com.maker.thingelse" not a match.
        if base.hasPrefix(bundleID + ".") { return .likely }

        return nameOnly(base: base, appName: appName)
    }

    /// The last resort, and the one that is never ticked by default.
    private static func nameOnly(base: String, appName: String) -> Confidence? {
        guard !appName.isEmpty else { return nil }
        // Exact, case-insensitive, whole name. Not "contains": an app called
        // "Mail" would otherwise match every folder with mail in its name.
        return base.compare(appName, options: .caseInsensitive) == .orderedSame
            ? .possible : nil
    }

    /// Whether this item should be ticked when the list first appears.
    ///
    /// Only what is certainly the app's. Everything else is shown, with its
    /// confidence, for somebody to decide about.
    static func isTickedByDefault(_ item: Item) -> Bool { item.confidence == .certain }
}

// MARK: - Finding them

extension AppLeftovers {

    /// Everything on disk that looks like it belongs to this app.
    ///
    /// Shallow: only the immediate children of each search root. An app's
    /// leftovers sit at the top of `Application Support` or `Preferences`,
    /// and descending turns a quick answer into a walk of several hundred
    /// thousand files for nothing.
    ///
    /// Blocking; call it off the main thread.
    static func find(bundleID: String, appName: String,
                     home: URL = FileManager.default.homeDirectoryForCurrentUser,
                     includingBundle bundle: URL? = nil) -> [Item] {
        let fm = FileManager.default
        var found: [Item] = []

        if let bundle, fm.fileExists(atPath: bundle.path) {
            found.append(Item(url: bundle,
                              bytes: size(of: bundle, fm: fm),
                              confidence: .certain))
        }

        for root in searchRoots(home: home) {
            guard let names = try? fm.contentsOfDirectory(atPath: root.path) else { continue }
            for name in names {
                guard let confidence = match(filename: name, bundleID: bundleID,
                                             appName: appName) else { continue }
                let url = root.appendingPathComponent(name)
                found.append(Item(url: url, bytes: size(of: url, fm: fm),
                                  confidence: confidence))
            }
        }

        // Most certain first, then biggest: the rows somebody acts on without
        // reading are the ones at the top, so the safest are put there.
        return found.sorted {
            $0.confidence != $1.confidence ? $0.confidence > $1.confidence
                                           : $0.bytes > $1.bytes
        }
    }

    private static func size(of url: URL, fm: FileManager) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey,
                                                       .totalFileAllocatedSizeKey])
        if values?.isDirectory != true {
            return Int64(values?.totalFileAllocatedSize ?? 0)
        }
        guard let walk = fm.enumerator(at: url,
                                       includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
                                       options: [], errorHandler: { _, _ in true })
        else { return 0 }
        var total: Int64 = 0
        for case let child as URL in walk {
            total += Int64((try? child.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        return total
    }

    /// Moves the chosen leftovers to the Bin.
    ///
    /// The same `trashItem` the large-files list uses, and for the same
    /// reason: an uninstaller that is wrong about one folder should cost
    /// somebody a trip to Finder, not their data.
    static func moveToBin(_ items: [Item]) -> LargeFiles.Removal {
        LargeFiles.moveToBin(items.map { LargeFiles.Item(url: $0.url, bytes: $0.bytes) })
    }
}
