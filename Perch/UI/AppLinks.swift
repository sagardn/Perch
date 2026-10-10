import AppKit

/// Where Perch points on the web.
///
/// Perch's own copy of the handful of links the app shell needs. Kit's
/// `Branding` still holds these for Kit and `Modules/Net` (which reads the
/// public-IP endpoints from it), and that copy goes when Kit does — this one
/// exists so a rebuilt view does not have to reach into the framework it is
/// replacing for the address of its own repository.
enum AppLinks {

    /// owner/name on GitHub. The updater reads releases from here.
    static let repository = "sagardn/Perch"

    static var repositoryURL: URL? {
        URL(string: "https://github.com/\(repository)")
    }

    static var issuesURL: URL? {
        URL(string: "https://github.com/\(repository)/issues/new")
    }

    static var releasesURL: URL? {
        URL(string: "https://github.com/\(repository)/releases")
    }

    static func releaseNotesURL(_ version: String) -> URL? {
        URL(string: "https://github.com/\(repository)/releases/tag/\(version)")
    }

    /// nil hides every Donate button in the app.
    ///
    /// Upstream's Sponsors, PayPal, Patreon and hosted-service buttons are
    /// deliberately absent: each one paid the original author rather than this
    /// fork, and the service one advertised is not a service this fork runs.
    static let donationURL: URL? = URL(string: "https://ko-fi.com/sagardn")
}

/// Restarts Perch.
///
/// A shell that waits half a second and reopens the bundle, because the
/// process has to be gone before `open` will start a second copy. Used by the
/// settings that cannot be applied to a running app -- the dock icon is the
/// only one left.
///
/// `Never`: the call does not come back, and saying so stops every caller
/// having to write an unreachable `return` after it.
func restartPerch(after seconds: TimeInterval = 0.5) -> Never {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
    try? task.run()
    NSApp.terminate(nil)
    exit(0)
}
