<p align="center">
  <img src="Perch/Supporting%20Files/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="120" alt="Perch icon">
</p>

<h1 align="center">Perch</h1>

<p align="center">
  A native macOS menu bar app launcher, window switcher, and system monitor — all in one.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?style=flat-square&logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/Release-1.0-purple?style=flat-square" alt="Release 1.0">
  <img src="https://img.shields.io/badge/No%20Telemetry-✓-brightgreen?style=flat-square" alt="No Telemetry">
</p>

<p align="center">
  <img src="docs/screenshots/menubar.png" width="347" alt="Perch in the menu bar: SSD, GPU, sensor, CPU and RAM readings coloured by load, with network speed">
</p>

<p align="center">
  <img src="docs/screenshots/monitor.png" width="860" alt="The CPU, Network, Memory and Disk popups">
</p>

---

## What is Perch?

**Perch** is a lightweight, native macOS app that lives entirely in your menu bar. It combines two things:

- 🚀 **App Launcher & Window Switcher** — a curated list of your apps, accessible via a Spotlight-style search panel or a single hotkey. Perch shows each app's real icon, a running indicator, and does the right thing on click — launch, focus, minimise, or restore.
- 📊 **System Monitor** — live CPU, RAM, disk, network, and temperature readings drawn directly in the menu bar, with a mini graph popup on click.

No Dock clutter, and no second app to run — the launcher and the monitor share
one process, and the menu bar shows only the readings you switch on.

---

## Features

### App Launcher
| App state | Click does |
|---|---|
| Not running | Launch it |
| Running, window behind | Bring it to front |
| Running and frontmost | Minimise it |
| Minimised or hidden | Restore + focus |
| Full screen | Shows a notice (macOS limitation) |
| Menu-bar-only app | Activate it |

- **Spotlight-style search panel** — `⌃Space` opens a floating search panel at the pointer. Type to fuzzy-filter, press Return or click to switch.
- **MRU ordering** — recently used apps float to the top automatically.
- **Trackpad gesture** — a three-finger double tap opens the search panel; four-finger is available too.
- **Per-app hotkeys** — assign `⌃1` … `⌃9` shortcuts to jump to specific apps instantly.
- **`⌃Tab` custom switcher** — right-click any result → **Add to ⌃Tab Switcher**, and `⌃Tab` then cycles *only* those apps, most recently used first. Mark the three or four you actually live in and the key stops walking through everything. Marked nothing? It falls back to recent apps, so the key never does nothing. (Can be turned off if it conflicts with your browser or terminal.)
  - If another app already owns `⌃Tab`, macOS gives it to whoever registered first and tells the loser nothing. Perch notices, switches the cycle to **`⌥Tab`** and says so on launch.
- **`⌃\`` toggle** — minimises the frontmost app; press again to restore it.

<p align="center">
  <img src="docs/screenshots/launcher.png" width="320" alt="The Ctrl+Space search panel listing running apps">
</p>

### System Monitor
Live readings drawn as compact widgets in the menu bar itself:

| Widget | What it shows |
|---|---|
| **CPU** | usage % |
| **RAM** | usage % |
| **Disk** | read/write speed |
| **Network** | ↑↓ throughput |
| **Temperature** | CPU die temp |

Click any widget in the menu to see a scrolling chart and detailed breakdown.

### Running Indicators
Every row in the search panel carries a dot for that app's window state:

```
●  Google Chrome      running, window on screen
○  Reminders          running, but minimised or hidden
   Firefox            not running
```

`⌃Space` is how you reach the list; apps in the `⌃Tab` cycle are marked `⌃⇥`.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌃Space` | Open / close the search panel |
| `⌃`` ` `` ` | Minimise frontmost app (press again to restore) |
| `⌃Tab` | Cycle to the previously used app |
| `⌃1` … `⌃9` | Jump directly to a pinned app (configured per-app) |

Every shortcut — including the search panel's own keys, the per-module popup
shortcuts and the Settings window — is listed in the
**[User Manual](docs/USER_MANUAL.md)**.

---

## Installation

### Download

