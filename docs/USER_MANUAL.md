# Perch — User Manual

Perch is two apps sharing one menu bar icon:

- **a system monitor** — CPU, GPU, memory, disk, network, battery, sensors,
  Bluetooth and clock readings drawn as widgets in the menu bar, each with a
  popup of detail behind it. This half is the module system.
- **an app launcher and switcher** — a Ctrl+Space search panel, per-app
  hotkeys, a minimize/restore key and a trackpad gesture.

The two halves know nothing about each other, so you can use either one and
ignore the other: turn every module off and Perch is a launcher; ignore the
hotkeys and it is a system monitor.

---

## Contents

- [First run](#first-run)
- [Keyboard shortcuts](#keyboard-shortcuts) — the complete list
- [The search panel](#the-search-panel)
- [Managing your app list](#managing-your-app-list)
- [The trackpad gesture](#the-trackpad-gesture)
- [Launcher settings](#launcher-settings)
- [The system monitor](#the-system-monitor)
- [Application settings](#application-settings)
- [Where Perch keeps things](#where-perch-keeps-things)
- [Troubleshooting](#troubleshooting)
- [Uninstalling](#uninstalling)

---

## First run

Perch has no dock icon by default — it lives in the menu bar. If no module is
showing a widget, the Settings window opens by itself at launch so there is
something to click.

### Permissions

| Permission | What needs it | Where to grant it |
|---|---|---|
| **Accessibility** | Minimizing, restoring, raising a specific window, and "New Window". *Raising* an app needs no permission, so the launcher partly works without it. | System Settings → Privacy & Security → Accessibility |
| **Input Monitoring** | The trackpad gesture only. | System Settings → Privacy & Security → Input Monitoring |
| **Menu Bar** (macOS 26 and newer) | Showing any menu bar item at all. | System Settings → Menu Bar → turn Perch **on** |

Perch asks for Accessibility on first launch and shows a HUD explaining what is
missing. The global hotkeys are registered through Carbon rather than an event
tap, so **they keep working even before Accessibility is granted** — you get a
HUD instead of silence.

---

## Keyboard shortcuts

### Global — the launcher

These work from any app.

| Shortcut | Action |
|---|---|
| **⌃Space** | Open / close the search panel |
| **⌃`** | Minimize the frontmost window. Press again to bring back the last window you put away. |
| **⌃Tab** | Step back through recently used apps, one press per step. On by default — [it can be turned off](#launcher-settings). |
| **⌃1** … **⌃9**, **⌃0** | Jump straight to the app holding that shortcut — no panel, no menu |

A per-app shortcut is a single character pressed with Control. The characters
Perch accepts are `0`–`9`, `` ` ``, `;` and `space`; anything else is ignored.

> **Careful with `` ` ``, `;` and `space`.** ⌃Space and ⌃` are already the panel
> and the minimize key. macOS gives a hotkey to whoever registers it first, so
> assigning one of those to an app means one of the two silently loses (the
> loser is logged, not shown).

**⌃Tab is a global hotkey**, which means it is taken away from every app that
uses it for tab switching — Chrome, Safari, terminals. If that bites, turn it
off; see [Launcher settings](#launcher-settings).

### What a shortcut or a ↩ actually does

Activating an app is a *toggle*, so the same key both goes to an app and puts it
away:

| The app is… | What happens |
|---|---|
| not running | it launches (a HUD says so if it is not installed) |
| hidden | it unhides and comes forward |
| minimized | it restores and comes forward |
| running but not frontmost | it comes forward |
| already frontmost | its window minimizes |
| already frontmost and full-screen | a HUD: macOS cannot minimize a full-screen window |
| marked **launch-only** (Launchpad) | it only ever comes forward, never minimizes |

### Inside the search panel

| Key | Action |
|---|---|
| *(type)* | Filter the list |
| **↓** or **⇥** | Next result |
| **↑** or **⇧⇥** | Previous result |
| **↩** | Activate the selected app (the toggle above) |
| **→** | Open the selected row's options menu — only once the caret has nothing left to walk through, so → still works as a caret key while you are editing the query |
| **⎋** | Close the panel |
| **⌃Space** | Close the panel |

⇥ walks the list the way ⌘⇥ does, so switching apps is one key held and tapped
rather than a reach for the arrows. With an empty query the list is already in
most-recently-used order, so ⌃Space ⇥ ↩ goes back one app.

The mouse: **click** a row to activate it, **right-click** it for the options
menu (with Quit first), or click the **▸** at the row's right edge for the same
menu without Quit at the top.

### Per-module popup shortcuts

Every module can be given its own global shortcut that opens that module's
popup — any combination of ⌃ ⇧ ⌘ ⌥ plus a key.

Set it in **the module's own settings → Keyboard shortcut**, by recording the
combination you want. These are yours to choose; Perch ships none.

### The Settings window

| Shortcut | Action |
|---|---|
| **⌘W** | Close the Settings window |
| **⌘Q** | Also closes the Settings window — it does **not** quit Perch |
| **⌘M** | Minimize the Settings window |

To quit Perch, use the **power button** in the Settings window footer.

---

## The search panel

⌃Space (or the trackpad gesture) brings up a Spotlight-like panel. By default it
appears **at the pointer**, not centred — that is how the menu it replaced
behaved, and it can be changed.

**What it lists:** every app on your list, plus every regular app currently
running, deduplicated. So an app does not have to be on your list to be
switched to — the list is for ordering, pinning and hotkeys.

**How it sorts:**

1. **Pinned** entries first, always (Launchpad is pinned out of the box: it is a
   launcher you reach for, not an app you "use", so recency would always bury it).
2. With a query — **relevance**, recency breaking ties.
3. With no query — **most recently used**, so the app you just came from is the
   top hit.

Each row shows the app icon, its name and a dot for its window state.

### The options menu

Right-click a row, or press → , or click the ▸ arrow:

| Item | Notes |
|---|---|
| **Open** / **Bring to Front** | Depending on whether it is running |
| **New Window** | Presses the app's own New Window menu item. A HUD says so if the app has none. |
| **Windows** | Listed when the app has more than one. ● is visible, ○ is minimized. Pick one to raise it. |
| **Restore** / **Minimize** / **Hide** | Whichever applies to the current state |
| **Quit** | First in the menu on a right-click |
| **Add to / Remove from My Apps** | Puts the app on, or takes it off, your list |
| **Reveal in Finder** | |
| **Copy Bundle ID** | |
| **Add an App…** | File picker; several at once is fine |
| **Edit Apps…** | Opens the Perch Apps window |

The panel has no status-bar menu of its own, so this menu is where the app list
gets managed from.

---

## Managing your app list

**Edit Apps…** (from any row's options menu) opens the **Perch Apps** window:

- **drag** rows to reorder them
- **＋** adds a running app, or browses for one on disk
- **－** removes the selected row
- the small field on the right of each row sets that app's **⌃ shortcut** —
  type one character, or clear it for none

Changes save immediately and hotkeys re-register on the spot, so a removed app
stops answering its ⌃digit straight away.

### apps.json

The list is a JSON file rather than something baked into the binary, so adding
an app can be an edit and a reload rather than a rebuild:

```
~/Library/Application Support/Perch/apps.json
```

It is written with the defaults the first time Perch runs. Each entry:

| Field | Type | Meaning |
|---|---|---|
| `name` | string | What the row says |
| `bundleID` | string | The app's bundle identifier |
| `shortcut` | string or absent | One character, pressed with Control. `"2"` means ⌃2 goes straight here. |
| `launchOnly` | bool | Only ever launch or come forward, never minimize. Launchpad is one of these. |
| `pinned` | bool | Held at the top of the panel regardless of recency or search score |

If the file cannot be read, Perch logs the reason and falls back to the
defaults rather than starting empty.

---

## The trackpad gesture

A trackpad tap opens the search panel. **Three-finger double tap** by default,
with **four-finger** available alongside it in **Settings → Search & switcher**.

Two fingers is deliberately not offered. macOS makes a two-finger tap a
secondary click and a two-finger double tap Smart Zoom, and this layer can only
observe touches — it cannot swallow them — so every search also fired a
right-click and a zoom.

There is no public API for a global trackpad gesture — the public NSEvent
gesture events only reach the frontmost app's own views — so Perch reads the
private `MultitouchSupport` framework, the same route BetterTouchTool takes.
Deliberately accepted consequences:

- it is undocumented, and Apple can change or remove it
- an app using it cannot ship through the Mac App Store
- it reads finger counts, not events, so it needs no permission (measured on
  macOS 27 with Input Monitoring explicitly denied: 459 contact frames in six
  seconds, and no dialog)

To keep the risk small, Perch reads *only* the finger count it is handed, and
never parses the touch struct whose layout changes between macOS releases.

**What counts as a tap:** all fingers down and up again in under 0.25 s, with
the peak finger count being one of the counts that are switched on. A second
tap has to land within 0.45 s **and use the same number of fingers** — a
three-finger tap followed by a four-finger tap is two gestures, not a double
tap. Multi-finger *swipes* keep fingers down far longer, which is what keeps
Mission Control and space switching out of it.

> **macOS claims three-finger taps too** — a three-finger tap is Look Up, and
> this layer cannot swallow it, so it still fires. It is far less disruptive
> than the two-finger overlap that got two fingers dropped. If it bothers you,
> switch three off and leave **four-finger double tap** on: four is the one
> count nothing stock claims.

**No permission is asked for.** Reading the finger count out of
MultitouchSupport is not an event tap, so Input Monitoring does not govern it —
verified with the grant denied. If the gesture does nothing, the cause is the
finger count, not a permission: check which counts are switched on.

---

## Launcher settings

> These live in **Settings → Search & switcher**. The search panel itself is
> reached by hotkey or by the trackpad gesture; there is no menu bar item for
> it.

The launcher half has **no settings UI in the merged app**. These live in
UserDefaults, under the domain `com.sagar.perch`, and are read at launch —
change one, then **restart Perch**.

| Key | Type | Default | What it does |
|---|---|---|---|
| `gestureEnabled` | bool | `true` | Whether the trackpad gesture opens the panel |
| `gestureFingerCounts` | array of int | `[2, 3]` | Finger counts the gesture answers to; 2, 3 and 4 are allowed |
| `gestureTaps` | int | `2` | Taps the gesture wants |
| `cycleHotkeyEnabled` | bool | `true` | Whether ⌃Tab cycles recent apps |
| `openAtPointer` | bool | `true` | Panel opens at the pointer; `false` centres it |
| `hideOnOutsideClick` | bool | `true` | Panel closes when it loses focus, as Spotlight does. `false` keeps it up while you click around elsewhere — ⎋ and ⌃Space still close it. |

```bash
# four-finger double tap only, leaving two and three to macOS
defaults write com.sagar.perch gestureFingerCounts -array 4

# give Ctrl+Tab back to your browser
defaults write com.sagar.perch cycleHotkeyEnabled -bool false

# centre the search panel instead of following the pointer
defaults write com.sagar.perch openAtPointer -bool false

# then restart Perch
```

To read one back: `defaults read com.sagar.perch gestureFingerCounts`.

---

## The system monitor

### Modules

| Module | Reads |
|---|---|
| **CPU** | Utilization, per-core load, frequency, top processes, temperature |
| **GPU** | Utilization, temperature, fan, render/tiler usage |
| **RAM** | Used / free / cached, pressure, swap, top processes |
| **Disk** | Free space, read/write activity, SMART where available |
| **Network** | Upload/download, interface, local and public IP, top processes |
| **Battery** | Charge, time remaining, cycles, health, power source |
| **Sensors** | Temperature, voltage, power and current from the SMC; fan control (legacy) |
| **Bluetooth** | Connected devices and their battery levels |
| **Clock** | One or more time zones |

A **Remote** module exists in the source but is disabled in this fork — the
protocol, the accounts and the servers are upstream's, and a fork has nothing
to talk to.

Sensors and Bluetooth are the expensive ones. If you want to cut Perch's energy
impact, turn those off first — it can halve the CPU cost.

### Widgets

Each module draws one or more widgets in the menu bar. Turn them on per module
in that module's settings. The kinds:

| Widget | Shows |
|---|---|
| **Mini** | A label and one number |
| **Line chart** | A rolling line of recent values |
| **Bar chart** | One bar per core, disk or interface |
| **Pie chart** | A filled ring |
| **Network chart** | Up and down as two stacked lines |
| **Speed** | Upload/download figures, with or without an arrow |
| **Battery** | A battery glyph, optionally with the percentage |
| **Battery details** | Time remaining or percentage as text |
| **Memory** | Used and free side by side |
| **Sensors** | A stack of chosen sensor readings |
| **Label** | A vertical two-line label to prefix another widget |
| **Tachometer** | A dial |
| **State** | A dot whose colour tracks a threshold |
| **Text** | A formatted line you compose yourself |

Widgets are separate menu bar items, so **macOS decides their order**, not
Perch. To rearrange: hold **⌘** and drag the icon along the menu bar.

### Popups

**Click a widget** — left or right — to open its popup. In the popup header:

- **⚙︎ gear** — open that module's settings
- **✕** — close the popup

### Combined modules

Turn **Combined modules** on to fold several modules into a single menu bar
item, with a chosen order, spacing, an optional separator, and an optional
combined popup showing all of them at once.

---

## Application settings

The Settings window has a sidebar: **Dashboard**, one entry per module, and
**Settings** for everything app-wide.

### Settings

| Setting | Default | Notes |
|---|---|---|
| **Check for updates** | Once per day | Also: At start, Once per week, Once per month, Never, and **Silent**. |
| **Temperature** | System | Celsius / Fahrenheit / System |
| **Show icon in dock** | Off | Perch is a menu bar app; this gives it a dock icon too |
| **Start at login** | Off | |
| **Keep the menubar items position** | Off | Remembers where each widget sat, rather than letting macOS reshuffle |
| **macOS widgets** | Off | Needed for the desktop/Notification Centre widgets. Off by default because the system process that carries the data (`chronod`) struggles with the load. |
| **Combined modules** | Off | Plus module selector, **Spacing**, **Separator** and **Combined details** |
| **Export settings** | — | Writes your whole configuration to a file |
| **Import settings** | — | Reads one back |
| **Reset settings** | — | Back to defaults, after a confirmation |
| **Uninstall fan helper** | — | Removes the privileged SMC helper |
| **Stress tests** | — | Loads efficiency, performance or "super" cores, or the GPU, so you can watch the readings move |

> **"Silent" is not a quiet check.** It downloads the release and installs it,
> replacing the running application without asking. The default is a daily
> check that tells you and waits.

### The footer

| Button | Action |
|---|---|
| ♥ **Support** | Opens the Ko-fi page |
| 🐜 **Report a bug** | Opens a new GitHub issue |
| ⏸ **Pause** | Disables every module and leaves a single Perch icon in the menu bar; click it to reopen Settings. Press again to resume — the modules that were on come back on. |
| ⏻ | Quits Perch |

Modules with a preview also get a preview toggle in the window's toolbar,
beside the enable switch.

---

## Where Perch keeps things

| Path | What |
|---|---|
| `~/Library/Application Support/Perch/apps.json` | The launcher's app list |
| `com.sagar.perch` (UserDefaults) | Every setting — both halves |
| `~/Library/Containers/…WidgetsExtension…` | The macOS widget extension's container |
| `/Library/PrivilegedHelperTools/com.sagar.perch.SMC.Helper` | The SMC helper, if fan control was used |
| `/Library/LaunchDaemons/com.sagar.perch.SMC.Helper.plist` | Its launch daemon |

Perch collects no telemetry or analytics. The only external requests are the
update check against this repository's releases, and `https://ifconfig.co/ip`
for the public IP shown in the Network popup — made only when that popup asks
for it. `ifconfig.co` runs [echoip](https://github.com/mpolden/echoip), which is
MIT licensed and self-hostable if you would rather not depend on someone else's
server; repoint the endpoint in `Perch/Monitor/NetworkInfo.swift`.

---

## Troubleshooting

**No Perch icons in the menu bar at all.** macOS 26 added a privacy control:
System Settings → Menu Bar → turn Perch on. This is almost always the cause if
Perch is running with a module enabled and a widget active.

**Nothing minimizes; apps only come forward.** Accessibility is not granted.
Raising a window needs no permission, minimizing one does.

**The gesture does nothing.** Check Input Monitoring. If Perch could not read
the trackpad at all it will have turned the setting off and said so.

**⌃Tab stopped working in my browser.** That is Perch holding it globally.
`defaults write com.sagar.perch cycleHotkeyEnabled -bool false`, then restart.

**A ⌃digit shortcut does nothing.** Another app registered that hotkey first —
macOS gives it to whoever asked first. Pick a different character in Perch Apps.

**"macOS can't minimize a full-screen window."** It cannot, and hiding the app
instead was tried and rejected: ⌘H tears down the full-screen space, after
which the app reports no windows and nothing can bring it back.

**Desktop widgets show no data.** Turn **macOS widgets** on in Settings.

**Perch uses too much CPU / battery.** Disable modules you do not need,
starting with Sensors and Bluetooth.

**Sensors show the wrong core count.** CPU/GPU sensors are thermal zones, not
cores. "CPU Efficient Core 1" is one sensor inside the efficiency cluster, not
one core's temperature.

**Fan control is odd.** It is in legacy mode: no updates, no fixes. It stays in
because it still works acceptably on older Macs.

---

## Uninstalling

Run the script bundled with the app, as yourself rather than with `sudo` —
Perch installs no helper, so nothing it removes needs administrator rights:

```bash
sh /Applications/Perch.app/Contents/Resources/Scripts/uninstall.sh
```

It quits Perch and removes `Perch.app`, the application data and preferences
listed above, and the Accessibility and notification permissions macOS keeps
for it. If the app has already
gone to the Trash, the same script can be run from the repository:

```bash
sh Tools/uninstall.sh
```
