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

Source commit: `6718b5c`. Release executable SHA-256: `f97282867a7c8dadf0b62e7c955f2108a34986b06e6c013b5e674aeb7d9f49c9`. The running bundle, packaged bundle and ZIP contain the same executable. The release build, signature check and all 24 tests passed after the foreground-focus correction.

The standalone GUI showed Accessibility **Connected**, including after a same-binary restart. AnyDesk appeared once in its application search. Two disposable TextEdit documents appeared as separate rows. Minimizing the selected document left the other available; restoring it raised the exact document without the previous restore timeout.

Foreground activation remains **unconfirmed**: a selected document sometimes showed active window controls, but the global foreground process and TaskPane's verification did not agree. The GUI inventory also temporarily omitted the fixture rows before returning. A separate, read-only integration run of the unchanged window engine retained both exact fixture identities through 12 settled samples; that different launch context does not establish standalone GUI acceptance.

Final acceptance still requires a real mouse-click foreground check, repeatable inventory continuity, close verification on this binary and taskbar second-click minimize/restore. Closing only the selected fixture while preserving another was verified on the preceding build; it is not counted as a pass for this final executable. Runtime success is not inferred from compilation or static review.

## Unverified scenarios

Physical display unplug/replug, real sleep/wake, Intel hardware, every supported macOS version, all third-party app window implementations and exhaustive Spaces/full-screen behavior require later testing. Native actions deliberately refuse ambiguous matches.
