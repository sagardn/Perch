import AppKit

/// The Free up space page: the four ways Perch can help with a full disk.
///
/// It was a section at the bottom of the Disk module's settings, which is
/// where it was written and the wrong place for it. That page configures the
/// Disk *module* -- which volume it watches, which shapes it draws in the
/// menu bar, when it warns. These rows configure nothing; they are actions,
/// and they are about the Mac rather than about a module. Somebody wanting
/// to uninstall an app had no reason to open a monitoring module's settings
/// to find it, and nobody did.
///
/// The order is by how much is asked of the person, lightest first: macOS
/// can be asked to do it, the Bin can be emptied, the big files can be
/// looked at, an app can be taken away. The two rows that remove anything
/// open a window that lists what it is going to remove, with checkboxes, and
/// everything Perch removes itself goes to the Bin.
final class CleanupPane: NSStackView {

    init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 0))
        translatesAutoresizingMaskIntoConstraints = false

        // Perch asks for no disk permission of its own. The first two rows
        // hand the job to something that already has one, and the last two
        // search only what macOS lets any app read.
        let macOSCan = Controls.section(localized("What macOS can do"), [
            Controls.row(localized("Space macOS can reclaim"), Controls.group([
                Controls.button("Storage settings…") { DiskCleanup.openStorageSettings() },
            ])),
            Controls.row(localized("Deleted files"), Controls.group([
                Controls.button("Open Bin") { DiskCleanup.openBin() },
            ])),
        ])

        let perchCan = Controls.section(localized("What Perch can find"), [
            Controls.row(localized("What is taking the room"), Controls.group([
                Controls.button("Find large files…") { LargeFilesWindow.present() },
            ])),
            Controls.row(localized("An app or tool you no longer want"), Controls.group([
                Controls.button("Remove an app or tool…") { UninstallWindow.present() },
            ])),
        ])

        let note = NSTextField(wrappingLabelWithString:
            localized("Everything Perch removes goes to the Bin, so nothing is erased until you empty it."))
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.translatesAutoresizingMaskIntoConstraints = false

        let column = NSStackView(views: [macOSCan, perchCan, note])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 18
        column.edgeInsets = NSEdgeInsets(top: 44, left: 18, bottom: 18, right: 18)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            macOSCan.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -36),
            perchCan.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -36),
            note.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -36),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Nothing to refresh: the page holds no reading, only four ways in.
    func viewWillAppear() {}
}
