# Architecture

Perch is two applications sharing one process and one menu bar:

- **the launcher** — a search panel, global hotkeys, window control
- **the monitor** — readings drawn into the menu bar, each with a popup

They share no code and know nothing about each other, which is deliberate:
either half can be worked on, or removed, without touching the other.

The monitor half is mid-migration. This document says exactly where it is.

---

## The tree

| Path | Origin | Role |
|---|---|---|
| `Perch/Launcher/` | written here | the launcher, start to finish |
| `Perch/Monitor/` | written here | **the independent monitor — all new work goes here** |
| `Perch/Views/` | written here | the settings window and the first-run window |
| `Perch/AppDelegate.swift` | written here | application lifecycle and the four windows |
| `Perch/Startup/` | written here | launch arguments, diagnostics, schedules, the support prompt, the popup shortcut |
| `Perch/UI/`, `Perch/Settings/`, `Perch/System/`, `Perch/Update/` | written here | controls, preferences, the Dashboard, the updater |
| `LaunchAtLogin/` | written here | the login item helper |
| `Tools/` | written here | icon generator, test suites, installer, uninstaller, the i18n check |

`Kit/`, `Modules/`, `SMC/` and `Widgets/` are gone. Nothing links a framework
and the built bundle has no `Contents/Frameworks` at all.

Nothing in the tree is derived any more, and Perch is MIT under its own
copyright alone (`LICENSE`). The last derived content went in one change:

| What | How it went |
|---|---|
| 41 `.lproj` translations | retranslated from a rewritten `en.lproj`, working from the English only -- the first pass left 2,141 old pairs in place; see Localisation ▸ How the translations were made |
| `Tools/i18n.py` | rewritten from its documented behaviour -- `check`, `fix`, `scan` -- with no `translate` command |
| `Makefile`, `exportOptions.plist` | deleted; releases are built by `.github/workflows/release.yaml` |
| `background.png`, `Assets.xcassets/devices`, `support/github.png` | deleted; the Dashboard draws the system's own Mac icons and the setup window a system symbol |

"Derived" meant third-party MIT work, renamed: a file can stop importing a
framework and still be that framework's author's work, because structure is
copyrightable. Rewiring is not rewriting. The audit that found the last of it
did not trust headers: it compared every file in the tree, by git blob hash,
against the commit that imported upstream, and then measured line overlap for
the files edited since. That is how the two scripts turned up -- neither
carried a copyright line, and every Swift-only count had missed them.

**Do not restore anything from before the relicensing.** History before it
carries upstream's translations, scripts and assets under upstream's notice;
bringing any of it back brings the obligation back with it.

**There is no dependency on any other project.** No submodule, no package,
no service, no release feed, no network call.

---

## Migration status

Complete. What follows is the record of what each module became.

### What is independent today

`Perch/Monitor/`, built against public macOS APIs only:

| File | Reads | Via |
|---|---|---|
| `Readings.swift` | CPU, memory, disk, network, battery | `host_statistics`, `getifaddrs`, `IOPowerSources` |
| `CPUReadings.swift` | per-core load, user/system split, cluster layout | `host_processor_info`, `sysctl` |
| `MemoryReadings.swift` | app/wired/compressed/cached, swap, pressure | `host_statistics64`, `sysctl` |
| `NetworkMonitor.swift` | per-interface throughput, totals, latency, jitter | `getifaddrs`, TCP handshake timing |
| `NetworkInfo.swift` | interface, Wi-Fi, local and public IP | `SystemConfiguration`, `CoreWLAN` |
| `ProcessNetwork.swift` | per-process network I/O | `nettop` |
| `GPUStats.swift` | GPU utilization, renderer/tiler, memory | IORegistry |
| `Temperature.swift` | Apple silicon sensors | `IOHIDEventSystemClient` |

The UI they feed:

