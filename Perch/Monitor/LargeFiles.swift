import Foundation

/// Finding what is actually taking the space.
///
/// Perch shows things; Finder deletes them. This walks a few folders and
/// reports the biggest items in them, and every one of them opens in Finder
/// rather than being removed here.
///
/// That split is the whole design and it is not timidity. Deleting a user's
/// files is the one mistake that cannot be undone by fixing the bug
/// afterwards, and the folders worth scanning -- Downloads, Documents,
/// Desktop -- are exactly the ones macOS guards, so a delete button would
/// also mean asking a menu bar monitor for permission over somebody's whole
/// home directory. Showing needs the same permission for a moment; keeping
/// it, to delete with, is a different bargain.
enum LargeFiles {

    /// What kind of thing a file is, by extension.
    ///
    /// Extension and nothing else: reading each file to sniff its type would
    /// mean opening every one of a hundred thousand files to draw a list.
    /// The cost of being wrong is a video filed under Other, which is a
    /// cosmetic error in a list somebody is reading anyway.
    enum Category: String, CaseIterable {
        case video, audio, image, archive, installer, document, other

        var title: String {
            switch self {
            case .video:     return localized("Video")
            case .audio:     return localized("Audio")
            case .image:     return localized("Images")
            case .archive:   return localized("Archives")
            case .installer: return localized("Installers")
            case .document:  return localized("Documents")
            case .other:     return localized("Other")
            }
        }

        static let extensions: [Category: Set<String>] = [
            .video: ["mov", "mp4", "m4v", "avi", "mkv", "webm", "mpg", "mpeg",
                     "wmv", "flv", "hevc", "prores", "braw", "r3d"],
            .audio: ["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac", "ogg",
                     "opus", "alac", "logicx", "band", "caf"],
            .image: ["jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif",
                     "raw", "cr2", "cr3", "nef", "arw", "dng", "psd", "webp",
                     "svg", "bmp"],
            .archive: ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar",
                       "sit", "sitx", "zst"],
            // The one category with a reason to exist beyond sorting: an
            // installer in Downloads has already done its job, and these are
            // large. It is the closest thing to "junk" that is actually
            // true -- unlike a cache, nothing re-creates it and nothing
            // breaks without it.
            .installer: ["dmg", "pkg", "iso", "mpkg", "msi", "appx"],
            .document: ["pdf", "doc", "docx", "pages", "xls", "xlsx", "numbers",
                        "ppt", "pptx", "key", "epub", "txt", "rtf", "md"],
        ]

        static func of(_ url: URL) -> Category {
            let ext = url.pathExtension.lowercased()
            guard !ext.isEmpty else { return .other }
            for category in Category.allCases where category != .other {
                if extensions[category]?.contains(ext) == true { return category }
            }
            return .other
        }
    }

    struct Item: Equatable {
        let url: URL
        let bytes: Int64

        var name: String { url.lastPathComponent }
        var category: Category { Category.of(url) }
    }

    /// The `n` largest, biggest first.
    ///
    /// Separated from the walk so the ranking can be checked against a list
    /// written down. Ties keep the order they arrived in, which for a
    /// directory walk is alphabetical-ish and stable between runs -- a list
    /// that reshuffles two equal files on every scan looks broken.
    static func largest(_ items: [Item], limit: Int) -> [Item] {
        guard limit > 0 else { return [] }
        return Array(items.enumerated()
            .sorted { lhs, rhs in
                lhs.element.bytes != rhs.element.bytes
                    ? lhs.element.bytes > rhs.element.bytes
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
            .prefix(limit))
    }

    /// Whether to treat a directory as one item and stop descending.
    ///
    /// A `.app`, a `.photoslibrary` or an `.xcodeproj` is one thing to the
    /// person looking at it. Walking inside and reporting its twenty largest
    /// parts answers a question nobody asked and buries the real answer --
    /// which is that the bundle itself is large.
    static let opaqueExtensions: Set<String> = [
        "app", "photoslibrary", "musiclibrary", "tvlibrary", "imovielibrary",
        "fcpbundle", "logicx", "sparsebundle", "bundle", "framework",
        "xcodeproj", "xcworkspace", "rtfd", "download",
    ]

    static func isOpaque(_ url: URL) -> Bool {
        opaqueExtensions.contains(url.pathExtension.lowercased())
    }

    /// Whether to leave a path alone entirely.
    ///
    /// Not a judgement about what is junk -- there is no such judgement that
    /// survives a real disk. These are the places where a size is either
    /// meaningless or misleading: the snapshot mount macOS keeps, anything
    /// not on this volume, and the caches a report would invite somebody to
    /// delete when deleting them only makes the next hour slower.
    static func isSkipped(_ url: URL) -> Bool {
        let path = url.path
        if path.hasPrefix("/System/Volumes") { return true }
        if path.contains("/.Trash") { return true }
        if path.contains("/Library/Caches/") { return true }
        return false
    }

    /// The folders worth offering to look in.
    ///
    /// Each one is somewhere people actually accumulate large files. They are
    /// also each TCC-guarded, so the first scan prompts -- which is the
    /// honest shape: the person is asked about the folder they just asked to
    /// have searched.
    static func defaultRoots(home: URL) -> [URL] {
        ["Downloads", "Documents", "Desktop", "Movies", "Music", "Pictures"]
            .map { home.appendingPathComponent($0) }
    }
}

