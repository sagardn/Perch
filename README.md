<p align="center">
  <img src="Perch/Supporting%20Files/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="Perch icon">
</p>

<h1 align="center">Perch</h1>

<p align="center">
  <strong>Your Mac, at a glance and a keystroke.</strong><br>
  A native menu bar app that switches apps, places windows, watches your system<br>
  and clears the clutter off it — all in one quiet process, with no account,<br>
  no telemetry and nothing to pay.
</p>

<p align="center">
  <a href="https://github.com/sagardn/Perch/releases/latest"><img src="https://img.shields.io/github/v/release/sagardn/Perch?style=for-the-badge&label=release&color=0E9BA8" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-111827?style=for-the-badge&logo=apple" alt="macOS 14 or newer">
  <img src="https://img.shields.io/badge/Swift-native-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Native Swift">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-CE7C00?style=for-the-badge" alt="MIT licence"></a>
</p>

<p align="center">
  <a href="#install"><strong>Install</strong></a> ·
  <a href="#what-you-get"><strong>Features</strong></a> ·
  <a href="#free-up-space"><strong>Free up space</strong></a> ·
  <a href="#keyboard-shortcuts"><strong>Shortcuts</strong></a> ·
  <a href="#privacy"><strong>Privacy</strong></a> ·
  <a href="docs/USER_MANUAL.md"><strong>Manual</strong></a> ·
  <a href="https://ko-fi.com/sagardn"><strong>Support</strong></a>
</p>

<br>

<p align="center">
  <img src="docs/screenshots/menubar.png" width="347" alt="Perch in the menu bar: SSD, GPU, sensor, CPU and RAM readings coloured by load, with network speed">
</p>

<p align="center">
  <img src="docs/screenshots/monitor.png" width="900" alt="The CPU, Network, Memory and Disk popups">
</p>

---

## Why Perch

Most Macs end up running three small utilities: one to launch and switch apps,
one to show what the machine is doing, and one more for the shortcut neither
of them has. Perch is all three, built as one native app.

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>⚡️ Switch in a keystroke</h3>
      <code>⌃Space</code> opens a search panel wherever your pointer is. Type,
      press Return, and Perch launches, focuses, minimises or restores the app —
      whichever the moment needs. <code>⌃⌥←</code> and friends place the window
      once you are there.
    </td>
    <td width="50%" valign="top">
      <h3>📊 See your Mac live</h3>
      CPU, GPU, memory, disk, network and sensors, drawn right in the menu bar
      and coloured by how hard each one is working. Click any reading for the
      full picture, including which app is responsible.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🧹 Take the space back</h3>
      Find the files that are actually large, uninstall an app along with
      everything it scattered around your Library, or clear out what your AI
      tools have piled up. Everything goes to the Bin, so nothing is a one-way
      door.
    </td>
    <td width="50%" valign="top">
      <h3>🪶 Stay out of the way</h3>
      No Dock icon, no window you did not ask for, no network calls behind your
      back. The expensive work runs only while you are looking at it.
    </td>
  </tr>
</table>

---

## What you get

### The launcher and switcher

<p align="center">
  <img src="docs/screenshots/launcher.png" width="320" alt="The Ctrl+Space search panel listing running apps">
</p>

- **Search panel** — `⌃Space` opens a floating panel at the pointer. Fuzzy-filter
  as you type; recently used apps rise to the top on their own.
- **Answers in the same panel** — type `12*8+5` or `5 km in miles` and the answer
  sits above your apps; ↩ copies it. Type `lock`, `sleep`, `dark` or `empty bin`
  for the system action. A query that could be an app's name stays an app search.
- **One click, the right action** — Perch reads each app's state and does what you meant:

  | When the app is… | Clicking it… |
  |---|---|
  | Not running | launches it |
  | Running, behind other windows | brings it to the front |
  | Already frontmost | minimises it |
  | Minimised or hidden | restores and focuses it |
  | A menu-bar-only app | activates it |

- **Your own `⌃Tab`** — mark the three or four apps you live in, and `⌃Tab`
  cycles only those, most recent first. If another app already owns `⌃Tab`,
  Perch notices, moves to `⌥Tab` and tells you.
