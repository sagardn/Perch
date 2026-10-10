//
//  largefiles-test.swift
//
//  Exercises the large-file finder: what it ranks, what it treats as one
//  thing, and what it leaves alone.
//
//  Run:  cat Perch/UI/Localized.swift Perch/Monitor/LargeFiles.swift \
//            Tools/largefiles-test.swift | swift -
//
//  The walk itself is checked against a directory built here rather than
//  against whatever is on this Mac, because the interesting cases -- a bundle
//  that must count as one item, a tie that must not reshuffle, a folder that
//  must be skipped -- cannot be arranged on a real disk to order.
//
import Foundation

setvbuf(stdout, nil, _IONBF, 0)

var failures = 0
func check(_ name: String, _ ok: Bool) {
    print(ok ? "  ok   \(name)" : "  FAIL \(name)")
    if !ok { failures += 1 }
}

func item(_ path: String, _ bytes: Int64) -> LargeFiles.Item {
    LargeFiles.Item(url: URL(fileURLWithPath: path), bytes: bytes)
}

// MARK: - Ranking

print("LargeFiles.largest")

let unsorted = [item("/a", 10), item("/b", 500), item("/c", 50), item("/d", 5000)]
check("biggest first", LargeFiles.largest(unsorted, limit: 4).map(\.name) == ["d", "b", "c", "a"])
check("limited to what was asked for",
      LargeFiles.largest(unsorted, limit: 2).map(\.name) == ["d", "b"])
check("a limit past the end is not an error",
      LargeFiles.largest(unsorted, limit: 99).count == 4)
check("a limit of zero returns nothing", LargeFiles.largest(unsorted, limit: 0).isEmpty)
check("a negative limit returns nothing", LargeFiles.largest(unsorted, limit: -1).isEmpty)
check("nothing in, nothing out", LargeFiles.largest([], limit: 10).isEmpty)

// A list that reshuffles two equal files between scans looks broken, and the
// files have not changed.
do {
    let tied = [item("/first", 100), item("/second", 100), item("/third", 100)]
    let once = LargeFiles.largest(tied, limit: 3).map(\.name)
    let twice = LargeFiles.largest(tied, limit: 3).map(\.name)
    check("ties keep the order they arrived in", once == ["first", "second", "third"])
    check("and that order is stable between runs", once == twice)
}

// MARK: - What counts as one thing

print("\nLargeFiles.isOpaque")

check("an app is one item", LargeFiles.isOpaque(URL(fileURLWithPath: "/A/Xcode.app")))
check("so is a photo library",
      LargeFiles.isOpaque(URL(fileURLWithPath: "/A/Mine.photoslibrary")))
check("and a sparse bundle",
      LargeFiles.isOpaque(URL(fileURLWithPath: "/A/Backup.sparsebundle")))
check("the extension is matched whatever its case",
      LargeFiles.isOpaque(URL(fileURLWithPath: "/A/Thing.APP")))
check("an ordinary folder is not", !LargeFiles.isOpaque(URL(fileURLWithPath: "/A/Holiday")))

// The first run of this filled all twenty rows with one project's
// dependencies, 30 MB each, burying everything worth acting on.
check("node_modules is one thing",
      LargeFiles.isOpaque(URL(fileURLWithPath: "/p/node_modules")))
check("so is a .git directory", LargeFiles.isOpaque(URL(fileURLWithPath: "/p/.git")))
check("and DerivedData", LargeFiles.isOpaque(URL(fileURLWithPath: "/p/DerivedData")))
check("a folder merely containing the word is not",
      !LargeFiles.isOpaque(URL(fileURLWithPath: "/p/my_node_modules_backup")))

print("\nLargeFiles.Item.folder")