One command. Paste it in Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/sagardn/Perch/main/Tools/install.sh | bash
```

It downloads the latest release, verifies the disk image, installs to
`/Applications` and launches it.

**Why a command and not a double-click?** Perch is signed ad hoc rather than
with a paid Apple Developer ID ($99/year), so macOS will not open it when it
arrives through a browser. Quarantine is attached by the program that downloads
a file, not by the file itself — `curl` does not attach it, so this path never
meets Gatekeeper.

<details>
<summary>If you downloaded the DMG with a browser and macOS blocked it</summary>

You will see **“Perch.app” Not Opened — Apple could not verify…**, offering only
*Move to Trash* and *Done*. Click **Done** — nothing is wrong with the app;
macOS is telling you it is not notarised.

On **macOS 15 and later**, the old right-click → Open trick no longer works.
Instead:

1. Drag Perch to **Applications** and try to open it once (you get the dialog above).
2. Open **System Settings → Privacy & Security**.
3. Scroll to **Security**. There is now a line saying *“Perch.app” was blocked…*
   with an **Open Anyway** button.
4. Click it, authenticate, then open Perch again and choose **Open**.

Or clear the flag on that one app from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Perch.app
```

</details>

### Build from Source

Requires **Xcode** (or Xcode Command Line Tools for the launcher only).

```bash
# Clone the repo
git clone https://github.com/sagardn/Perch.git
cd Perch

# Build with Xcode
open Perch.xcodeproj
# Product → Archive → Distribute App → Copy App
```

Move `Perch.app` to your `/Applications` folder and launch it.

> **Note:** There is no Homebrew formula for Perch.

### Uninstall

```bash
sh /Applications/Perch.app/Contents/Resources/Scripts/uninstall.sh
```

This quits Perch and removes:
- `Perch.app`
- Its preferences (the `com.sagar.perch` defaults) and data (`~/Library/Application Support/Perch`, caches, saved window state)
- The Accessibility and notification permissions macOS keeps for it, so a reinstall starts clean

Run it as yourself, not with `sudo`. Perch installs no helper or launch daemon,
so nothing it removes needs administrator rights.

If the app is already in the Trash, run it from the repo directly:
```bash
sh Tools/uninstall.sh
```

---

## Updates

Perch checks its own GitHub releases once per day and tells you when one is
newer. **Settings → Check for updates** changes the interval or turns it off.

*Silent* is offered but does exactly what it says: it downloads the release and
replaces the running app without asking. It is not the default for that reason.

### Releasing

Tag a version and CI does the rest:

```bash
# bump MARKETING_VERSION in Perch.xcodeproj first, then
git tag v1.0.1
git push origin v1.0.1
```

`.github/workflows/release.yaml` builds, packages `Perch.dmg` and publishes the
release with generated notes. The tag must match `MARKETING_VERSION` — the
workflow fails if it does not, because the updater compares the two and a
mismatched release could never be offered.

---

## Troubleshooting

### A hotkey does nothing

There is no "hotkey permission" in macOS, and nothing in System Settings grants
one — Perch registers its keys through Carbon, which needs no privilege at all.
When a key does nothing, it is almost always owned by something else: a global
hotkey belongs to whichever app registered it **first**, and the loser is told
nothing.

- **`⌃Tab`** — browsers, terminals and window managers all want this key. Perch
  now notices the collision, moves the app cycle to **`⌥Tab`**, and says so on
  launch.