- **Per-app hotkeys** — `⌃1` … `⌃9` jump straight to the apps you pin.
- **Minimise and back** — `` ⌃` `` tucks the frontmost app away; press again to bring it back.
- **Window snapping** — `⌃⌥←` / `⌃⌥→` put the window in the left or right half (press again
  for two thirds, then one third), `⌃⌥↑` / `⌃⌥↓` the top or bottom half, `⌃⌥U I J K` the
  quarters, `⌃⌥↩` fills the screen, `⌃⌥C` centres, `⌃⌥⌫` puts it back, and `⌃⌥⌘←` / `⌃⌥⌘→`
  move it to the other display. Rectangle's keys, so there is nothing new to learn.
- **Trackpad gesture** — a three-finger double tap opens the search (four-finger is a switch away).
- **Running indicators** — every row shows whether its app is open, hidden or not running.

### The system monitor

Six modules, each with its own menu bar reading and its own popup:

| Module | In the menu bar | In the popup |
|---|---|---|
| **CPU** | total load | history, every core, user/system split, load average, top processes |
| **GPU** | utilisation | history, renderer and tiler, memory in use |
| **Memory** | used % | breakdown bar, memory pressure, swap, top processes |
| **Disk** | used % | capacity bar, read/write activity, every volume |
| **Network** | upload and download | connection status, latency, Wi-Fi signal, traffic history, top processes |
| **Sensors** | the sensor you choose | every temperature, voltage, current, power and fan reading your Mac publishes |

Every popup opens the same way — a one-line verdict like **● Light load** or
**● Pressure warning**, then the headline figures, then a picture of the reading
— so learning one teaches you all six.

Wherever a popup lists processes, **right-click one** to **Quit** it politely or
**Force Quit** it when it has stopped answering. Quit is what ⌘Q does, so a
document with unsaved changes still gets to ask.

- **Nine shapes** for the menu bar: a figure, a line or bar chart, a ring, a
  gauge, a stacked pair, network rates and more. Mix them per module.
- **Colours that mean something** — teal when all is well, amber when busy, red
  when it needs you. Pick your own three colours in Settings, or switch the
  menu bar to plain white.
- **One item or many** — show each module separately, or combine them into a
  single compact menu bar item.
- **Alerts** — get notified when a reading crosses a threshold you set, when
  your network changes, when one app has held the CPU for minutes on end (with
  a **Quit** button), or when macOS starts slowing your Mac down to cool it.
  The runaway alert stays quiet about macOS's own background work, which you
  could not act on anyway, and names the process that is actually busy rather
  than the app it happens to live inside.

### Free up space

<p align="center">
  <img src="docs/screenshots/cleanup.png" width="900" alt="The Free up space page: Storage settings and Open Bin under 'What macOS can do', and large files, AI assistants and uninstall under 'What Perch can find'">
</p>

A full disk is the one problem a monitor can point at and then do something
about. **Free up space** in the sidebar has four ways in, and a rule that
covers all of them: **everything Perch removes goes to the Bin**, so a wrong
guess costs you a trip to Finder rather than your data.

- **Large files** — the biggest things in your home folder, sorted by size and
  filtered by kind: video, audio, images, archives, installers, documents. It
  skips the places that only look big — `node_modules`, `.git`, DerivedData —
  because a thousand small files are not what filled your disk.
- **Uninstall an app** — dragging an app to the Bin leaves its settings, caches
  and saved state behind. Perch finds them by **bundle identifier**, which is
  unique, and tells you how sure it is: files matched by the identifier are
  ticked, a helper's files are *probably this app*, and anything matched only
  by the app's *name* is shown in orange and never ticked for you. An app
  called Notes must not take your notes with it.
- **Uninstall a command-line tool** — Homebrew formulae and casks, npm globals,
  pipx apps and loose binaries in `~/.local/bin`, `~/go/bin` and friends. Tools
  a package manager installed are removed with **that manager's own command**,
  shown in full with Copy and Run beside it, because deleting `Cellar/ripgrep`
  by hand leaves Homebrew believing it is still there. Only what you actually
  asked to install is listed — not the forty dependencies underneath it.
- **AI assistants** — Claude, Codex, Copilot, Gemini, Grok, Cursor, opencode and
  the rest quietly keep every conversation, every cached model and every
  installer they ever downloaded. Perch adds it up and lets you choose by age.
  Caches, logs and downloads come ticked, because the tool rebuilds them without
  noticing; **conversations and downloaded models never come ticked**, however
  large, because only you know whether you want them back.

> **What it will not touch.** Matching is an allowlist, not a block list — a
> file is only offered if its name follows a convention Perch recognises. That
> is why no credential, settings file or installed plugin can ever appear on
> the list. Perch also never asks for Full Disk Access, so a few corners stay
> invisible to it; saving you a few hundred megabytes is not worth being able
> to read every file you own.

---

## Install

Paste this into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/sagardn/Perch/main/Tools/install.sh | bash
```