do {
    let home = URL(fileURLWithPath: "/Users/me")
    func folder(_ path: String) -> String {
        LargeFiles.Item(url: URL(fileURLWithPath: path), bytes: 1).folder(relativeTo: home)
    }
    check("a file in Downloads says Downloads",
          folder("/Users/me/Downloads/big.dmg") == "Downloads")
    check("a nested one says the whole path under home",
          folder("/Users/me/Documents/work/api/buf") == "Documents/work/api")
    check("a file in home itself says ~", folder("/Users/me/loose.bin") == "~")
    check("something outside home keeps its real path",
          folder("/Volumes/Drive/clip.mov") == "/Volumes/Drive")
}
check("nor a video file", !LargeFiles.isOpaque(URL(fileURLWithPath: "/A/clip.mov")))

// MARK: - What is left alone

print("\nLargeFiles.isSkipped")

// The snapshot mount: sizes under it are the same bytes counted twice.
check("the system snapshot mount is skipped",
      LargeFiles.isSkipped(URL(fileURLWithPath: "/System/Volumes/Data/Users/me/x")))
check("the Bin is skipped -- it needs Full Disk Access and is Finder's job",
      LargeFiles.isSkipped(URL(fileURLWithPath: "/Users/me/.Trash/old.zip")))
// Caches are the thing every cleaner offers and every cleaner should not:
// the space comes back by itself and deleting it only slows the next hour.
check("caches are skipped",
      LargeFiles.isSkipped(URL(fileURLWithPath: "/Users/me/Library/Caches/com.x/blob")))
check("an ordinary file is not skipped",
      !LargeFiles.isSkipped(URL(fileURLWithPath: "/Users/me/Downloads/big.dmg")))

// MARK: - Where it looks

print("\nLargeFiles.defaultRoots")

do {
    let roots = LargeFiles.defaultRoots(home: URL(fileURLWithPath: "/Users/me"))
    check("the folders people actually fill", roots.count == 6)
    check("Downloads is among them", roots.contains { $0.lastPathComponent == "Downloads" })
    check("and none of them is the home folder itself",
          !roots.contains { $0.lastPathComponent == "me" })
    check("nor anything outside home",
          roots.allSatisfy { $0.path.hasPrefix("/Users/me/") })
}

// MARK: - Walking a directory built for the purpose

print("\nLargeFiles.scan")

