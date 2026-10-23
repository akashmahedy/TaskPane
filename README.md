# TaskPane

A native macOS taskbar and menu bar companion, created by **akashmahedy**.

The main product priority is Lawand Taskbar-style window behavior and customization. System monitoring is an optional companion module. See [the taskbar-first priorities](docs/ROADMAP.md).

**0.1.0 — private alpha.** This is an early working build, not a complete replacement for every feature in the roadmap. Free and open source under GPL-3.0-or-later. No account, paid unlock, ads, analytics, or cloud monitoring.

## In this alpha

These features are implemented through source `8815aa4`, which passed the optimized release build, 41 tests in 3 suites and [GitHub CI](https://github.com/akashmahedy/TaskPane/actions/runs/39965872433). Native checks on this build passed Start search, dismissal and reopening with the Focus launch button hidden, its auto-hide transition, and the normal Start button and Escape. Combined reordering has a regression test and completed source review; its native acceptance awaits renewal of the existing Accessibility permission. Broader inventory, Spaces/displays and full-screen/app-control acceptance remain pending. See [validation details](docs/VALIDATION.md); full reference parity is not claimed.

- Individual verified window buttons, with an adjacent mode that keeps each app's windows together without combining them. Explicit options can combine windows into app buttons always or when space is needed.
- Activate, minimize, restore, close and full-screen controls, focused-window indicators, and app pin/unpin, hide, normal quit and exclusion commands.
- Drag individual windows into a session order; adjacent mode moves an app's block when dragging across another app and individual windows within the same app. Drag pinned apps to reorder them.
- Start popover anchored to the invoked taskbar, with search, an alphabetical app list, a pinned-app grid and recent apps from the current session.
- Persistent pins and app exclusions; saved application, section and pin ordering.
- Taskbar, menu bar, or combined mode; bottom/top/left/right edges and optional bars on all displays.
- Auto-hide, per-display filtering and separate controls for minimized, off-screen and dialog windows.
- Native CPU, memory, primary-interface network, internal-battery and clock widgets.
- Per-widget placement: taskbar, menu bar, both, or off. CPU/memory sparklines in the taskbar.
- System/light/dark appearance, accent color, bar transparency, icon/text sizes and item background opacity.
- Fixed/adaptive item widths, minimum/maximum width, item height, spacing, corner radii and density shortcuts.
- Bar length, edge distance, alignment and position offset; section ordering, automatic application/title/recent sorting and manual application ordering.
- Five presets: Balanced, Windows style, Compact, Monitoring and Focus. Each has its own illustrated preview. Applying a preset preserves pins and exclusions. Fresh installations start with Windows style.
- Automatic local preferences, versioned JSON export/import, strict validation and atomic writes.
- Creator credit in the About screen and app footer.

## Build and run

Requires macOS 14 or later and Swift 6 or later. Apple Silicon is the initial runtime test target. Intel builds and older supported macOS releases require separate runtime validation. No third-party Swift packages are fetched.

```sh
bash scripts/build.sh debug
open dist/TaskPane.app
```

For an optimized build, use `bash scripts/build.sh release`. The script creates an app bundle and an original icon, then signs it locally with an ad-hoc signature. **It is not notarized or Developer ID signed.** Rebuilding an ad-hoc app can require granting Accessibility again.

Both full Xcode and Command Line Tools are supported. The script keeps compiler caches in `.build`. On CLT-only systems the test script supplies the bundled Swift Testing framework/plugin paths.

```sh
bash scripts/test.sh
dist/TaskPane.app/Contents/MacOS/TaskPane --diagnose
```

Diagnostics sample for seven seconds and print metrics and counts, not window titles, app lists or preference paths. They exit nonzero if CPU/memory sanity checks fail. A graphical user session is needed for window/display observations.

## Window access

App activation works without Accessibility. Use **Overview → Enable window control**, then explicitly allow TaskPane in macOS Privacy & Security, to operate individual windows. TaskPane does not edit the permission database or alter Dock settings.

Window rows come from public Accessibility window lists, with duplicate AX elements removed and helper/floating windows excluded. Core Graphics supplies visibility hints only. Actions retain an exact AX element and recheck its owner and membership in a fresh application window list; titles and positions never identify action targets. If verification fails, no action is sent. Without Accessibility, the bar provides application switching instead of individual window rows.

Apps with incomplete Accessibility support, slow AX responses, nonstandard windows and some full-screen/other-Space windows may be omitted or refuse actions. Visibility is best effort. Minimized windows can be shown; off-screen windows and dialogs are hidden by default. TaskPane does not extract browser tabs as separate windows.

Under load, previously verified row details can be reused for up to 12 seconds, provided the exact window is still in a freshly retrieved AX window list. A complete list that no longer contains the window removes it. Every window action performs its own fresh verification.

## Preferences and backups

Preferences are stored in `~/Library/Application Support/TaskPane/preferences.json`. **Backup → Export preferences** writes a portable JSON file. **Import preferences** validates the complete file, asks before replacing a valid setup, and persists it before updating the UI. Invalid files leave the current setup unchanged. An unreadable original settings file is retained; an explicit valid import preserves a separate copy before restoring it.

**Use classic taskbar behavior** enables adjacent window buttons, window titles, focused-click minimize, minimized/off-screen windows, windows from all displays and manual ordering. It preserves appearance, widgets, pins, exclusions and saved application order, and resets the temporary individual-window order.

Application, section and pin ordering are serialized with preferences. Individual-window identifiers and their manual order stay in the current TaskPane session and are not exported. Recent apps are kept in memory, bounded to 12 entries for the session, with no history file.

Backups contain preferences and application paths, which may include a local username. Keep personal backups private. They never include passwords, screenshots or macOS permission grants. The import format is limited to 1 MiB and rejects unsupported versions, invalid ranges, duplicate widgets and unsafe application paths.

The `--data-dir /absolute/test/folder` argument isolates preference storage for manual testing.

## Current limits

- No window thumbnails, live previews, screen recording, snapping, saved window layouts, global shortcuts, fan control, or GPU/temperature/SMART collectors yet.
- Display filtering uses window geometry. Exact active-Space filtering/moving is not implemented; the taskbar follows Spaces and uses best-effort on-screen hints. Enabling off-screen windows can include other Spaces.
- The baseline collectors share one engine and currently sample while TaskPane runs, even when a widget is hidden. Demand-based per-collector scheduling is planned.
- Network speed follows the primary routed interface, with a physical-interface fallback for VPNs; it is not a sum of all adapters. No public-IP request or connectivity probe is made.
- Menu bar widgets are combined into one item. Graphs are available in taskbar CPU/memory widgets; menu bar values are text.
- Current display settings are shared across enabled displays; independent per-display profiles are planned.
- No automatic updater, login helper or privileged service is installed.
- Interface language is English in this alpha; Bengali localization is planned.

## Roadmap

See [the release plan](docs/ROADMAP.md), [privacy details](docs/PRIVACY.md), and [validation notes](docs/VALIDATION.md).

## Credits

Product direction and creator: **akashmahedy**. Engineering assistance: OpenAI Codex.

Feature research referenced Taskbar, uBar, Sidebar and Stats. This alpha is original code using Apple frameworks and does not bundle their source code, assets or binaries. App icons displayed for installed apps are obtained from macOS at runtime. The TaskPane app icon is generated from original drawing code.

Copyright © 2026 akashmahedy. See [LICENSE](LICENSE).