It downloads the latest release, verifies the disk image, installs Perch to
`/Applications` and launches it. Perch needs one permission, **Accessibility**,
to raise, minimise and restore windows, and asks for it the first time you do.

**Requires macOS 14 Sonoma or newer.** Updates arrive by themselves: Perch checks
its GitHub releases once a day and offers new versions in place.

<details>
<summary><strong>Why a command, not a download link?</strong></summary>

<br>

Perch is signed ad hoc rather than with a paid Apple Developer ID, so macOS
refuses to open it when it arrives through a browser. Quarantine is attached by
the program that downloads a file — `curl` does not attach it, so this route
never meets Gatekeeper. Nothing is disabled system-wide.

If you downloaded `Perch.dmg` with a browser and macOS blocked it ("Apple could
not verify…"), click **Done**, then open **System Settings → Privacy & Security**,
scroll to **Security** and click **Open Anyway** beside Perch.

</details>

<details>
<summary><strong>Build from source</strong></summary>

<br>

Requires Xcode with the macOS 26 SDK.

```bash
git clone https://github.com/sagardn/Perch.git
cd Perch
xcodebuild -project Perch.xcodeproj -scheme Perch -configuration Release build
```

Or open `Perch.xcodeproj` and use **Product → Archive → Distribute App → Copy App**,
then move `Perch.app` to `/Applications`.

</details>

<details>
<summary><strong>Uninstall</strong></summary>

<br>

```bash
sh /Applications/Perch.app/Contents/Resources/Scripts/uninstall.sh
```

This quits Perch and removes the app, its preferences and data, and the
Accessibility and notification grants macOS keeps for it, so a reinstall starts
clean. Run it as yourself, not with `sudo` — Perch installs no helper or daemon.

</details>

---

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌃Space` | Open or close the search panel |
| `⌃Tab` | Cycle your marked apps, most recent first |
| `⌃1` … `⌃9` | Jump to a pinned app |
| `` ⌃` `` | Minimise the frontmost app; press again to restore |
| `⌃⌥←` `⌃⌥→` `⌃⌥↑` `⌃⌥↓` | Snap the window to a half (repeat for ⅔, ⅓) |
| `⌃⌥U` `⌃⌥I` `⌃⌥J` `⌃⌥K` | Snap to a quarter |
| `⌃⌥↩` · `⌃⌥C` · `⌃⌥⌫` | Fill the screen · centre · put it back |
| `⌃⌥⌘←` `⌃⌥⌘→` | Move the window to the other display |

Once the panel is open, your hands never leave it:

| Key | Action |
|---|---|
| *type* | Filter the list as you go |
| `↓` or `⇥` | Next result |
| `↑` or `⇧⇥` | Previous result |
| `↩` | Activate the selected app |
| `→` | Open that row's options menu |
| `⎋` | Close the panel |

`⇥` walks the list the way `⌘⇥` does, so switching apps is one key held and
tapped rather than a reach for the arrows. With an empty query the list is
already in most-recently-used order — so `⌃Space ⇥ ↩` flips you back to the
last app, and that is the whole gesture.

Every module popup can be given a shortcut of its own too. The
[User Manual](docs/USER_MANUAL.md) lists every key in the app.

---

## Privacy

No analytics, no telemetry, no crash reporting, no account. Perch talks to the
network in three cases, and every one is under your control:

- **Update check** — a plain read of
  `api.github.com/repos/sagardn/Perch/releases/latest`, once a day. Nothing about
  your Mac is sent. Set **Check for updates** to **Never** and it stops.
- **Connectivity check** — while the Network popup is open, a TCP handshake with
  `1.1.1.1` measures latency and whether the internet answers. No data is sent
  over it.
- **Public IP** — fetched from `ifconfig.co` only if you turn on alerts for
  public-IP changes in the Network module, and then once every two minutes.

---

## Troubleshooting

<details>
<summary><strong>"DMG signature validation failed: could not read current team ID"</strong></summary>

<br>

You are on Perch **1.0.5 or older**. The updater in those versions only accepts
an update when the running app carries an Apple Developer Team ID, which an
ad-hoc-signed app never has, so it can never install one. Nothing a newer
release does can change that check. Update once by hand with the install
command above — it replaces the old copy and keeps your settings — and from
then on the built-in updater works. Afterwards, remove Perch from **System
Settings → Privacy & Security → Accessibility** with **−** and allow it again.

</details>

<details>
<summary><strong>A hotkey does nothing</strong></summary>

<br>

macOS has no "hotkey permission" — a global shortcut belongs to whichever app
registered it first, and the loser is not told. Perch names any shortcut it
could not claim in a notice at launch, and moves its app cycle from `⌃Tab` to
`⌥Tab` when something else owns it. Quit the app that owns the key, turn Perch's
off in Settings, or check **System Settings → Keyboard → Keyboard Shortcuts…**
for a system shortcut using the same keys.

</details>

<details>
<summary><strong>The shortcut fires, but windows don't move</strong></summary>

<br>

That is **Accessibility**: **System Settings → Privacy & Security → Accessibility**
→ turn **Perch** on.

If it was working and stopped after an update, the switch can look on while the
grant no longer applies — macOS ties it to the app's signature, which changes
with every ad-hoc-signed build. Select Perch, click **−**, then click **+**, choose
`/Applications/Perch.app`, and reopen Perch.

</details>

<details>
<summary><strong>The trackpad gesture does nothing</strong></summary>

<br>

The default is a **three-finger** double tap; four-finger is off until you turn
it on in **Settings → Search & switcher**, where **Trackpad gesture opens the
search** must also be on. No permission is involved.

</details>

<details>
<summary><strong>A reading is missing from the menu bar</strong></summary>

<br>

If you see `«` among your menu bar icons, macOS is hiding items that don't fit,
newest first — so Perch can be running and invisible. Quit another menu bar app
or ⌘-drag items to make room. On macOS 26, also check **System Settings → Menu
Bar** and make sure Perch is allowed. Finally, confirm the module is switched on
in Perch's Settings sidebar.

</details>

<details>
<summary><strong>Reducing Perch's energy use</strong></summary>

<br>

Switch off the modules you don't need. Sensors is the most expensive by some
way, because reading every sensor walks the whole controller table.

</details>

More answers live in the [User Manual](docs/USER_MANUAL.md).

---

## Something to send with a bug report

Press the **bug** button at the bottom of the Settings sidebar. It copies a
diagnostics report to your clipboard and opens the issue form, so you can paste
it straight in — it is the first thing anyone will ask for.

The report says which macOS and Perch you are running, which Mac you have,
which modules are on and which readings answered. It is built to carry nothing
that identifies you: no serial number, no Wi-Fi name, no IP or MAC address, no
volume names. The tests assert each of those by name. It is plain text, so read
it before you send it.

---

## Support Perch

Perch is free and stays free. If it saves you a few seconds a day, you can say
thanks with a coffee — it goes straight into the time it takes to keep building it.

<p align="center">
  <a href="https://ko-fi.com/sagardn"><img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-Ko--fi-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Support Perch on Ko-fi"></a>
</p>

Starring the repository and telling a friend helps just as much.

---

## Contributing

Pull requests are welcome — read it, learn from it, fork it, and if you improve
something, send it back. [CONTRIBUTING.md](CONTRIBUTING.md) has the short version
of what makes a change easy to merge, and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
explains how the code fits together.

Good first contributions: correcting a translation in a language you speak (all
of them are machine-written and unreviewed), sensor support for a Mac we have
not tested on, and bug fixes with a note on how to reproduce them.

---

<p align="center">
  <a href="LICENSE">MIT</a> © 2026 Sagar
</p>
