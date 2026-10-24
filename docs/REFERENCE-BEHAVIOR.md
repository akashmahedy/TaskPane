# Taskbar reference behavior ledger

The current customization/feature matrix and remaining gaps are maintained in [TASKBAR-PARITY.md](TASKBAR-PARITY.md). The baseline observations below retain their original source and native-test scope.

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

## TaskPane implementation and partial native evidence

The window-ordering and Start/menu changes are implemented through source `4c169fb`. The optimized release build, 41 tests in 3 suites, and [CI run 40062127577](https://github.com/akashmahedy/TaskPane/actions/runs/40062127577) passed. Native observations below were supplied by the coordinating agent; they establish partial coverage, not full reference parity.

| Area | Implemented source | Native evidence / remaining acceptance |
| --- | --- | --- |
| Window buttons | Separate and adjacent modes retain individual buttons. Optional explicit combine modes are additional TaskPane choices. | Earlier GUI checks showed separate Overview rows and selected minimize/restore state changes. Both separate bar buttons were observed after leaving full screen. During full screen, one fixture was absent from its owner's fresh AX list; broader inventory continuity remains unaccepted. |
| Ordering | Individual session window order, adjacent app-block moves across apps, and pin dragging. | Core tests and controlled user-assisted individual-window/combined-group physical drags passed on `4c169fb`, with independent AX/order/count and saved-preference checks. Pin dragging, additional directions, adjacent-block/filtering/Space transitions and display coverage remain pending. |
| Start | Bar-anchored popover with search, alphabetical headings, pinned/recent apps and Escape dismissal. | Focus/hidden-launcher and normal Start search, close/reopen, Escape and auto-hide transition passed on `4c169fb`. Broader launch, keyboard traversal and display coverage remain pending. |
| Window/app commands | Full-screen toggle, pin/unpin, hide, normal quit and exclude commands alongside activate/minimize/restore/close. | Final GUI menu entries were visible and explicit minimize/restore was checked. Physical right-click and full-screen/hide/quit outcomes remain pending. |
| Spaces and previews | Visibility remains a hint; no thumbnail collector exists. | Authoritative Space filtering and optional permission-based thumbnails remain gaps. |
| Additional reference options | Middle-click close, badges, tab handling and overlap avoidance remain incomplete. | Track and validate these separately. |

The earlier accepted two-window smoke baseline and final executable/hash details remain in [VALIDATION.md](VALIDATION.md). Earlier Layout/theme checks and the short interactive CPU sample are recorded there; that sample is not a sustained-performance result. The controlled drag and Start cases passed; broader native checks remain pending. Existing user preferences must survive these changes.