// MARK: - Walking the disk

extension LargeFiles {

    /// The biggest items under `roots`.
    ///
    /// Bounded by a deadline rather than trusting the walk to be quick: a
    /// Pictures folder can hold a hundred thousand files, and a scan that
    /// takes a minute on somebody else's Mac is a scan that looks hung. What
    /// it has found when time runs out is still the right answer for the part
    /// it reached, which is better than nothing and much better than a beach
    /// ball.
    ///
    /// Blocking, and meant to be called off the main thread.
    static func scan(roots: [URL], limit: Int = 20,
                     deadline: Date = Date().addingTimeInterval(8)) -> [Item] {
        let fm = FileManager.default
        var found: [Item] = []

        for root in roots {
            guard Date() < deadline else { break }
            guard !isSkipped(root) else { continue }

            // `skipsHiddenFiles` because a dotfile is not what anybody means
            // by a large file, and because it keeps the walk out of the
            // version-control and cache directories that live in them.
            guard let walk = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey,
                                             .totalFileAllocatedSizeKey, .isPackageKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }   // an unreadable folder is skipped, not fatal
            ) else { continue }

            for case let url as URL in walk {
                if Date() >= deadline { break }

                if isSkipped(url) {
                    walk.skipDescendants()
                    continue
                }

                let values = try? url.resourceValues(forKeys: [
                    .isDirectoryKey, .totalFileAllocatedSizeKey, .isPackageKey])

                let isDirectory = values?.isDirectory ?? false
                let isBundle = (values?.isPackage ?? false) || isOpaque(url)

                if isDirectory && isBundle {
                    // One item, not its contents.
                    walk.skipDescendants()
                    if let size = directorySize(of: url, fm: fm, deadline: deadline), size > 0 {
                        found.append(Item(url: url, bytes: size))
                    }
                    continue
                }
                if isDirectory { continue }

                if let size = values?.totalFileAllocatedSize, size > 0 {
                    found.append(Item(url: url, bytes: Int64(size)))
                }
            }
        }

        return largest(found, limit: limit)
    }

    /// What a bundle adds up to, with the same deadline over it.
    private static func directorySize(of url: URL, fm: FileManager,
                                      deadline: Date) -> Int64? {
        guard let walk = fm.enumerator(
            at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [], errorHandler: { _, _ in true }) else { return nil }

        var total: Int64 = 0
        for case let child as URL in walk {
            if Date() >= deadline { break }
            total += Int64((try? child.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        return total
    }
}


// MARK: - Removing what was chosen

extension LargeFiles {

    /// What came of moving a set of files to the Bin.
    struct Removal: Equatable {
        var moved: [URL] = []
        var failed: [URL] = []

        var bytesFreed: Int64 = 0
        var isCompleteSuccess: Bool { failed.isEmpty && !moved.isEmpty }
    }

    /// Moves files to the Bin.
    ///
    /// **To the Bin, never `removeItem`.** The difference is the whole reason
    /// this is allowed to exist inside a monitoring app: a file in the Bin is
    /// a mistake somebody can undo in Finder, and a file passed to
    /// `removeItem` is a mistake nobody can undo at all. Every bug in the
    /// ranking, the selection or the hit testing above becomes recoverable at
    /// this one line, so it is the line that does not change.
    ///
    /// Partial failure is normal rather than exceptional -- a file can be
    /// locked, in use, or on a volume with no Bin -- so each is reported
    /// rather than the whole batch failing on the first.
    static func moveToBin(_ items: [Item]) -> Removal {
        var result = Removal()
        for item in items {
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                result.moved.append(item.url)
                result.bytesFreed += item.bytes
            } catch {
                result.failed.append(item.url)
            }
        }
        return result
    }

    /// What to say afterwards.
    static func message(for removal: Removal) -> String {
        if removal.moved.isEmpty {
            return localized("Nothing could be moved to the Bin")
        }
        if removal.failed.isEmpty {
            return localized("%0 moved to the Bin", String(removal.moved.count))
        }
        return localized("%0 moved, %1 could not be",
                         String(removal.moved.count), String(removal.failed.count))
    }
}