- **Everything else** — if `⌃Space` or `` ⌃` `` are taken, Perch names them in a
  notice at launch. Quit whatever owns them, or turn Perch's off in Settings.
- **macOS itself** — check **System Settings → Keyboard → Keyboard Shortcuts…**
  for a system shortcut using the same combination.

### The hotkey fires, but the window does not move

That is **Accessibility**, which is a real permission and the only one Perch
needs to raise, minimise and restore windows:

**System Settings → Privacy & Security → Accessibility** → turn **Perch** on.

### It worked before an update, and stopped

macOS ties the Accessibility grant to the app's code signature. Perch is signed
ad hoc rather than with a paid Developer ID, so the signature changes with every
build — after an update the switch still *looks* on while the grant no longer
applies. Remove and re-add it:

1. **System Settings → Privacy & Security → Accessibility**
2. Select **Perch**, click **−**
3. Click **+**, choose `/Applications/Perch.app`, leave it switched **on**
4. Quit and reopen Perch

### Perch asks for permission at every login

It should never do that, and as of 1.0.9 it does not: Perch no longer asks for
anything at startup. It checks quietly, and only asks when you do something
that needs the permission, or when you click **Allow Accessibility…** in
Settings.

If you still see a dialog at every login, the login item is probably pointing
at the wrong copy of Perch. That happens when "Start at login" was switched on
while running a build from Xcode: macOS then starts *that* copy, which is
replaced by the next build, so its code signature changes and every grant is
invalidated again. Check which one is registered:

```bash
sfltool dumpbtm | grep -B6 'Bundle Identifier: com.sagar.perch' | grep URL:
```

If the path is not `/Applications/Perch.app`, repair it:

```bash
# tell the wrongly-registered copy to deregister itself, then register the real one
/path/to/that/copy/Contents/MacOS/Perch --unregister-login-item
open -a /Applications/Perch.app --args --register-login-item
```

Perch now refuses to register a login item for a bundle inside a build folder,
and says so on screen when it has been started from one.

### The trackpad gesture does not open the search

First check the finger count: **two-** and **three-finger** double taps are on
by default, four-finger is not. **Settings → Search & switcher** has a switch
for each.

This is not a permissions problem. Perch reads the finger count out of the
private `MultitouchSupport` framework, which is not an event tap, so Input
Monitoring does not apply — measured with that grant explicitly denied, the
touches still arrive. If the gesture does nothing at all, make sure
**Trackpad gesture opens the search** is on.

### No CPU temperature in the menu bar

Three things to check, in order:

1. **Is the Sensors module on?** Open Perch's settings and look at the sidebar.
   A Mac where it was switched off stays off — that is a saved preference. New
   installs enable it, pick a CPU temperature sensor automatically, and prefer
   one that is actually reporting.
2. **Is your menu bar full?** If you see a `«` near the left of the status
   items, macOS is hiding the ones that do not fit, newest first — so Perch's
   temperature can be running and invisible. Quit a menu bar app, or ⌘-drag
   items to reorder, and it appears. This is macOS, not Perch.
3. **Does this Mac report one at all?** Open the Sensors popup: if it lists
   *Average CPU* and *Hottest CPU*, the readings exist and the problem is one of
   the two above.

The sensor Perch picks by default is **Average CPU**, which the app computes
from whichever keys your Mac actually reports — so it works the same on M1
through M5 and on Intel, rather than depending on a per-generation key.

---

## Requirements

- **macOS 14 Sonoma** or newer — the settings window uses `NavigationSplitView`, and the bundled widget extension requires 14
- Only stable macOS releases are supported (not betas)
- **Accessibility permission** is required for window switching (Perch will prompt on first launch)

---

## Configuration

Apps are stored in a JSON config file, but you should rarely need to open it.
To add an app:

1. Press `⌃Space` to open the search panel
2. Right-click the app's row — or select it and press `→`
3. Choose **Add to My Apps**, or **Add an App…** to pick one from disk

**Edit Apps…** in that same menu opens the Perch Apps window: drag to reorder,
`－` to remove, and a field on each row to set its `⌃N` shortcut inline.

The file itself lives here, if you would rather edit it directly:

```
~/Library/Application Support/Perch/apps.json
```

```json
[
  { "name": "Chrome",   "bundleID": "com.google.Chrome",         "shortcut": "1" },
  { "name": "Terminal", "bundleID": "com.apple.Terminal",        "shortcut": "2" },
  { "name": "Slack",    "bundleID": "com.tinyspeck.slackmacgap", "shortcut": "3" }
]
```

---

## Settings

### Application settings

The Settings window — the **⚙︎** in any module popup — covers updates,
temperature units, dock icon, start at login, menu bar position, macOS widgets
and combined modules, plus export, import and reset. Full reference in the
[User Manual](docs/USER_MANUAL.md#application-settings).

### Search & switcher settings

**Settings → Search & switcher** has a switch for each of these, plus
**Allow Accessibility…**. They are also plain UserDefaults keys, if you prefer
the command line — change one, then restart Perch:

| Setting | Key | Default |
|---|---|---|
| Search opens at pointer | `openAtPointer` | On |
| Hide on outside click | `hideOnOutsideClick` | On |
| ⌃Tab cycle | `cycleHotkeyEnabled` | On |
| Trackpad gesture | `gestureEnabled`, `gestureFingerCounts`, `gestureTaps` | On, two- **and** three-finger double tap |

```bash
# four-finger double tap only, leaving two and three to macOS
defaults write com.sagar.perch gestureFingerCounts -array 4
```

---

## Privacy

No analytics, no telemetry, no crash reporting, no account. Perch makes exactly
two kinds of outbound request, both of which you can turn off:

- **`https://api.github.com/repos/sagardn/Perch/releases/latest`** — the update
  check, once per day. Set *Check for updates* to **Never** in Settings and it
  is never contacted. Nothing about your machine is sent; it is a plain read of
  the public releases endpoint.
- **`https://api.country.is/`** — your public IP and its two-letter country code
  (for the flag beside it), shown in the Network popup and only fetched while
  that popup is open. It returns those two fields and nothing else: no city, no
  coordinates, no ISP.