| File | Role |
|---|---|
| `Popup.swift` | `ReadingPopup`, the floating panel and its header |
| `PopupSection.swift` | section header, value row, status pill, big reading, traffic chart, connectivity grid, core bars, process row |
| `Modules.swift` | `PopupContent`, the contract; `NativeModules`, the registry |
| `CPUPopup.swift`, `GPUPopup.swift`, `RAMPopup.swift`, `DiskPopup.swift`, `NetworkPopup.swift` | the five modules built so far |
| `CPUTile.swift`, `GPUTile.swift`, `RAMTile.swift`, `DiskTile.swift`, `NetworkTile.swift` | their tiles in the combined details popup |
| `Changes.swift` | the rule for when something has really changed |
| `ProcessCPU.swift`, `ProcessMemory.swift` | the two `ps` readers behind the process lists |
| `MenuBarWidget.swift` | draws a reading in any of the six shapes |
| `MenuBarStyle.swift` | the six shapes, their stored list and their widths |
| `MonitorBar.swift` | the menu bar: an item each, or one shared item |
| `CombinedBar.swift`, `CombinedLayout.swift` | the shared item and its arithmetic |
| `Thresholds.swift` | the rule for when a reading deserves a notification |

### How to see it

Nothing needs the flag any more. Every module Perch draws is a registered
module in its own right — CPU, RAM and Network — rather than a preview beside
the one it duplicates. The flag stays for the next module, which will spend a
few commits behind it:

```bash
defaults write com.sagar.perch nativeMonitor -bool true
```

### What is left

Nothing. Every module is Perch's, the shell reads its settings through
`Preferences`, the framework they were built on has been deleted along with
its Xcode target, and the translations, scripts and assets that came with the
import have been replaced or deleted.

### What Disk does not reproduce

Two of the old module's readings, both for the same reason -- they need a
privilege an ad-hoc signed build does not have:

- **SMART lifetime totals**, the bytes a drive has read and written since it
  left the factory. Enabling SMART reporting on a device is a privileged
  operation; the popup reports bytes since the device was attached instead,
  which is what the IORegistry gives freely.
- **Per-process disk I/O.** There is no public per-process byte counter;
  the old module's was a privileged path, and `nettop`'s equivalent does not
  exist for storage.

Its `text` shape is left out, as RAM's and Network's are.

The volume the menu bar figure is about is kept, but stored differently.
The old module stored the drive's **name** under `Disk_disk`; two drives
called "Backup" are entirely possible and a name cannot tell them apart, so
Perch stores the mount point. A chosen volume that is not mounted falls back
to the startup volume without forgetting the choice.

**Three keys have held this setting**, because the module was built twice --
once here and once in a parallel session, before the two were reconciled:

| Key | What it holds |
|---|---|
| `Disk_volume` | **canonical**: a mount point |
| `Disk_selectedDisk` | a mount point, from the parallel implementation |
| `Disk_disk` | a drive *name*, from the module being replaced |

`DiskReadings.resolveWatchedVolume` decides between them and is pure, so the
precedence is tested against values written down. A value already under the
canonical key is a choice made here and is never overwritten by an older key
that also exists. Otherwise the parallel key transfers if that volume is
mounted, then the old name resolves — but only if exactly one mounted volume
answers to it, since two drives of the same name is the ambiguity that made
names unusable. Both old keys are removed once read.

### What Sensors does not reproduce

**Fan control.** Reading the SMC needs no privilege -- measured, not assumed:
`IOServiceOpen` on `AppleSMC` succeeds from an ordinary process. *Writing* a
key is what spins a fan, and that needs a helper installed through
`SMJobBless`, which an ad-hoc signed build cannot do. `SMCKit` has no write
path at all, so there is nothing to go wrong in the direction that could
damage hardware. Fan *readings* are implemented and will report on a Mac that
has fans; this one is a MacBook Air and has none, so **they are unverified on
this hardware** and said so in the code.

**The 587-line key table.** The module this replaces mapped SMC keys to human
names from a transcription of undocumented firmware keys, most of which
cannot be checked on any one machine. It is not reproduced. Perch names HID
sensors whatever the system calls them -- they are self-describing -- groups
SMC keys by the one convention that has held for twenty years (T temperature,
V volts, I amps, P watts, F fans), and gives a real name only to the handful
that could be verified against a second source. A sensor named `Ts0P` is
opaque; a sensor named wrongly is a lie with a number beside it.

