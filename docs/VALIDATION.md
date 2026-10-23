# Private-alpha validation

This file records actual validation separately from planned coverage. Latest local pass: 2026-10-23.

## Build target

Swift 6 / Swift 5 language mode, macOS 14 deployment target. Local runtime target: Apple Silicon, macOS 27.0.1. No Intel or macOS 14 runtime result is claimed.

## Completed checks

- Debug and optimized release bundle builds passed. `codesign --verify --deep --strict` accepted the final local ad-hoc bundle. Plist and shell syntax checks passed.
- Swift Testing: **24 tests in 2 suites passed**. Coverage includes all presets, expanded layout export/import, old schema-1 backups, numeric/path/widget validation, manual ordering transitions, corrupt-file preservation and failed writes.
- Native GUI: live CPU/RAM/network dashboard, five distinct illustrated presets, Windows-style full-width taskbar, exact custom item width, light/system themes, section ordering, automatic/manual controls, launcher search, pin/unpin, creator credit and preference export/import.
- Extended backup test: exported a 168-point item width, changed it to 180, imported the backup and verified the saved preferences exactly matched the exported snapshot.
- Without Accessibility, the final bar displayed one application button per running application. Its actual full-width layout was visually inspected.
- Earlier native diagnostics on this Mac passed CPU/RAM sanity checks and detected two displays. That result preceded the window-inventory redesign and does not validate the final window count.
- Open Code Review delegation covered all 21 selected files, with no skipped reviewable files. Tests and excluded metadata/docs received additional manual review. See [REVIEW.md](REVIEW.md).

## Pending native window-control verification

The final ad-hoc build needs a renewed macOS Accessibility grant. Individual-window counts and activate/minimize/restore/close actions have not yet been revalidated on this final binary. The inventory and exact-element action checks were reviewed and compiled; runtime success is not inferred from compilation.

## Unverified scenarios

Physical display unplug/replug, real sleep/wake, Intel hardware, every supported macOS version, all third-party app window implementations and exhaustive Spaces/full-screen behavior require later testing. Native actions deliberately refuse ambiguous matches.
