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

Source commit: `a9d292f`. Release executable SHA-256: `9627e2846395c19f713e8c73b9bd005f3ffcd8555c55ca8667652a1c5318affa`. The running bundle, packaged bundle and ZIP contain the same executable. The release build, signature check and all 24 tests passed. [GitHub CI run 39949068869](https://github.com/akashmahedy/TaskPane/actions/runs/39949068869) also passed.

The basic local P0 window-control smoke test is accepted on this build:

- The standalone GUI showed Accessibility **Connected**, including after a same-binary restart. AnyDesk appeared as one application button. Two disposable TextEdit documents appeared as separate window rows.
- Minimizing document A changed only A to minimized; its raw subrole became `AXDialog` while B remained unminimized. Restoring A returned it to unminimized state with TextEdit globally foreground. Closing A left only B.
- In the grouped taskbar, the first click activated B; a second click while B was focused minimized it. B again reported raw `AXDialog`. With dialog display disabled, its taskbar button remained available after approximately nine seconds of refreshes.
- Clicking that same taskbar button restored B to unminimized state with TextEdit globally foreground. Closing B left no test-document rows.
- The temporary change to `currentDisplayOnly` was restored to `true`. The user's Compact preset and always-grouped preference were preserved.

The public Workspace broker and exact AX focus readback were exercised in these native actions. This passes the local two-window smoke test, including the minimized-role regression; it does not establish exhaustive inventory continuity or full reference-app parity.

## Unverified scenarios

Broader inventory continuity, renamed/hidden windows, physical display unplug/replug, real sleep/wake, Intel hardware, every supported macOS version, other third-party app window implementations and exhaustive Spaces/full-screen behavior require later testing. A newly discovered minimized dialog without prior verified standard-window identity remains filtered when dialog display is disabled. Native actions deliberately refuse ambiguous matches.
