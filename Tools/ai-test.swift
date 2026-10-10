//
//  ai-test.swift
//
//  Exercises which of an AI assistant's files are offered for removal.
//
//  Run:  cat Perch/UI/Localized.swift Perch/Cleanup/LargeFiles.swift \
//            Perch/Cleanup/AppLeftovers.swift \
//            Perch/Cleanup/AIAssistants.swift Tools/ai-test.swift | swift -
//
//  These directories hold two things that look alike from the outside: a
//  cache the tool rebuilds without noticing, and the credential that keeps
//  somebody signed in. The names below were taken from the real contents of
//  ~/.claude, ~/.codex, ~/.grok, ~/.gemini, ~/.copilot and ~/.opencode, and
//  most of the cases are about what must NOT be offered.
//
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures = 0
func check(_ name: String, _ ok: Bool) {
    print(ok ? "  ok   \(name)" : "  FAIL \(name)")
    if !ok { failures += 1 }
}

func kind(_ name: String) -> AIAssistants.Kind? { AIAssistants.kind(of: name) }

// MARK: - What must never be offered

print("Nothing that signs somebody out, or that they installed")

// The entry a denylist forgets. Being signed out of every assistant with no
// idea why is the worst outcome this file can produce.
for name in ["auth.json", ".credentials.json", "credentials.json"] {
    check("\(name) is not offered", kind(name) == nil)
}
for name in ["settings.json", "config.toml", "config.json", "hooks.json",
             "managed_config.lock", "models.json"] {
    check("\(name) is not offered", kind(name) == nil)
}
// Installed functionality, not leavings.
for name in ["plugins", "skills", "installed-plugins", "bin", "packages",
             "bundled", "vendor", "grove", "ide", "antigravity-ide"] {
    check("\(name) is not offered", kind(name) == nil)
}
// Somebody's own writing and the tool's own backups.
for name in ["CLAUDE.md", "README.md", "CHANGELOG.md", "backups",
             "settings.json.bak", "agent_id", "installation_id"] {
    check("\(name) is not offered", kind(name) == nil)
}

// MARK: - What is offered, and as what

print("\nCaches, logs and downloads — the tool rebuilds these")

check("cache", kind("cache") == .caches)
check("caches", kind("caches") == .caches)
check("paste-cache", kind("paste-cache") == .caches)
check("marketplace-cache", kind("marketplace-cache") == .caches)
check("models_cache.json", kind("models_cache.json") == .caches)
check("logs", kind("logs") == .logs)
check("telemetry", kind("telemetry") == .logs)
// The schema number comes off, so logs_2.sqlite is logs.
check("logs_2.sqlite", kind("logs_2.sqlite") == .logs)
// And the write-ahead log travels with the database rather than being left
// behind as an orphan beside a file that is gone.
check("logs_2.sqlite-wal", kind("logs_2.sqlite-wal") == .logs)
check("logs_2.sqlite-shm", kind("logs_2.sqlite-shm") == .logs)
check("downloads", kind("downloads") == .downloads)

print("\nConversations and memory — a real loss, so never ticked")

check("projects", kind("projects") == .conversations)
check("sessions", kind("sessions") == .conversations)
check("session-env", kind("session-env") == .conversations)
check("shell-snapshots", kind("shell-snapshots") == .conversations)
check("history.jsonl", kind("history.jsonl") == .conversations)
check("file-history", kind("file-history") == .conversations)
check("prompt-history.jsonl", kind("prompt-history.jsonl") == .conversations)
check("thread_history_1.sqlite", kind("thread_history_1.sqlite") == .conversations)
check("memories_1.sqlite", kind("memories_1.sqlite") == .conversations)
check("active_sessions.json", kind("active_sessions.json") == .conversations)
check("plans", kind("plans") == .conversations)
check("todos", kind("todos") == .conversations)

print("\nWhat is ticked when the list opens")

check("a cache is ticked", AIAssistants.Kind.caches.isTickedByDefault)
check("logs are ticked", AIAssistants.Kind.logs.isTickedByDefault)
check("downloaded updates are ticked", AIAssistants.Kind.downloads.isTickedByDefault)
// Somebody who resumes old sessions loses them. They are shown, named and
// left for a person to decide about.
check("conversations are not", !AIAssistants.Kind.conversations.isTickedByDefault)

// MARK: - Where it looks

print("\nWhere an assistant keeps things")

let home = URL(fileURLWithPath: "/Users/someone")
let roots = AIAssistants.roots(for: "claude", home: home).map { $0.path }
check("the dot directory", roots.contains("/Users/someone/.claude"))
check("the XDG config directory", roots.contains("/Users/someone/.config/claude"))
check("the XDG state directory", roots.contains("/Users/someone/.local/state/claude"))
check("the XDG cache directory", roots.contains("/Users/someone/.cache/claude"))
check("Application Support",
      roots.contains("/Users/someone/Library/Application Support/claude"))
check("Library caches", roots.contains("/Users/someone/Library/Caches/claude"))
check("nothing outside the home folder",
      roots.allSatisfy { $0.hasPrefix("/Users/someone/") })

// Everything under ~/.cache is a cache whatever the tool named the
// directories inside it, so those are taken whole rather than classified.
print("\nRoots that are a cache in their entirety")

func whole(_ path: String) -> Bool {
    AIAssistants.isWhollyCache(URL(fileURLWithPath: path), home: home)
}
check("~/.cache/opencode is taken whole", whole("/Users/someone/.cache/opencode"))
check("~/Library/Caches/claude too", whole("/Users/someone/Library/Caches/claude"))
check("~/Library/Logs/claude too", whole("/Users/someone/Library/Logs/claude"))
check("but ~/.claude is not", !whole("/Users/someone/.claude"))
check("nor ~/.config/claude", !whole("/Users/someone/.config/claude"))
// The prefix must be a whole path component: a directory called
// ~/.cachesomething is not inside ~/.cache.
check("a lookalike directory is not inside the cache",
      !whole("/Users/someone/.cachesomething"))

print("\nThe list of assistants")

check("the ones measured are known",
      ["claude", "codex", "grok", "gemini", "copilot", "opencode"]
          .allSatisfy(AIAssistants.known.contains))
check("and nothing that is not an assistant is",
      !AIAssistants.known.contains("ssh") && !AIAssistants.known.contains("config"))

print("")
if failures == 0 { print("all passed") } else { print("\(failures) failed") }
exit(failures == 0 ? 0 : 1)
