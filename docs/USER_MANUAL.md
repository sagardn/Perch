# Perch — User Manual

Perch is two apps sharing one process:

- **a launcher and switcher** — a ⌃Space search panel, per-app hotkeys, your
  own ⌃Tab cycle, a minimise/restore key and a trackpad gesture.
- **a system monitor** — CPU, GPU, memory, disk, network and sensor readings
  drawn in the menu bar, each with a popup of detail behind it.

The two halves know nothing about each other, so you can use either one and
ignore the other: switch every module off and Perch is a launcher; ignore the
hotkeys and it is a system monitor.

---

## Contents

- [First run](#first-run)
- [Keyboard shortcuts](#keyboard-shortcuts) — the complete list
- [The search panel](#the-search-panel)
- [Managing your app list](#managing-your-app-list)
- [The trackpad gesture](#the-trackpad-gesture)
- [The system monitor](#the-system-monitor)
- [Settings](#settings)
- [Where Perch keeps things](#where-perch-keeps-things)
- [Privacy](#privacy)
- [Troubleshooting](#troubleshooting)
- [Uninstalling](#uninstalling)

---

## First run

Perch has no Dock icon by default — it lives in the menu bar. If no module has
anything to show in the menu bar, the Settings window opens by itself at launch
so there is something to click.

### Permissions

| Permission | What needs it | Where to grant it |
|---|---|---|
| **Accessibility** | Minimising, restoring and raising a specific window, and **New Window**. *Bringing an app forward* needs no permission, so the launcher partly works without it. | System Settings → Privacy & Security → Accessibility, or **Settings → Search & switcher → Window control → Allow…** |
| **Input Monitoring** | Module popup shortcuts only, and only once you set one. | System Settings → Privacy & Security → Input Monitoring |
| **Menu Bar** (macOS 26 and newer) | Showing any menu bar item at all. | System Settings → Menu Bar → turn Perch **on** |

Perch does not ask for anything at launch. It checks quietly, and asks for
Accessibility only when you do something that needs it. The global hotkeys are
registered through Carbon rather than an event tap, so **they work before
Accessibility is granted** — you get a notice instead of silence.

The trackpad gesture needs no permission at all; see
[The trackpad gesture](#the-trackpad-gesture).

> **Updating can make Accessibility look granted when it is not.** macOS ties
> the grant to the app's code signature, and Perch's ad-hoc signature changes
> with every build. If window control stops working after an update, select
> Perch in the Accessibility list, click **−**, then grant it again.

---

## Keyboard shortcuts

### Global — the launcher

These work from any app.

| Shortcut | Action |
|---|---|
| **⌃Space** | Open / close the search panel |
| **⌃`** | Minimise the frontmost window. Press again to bring back the last window you put away. |
| **⌃Tab** | Cycle the apps you marked for it, most recently used first. With nothing marked, it cycles recent apps. On by default — [it can be turned off](#search--switcher). |
| **⌃1** … **⌃9**, **⌃0** | Jump straight to the app holding that shortcut — no panel, no menu |

A per-app shortcut is a single character pressed with Control. The characters
Perch accepts are `0`–`9`, `` ` ``, `;` and `space`; anything else is ignored.

> **Careful with `` ` ``, `;` and `space`.** ⌃Space and ⌃` are already the panel
> and the minimise key. macOS gives a hotkey to whoever registers it first, so
> assigning one of those to an app means one of the two silently loses.

**⌃Tab is a global hotkey**, so while Perch holds it, browsers and terminals
lose it for tab switching. If another app registered ⌃Tab first, Perch notices,
moves its cycle to **⌥Tab** and says so at launch. To give ⌃Tab back entirely,
switch the cycle off in [Settings → Search & switcher](#search--switcher).

### Window snapping

Moves the frontmost window. Needs Accessibility, like minimising does.

| Shortcut | Puts the window |
|---|---|
| **⌃⌥←** / **⌃⌥→** | In the left / right half. Press again for two thirds, again for one third, again for half. |
| **⌃⌥↑** / **⌃⌥↓** | In the top / bottom half, cycling the same way |
| **⌃⌥U** **⌃⌥I** **⌃⌥J** **⌃⌥K** | In the top-left, top-right, bottom-left, bottom-right quarter |
| **⌃⌥↩** | Over the whole usable screen (not full screen: the menu bar and Dock stay) |
| **⌃⌥C** | In the centre, at its current size |
| **⌃⌥⌫** | Back where it was before Perch first moved it |
| **⌃⌥⌘←** / **⌃⌥⌘→** | On the previous / next display, at the same place and proportion |

These are Rectangle's keys. If Rectangle (or another window manager) is
running, it owns them, and Perch says which it could not claim. To give them
all back:

```bash
defaults write com.sagar.perch windowSnapping -bool false
```

then restart Perch.

### What a shortcut or a ↩ actually does

Activating an app is a *toggle*, so the same key both goes to an app and puts it
away:

| The app is… | What happens |
|---|---|
| not running | it launches (a notice says so if it is not installed) |
| hidden | it unhides and comes forward |
| minimised | it restores and comes forward |
| running but not frontmost | it comes forward |
| already frontmost | its window minimises |
| already frontmost and full-screen | a notice: macOS cannot minimise a full-screen window |
| marked **launch-only** (Launchpad) | it only ever comes forward, never minimises |

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

### Module popup shortcuts

Each monitor module can have a global shortcut that opens its popup. Perch ships
none, and there is no recorder in Settings yet, so a shortcut is set from
Terminal. It is stored as a list of virtual key codes: the modifiers first, in
the order **⌃ 59, ⇧ 60, ⌘ 55, ⌥ 58**, then the key.

```bash
# ⌃⌥C opens the CPU popup (C is key code 8)
defaults write com.sagar.perch CPU_popupShortcut -array 59 58 8

# remove it again
defaults delete com.sagar.perch CPU_popupShortcut
```

The keys are `CPU_popupShortcut`, `GPU_popupShortcut`, `RAM_popupShortcut`,
`Disk_popupShortcut`, `Network_popupShortcut` and `Sensors_popupShortcut`.
Restart Perch after changing one. A shortcut that lists the modifiers in any
other order never matches.

Setting the first shortcut is what makes macOS ask for **Input Monitoring**:
watching for a key pressed in another app needs it. With no popup shortcut set,
Perch does not watch the keyboard at all.

### The Settings window

| Shortcut | Action |
|---|---|
| **⌘W** | Close the Settings window |
| **⌘Q** | Also closes the Settings window — it does **not** quit Perch |
| **⌘M** | Minimise the Settings window |

To quit Perch, use the **power button** in the Settings window footer.

---

## The search panel

⌃Space (or the trackpad gesture) brings up a Spotlight-like panel. By default it
appears **at the pointer**, not centred; that can be changed in
[Settings](#search--switcher).

**What it lists:** every app on your list, plus every regular app currently
running, deduplicated. So an app does not have to be on your list to be
switched to — the list is for ordering, pinning and hotkeys.

**How it sorts:**

1. **Pinned** entries first, always (Launchpad is pinned out of the box: it is a
   launcher you reach for, not an app you "use", so recency would always bury it).
2. With a query — **relevance**, recency breaking ties.
3. With no query — **most recently used**, so the app you just came from is the
   top hit.

Each row shows the app icon, its name and a dot for its window state: ● running
with a window on screen, ○ running but minimised or hidden, nothing when it is
not running. Apps in your ⌃Tab cycle are marked `⌃⇥`.

### The options menu

Right-click a row, or press → , or click the ▸ arrow:

| Item | Notes |
|---|---|
| **Open** / **Bring to Front** | Depending on whether it is running |
| **New Window** | Presses the app's own New Window menu item. A notice says so if the app has none. |
| **Windows** | Listed when the app has more than one. ● is visible, ○ is minimised. Pick one to raise it. |
| **Restore** / **Minimise** / **Hide** | Whichever applies to the current state |
| **Quit** | First in the menu on a right-click |
| **Add to / Remove from ⌃Tab Switcher** | Puts the app in, or takes it out of, the ⌃Tab cycle |
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
| `launchOnly` | bool | Only ever launch or come forward, never minimise. Launchpad is one of these. |
| `pinned` | bool | Held at the top of the panel regardless of recency or search score |

If the file cannot be read, Perch logs the reason and falls back to the
defaults rather than starting empty.

---

## The trackpad gesture

A trackpad tap opens the search panel. **Three-finger double tap** by default,
with **four-finger** available alongside it in
[Settings → Search & switcher](#search--switcher).

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
- it reads finger counts, not events, so it needs no permission (measured with
  Input Monitoring explicitly denied: 459 contact frames in six seconds, and no
  dialog)

To keep the risk small, Perch reads *only* the finger count it is handed, and
never parses the touch struct whose layout changes between macOS releases.

**What counts as a tap:** all fingers down and up again in under 0.25 s, with
the peak finger count being one of the counts that are switched on. A second
tap has to land within 0.45 s **and use the same number of fingers** — a
three-finger tap followed by a four-finger tap is two gestures, not a double
tap. Multi-finger *swipes* keep fingers down far longer, which is what keeps
Mission Control and space switching out of it.

> **macOS claims three-finger taps too** — a three-finger tap is Look Up, and
> this layer cannot swallow it, so it still fires. If it bothers you, switch
> three off and leave **four-finger double tap** on: four is the one count
> nothing stock claims.

---

## The system monitor

### Modules

Six modules, each switched on or off in the Settings sidebar:

| Module | In the menu bar by default | In its popup |
|---|---|---|
| **CPU** | total load | load history, every core (efficiency and performance clusters apart), user/system split, load average, temperature, limits when macOS is throttling, top processes |
| **GPU** | utilisation | utilisation history, renderer and tiler, memory in use, every accelerator on a Mac with more than one |
| **RAM** | used % | breakdown bar (app, wired, compressed, cached, free), memory pressure, swap, top processes |
| **Disk** | used % of the watched volume | capacity bar, read/write activity, every other volume, per-device totals |
| **Network** | upload and download | online status and latency, Wi-Fi signal, traffic history, reachability, local IP, top processes |
| **Sensors** | the watched sensor | every temperature, voltage, current, power and fan reading your Mac publishes, grouped by kind |

Sensors is the expensive one: reading every sensor walks the whole controller
table. If you want to cut Perch's energy use, switch it off first.

### Menu bar shapes

Each module draws one or more shapes, chosen on its page in Settings. Not every
shape suits every reading, so each module offers only the ones it can fill:

| Shape | Shows |
|---|---|
| **Name** | The module's short label |
| **Figure** | A caption over one number — the default for most modules |
| **Line chart** | A rolling line of recent values |
| **Bar chart** | One bar per core |
| **Ring** | A filled ring, split into parts where the reading has them |
| **Gauge** | A dial |
| **Used and free** | Two figures stacked |
| **Rates** | Upload and download, each with its arrow |
| **Traffic chart** | Upload above a line, download below it |

Numbers are coloured by how hard the reading is working — **teal** when calm,
**amber** when busy, **red** when it needs you — and turn bold once they are
flagged. Each module judges by its own scale: a disk is flagged at 90% full,
not 50%; memory follows macOS's own memory pressure rather than the percentage;
a temperature is flagged at 85 °C. The three colours, and whether the menu bar
is coloured at all, are in [Settings → Colours](#colours).

Separate items are ordered by macOS, not Perch. To rearrange them, hold **⌘**
and drag an item along the menu bar.

### Popups

**Click a reading** to open its popup. Every popup opens the same way: a
one-line verdict with a coloured dot (**● Light load**, **● Pressure warning**,
**● Online · Wi-Fi · 65 ms**), the headline figures, then a chart or bar of the
reading, then the detail. Rows you need once — a model name, a mount point, a
hardware address — are folded under **More details**, which remembers whether
you left it open.

The **⚙︎ gear** in the popup header opens that module's page in Settings.

A popup closes when you click anywhere else or press **⎋**. It scrolls with the
trackpad or wheel when it is taller than the screen allows.

### Combined modules

**Settings → Menu bar → Combine modules into one item** folds the modules into
a single menu bar item. Once it is on, you can choose the **Spacing**, add
**Separators**, and turn on **One popup for all**, which opens a single popup
showing every module at once.

### Alerts

A module can notify you when a reading crosses a line you set, under **Notify
me when** on its page in Settings:

| Module | Thresholds |
|---|---|
| **CPU** | total, system, user, efficiency-cores and performance-cores load |
| **RAM** | memory used, memory free, memory pressure, swap |
| **GPU** | utilisation |
| **Disk** | disk usage |

**Network** works the other way, under **Tell me when**: it notifies you when
the interface, the local IP, the Wi-Fi network or the public IP changes. The
public IP is only looked up when **Look up the public address** is on; see
[Privacy](#privacy).

Alerts keep working while every popup is closed — that is when a change is most
likely to go unnoticed.

---

## Settings

Open Settings from the **⚙︎** in any popup. The window has a sidebar:
**Dashboard**, **Settings**, then one page per module with its on/off switch.

### Dashboard

A summary of this Mac: processor, memory, graphics, disks, displays, model
identifier, production year, serial number and uptime.

### Module pages

Each module's page has its menu bar shapes, its alerts, and settings of its
own — chart history length and how many top processes to list for most;
**Show temperature** for CPU; the watched volume and **Include removable
drives** for Disk; the watched sensor, the reading interval, which sensors show
in the popup and **Read the HID sensors** for Sensors.

### General

| Setting | Default | Notes |
|---|---|---|
| **Start at login** | Off | |
| **Show in Dock** | Off | Perch is a menu bar app; this gives it a Dock icon too |
| **Check for updates** | Once per day | Also: Never, Once per hour, Once per week, and **Silent** |
| **Temperature unit** | System | Celsius, Fahrenheit, or whatever macOS uses |

> **"Silent" is not a quiet check.** It downloads the release and installs it,
> replacing the running application without asking. The default is a daily
> check that tells you and waits.

### Menu bar

| Setting | Default | Notes |
|---|---|---|
| **Combine modules into one item** | Off | Then **Spacing**, **Separators** and **One popup for all** — see [Combined modules](#combined-modules) |
| **Keep item positions** | Off | Remembers where each item sat, rather than letting macOS reshuffle them |

### Colours

| Setting | Default | Notes |
|---|---|---|
| **Colour the menu bar** | On | Off draws every figure and arrow in the menu bar's own colour. The popups keep their colours either way. |
| **Normal** | `#0E9BA8` teal | A calm reading |
| **Busy · upload and write** | `#CE7C00` amber | A busy reading; also the upload and disk-write series |
| **Critical** | `#C9302C` red | A reading that needs you |

Each colour has a colour well, which opens the macOS colour picker, and a field
that takes a hex code (`#RRGGBB` or `#RGB`). The reset arrow beside a changed
colour restores the default. Changes apply immediately.

### Search & switcher

| Setting | Default | Notes |
|---|---|---|
| **Open where the pointer is** | On | Off centres the panel on the screen |
| **Close when it loses focus** | On | Off keeps the panel up while you click elsewhere; ⎋ and ⌃Space still close it |
| **⌃Tab cycles your marked apps** | On | Off gives ⌃Tab back to every other app |
| **Trackpad gesture opens the search** | On | Then **Three-finger double tap** (on) and **Four-finger double tap** (off) |
| **Window control** | — | Shows whether Accessibility is granted, with **Allow…** when it is not |

These are also plain preferences, if you would rather use Terminal — change
one, then restart Perch:

| Key | Type | Default |
|---|---|---|
| `openAtPointer` | bool | `true` |
| `hideOnOutsideClick` | bool | `true` |
| `cycleHotkeyEnabled` | bool | `true` |
| `gestureEnabled` | bool | `true` |
| `gestureFingerCounts` | array of int | `[3]` — 3 and 4 are allowed |
| `gestureTaps` | int | `2` |

```bash
# four-finger double tap only, leaving three to macOS's Look Up
defaults write com.sagar.perch gestureFingerCounts -array 4

# give Ctrl+Tab back to your browser
defaults write com.sagar.perch cycleHotkeyEnabled -bool false
```

### Backup

**Export…** writes every Perch setting to a file. **Import…** reads one back and
offers to restart Perch so every setting takes effect. **Reset…** returns
everything to the defaults after a confirmation, and restarts Perch.

### The footer

| Button | Action |
|---|---|
| ♥ **Support** | Opens Perch's Ko-fi page |
| 🐜 **Report a bug** | Opens a new GitHub issue |
| ⏸ **Pause** | Switches every module off and leaves a single Perch icon in the menu bar; click it to reopen Settings. Press again to resume — the modules that were on come back on. |
| ⏻ | Quits Perch |

---

## Where Perch keeps things

| Path | What |
|---|---|
| `~/Library/Application Support/Perch/apps.json` | The launcher's app list |
| `com.sagar.perch` (UserDefaults) | Every setting — both halves |

Perch installs no helper, daemon or extension.

---

## Privacy

Perch collects no telemetry or analytics and has no account. It talks to the
network in three cases:

- **Update check** — a plain read of
  `https://api.github.com/repos/sagardn/Perch/releases/latest`, on the schedule
  set in **Check for updates**. Nothing about your Mac is sent. **Never** stops it.
- **Connectivity check** — while the Network popup is open, a TCP handshake
  with `1.1.1.1` on port 53, every few seconds, to measure latency and whether
  the internet answers. No data is sent over it.
- **Public IP** — `https://ifconfig.co/ip`, only when **Look up the public
  address** is on and you have asked to be told when the public IP changes;
  then once every two minutes. `ifconfig.co` runs
  [echoip](https://github.com/mpolden/echoip), which is open source and
  self-hostable if you would rather not depend on someone else's server;
  repoint the endpoint in `Perch/Monitor/NetworkInfo.swift`.

---

## Troubleshooting

**No Perch items in the menu bar at all.** On macOS 26 and newer: System
Settings → Menu Bar → turn Perch on. If you see `«` among your menu bar icons,
macOS is hiding items that do not fit, newest first — quit another menu bar app
or ⌘-drag items to make room. Finally, check the module is switched on in the
Settings sidebar.

**Nothing minimises; apps only come forward.** Accessibility is not granted, or
was granted to an earlier build — see [Permissions](#permissions). Raising an
app needs no permission, minimising one does.

**The gesture does nothing.** Check which finger counts are switched on in
Settings → Search & switcher: the default is three, not two or four. No
permission is involved. If Perch could not read the trackpad at all, it turns
the setting off and says so.

**⌃Tab stopped working in my browser.** That is Perch holding it globally.
Switch off **⌃Tab cycles your marked apps** in Settings → Search & switcher.

**A hotkey does nothing.** Another app registered it first — macOS gives a
global hotkey to whoever asked first and tells the loser nothing. Perch names
the shortcuts it could not claim in a notice at launch. Quit the app that owns
the key, pick a different character in Perch Apps, or look for a clash in
System Settings → Keyboard → Keyboard Shortcuts….

**A popup shortcut does nothing.** Check the key codes are in the order ⌃ ⇧ ⌘ ⌥
then the key, that Perch was restarted, and that Input Monitoring is granted —
see [Module popup shortcuts](#module-popup-shortcuts).

**"macOS can't minimise a full-screen window."** It cannot, and hiding the app
instead was tried and rejected: ⌘H tears down the full-screen space, after
which the app reports no windows and nothing can bring it back.

**Perch uses too much CPU or battery.** Switch off the modules you do not need,
starting with Sensors.

**Sensors show the wrong core count.** CPU and GPU sensors are thermal zones,
not cores. "CPU Efficient Core 1" is one sensor inside the efficiency cluster,
not one core's temperature.

**A sensor shows an impossible reading** (−2 °C, or a jump far above its
neighbours). Some sensor keys report raw or uncalibrated values. Hide it under
the Sensors page's popup list, and if another sensor beside it agrees with the
high value, the reading is real.

---

## Uninstalling

Run the script bundled with the app, as yourself rather than with `sudo` —
Perch installs no helper, so nothing it removes needs administrator rights:

```bash
sh /Applications/Perch.app/Contents/Resources/Scripts/uninstall.sh
```

It quits Perch and removes `Perch.app`, the application data and preferences
listed above, and the Accessibility and notification permissions macOS keeps
for it. If the app has already gone to the Trash, the same script can be run
from the repository:

```bash
sh Tools/uninstall.sh
```