Two implementations of the SMC client were written in parallel by two
sessions before they agreed which to keep. That is how the decoding came to
be checked twice: written separately from the same protocol, they agreed on
`VP0R` to two decimal places and `TB0T` to within a fifth of a degree. On this
machine the DC input's power also equals its own volts times amps to two
decimals, which is the closest thing to a second instrument available.

### Battery and Bluetooth are gone, and are not coming back

Neither was rebuilt, and that was a decision rather than a gap. macOS already
shows battery charge and Bluetooth device batteries in its own menu bar, so a
second copy inside Perch was duplication to maintain rather than something the
app was for. Both modules, both framework targets and both embedded
frameworks are removed; `NSBluetoothAlwaysUsageDescription` went with them,
because nothing links CoreBluetooth any more and advertising a permission the
app can never request is a promise about data it does not collect.

A settings file that still names either module is ignored rather than
repaired — there is no module to attach a stale `Battery_state` to, and the
registry simply does not list one.

`LoadBand.of(_:reversed:)` stays. It exists for readings where low is the bad
end, which was battery charge, and it is the kind of thing worth keeping
built: it costs two lines and the next reading of that shape will want it.

### A trap worth writing down

An APFS container's volumes each report the **container's** capacity. On this
Mac thirteen volumes mount; Macintosh HD, VM, Preboot, Update and Recovery
all report 195,383,263,232 bytes total and nothing available. Listing them
shows one disk five times, every copy apparently full, and summing them
invents a machine with a terabyte of storage. `DiskReadings.volumes` keeps
the browsable ones -- what Finder lists -- which leaves two.

The percentage is of the container: used is capacity less what is available
for important usage. `df` prints 74% for the same disk because it compares
one volume's own usage against the container's size, which is the figure that
does not mean anything. 4.6 GiB free of 182 GiB is 97%, and 97% is what the
menu bar says.

### What GPU does not reproduce

Three readings the module it replaced showed are not here, and the first two
are not coming:

- **Neural Engine power** and **frames per second**. Both come from IOReport,
  which is a private framework reached through `dlsym` — the same reason CPU
  has no live clock frequency. `docs` says it once for all of them.
- **GPU temperature.** No sensor on Apple silicon identifies itself as the
  graphics processor. Measured on an M2: thirty-seven sensors answer, and the
  closest are `PMU tdie1...8`, which are the SoC die — the CPU clusters, the
  GPU and the Neural Engine share it. Reporting that figure under a GPU label
  would be a confident-looking number about the wrong thing. The sensor list
  in the Sensors module shows all of them, named as the hardware names them.
- **Fan speed** went with the SMC helper, which an ad-hoc signed build cannot
  install.

What it does report comes from `PerformanceStatistics`, which every
accelerator driver publishes in the IORegistry: overall utilization, the
renderer and tiler split on Apple silicon, memory in use, the device name, and
one row per accelerator on a Mac with more than one. `gpu-core-count` gives
the core count where the chip publishes it, which is Apple silicon only — a
shader count is not the same thing, so it is a dash on AMD and Intel rather
than a number that means something else.

### What Network does not reproduce

The module it replaced offered five menu bar shapes. Perch draws three of
them — the name, the pair of rates, and the two-sided traffic chart. The two
left out are `text` and `state`, the same pair RAM's left out, for the same
reason: both are drawing routines rather than readings, and the stored name of
either is kept rather than discarded.

Its alerts are the same five, and they are *changes* rather than thresholds —
a link does not cross a line, it becomes something else. The confirmation
counts are kept too, two for the connection and three for the public address,
because a probe through a struggling link fails occasionally without the link
being down. `ChangeTracker` counts agreement with the new answer rather than
disagreement with the old one; the implementation it replaces counted
disagreement, which means three *different* wrong readings were enough to
report a change to the last of them.

### What RAM does not reproduce

The module it replaced offered nine menu bar shapes. Perch draws seven of
them -- the six every module shares, plus the pair of figures that shape
called `memory`. The two left out are `text`, a template language for
composing a string out of the module's values, and `state`, a coloured dot.
Both are shapes rather than readings, so nothing is unmeasurable about them;
they are simply not drawn yet, and the stored name of either is kept rather
than discarded, so switching one on again would be a drawing routine and
nothing else.

