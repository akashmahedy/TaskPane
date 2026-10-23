# Private-alpha validation

This file records actual validation separately from planned coverage. Latest local pass: 2026-10-23.

## Build target

Swift 6 / Swift 5 language mode, macOS 14 deployment target. Local runtime target: Apple Silicon, macOS 27.0.1. No Intel or macOS 14 runtime result is claimed.

## Latest bug-fix follow-up — `8815aa4`

Application source: `8815aa4893dae4875da554600d4ba51cbe6b4608`. The optimized release build, strict ad-hoc signature verification and **41 tests in 3 suites** passed. [CI run 39965872433](https://github.com/akashmahedy/TaskPane/actions/runs/39965872433) passed. Final OCR delegation covered 3/3 selected production files, with no skipped files or confirmed remaining findings; the regression test was reviewed separately.

Release executable SHA-256: `f4e095c9c1e9cd1329ff876127df6a1be02e19ddb077027cf02a4dbb0db0b279`. The app, packaged app and app extracted from the ZIP match, and all three strict signature checks passed. Private ZIP SHA-256: `06a0fb18d02e83d3ee9e2236b0960764b6127c87d8a152426101782cf682c39b`. The previous local app and package were preserved; no public binary release was uploaded.

Native checks on the creator's Mac, using one connected display:

- Applied Focus, which hides the launcher and enables auto-hide. The taskbar context-menu Start command opened the actual popover. Searching for TextEdit filtered the list and showed its launch result. Close dismissed the popover, and the context command reopened it successfully.
- With Start open and the pointer outside the bar, read-only geometry showed the bar in its expanded position. After dismissal, with the cursor unchanged, the bar retracted 31 points towards the bottom. This checks the transition; an exact five-point visible strip is not claimed.
- Restored the pre-test preferences through the app's validated Import flow. A private comparison confirmed every preference matched the snapshot, including appearance, widgets, pins, exclusions and ordering.
- The restored visible Start button opened its popover; TextEdit search and Escape dismissal worked.

Combined reorder's native acceptance remains pending. This rebuilt ad-hoc app does not yet have working Accessibility access, despite the older switch appearing enabled. Renewal of that existing permission awaits the user's specific approval. No broad permission reset or permission-database edit was performed. The regression test and source review pass, but they do not establish a native drag/drop result.

## Earlier behavior follow-up — `7a7d0b8`

Application source commit: `7a7d0b8d0643b644b88d3876bf4760149100d699`. The optimized release build and **40 tests in 3 suites** passed after the UI performance changes. This source commit was published, and [GitHub CI run 39956023920](https://github.com/akashmahedy/TaskPane/actions/runs/39956023920) completed successfully.

Release executable SHA-256: `983e0a6ffd8a320a897ac826217653f62e014c15cba22d0d3d57da8bccd01fb9`. Packaging checks confirmed matching executables in the running source bundle, packaged bundle and extracted ZIP; strict ad-hoc signature checks passed. Local ZIP SHA-256: `f844e19579ae1e3d27979971067e9962722aad322fe9b0b30dab5dfe1b9d8480`. A public binary release has not been uploaded.

The coordinating agent reported these partial native results on the final executable:

- The GUI showed Accessibility **Connected**. Two disposable fixture documents appeared as separate Overview rows.
- Explicitly minimizing fixture A produced A minimized / B unminimized. Restoring A produced A unminimized and an exact focused-window readback for A. A clean global-foreground result was not accepted in this repeat because the user was working concurrently.
- Layout numeric editing and switching Dark → System appearance worked. The test setup was configured through the GUI to use a full-width bar with adaptive item-width bounds of 80–220 points.
- Window/application menu commands were visible. Menu visibility does not establish successful full-screen, hide or quit execution, or physical right-click behavior.
- A later taskbar observation showed only fixture B. TextEdit's native View menu then reported **Exit Full Screen** for fixture A, while its fresh AX window list returned only B. After exiting full screen through TextEdit, a fresh AX list returned both fixtures unminimized and both separate taskbar buttons were visible. This exposes a full-screen/Spaces inventory boundary; it does not establish reliable TaskPane full-screen entry/exit across Spaces.

Start-menu contents and search have partial native evidence, including the intermediate `b744f77` build: an alphabetical app list, pinned-app grid and recent-app list were observed. These observations do not establish that every Start interaction was repeated on `7a7d0b8`.

A read-only process CPU-time measurement during GUI interaction recorded **1.35 CPU seconds over 12.02 wall-clock seconds**, averaging **11.23% of one core** (100% equals one fully occupied core). Process identity remained stable and the on-disk executable hash matched. This is one short interactive sample, not an idle or sustained-performance benchmark.

Physical window/pin dragging and right-click checks, full-screen/hide/quit action acceptance, broader inventory continuity, Spaces/display coverage and the user's manual acceptance remain pending. The earlier accepted smoke baseline below is preserved separately.

## Earlier alpha checks

- Debug and optimized release bundle builds passed. `codesign --verify --deep --strict` accepted the final local ad-hoc bundle. Plist and shell syntax checks passed.
- Swift Testing: **24 tests in 2 suites passed**. Coverage includes all presets, expanded layout export/import, old schema-1 backups, numeric/path/widget validation, manual ordering transitions, corrupt-file preservation and failed writes.
- Native GUI: live CPU/RAM/network dashboard, five distinct illustrated presets, Windows-style full-width taskbar, exact custom item width, light/system themes, section ordering, automatic/manual controls, launcher search, pin/unpin, creator credit and preference export/import.
- Extended backup test: exported a 168-point item width, changed it to 180, imported the backup and verified the saved preferences exactly matched the exported snapshot.
- Without Accessibility, the final bar displayed one application button per running application. Its actual full-width layout was visually inspected.
- The earlier seven-second native diagnostic passed CPU/RAM sanity checks and returned network/battery readings, two displays and 14 verified AX windows. This diagnostic process has its own launch/permission context; it does not establish that the interactive GUI has window-control access.
- Open Code Review delegation covered all 21 selected files, with no skipped reviewable files. Tests and excluded metadata/docs received additional manual review. See [REVIEW.md](REVIEW.md).

## Accepted earlier window-control baseline — `a9d292f`

Source commit: `a9d292f`. Release executable SHA-256: `9627e2846395c19f713e8c73b9bd005f3ffcd8555c55ca8667652a1c5318affa`. The running bundle, packaged bundle and ZIP contain the same executable. The release build, signature check and all 24 tests passed. [GitHub CI run 39949068869](https://github.com/akashmahedy/TaskPane/actions/runs/39949068869) also passed.

The basic local P0 window-control smoke test is accepted on this build:

- The standalone GUI showed Accessibility **Connected**, including after a same-binary restart. AnyDesk appeared as one application button. Two disposable TextEdit documents appeared as separate window rows.
- Minimizing document A changed only A to minimized; its raw subrole became `AXDialog` while B remained unminimized. Restoring A returned it to unminimized state with TextEdit globally foreground. Closing A left only B.
- In the grouped taskbar, the first click activated B; a second click while B was focused minimized it. B again reported raw `AXDialog`. With dialog display disabled, its taskbar button remained available after approximately nine seconds of refreshes.
- Clicking that same taskbar button restored B to unminimized state with TextEdit globally foreground. Closing B left no test-document rows.
- The temporary change to `currentDisplayOnly` was restored to `true`. The user's Compact preset and always-grouped preference were preserved.

The public Workspace broker and exact AX focus readback were exercised in these native actions. This passes the local two-window smoke test, including the minimized-role regression; it does not establish exhaustive inventory continuity or full reference-app parity.

## Unverified scenarios

Broader inventory continuity, renamed/hidden windows, physical drag/right-click input, physical display unplug/replug, real sleep/wake, Intel hardware, every supported macOS version, other third-party app window implementations and exhaustive Spaces/full-screen behavior require later testing. Full-screen, hide and normal-quit execution and the user's final manual check remain unaccepted. A newly discovered minimized dialog without prior verified standard-window identity remains filtered when dialog display is disabled. Native actions deliberately refuse ambiguous matches.
