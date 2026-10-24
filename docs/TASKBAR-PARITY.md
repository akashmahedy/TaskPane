# Taskbar feature and customization comparison

Lawand Taskbar is the primary interaction reference. This comparison was refreshed on 2026-10-24 against its [official feature page](https://lawand.io/taskbar/), [release notes](https://lawand.io/taskbar/release-notes/), the installed Taskbar 1.6.3 binary's preference labels, and TaskPane source. Vendor descriptions establish the reference contract; source availability does not by itself establish native parity.

TaskPane remains original, free and open-source software credited to **akashmahedy**. It does not include Lawand binaries, source, branding or assets.

## Reference contracts and implementation scope

| Area | Reference contract | TaskPane implementation and boundary |
| --- | --- | --- |
| Window buttons | Direct access to each window; optional adjacency without combining | Separate and adjacent modes preserve individual windows. Explicit combine modes remain additional choices. |
| Window switching | Select the exact window; focused-click minimizes, with an optional hide-app alternative | Exact-member Accessibility action paths and the hide-app option. App/OS-specific native behavior still needs acceptance checks. |
| Dragging | Reorder windows and pins; enable each independently | Session ordering and saved pin order, with independent drag switches. Earlier controlled physical drags passed; repeat on the new build. |
| Layout and appearance | Size, maximum task width scaled by size, font, transparency, title visibility, theme and centering | Overall scale plus independent dimensions, larger numeric ranges, spacing/padding/borders/shadow and a current-layout illustration. Requested dimensions are fitted to the display and button content. |
| Start | Searchable alphabetical apps, pins, recent apps, configurable size and font | Existing Start contents plus configurable width, height, icon and text size, fitted to the display. |
| Window previews | Optional hover thumbnails, size, hover delay and title controls | Selected-window ScreenCaptureKit capture with explicit permission request, delay and dimension/font options. Missing permission or ambiguous identity gives a useful fallback. No capture is saved to disk. |
| Minimized/hidden state | Optional visual indications | Independent dimming/marker options. |
| Middle click | Close the selected window | Optional native local middle-button handling invokes the existing exact-window close command. |
| Application badges | Show notification indicators, including pins | Optional read-only Dock application status-label collector. Only exact file-URL/bundle mappings are accepted. An app/macOS version exposing no label has no badge. |
| Overlap avoidance | Optionally resize windows overlapping the bar | Opt-in, reversible normal-window geometry service. Fresh exact-member AX validation is required before resizing; dialogs, minimized/full-screen windows and unavailable capabilities are skipped. User changes are preserved. |
| Displays | Each display's windows; all-windows/main-display alternatives and individual bar hiding | Display filtering and individual-display visibility choices. Reconnection and multiple physical displays require native coverage. |
| Spaces | Follow the active Space and retain order through transitions | A read-only compatibility adapter queries native topology and membership for exact known window IDs; unknown results fall back to visibility. All-known-desktops markers are supported. Complete off-Space window discovery and desktop assignment remain unverified/unimplemented respectively. |
| Standard tabs | Optionally show Finder-style tabs as separate tasks | Standard AppKit AXTabGroup tabs appear as independent tasks, using retained tab/group identity. Selection follows the new host root; Close uses the tab’s own close control or a verified explicit Close Tab command when the AX button is ineffective. Minimize/full screen affect the shared window. Browser content tabs are outside this standard-tab contract. |
| Dock integration | Move/auto-hide or fully hide the Dock and restore it when quitting | Explicit Apply manages edge, auto-hide and reveal delay. Full hiding suppresses normal edge reveal; optional normal-quit restoration and manual crash recovery retain original key presence and preserve later independent edits. System screens such as Mission Control can still show the Dock. No daemon is installed. |

The installed reference has a label describing auto-hide as planned. TaskPane's configurable automatic hiding/reveal is an additional feature; it must be tested on its own behavior rather than assumed to match an existing reference implementation.

## TaskPane adjustment ranges

These are TaskPane model/UI limits, not claims about Lawand's numeric endpoints. The installed reference confirms the corresponding preference categories, while its exact numeric endpoints have not been established in this source comparison.

| Adjustment | TaskPane range |
| --- | --- |
| Bar minimum thickness | 24–256 pt |
| Bar length | 10–100% of available edge |
| Edge distance | 0–1,000 pt |
| Along-edge offset | −4,000–4,000 pt, fitted to the display |
| Item fixed/minimum/maximum width | 24–1,200 pt |
| Item height | 20–240 pt |
| Icon size | 8–128 pt requested |
| Text size | 8–48 pt requested |
| Bar/item opacity | 0–100% |
| Spacing, padding | 0–100 pt |
| Corner radius | 0–128 pt |
| Border width | 0–12 pt |
| Hide/reveal/preview delay | 0–10 seconds |
| Activation strip | 1–40 pt |
| Animation duration | 0–2 seconds |
| Preview width / height | 120–1,000 / 80–800 pt |
| Start width / height | 320–1,200 / 240–1,200 pt |

The effective bar must accommodate item height and vertical padding. Icons and labels fit inside the selected item size; lowering the minimum thickness alone cannot shrink taller content. The overall-size control adjusts those dimensions together. Display fitting can reduce requested bar and menu dimensions. Accessibility Reduce Transparency overrides a transparent background when macOS requires an opaque surface.

Existing schema-one preferences remain readable. New options use defaults when absent, and validated export/import carries the options. Preference restoration during testing must use the latest pre-test snapshot rather than an older session's backup.

## Verification boundary

The preceding customization source `d66aab4` passed the optimized build, strict signature, 58 tests in 6 suites, delegated review of 24/24 production files and GitHub CI. Controlled native checks include the final real thumbnail and copied-backup import/restoration; earlier update builds exercised linked sizing, Start and two-display hiding. Refer to [VALIDATION.md](VALIDATION.md) for completed native checks and the executable they apply to. A build/test pass is not proof of thumbnail permission, actual badges, physical middle-click, reversible window resizing, or multi-display/Space behavior. Full reference parity is not established while the explicit gaps above remain.

## Tabs, Dock and community-theme follow-up

The 2026-10-24 follow-up adds standard native tabs, full Dock edge-reveal suppression with quit restoration, six Windhawk-inspired macOS presets and editable bar/button background colors. The reference 1.6.3 binary carries a `defaults write com.apple.dock autohide-delay -float 1000` argument array and a quit-time restoration path. TaskPane independently implements that category of behavior with a longer suppression delay, a durable local journal and per-key conflict preservation. This is not a claim to hide system-owned Mission Control UI. See [theme references](THEMES.md) and [native validation](VALIDATION.md). Desktop assignment and complete discovery of inaccessible off-Space roots remain separate limitations.

The final follow-up `e078f80` passed 63 tests, 13/13 production-file review, strict signing and CI. Final native checks confirmed inactive-tab close, full Dock configuration/normal-quit restoration, all six community-preset applications and exact restoration of the user's preferences. Earlier update-build native focus/minimize/restore evidence and remaining platform/locale limits are detailed in [VALIDATION.md](VALIDATION.md).