Its top-processes list reports **resident** memory, where that module reported
the phys_footprint `top` prints. The two disagree by a few hundred megabytes
on a busy machine. `ps -m` returns in 0.027s against `top -l 1 -o mem`'s
0.86s, most of which `top` spends pinning a core to sample the whole system,
and for a list that refreshes while a popup is open that is the wrong price
for a different definition. The section says "resident" rather than implying
they are the same number.

### What CPU does not reproduce

Two things the module it replaced offered are deliberately absent, and the
reasons are not going to change:

- **Live clock frequency.** It comes from IOReport: a private framework
  reached through `dlsym`, undocumented, different per chip generation, and
  metered by a sampling subscription that costs power to hold open. The public
  answer is `hw.cpufrequency`, which does not exist on Apple silicon —
  measured on an M2, along with `hw.cpufrequency_max` and `hw.busfrequency`.
  The popup shows the nominal clock where the kernel publishes one and leaves
  the row out where it does not. `CPUReadings.limits` does report what `pmset`
  knows about throttling, which is the part that is public.
- **A threshold on a third "super" core cluster.** No shipping Mac reports a
  third performance level, so there would be no figure to put in it.

---

## Localisation

Perch ships 41 `.lproj` files and is, in the part a user actually reads,
English only. Both halves of that are true at once and the second one is the
one worth knowing.

### What the files hold

159 keys, the same 159 in every language, checked by CI:

```bash
python3 Tools/i18n.py        # the 41 files are in step with en.lproj
python3 Tools/i18n.py scan   # en.lproj is in step with the code
```

`scan` is the one that matters and it was not being run. It compares en.lproj
against the source two ways, and both directions were wrong: 40 strings
reached `localized()` with no key in any file, so they could not be
translated at all, and 376 keys answered to nothing in the code — fan
control, the clock module, the colour pickers, Battery, Bluetooth, and the
old modules' wording for readings the rebuilt popups phrase differently
("Disk utilization threshold" against the shipping `localized("Disk usage
threshold")`). Both are now zero.

Deleting those 376 was safe for a specific reason rather than by luck.
`scan`'s `used()` counts every string literal in the tree, not only the
arguments of `localized(`, so a key reached through a variable still counts
as used — and seven call sites do pass a variable:

```
Thresholds.swift:347      localized(level.label)
RAMTile.swift:90          localized(pressure.label)
Views/Settings.swift:147  localized(title)
SettingsShell.swift:49    localized($0.moduleName)
SettingsShell.swift:251   localized($0.moduleName)
SettingsShell.swift:252   localized(model.selection)
Setup.swift:364           localized(preset.name)
```

Every one of them resolves to a literal that is written down somewhere:
`MemoryReadings.Pressure.label` returns "Normal"/"Warning"/"Critical", the
module shells name themselves, Setup's presets are an array of literals, and
`model.selection` is handed the same `title` that line 147 localises. Add an
eighth call site whose argument is *computed* — a key assembled from parts,
or read from a file — and `scan`'s unused list stops being trustworthy. Say
so here if you do.

### What is not localised

Everything user-facing now goes through `localized()`. The rebuilt popups
used to hand literals straight to the view — 122 of them at the worst point,
including a `UpdateWindow` that called `localized()` zero times, so the whole
update flow was English on a Japanese machine. 182 strings go through it
today and fourteen literals remain, every one of them deliberate:

| Still a literal | Why |
|---|---|
| `"Perch"` in `GeneralPane` and `UpdateWindow` | the product name; it is not translated anywhere |
| `"CPU"`, `"GPU"`, `"RAM"`, `"NET"` | menu bar labels, where the space is a few points wide and the abbreviation is read the same in every language the app ships |
| `"↓ "`, `"↑ "` | direction arrows |
| `"⌃-"` | a keyboard glyph standing in for an unset shortcut |
| `com.sagar.perch.*` ×4 | dispatch queue labels, which no one ever sees |