do {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("perch-largefiles-\(UUID().uuidString)")
    try! fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    func write(_ name: String, _ bytes: Int) {
        let url = root.appendingPathComponent(name)
        try? fm.createDirectory(at: url.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        try? Data(count: bytes).write(to: url)
    }

    write("small.bin", 1_000)
    write("medium.bin", 400_000)
    write("large.bin", 2_000_000)
    write("nested/deep/buried.bin", 900_000)
    // A bundle: three parts that must be reported as one item, not three.
    write("Thing.app/Contents/MacOS/a", 300_000)
    write("Thing.app/Contents/MacOS/b", 300_000)
    write("Thing.app/Contents/Resources/c", 300_000)

    let found = LargeFiles.scan(roots: [root], limit: 10)
    let names = found.map(\.name)

    check("the biggest file comes first", names.first == "large.bin")
    check("a file in a subfolder is found too", names.contains("buried.bin"))
    check("the bundle is reported", names.contains("Thing.app"))
    check("as one item, not its three parts",
          names.filter { $0 == "Thing.app" }.count == 1 && !names.contains("a"))
    check("and its size is the sum of what is inside",
          (found.first { $0.name == "Thing.app" }?.bytes ?? 0) >= 900_000)
    check("every size is positive", found.allSatisfy { $0.bytes > 0 })
    check("the small file ranks last", names.last == "small.bin")

    // A deadline already past: the walk must come back rather than finish.
    let timedOut = LargeFiles.scan(roots: [root], limit: 10,
                                   deadline: Date().addingTimeInterval(-1))
    check("a scan out of time returns rather than running on", timedOut.isEmpty)

    check("a folder that does not exist is not a crash",
          LargeFiles.scan(roots: [root.appendingPathComponent("nope")], limit: 5).isEmpty)
}

// MARK: - Sorting files into kinds

print("\nLargeFiles.Category")

func kind(_ name: String) -> LargeFiles.Category {
    LargeFiles.Category.of(URL(fileURLWithPath: "/x/\(name)"))
}

check("a movie is video", kind("holiday.mov") == .video)
check("so is an mkv", kind("film.mkv") == .video)
check("a song is audio", kind("track.flac") == .audio)
check("a photo is an image", kind("DSC_0001.NEF") == .image)
check("a gif is an image", kind("cat.gif") == .image)
check("a zip is an archive", kind("backup.zip") == .archive)
check("a disk image is an installer", kind("Thing-1.2.dmg") == .installer)
check("a pdf is a document", kind("invoice.pdf") == .document)
check("extensions are matched whatever their case", kind("CLIP.MOV") == .video)
check("something unrecognised is other", kind("data.qqq") == .other)
check("and so is a file with no extension at all", kind("Makefile") == .other)
// A name with dots in it must be read by its last component, not its first.
check("only the final extension counts", kind("archive.tar.gz") == .archive)

check("every category has a title",
      LargeFiles.Category.allCases.allSatisfy { !$0.title.isEmpty })
// No extension may sit in two buckets, or which one wins depends on the
// order of a dictionary, which has none.
do {
    var seen = Set<String>()
    var overlap = false
    for (_, exts) in LargeFiles.Category.extensions {
        for e in exts where !seen.insert(e).inserted { overlap = true }
    }
    check("no extension belongs to two categories", !overlap)
}

// MARK: - Moving files to the Bin

print("\nLargeFiles.moveToBin")

do {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("perch-bin-\(UUID().uuidString)")
    try! fm.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: root) }

    let a = root.appendingPathComponent("one.bin")
    let b = root.appendingPathComponent("two.bin")
    try! Data(count: 2_048).write(to: a)
    try! Data(count: 4_096).write(to: b)

    let removal = LargeFiles.moveToBin([LargeFiles.Item(url: a, bytes: 2_048),
                                        LargeFiles.Item(url: b, bytes: 4_096)])

    check("both were moved", removal.moved.count == 2)
    check("none failed", removal.failed.isEmpty)
    check("the freed total is the sum of them", removal.bytesFreed == 6_144)
    check("that counts as a complete success", removal.isCompleteSuccess)
    // The point of the whole design: gone from here, not gone from the disk.
    check("the originals are no longer where they were",
          !fm.fileExists(atPath: a.path) && !fm.fileExists(atPath: b.path))

    // Tidy up after ourselves rather than leaving two files in the Bin.
    for url in removal.moved {
        let inBin = (try? fm.url(for: .trashDirectory, in: .userDomainMask,
                                 appropriateFor: nil, create: false))?
            .appendingPathComponent(url.lastPathComponent)
        if let inBin { try? fm.removeItem(at: inBin) }
    }
}

do {
    // A path that is not there. One failure must not take the batch with it.
    let missing = URL(fileURLWithPath: "/nonexistent/perch/\(UUID().uuidString)")
    let removal = LargeFiles.moveToBin([LargeFiles.Item(url: missing, bytes: 10)])
    check("a file that cannot be moved is reported, not thrown",
          removal.failed.count == 1 && removal.moved.isEmpty)
    check("and nothing is claimed as freed", removal.bytesFreed == 0)
    check("which is not a complete success", !removal.isCompleteSuccess)
}

check("an empty selection moves nothing",
      LargeFiles.moveToBin([]) == LargeFiles.Removal())

print("\nLargeFiles.message")

check("a clean run says how many moved",
      LargeFiles.message(for: .init(moved: [URL(fileURLWithPath: "/a")], failed: [],
                                    bytesFreed: 1)).contains("1"))
check("a total failure says so",
      LargeFiles.message(for: .init(moved: [], failed: [URL(fileURLWithPath: "/a")],
                                    bytesFreed: 0)).contains("Nothing"))
check("a partial run reports both numbers",
      LargeFiles.message(for: .init(moved: [URL(fileURLWithPath: "/a")],
                                    failed: [URL(fileURLWithPath: "/b")],
                                    bytesFreed: 1)).contains("1"))

print(failures == 0 ? "\nall passed" : "\n\(failures) failed")
exit(failures == 0 ? 0 : 1)
