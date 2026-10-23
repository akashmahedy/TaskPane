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
- The earlier seven-second native diagnostic passed CPU/RAM sanity checks and returned network/battery readings, two displays and 14 verified AX windows. This diagnostic process has its own launch/permission context; it does not establish that the interactive GUI has window-control access.
- Open Code Review delegation covered all 21 selected files, with no skipped reviewable files. Tests and excluded metadata/docs received additional manual review. See [REVIEW.md](REVIEW.md).

## Latest native window-control checks

Source commit: `0c951d7`. Release executable SHA-256: `d32c23773e2a57c9ce161cfec5f0560c21f64d6847053d9acf7ba6958f4e1ed5`. The running bundle, packaged bundle and ZIP contain the same executable. The release build, signature check, all 24 tests and GitHub CI passed after the Workspace activation correction.

The standalone GUI showed Accessibility **Connected**, including after a same-binary restart. AnyDesk appeared once in its application search. Two disposable TextEdit documents appeared as separate rows. Minimizing the selected document left the other available; restoring it raised the exact document without the previous restore timeout.

Foreground activation is now verified on this build: a read-only timeline captured a real foreground transition from another application to TextEdit, the selected fixture was active, and TaskPane completed its focus check without an activation error. This follows a manual mouse-click confirmation of the earlier build's focus bug. The fix uses the public Workspace activation broker, then raises and verifies the exact selected window.

During interactive GUI testing, fixture rows temporarily disappeared before returning while settings/window context was also changing. A separate read-only integration run of the unchanged inventory engine retained both exact fixture identities through 12 settled samples. That different launch context does not establish standalone GUI inventory continuity.

Final acceptance still requires controlled inventory continuity, repeat minimize/restore/close verification on this binary and taskbar second-click minimize/restore. Closing only the selected fixture while preserving another was verified on a preceding build; it is not counted as a pass for this final executable. Runtime success is not inferred from compilation or static review.

## Unverified scenarios

Physical display unplug/replug, real sleep/wake, Intel hardware, every supported macOS version, all third-party app window implementations and exhaustive Spaces/full-screen behavior require later testing. Native actions deliberately refuse ambiguous matches.
