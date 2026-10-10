import Foundation

/// What the AI coding assistants keep on disk, and which of it is safe to
/// take away while leaving the tool installed and signed in.
///
/// They are worth their own reader because of the numbers. Measured on one
/// Mac: `~/.codex` 2.4 GB, `~/.claude` 515 MB, `~/.grok` 170 MB,
/// `~/.opencode` 205 MB across five directories. Most of that is not the
/// program -- it is every conversation ever held, every file version it
/// kept, the installers it downloaded to update itself, and its logs.
///
/// **Matching is an allowlist, not a denylist.** Only names that follow a
/// known convention -- `cache`, `logs`, `sessions`, `downloads` and the rest
/// below -- are offered; anything unrecognised is left alone. A denylist
/// gets this backwards: the one entry nobody thought to exclude is
/// `auth.json`, and the cost of that mistake is somebody signed out of
/// everything with no idea why. Nothing here can reach a credential,
/// a settings file or an installed plugin, because none of them are named
/// like a cache.
enum AIAssistants {

    /// What a directory is for, which decides whether it is ticked.
    enum Kind {
        /// Conversations, memories, plans, file history. Removable, and a
        /// real loss to somebody who resumes old sessions -- so it is shown
        /// and never ticked for them.
        case conversations
        /// Rebuilt on demand. Ticked.
        case caches
        /// Ticked.
        case logs
        /// Installers the tool fetched to update itself. Ticked: it will
        /// fetch them again if it ever needs them.
        case downloads

        var label: String {
            switch self {
            case .conversations: return localized("conversations and memory")
            case .caches:        return localized("cache")
            case .logs:          return localized("logs")
            case .downloads:     return localized("downloaded updates")
            }
        }

        /// Only what the tool can rebuild by itself.
        var isTickedByDefault: Bool { self != .conversations }
    }

    struct Item: Equatable {
        let url: URL
        let kind: Kind
        let bytes: Int64
        /// False when macOS would not say how big it is. Such an entry used
        /// to be dropped from the list entirely, because it measured zero
        /// and a zero was skipped as nothing to offer -- so a directory
        /// Perch could not open simply did not appear, however large it was.
        let isMeasured: Bool

        var name: String { url.lastPathComponent }

        init(url: URL, kind: Kind, bytes: Int64, isMeasured: Bool = true) {
            self.url = url
            self.kind = kind
            self.bytes = bytes
            self.isMeasured = isMeasured
        }

        static func == (a: Item, b: Item) -> Bool { a.url == b.url }
    }

    struct Tool: Equatable {
        let name: String
        let items: [Item]

        var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }

