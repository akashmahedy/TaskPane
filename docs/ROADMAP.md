# TaskPane release plan

TaskPane is a window-first taskbar for macOS. Lawand Taskbar is the primary feature and interaction reference. System widgets and later productivity modules support that core. All released functionality remains free and open source.

## Main priority: the taskbar

1. Accurate individual-window inventory: one entry per real window, stable identity, predictable minimized/hidden-window handling and useful display filtering.
2. Reliable window interaction: activate the exact selected window, click the focused window to minimize, restore minimized windows, and provide window controls and grouping.
3. Configurable taskbar layout: item width/height, labels, spacing, transparency, screen edge and offset, ordering, pins, auto-hide and distinct preset previews. Preserve these choices through export/import.
4. Close remaining gaps against [the primary reference](https://lawand.io/taskbar/) after the core actions pass native testing. New monitoring collectors must not delay these taskbar milestones.

Native acceptance comes before claiming feature completion: compare the actual app window list with TaskPane, test same-app multiple windows and renamed/minimized windows, and exercise switching and controls on disposable test windows.

## Next reference-parity milestones

These milestones distinguish source implementations awaiting native acceptance from remaining gaps. The official reference website and TaskPane source were compared on 2026-10-23; [the reference behavior ledger](REFERENCE-BEHAVIOR.md) records the evidence boundaries. Implementing a control does not establish full reference parity.

| Priority | Taskbar milestone | Current alpha boundary |
| --- | --- | --- |
| P0 | Native acceptance of exact-window count, activation, minimize, restore and close | Basic local two-window smoke accepted on `a9d292f`, including grouped second-click minimize/restore with dialogs disabled; broader inventory and app/platform coverage remains pending |
| P1 | Drag individual windows freely; optionally keep the same app's windows adjacent without collapsing them | Implemented in source: session window ordering, adjacent separate buttons, app-block moves across apps in adjacent mode, and pin dragging. Physical drag/drop and broader native acceptance are pending. Explicit combine modes remain optional |
| P1 | Current-Space, display and full-screen reliability | Visibility is a best-effort hint; it is not authoritative Space membership |
| P1 | Hover window thumbnails with an optional, explicit capture permission | No thumbnail collector is implemented |
| P1 | Start menu anchored to the clicked display, with pinned and recent apps plus search | Implemented in source as a bar-anchored popover with alphabetical headings, pinned apps, session recent apps, search and Escape dismissal; native placement, interaction and display coverage are pending |
| P1 | Window and application context controls | Implemented in source: full-screen toggle, pin/unpin, hide, normal quit and exclude commands alongside activate/minimize/restore/close; new commands await native acceptance |
| P2 | Optional overlap avoidance by resizing affected windows | Window geometry is read; automatic overlap resizing is not implemented |
| P2 | Middle-click close | No middle-click handler is implemented |

Extend the accepted local P0 smoke test to broader inventory and app/platform coverage. Next validate the new window/adjacent-block and pin dragging with physical input, Start search/launch/dismissal and placement on each display, and full-screen/app menu actions. Repeat ordering checks through filtering and Space/full-screen/display transitions; these broader physical and Spaces checks remain pending. Then implement thumbnails and the P2 controls. The minimized-role correction requires prior verified standard-window identity; a newly discovered minimized dialog remains filtered when dialog display is disabled. A permission-dependent feature must retain a useful fallback when that permission is declined.

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
