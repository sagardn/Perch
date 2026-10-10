import AppKit

/// The processes using the most processor time.
///
/// `ps` rather than a subprocess-free API: reading another process's CPU
/// accounting means `proc_pid_rusage`, which needs the same privileges as
/// `ps` already has, for every pid on the machine on every refresh. `ps`
/// does that walk once in C and hands back a sorted list.
///
/// Percentages are shares of **one** core, the way `ps` and `top` report
/// them -- a process can read 150% on an 8-core machine. That is not a bug
/// and the popup says "of one core" so nobody has to guess.
enum ProcessCPU {

    struct Entry: Identifiable {
        let pid: Int32
        let name: String
        /// Percent of a single core.
        let usage: Double
        var id: Int32 { pid }
    }

    private static let queue = DispatchQueue(label: "com.sagar.perch.cpu.processes",
                                             qos: .utility)
    private static var running = false

    static func top(_ limit: Int = 8, completion: @escaping ([Entry]) -> Void) {
        guard !running else { return }
        running = true

        queue.async {
            let entries = read(limit)
            DispatchQueue.main.async {
                running = false
                completion(entries)
            }
        }
    }

    /// `-A` every process, `-c` the executable name rather than the full
    /// argv (which would be a full path plus flags), `-r` sorted by CPU.
    private static func read(_ limit: Int) -> [Entry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pid,pcpu,comm", "-r"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            NSLog("Perch: ps could not be run: \(error)")
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return parse(text, limit: limit)
    }

    /// Lines look like `  481  12.4 Google Chrome`. The name is whatever is
    /// left after the two numeric columns, so it may contain spaces.
    static func parse(_ text: String, limit: Int) -> [Entry] {
        var entries: [Entry] = []

        for line in text.split(separator: "\n").dropFirst() {   // drop the header
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 2,
                                      omittingEmptySubsequences: true)
            guard parts.count == 3,
                  let pid = Int32(parts[0]),
                  let usage = Double(parts[1]) else { continue }

            let name = parts[2].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            // ps lists itself and every idle daemon; neither is worth a row.
            guard usage > 0 else { continue }

            entries.append(Entry(pid: pid, name: name, usage: usage))
            if entries.count >= limit { break }   // already sorted by -r
        }
        return entries
    }
}