        static func == (a: Tool, b: Tool) -> Bool { a.name == b.name }
    }

    /// The assistants this knows the shape of.
    ///
    /// A list, because there is no way to ask a directory whether it belongs
    /// to an AI tool, and guessing from the home folder would put somebody's
    /// `.ssh` one rule away from a checkbox. Adding one is a line.
    static let known = ["claude", "codex", "grok", "gemini", "copilot",
                        "opencode", "cursor", "windsurf", "aider", "continue",
                        "amp", "qwen", "goose", "crush"]

    // MARK: - The rules

    /// A name with its extension taken off, lowercased.
    ///
    /// `logs_2.sqlite-wal` has an extension of `sqlite-wal`, so the base is
    /// `logs_2` and the write-ahead log travels with the database it belongs
    /// to rather than being left behind as an orphan.
    static func base(of name: String) -> String {
        (name as NSString).deletingPathExtension.lowercased()
    }

    /// Conversation stores, by the names the tools actually use.
    static let conversationNames: Set<String> = [
        "projects", "sessions", "session-env", "shell-snapshots", "plans",
        "file-history", "active_sessions", "history", "prompt-history",
        "memories", "goals", "queue", "thread_history", "todos",
    ]

    /// `memories_1.sqlite` and `thread_history_1.sqlite` are the same thing
    /// with a schema number welded on.
    private static func withoutSchemaNumber(_ name: String) -> String {
        guard let underscore = name.lastIndex(of: "_"),
              name[name.index(after: underscore)...].allSatisfy(\.isNumber),
              name.index(after: underscore) < name.endIndex
        else { return name }
        return String(name[..<underscore])
    }

    /// What this entry is, or nil for anything not recognised -- which is
    /// most of a tool's directory, and is the point.
    static func kind(of name: String) -> Kind? {
        let base = base(of: name)
        let stem = withoutSchemaNumber(base)

        if base == "downloads" { return .downloads }
        if ["logs", "log", "telemetry"].contains(stem) { return .logs }
        if stem == "cache" || stem == "caches"
            || base.hasSuffix("-cache") || base.hasSuffix("_cache") { return .caches }
        if conversationNames.contains(stem)
            || base.hasSuffix("-history") || base.hasSuffix("_history") { return .conversations }
        return nil
    }

    // MARK: - Finding it

    /// Every place one assistant keeps things.
    ///
    /// Both conventions, because they use both: the dot directory in the
    /// home folder, the XDG directories under it, and the macOS ones under
    /// `~/Library`.
    static func roots(for name: String, home: URL) -> [URL] {
        [".\(name)", ".config/\(name)", ".local/state/\(name)",
         ".local/share/\(name)", ".cache/\(name)",
         "Library/Application Support/\(name)", "Library/Caches/\(name)",
         "Library/Logs/\(name)"].map { home.appendingPathComponent($0) }
    }

    /// A root that is a cache in its entirety, so its contents need no
    /// classifying: everything under `~/.cache/<tool>` is a cache by
    /// definition, whatever the tool called the directories inside it.
    static func isWhollyCache(_ url: URL, home: URL) -> Bool {
        let path = url.path
        return path.hasPrefix(home.appendingPathComponent(".cache").path + "/")
            || path.hasPrefix(home.appendingPathComponent("Library/Caches").path + "/")
            || path.hasPrefix(home.appendingPathComponent("Library/Logs").path + "/")
    }

    /// What every known assistant on this Mac is holding. Blocking.
    static func find(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [Tool] {
        let fm = FileManager.default
        var tools: [Tool] = []

        for name in known.sorted() {
            var items: [Item] = []

            for root in roots(for: name, home: home) {
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else { continue }

                if isWhollyCache(root, home: home) {
                    let measured = AppLeftovers.measure(root, fm: fm)
                    if measured != 0 {
                        items.append(Item(url: root,
                                          kind: root.path.contains("/Logs/") ? .logs : .caches,
                                          bytes: measured ?? 0,
                                          isMeasured: measured != nil))
                    }
                    continue
                }

                for entry in (try? fm.contentsOfDirectory(atPath: root.path))?.sorted() ?? [] {
                    guard let kind = kind(of: entry) else { continue }
                    let url = root.appendingPathComponent(entry)
                    let measured = AppLeftovers.measure(url, fm: fm)
                    // A store that really is empty is nothing to offer and
                    // nothing to free; it only lengthens the list. One that
                    // would not answer is kept, because the reason it would
                    // not answer is not that it is small.
                    guard measured != 0 else { continue }
                    items.append(Item(url: url, kind: kind, bytes: measured ?? 0,
                                      isMeasured: measured != nil))
                }
            }

            if !items.isEmpty {
                tools.append(Tool(name: name, items: items.sorted { $0.bytes > $1.bytes }))
            }
        }

        return tools.sorted { $0.bytes > $1.bytes }
    }

    /// To the Bin, like everything else Perch removes. A conversation store
    /// somebody wanted back is then a trip to Finder.
    static func moveToBin(_ items: [Item]) -> LargeFiles.Removal {
        LargeFiles.moveToBin(items.map { LargeFiles.Item(url: $0.url, bytes: $0.bytes) })
    }
}