They are listed because the obvious next contribution is to "finish the job"
by wrapping them, and each one would be a small regression: a translated
product name, a menu bar item that no longer fits, or a queue label that
changes with the user's locale.

A clean `scan` means every string the code localises has a key. It still
does not mean the app is *translated* — see below.

### How the translations were made

Twice, and the first time did not take.

The pass at the relicensing rewrote the headers, deleted 376 dead keys and
fixed individual entries, and the files read as Perch's afterwards. They were
not: compared pair by pair -- same key, same value -- against the import they
started from, 2,141 translated lines across the 38 non-English languages were
still verbatim. Whole-file similarity (12-34%) hid it; only the per-pair
comparison finds it, so that is the check to run on anything inherited.

The second pass (`e00b974`, 1.0.14) replaced every value in those 38 files:
each language translated by a model from `en.lproj` alone, told not to open
any existing translation or any history. en-GB and en-AU are `en` with
British spelling. Each file's header says it is machine-translated, dated,
and unreviewed.

### The fifty keys added after that pass

Wrapping the remaining literals added 50 keys, and they are **English in all
38 translated files**. `Tools/i18n.py fix` fills a missing key with the
English text, which is what keeps `check` green; it is not a translation and
does not pretend to be.

This is not a regression. Those strings were hard-coded English a commit
earlier, so nobody loses a translation they had — what changes is that they
are now *translatable*, and a translation pass has something to find. Run
`scan` and `check` after any such pass; the keys are listed under their own
source file in `en.lproj`, so the new ones are the sections named for the
popups and `Launcher ·`.

"Replaced every value" does not mean every value differs. Diff the two passes
and about three quarters are byte-identical, because most of a 159-string UI
is one- and two-word vocabulary with one rendering per language. What changed
tracks how much room a translator had:

| English key | Re-translated value differs |
|---|---:|
| 1 word | 16% |
| 2 words | 23% |
| 3-4 words | 30% |
| 5+ words | 49% |

That rising shape is what genuine re-translation looks like; carried-over
values would be indifferent to length. The other direction says the same
thing from the old side: against the import, the new files still match on
51% of one-word keys but on only 36 of 418 five-plus-word ones, and those 36
are formulaic ("Never check for updates (not recommended)"). No similarity
figure can prove independence -- two honest translations of "Once per week"
agree -- so the claim rests on how the files were made, which is recorded
here and in the commit, and the table is the corroboration.

### The translations are machine-written and unreviewed

None of the 38 has been read by a native speaker. The translators flagged
what they were least sure of: short labels that need the screen for context
("Clock" is the CPU's clock speed, "Figure" the menu bar shape that shows a
number), plural agreement in Czech, Croatian, Polish, Romanian, Russian,
Slovak, Slovenian, Ukrainian and Arabic -- where "%0 cores" became a label
and a count, "Ядер: %0", rather than a phrase -- and every term in Persian,
Bengali and Tamil, which macOS itself is not localised into. Correcting a
language you read is worth more than adding a new one.

---

## New hardware

Perch reads hardware, and the hardware changes under it. A new Apple silicon
generation arrives about once a year, and the way this app breaks on one is
not a crash — it is a reading that quietly goes missing, or worse, one that
reads zero because a key it expected was not there.

Three rules, and every reader is held to them.

**Discover, do not enumerate.** The SMC client walks the controller's own key
table rather than carrying a list of keys, because which keys exist differs by
model and firmware and a hard-coded table is wrong on the next Mac. The
performance levels come from `hw.nperflevels` and each level's own
`hw.perflevelN.name`, not from an assumption that there are two. The model
name comes from the device tree's `product-name`, so a Mac nobody has seen
reports itself correctly.

**Degrade to a dash, never to a zero.** A reading the machine does not answer
is nil all the way to the view, which draws "—". `GPUStats` looks each figure
up under several spellings and leaves it nil rather than guessing;
`levelLoads` returns nothing at all when the levels and the core count
disagree, because a mean over the wrong slice of cores is worse than no
figure. A fanless MacBook Air has no fan speed and that is not a bug — a fan
speed of 0 rpm would be.

**Be checkable on a Mac we do not have.** Nobody can test five generations:

