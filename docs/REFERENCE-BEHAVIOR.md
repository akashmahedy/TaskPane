# Taskbar reference behavior ledger

Recorded 2026-10-23 for Lawand Taskbar 1.6.3. Lawand Taskbar is TaskPane's primary interaction reference. This ledger distinguishes vendor documentation, native observations, and TaskPane source inspection. None alone establishes TaskPane runtime parity.

## Officially documented

The [official product page](https://lawand.io/taskbar/) documents these contracts:

| Area | Reference contract |
| --- | --- |
| Window buttons | Each window has its own button; clicking selects that window; clicking the focused window again minimizes it. |
| Grouping and ordering | Windows never combine into one app button. Optional grouping keeps an app's separate buttons adjacent. Individual buttons can be dragged freely. |
| Hover and pins | Hover previews windows. Pinned apps remain available when closed. |
| Start menu | Search, an alphabetical installed-app list, pinned apps and recently used apps. |
| Displays and Spaces | Current-Space windows; per-display bars, with all-screen window and main-display-only options. |
| Additional controls | Window/app context commands, middle-click close and optional window resizing to avoid overlap. |

Capture permission is optional; thumbnails are the feature requiring it. The [release notes](https://lawand.io/taskbar/release-notes/) additionally document configurable thumbnail delay, app badges, tab handling, focused-click hide behavior, and past ordering regressions during Space/full-screen transitions. These require targeted acceptance checks rather than inference from appearance.

## Observed in the installed reference

These observations were supplied by the coordinating agent from actual CUA inspection on 2026-10-23. They were not independently repeated by the author of this ledger. No private titles or screenshots are retained here.

| Area | Native observation |
| --- | --- |
| Start menu contents | The launcher button opens a borderless window: Search and an alphabetical list with letter headings on the left, a pinned-app grid above a Recent Apps list on the right. |
| Start menu dismissal | Escape closes the Start view and returns to the taskbar. |
| Window context menu | Taskbar submenu; Application: Keep in Taskbar, Hide, Add to Blacklist, Quit; Window: Fullscreen, Minimize, Close. Taskbar submenu contents remain unrecorded. |
| Enabled preferences | Task dragging, pinned-app dragging, hidden windows, app badges and windows from all screens. |
| Disabled preferences | Group tasks by app (chronologically), focused-click hide-app alternative, middle-click close, tabs as windows and main-display-only. |

These preference values describe the inspected installation, not established factory defaults. Exact Start placement across displays, outside-click dismissal, keyboard traversal and drag outcomes remain unverified here.

## TaskPane baseline and active work

The baseline below comes from source inspection before the current parity changes. The window-ordering and Start/menu implementation pass is **in progress**, with no new runtime pass claimed. Pending and later items remain separate follow-up work.

| Priority | Baseline gap | Scope / acceptance target |
| --- | --- | --- |
| First | `TaskbarView.swift` collapses grouped windows into an app button/popup. | Keep one button per window; grouping changes adjacency only. |
| First | Drag payloads and stored ordering identify apps, preventing interleaved same-app windows. Pins lack direct drag handlers. | Independent window ordering and pin dragging; preserve identity and ordering through focus changes. |
| Next | The launcher is a centered titled window containing one searchable app list. | Start popover at the invoked bar, alphabetical headings, pinned/recent sections, search and Escape dismissal. Validate on each display. |
| Next | Window menus expose Activate, Minimize and Close. | Add the observed application commands and Fullscreen, with safe exact-window actions. |
| Pending | Visibility hints do not establish Space membership; previews are absent. | Explicit Space/display/full-screen tests; optional permission-based thumbnails. |
| Later | Additional reference options remain incomplete. | Track middle-click behavior, badges, tab handling and overlap avoidance separately. |

The basic two-window TaskPane smoke test recorded in [ROADMAP.md](ROADMAP.md) is narrower than this ledger. Grouping, drag, Start and menu changes need their own native checks before being marked complete. Existing user preferences must survive the changes.