The Network module's connectivity check pings a host of your choosing
(`google.com` by default, configurable in that module's settings) when
connectivity history is enabled.

---

## FAQs

<details>
<summary><strong>How do I change the order of menu bar icons?</strong></summary>

macOS controls the order, not Perch. To rearrange: hold `⌘` and drag the icon to the position you want.

</details>

<details>
<summary><strong>Perch icons don't appear in the menu bar</strong></summary>

macOS 26 introduced a privacy control under **System Settings → Menu Bar**. Toggle **Perch** ON there.

</details>

<details>
<summary><strong>How do I reduce Perch's CPU or energy impact?</strong></summary>

Disable the system monitor modules you don't need. Sensors is the most expensive by some way; disabling it can cut Perch's CPU usage by half.

</details>

<details>
<summary><strong>Desktop widgets not showing data</strong></summary>

Enable **macOS widgets** in Perch Settings. It's off by default to avoid overloading `chronod`.

</details>

<details>
<summary><strong>Sensors show incorrect CPU/GPU core count</strong></summary>

Sensor names are thermal zones, not individual cores. Apple changes SMC keys with each SoC. "CPU Efficient Core 1" means one sensor in the efficiency cluster, not a specific core.

</details>

---

## Project Structure

```
Perch/
├── Perch/                      # the app itself
│   ├── AppDelegate.swift       # module list, launcher start-up, updater
│   ├── Launcher/               # the app-switcher half
│   │   ├── SearchPanel.swift   # Ctrl+Space panel: search, arrow menu, right-click
│   │   ├── WindowControl.swift # Accessibility: raise, minimise, new window
│   │   ├── Recents.swift       # most-recently-used ordering
│   │   ├── Hotkey.swift        # Carbon hotkeys (Ctrl+Space, Ctrl+1-9, Ctrl+`)
│   │   ├── Gesture.swift       # trackpad taps via MultitouchSupport
│   │   └── AppEntry.swift      # apps.json, the configured list
│   ├── Monitor/                # the system-monitor half: one folder, no
│   │                           # framework. Readers, popups, tiles, settings
│   │                           # pages and the menu bar for CPU, GPU, RAM,
│   │                           # Disk, Network and Sensors
│   ├── Update/                 # release feed, checksum, install, the window
│   ├── Settings/               # Preferences, the login item, the General pane
│   ├── System/                 # device information and the Dashboard
│   ├── UI/                     # controls, alerts, links, logging, localisation
│   ├── Views/                  # the settings window and the first-run window
│   └── Supporting Files/       # Info.plist, entitlements, 41 languages
├── LaunchAtLogin/              # the login item helper, the one dependency
├── Tools/                      # test suites, icon generator, bench,
│                               # install.sh, uninstall.sh, the i18n check
├── docs/USER_MANUAL.md         # the long-form manual
└── .github/workflows/          # build, release on a v* tag, linter, i18n
```

A metric is drawn in **four** independent places — the menu bar widget, the
popup, the dashboard portal and the module's settings page. Changing a colour or
a marker in one leaves the other three alone; that is the single most common
surprise in this codebase.

---

## Contributing

Pull requests are welcome. Perch is MIT licensed — read it, learn from it, fork
it, and if you improve something, send it back.

**Good first contributions:** translations, a new module or widget, sensor
keys for Macs I cannot test on, and bug fixes with a note on how to reproduce
what was broken.

On translations specifically, so you know what you are walking into: every
string lives in `Perch/Supporting Files/*.lproj/Localizable.strings`, 159 keys
per language, and `python3 Tools/i18n.py` checks the 41 files are in step
while `python3 Tools/i18n.py scan` checks them against the code. Both run in
CI. The translations are machine-written and nobody who reads those languages
has reviewed them yet, so correcting a language you actually read is worth
more than adding a new one. And the popups themselves are still largely
English: 122 strings reach a view without passing through `localized()`, and
wrapping those is the bigger win. `docs/ARCHITECTURE.md` ▸ Localisation has
the counts.

**Before a large change,** open an issue first — not as a formality, but so you
do not spend a weekend on something that turns out to conflict with work already
in progress. Small fixes need no discussion; just send them.

**What helps a PR get merged:**

- One change per pull request. Two unrelated fixes are two PRs.
- Say what the change does and why in the description. The *why* is the part a
  reviewer cannot reconstruct from the diff.
- Keep the surrounding style. SwiftLint runs on every push (`.swiftlint.yml`);
  if a rule genuinely gets in the way, scope a `swiftlint:disable` and write
  down the reason rather than reformatting readable code.
- Build it first: `xcodebuild -project Perch.xcodeproj -scheme Perch build`.
  CI does the same on macOS 26, and the glass effects need that SDK.

Not sure where to start? Open an issue describing what you would like to change
and I will point you at the right file.

---

## License

[MIT](LICENSE) © 2026 Sagar.