```bash
cat Perch/UI/Localized.swift Perch/Settings/Preferences.swift \
    Perch/Monitor/Readings.swift Perch/Monitor/CPUReadings.swift \
    Perch/Monitor/MemoryReadings.swift Perch/Monitor/GPUStats.swift \
    Perch/Monitor/DiskReadings.swift Perch/Monitor/NetworkInfo.swift \
    Perch/Monitor/Temperature.swift Perch/Monitor/SMCKit.swift \
    Perch/Monitor/SensorReadings.swift Perch/System/DeviceInfo.swift \
    Tools/hardware-report.swift | swift -
```

`Tools/hardware-report.swift` runs every reader and prints what this machine
answered, marking anything absent as MISSING rather than printing a zero. It
is written to be pasted into an issue. Where a GPU reading is missing it also
dumps the driver's own `PerformanceStatistics` keys, because the spelling a
new driver uses is exactly the thing nobody here has — and adding it is then a
one-line change.

### Measured on an M2 (Mac14,2, macOS 26)

46 of 48 readings answered. The two that did not are both correct absences:
the SSID, which needs Location permission, and fan speed on a fanless Air.

### The ordering that everything about clusters rests on

`hw.perflevel0` is **Performance**, while `host_processor_info` lists
**efficiency** cores first. So the core array runs in the opposite order to
the perflevel index, and `levelLoads` reverses accordingly.

This was an assumption in a comment until it was measured. Loading exactly
`hw.perflevel0.logicalcpu` threads at `.userInteractive` — the QoS the
scheduler reserves for performance cores — put ~285 busy ticks on cores 4–7
against 83–123 on cores 0–3 of an M2. Efficiency cores are first. Had it been
the other way round, every Mac would have had its two cluster figures swapped,
with nothing to show for it on screen but two plausible numbers in the wrong
rows.

A three-level machine is the natural extension of the same rule and is the one
case nobody has been able to run. `hardware-report` shouts if it sees one.

### What is generation-sensitive, and what happens

| Reader | Sensitivity | On an unknown chip |
|---|---|---|
| `CPUReadings` | `hw.perflevelN` count and order | all levels reported, named by the kernel |
| `GPUStats` | driver key spellings | the figure is nil, the row shows "—" |
| `SensorReadings` | which SMC keys exist | walks the table; new keys appear by themselves |
| `Temperature` | HID page/usage constants | nil, and SMC temperatures still work |
| `MemoryReadings`, `DiskReadings`, `NetworkInfo` | none — kernel APIs that predate Apple silicon | unaffected |

---

## Adding a module

1. Write the reader in `Perch/Monitor/`, against public APIs.
2. Add invariant tests to `Tools/monitor-test.swift`, and check them with
   `Tools/run-tests.sh monitor`.
3. Conform a type to `PopupContent` and build its view from the pieces in
   `PopupSection.swift` — do not draw bespoke sections.
4. Register it in `NativeModules.all` while it is still a preview, and in
   `ModuleRegistry` once it ships.

The contract:

```swift
protocol PopupContent: AnyObject {
    var title: String { get }
    var menuBarLabel: String { get }
    func makeView() -> NSView
    func willShow()
    func didHide()
    func refresh()
    func settingsView() -> NSView?
}
```

`makeView()` is called once and the view kept — rebuilding it would throw away
chart history. `refresh()` runs about once a second **while the popup is
visible only**; anything expensive throttles itself inside it (the network
module runs `nettop` every fourth tick and re-reads interface details every
fifth).

---

## Conventions

Comments record decisions, not restatements — what was measured, what was
rejected, which API constraint forced the shape. Colours are validated rather
than chosen; widths are measured against the strings they must hold.

Names that used to collide with the framework -- `SystemStats`, `MenuBar`,
`ChartView`, `NetworkChartView`, `PopupWindow` -- are free now that it is
gone, but the independent equivalents keep their own names: `Readings`,
`ReadingPopup`, `MonitorBar`. Grep before naming a type; the tree is large
enough to collide with itself.

See `CLAUDE.md` for the rules that bind future contributors and AI agents.
