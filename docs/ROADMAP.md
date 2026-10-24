# TaskPane release plan

TaskPane is a window-first taskbar for macOS. Lawand Taskbar is the primary feature and interaction reference. System widgets and later productivity modules support that core. All released functionality remains free and open source.

## Main priority: the taskbar

1. Accurate individual-window inventory: one entry per real window, stable identity, predictable minimized/hidden-window handling and useful display filtering.
2. Reliable window interaction: activate the exact selected window, click the focused window to minimize, restore minimized windows, and provide window controls and grouping.
3. Configurable taskbar layout: item width/height, labels, spacing, transparency, screen edge and offset, ordering, pins, auto-hide and distinct preset previews. Preserve these choices through export/import.
4. Close remaining gaps against [the primary reference](https://lawand.io/taskbar/) after the core actions pass native testing. New monitoring collectors must not delay these taskbar milestones.

Native acceptance comes before claiming feature completion: compare the actual app window list with TaskPane, test same-app multiple windows and renamed/minimized windows, and exercise switching and controls on disposable test windows.

## Customization update

Source `d66aab4` adds linked sizing, expanded adjustment ranges, more controls, configurable Start, optional hover snapshots, middle-click close, interaction switches, native Space membership, badges, reversible overlap avoidance and explicit Dock edge/auto-hide controls. See [the current reference comparison](TASKBAR-PARITY.md). Historical native evidence retains its original executable scope. The follow-up adds standard AppKit tab tasks, full Dock edge-reveal suppression and quit restoration, plus six community-inspired visual presets. Complete nonstandard/inaccessible off-Space discovery, Space assignment, independent display profiles and wider platform acceptance remain separate work.

## Next reference-parity milestones

These milestones distinguish implemented source, partial native evidence and remaining gaps. Source `d66aab4` passed the optimized release build, 58 tests in 6 suites and [CI run 40067061148](https://github.com/akashmahedy/TaskPane/actions/runs/40067061148). The official reference website and TaskPane source were compared on 2026-10-23; [the reference behavior ledger](REFERENCE-BEHAVIOR.md) records the evidence boundaries. Full reference parity is not established.

| Priority | Taskbar milestone | Current alpha boundary |
| --- | --- | --- |
| P0 | Native acceptance of exact-window count, activation, minimize, restore and close | Basic local two-window smoke accepted on `a9d292f`. Earlier `7a7d0b8` GUI repeated separate Overview rows and selected minimize/restore checks; clean global-foreground confirmation and broader bar inventory continuity remain pending |
| P1 | Drag individual windows freely; optionally keep the same app's windows adjacent without collapsing them | Implemented in source: session window ordering, adjacent separate buttons, app-block moves across apps in adjacent mode, and pin dragging. Controlled user-assisted individual-window and combined-group physical drags passed on `4c169fb`; pin dragging, adjacent-block drags and broader directions/filtering/display coverage remain pending. Explicit combine modes remain optional |
| P1 | Current-Space, display and full-screen reliability | Native membership is read when supported, with visibility fallback; complete off-Space discovery and transition acceptance remain pending |
| P1 | Hover window thumbnails with an optional, explicit capture permission | Optional ScreenCaptureKit snapshots are implemented; the final disposable-window image passed. Physical hover timing/pointer-transition coverage remains pending |
| P1 | Start menu anchored to the clicked display, with pinned and recent apps plus search | Controlled Focus/hidden-launcher and normal Start search, close/reopen, Escape and auto-hide transitions passed on `4c169fb`; full launch, keyboard traversal and multi-display coverage remain pending |
| P1 | Window and application context controls | Implemented in source and menu entries observed: full-screen toggle, pin/unpin, hide, normal quit and exclude commands alongside activate/minimize/restore/close. Physical right-click and full-screen/hide/quit outcomes remain pending |
| P2 | Optional overlap avoidance by resizing affected windows | Opt-in reversible resizing is implemented and passed ten injected service cases; physical resize/restoration acceptance remains pending |
| P2 | Middle-click close | An optional local native handler closes the verified selected window; physical middle-click acceptance remains pending |

Extend the accepted local P0 smoke test and final partial checks to broader inventory and app/platform coverage. Layout numeric edits and theme changes passed; the short interactive CPU measurement does not establish long-run performance. The controlled physical window/combined-drag and Start regressions are accepted. Next validate adjacent-block and pin dragging, additional directions, Start launching/keyboard traversal and placement on each display, and full-screen/app menu actions. Repeat ordering checks through filtering and Space/full-screen/display transitions; these broader checks remain pending. Continue native acceptance of thumbnails and the new interaction/overlap controls. The minimized-role correction requires prior verified standard-window identity; a newly discovered minimized dialog remains filtered when dialog display is disabled. A permission-dependent feature must retain a useful fallback when that permission is declined.

## 0.1 private alpha

Native shell; safe public-API window actions; launcher and pins; configurable bars and baseline widgets; five presets; validated export/import; creator credit. Validate on the creator's Mac before broader testing.

## Public 1.0

Finish the taskbar priorities, broader app/macOS/display testing, window snapshots and preview lifecycle, keyboard accessibility, localization, settings migrations and independent display profiles. Signed/notarized releases require a publisher-controlled Developer ID identity.

## Additional monitoring modules

Keep the shared baseline CPU/memory/network/battery engine and per-widget taskbar/menu-bar placement. Supported GPU/disk/temperature/Bluetooth collectors, alerts and per-collector demand scheduling follow the taskbar milestones.

## 1.1 productivity

Searchable window switcher, half/quarter snapping, folders/stacks, audio/media/device controls and configurable shortcuts.

## 1.2 layouts

Named window layouts, display reconnection recovery, optional live previews and linked-window behavior. Any undocumented APIs are isolated behind explicit capability checks and fallbacks.

## Separate experimental work

Fan control requires an independently reviewed privileged helper and hardware-specific testing. Remote monitoring, remote control and AI command features are outside the baseline product scope.
