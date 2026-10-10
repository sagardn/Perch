# Performance baseline

Measured 2026-10-09 on a MacBook Air 13" (M2, 8 cores, 16 GB), macOS 27.0,
Perch 1.0.11 installed at `/Applications/Perch.app`, ad-hoc signed.

Reproduce with `./Tools/bench.sh`. **Do not claim an improvement without
re-running it on the same machine with the same modules enabled** — these
numbers are a reference point for one configuration, not an absolute.

Modules enabled during the run: CPU, GPU, RAM, Network. Off: Disk, Sensors,
Battery, Bluetooth. No popup or settings window was opened.

## Numbers

| Measure | Result | Confidence |
|---|---|---|
| Idle CPU, sustained | **6.0 %** (5.66–6.19 % across 6 × 15 s) | high — very stable |
| Resident memory, settled | **127 MB** | high |
| Resident memory, peak at launch | 219 MB | high |
| Reader poll interval | **1 s**, every reader | exact (`Kit/module/reader.swift:57`) |
| Cold start to first menu bar item | 7.5 s / 43.5 s / 19.3 s | **low — see below** |

6 % sustained is the headline. For a menu bar monitor that is doing nothing
visible, on a machine doing nothing else, that is a lot: it is roughly half a
core-percent per enabled module per second of wall clock, and it is paid
whether or not anybody is looking.

### Why the startup number is not usable yet

The three cold-start runs disagree by a factor of six. The app is ad-hoc signed
and unnotarised, so Gatekeeper re-assesses the bundle on launch, and the bundle
had just been replaced — that is almost certainly what the 43 s run measured,
not Perch. A usable figure needs the same bundle launched repeatedly with no
reinstall in between, and ideally the app's own `"Perch started in …"` line
rather than polling for a menu bar window. **Treat startup as unmeasured.**

### A measurement trap worth recording

`ps -o %cpu` is the **average since the process started**, not current usage.
Sampling it 60 times on a freshly launched app reported *8.0 % mean, 23.4 %
max* — a decaying startup transient, read as if it were steady-state noise.
The true sustained figure, from the delta in cumulative CPU time, is 6.0 % with
a spread of half a percent. `Tools/bench.sh` does it the second way.

## Where the time actually goes

From `sample` over 15 s at idle (`/tmp/perch.sample.txt`). This is a sampling
profiler, not Instruments — directional, good enough to pick a target, not
precise attribution.

The heaviest frames are **not data collection**:

```
   42  AppKit           NSPerformVisuallyAtomicChange
   24  CoreAutoLayout   -[NSISEngine withBehaviors:performModifications:]
   24  UIFoundation     __NSStringDrawingEngine
   23  CoreAutoLayout   -[NSLayoutConstraint _addToEngine:…]
   22  CoreSVG          EnumerateNode(SVGNode const*, …)
   23  libswiftCore     swift_release_dealloc
   33  libsystem_malloc _xzm_xzone_malloc_tiny
   21  AppKit           -[NSView … _populateEngineWithConstraints…]
```

Reading that list: constraints being added to the layout engine, strings being
measured and drawn, SVG nodes being walked, and objects being allocated and
released — once per tick, forever. No `host_processor_info`, no `sysctl`, no
IOKit. **The cost is in redrawing the menu bar, not in reading the hardware.**

One Auto Layout path appears on a chart's own background queue
(`com.sagar.perch.Charts.Line`), which is worth a second look on its own
merits: AppKit layout off the main thread is not safe regardless of its cost.

## What this means for the rebuild

The independent layer in `Perch/Monitor/` currently replaces **readers** —
`CPUReadings`, `MemoryReadings`, `NetworkMonitor`, `GPUStats`, `Temperature`.
The profile says readers are not where the 6 % is. Rewriting them is still
worth doing for independence from the inherited architecture, but **it should not
be expected to move this number**, and a rewrite that reproduces the same
per-tick view rebuilding will land in exactly the same place.

Ranked by measured cost against likely effort:

1. **Stop rebuilding menu bar widget views every tick.** Update the value and
   redraw; do not re-add constraints, re-measure strings, or re-rasterise an
   SVG each second. This is where the samples are.
2. **Do not pay for what nobody is looking at.** `Charts.displayIfVisible()`
   already guards redraws on window visibility; the same discipline needs to
   reach the widgets and the popup content.
3. **Reconsider the flat 1 s interval.** Every reader ticks once a second
   regardless of whether its value is on screen or changing. Adaptive or
   event-driven intervals are the obvious follow-up — but only after 1 and 2,
   because halving the tick rate of cheap work saves nothing.

Numbers 1 and 2 are rendering work in `Kit/Widgets/` and `Kit/module/`, which
is derived code the rebuild intends to replace anyway. Doing them as part
of the replacement, rather than as a patch to code that is on its way out, is
the cheaper order.
