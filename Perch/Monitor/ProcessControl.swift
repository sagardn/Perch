import AppKit

/// Ending a process from the top-processes list.
///
/// The decision is small and the consequence is not: a force quit takes the
/// process down without letting it save, so what this must never do is report
/// success for something that did not happen, or quietly kill the wrong pid.
enum ProcessControl {

    /// What came of asking.
    enum Outcome: Equatable {
        case terminated
        /// Already gone. The list is a sample a second or two old, so a
        /// process that has exited on its own between the sample and the
        /// click is the ordinary case, not a failure.
        case alreadyGone
        /// Owned by another user, or protected by the system. Killing it
        /// needs privileges Perch does not have and should not ask for.
        case notPermitted
        case failed(code: Int32)
    }

    /// What a `kill(2)` return value means.
    ///
    /// Pure, because the interesting part is the mapping and the only way to
    /// exercise it for real is to kill something. `result` is kill's return,
    /// `code` the errno it left behind.
    static func outcome(result: Int32, errno code: Int32) -> Outcome {
        guard result != 0 else { return .terminated }
        switch code {
        case ESRCH: return .alreadyGone
        case EPERM: return .notPermitted
        default:    return .failed(code: code)
        }
    }

    /// A pid worth sending a signal to.
    ///
    /// Refuses the ones where `kill(2)` means something other than "end this
    /// process": 0 signals every process in our group, -1 signals everything
    /// we are allowed to signal, and any negative pid signals a whole process
    /// group. A list row should never be able to reach those, and the cost of
    /// being wrong is the machine, so it is checked rather than assumed.
    static func isSignallable(_ pid: Int32) -> Bool { pid > 1 }

    /// Ends a process now.
    ///
    /// `NSRunningApplication.forceTerminate()` where there is one, because it
    /// goes through the window server and leaves the Dock and the app
    /// switcher in a consistent state. A helper process -- most of what a
    /// memory list shows -- has no `NSRunningApplication`, so it takes a
    /// signal instead.
    @discardableResult
    static func forceQuit(pid: Int32) -> Outcome {
        guard isSignallable(pid) else { return .failed(code: EINVAL) }

        if let app = NSRunningApplication(processIdentifier: pid) {
            if app.isTerminated { return .alreadyGone }
            return app.forceTerminate() ? .terminated : .notPermitted
        }

        errno = 0
        let result = kill(pid, SIGKILL)
        return outcome(result: result, errno: errno)
    }

    /// What to tell somebody, or nil when it worked and the row simply
    /// disappears on the next sample.
    static func message(for outcome: Outcome, name: String) -> String? {
        switch outcome {
        case .terminated:   return nil
        case .alreadyGone:  return localized("%0 had already quit", name)
        case .notPermitted: return localized("%0 belongs to another user", name)
        case .failed:       return localized("Could not quit %0", name)
        }
    }
}
