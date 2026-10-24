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
| Standard tabs | Optionally show Finder-style tabs as separate tasks | Not implemented; no cosmetic toggle claims support. |
| Dock integration | Move/auto-hide or fully hide the Dock and restore it when quitting | Explicit Apply/Restore controls manage only edge and auto-hide, with a local original-value backup and conflict detection. Complete Dock hiding and automatic quit-time Dock restoration are not implemented; restoration is an explicit user action. |

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

Final source `d66aab4` passed the optimized build, strict signature, 58 tests in 6 suites, delegated review of 24/24 production files and GitHub CI. Controlled native checks include the final real thumbnail and copied-backup import/restoration; earlier update builds exercised linked sizing, Start and two-display hiding. Refer to [VALIDATION.md](VALIDATION.md) for completed native checks and the executable they apply to. A build/test pass is not proof of thumbnail permission, actual badges, physical middle-click, reversible window resizing, or multi-display/Space behavior. Full reference parity is not established while the explicit gaps above remain.
