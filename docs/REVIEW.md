# Private-alpha code review

Review date: 2026-10-23. Alibaba Open Code Review 1.13.1 ran in delegation mode: `ocr delegate preview` selected files and `ocr delegate rule` resolved rules. Codex performed the review. No OCR-managed LLM provider was configured.

## Coverage

The initial source submission contains 29 files: 21 OCR-reviewable and 8 excluded by default filters. All 21 reviewable files were reviewed, none skipped (100% coverage). Untracked source files were read in full. Tests, plist metadata and Markdown documentation excluded by OCR defaults were checked separately. Review evidence and private runtime observations stay outside the public repository.

| Area | Reviewed files |
| --- | --- |
| Build and packaging | Workflow, gitignore, license, Package.swift, build.sh, test.sh, make-icon.swift |
| Window and application services | WindowService.swift, LauncherService.swift |
| Monitoring | MetricsService.swift, Diagnostics.swift |
| Preferences | Preferences.swift, PreferencesFileStore.swift, SettingsStore.swift |
| Native UI | Main.swift, SettingsView.swift, SharedViews.swift, TaskbarCoordinator.swift, TaskbarView.swift, CustomizationViews.swift, PresetPreview.swift |

## Findings addressed

- Replaced Core Graphics window enumeration with deduplicated, verified Accessibility windows. Helper records cannot create taskbar rows.
- Window actions retain exact AX elements, then recheck current membership and process ownership before sending an action. Title/frame matching is used only for visibility hints.
- Window activation verifies and raises the selected element before activating its owner. Failure messages are retained.
- Preference import persists before replacing in-memory settings. Corrupt originals are preserved; failed writes and invalid imports leave existing data intact.
- Pinned-application additions and imports enforce limits and path validation.
- Network sampling uses 64-bit interface counters with bounded buffer parsing and reset handling.
- Diagnostics reject an absent memory sample instead of accepting the initial zero value.
- Application switching without Accessibility also honors manual/recent ordering and drag arrangement.
- Entering manual ordering from automatic sorting uses the displayed order, retaining dormant apps without reinstating stale positions.
- Auto-hide tracks each display independently. Adaptive item width uses the number of rendered groups and their label setting.
- Preset previews derive their width and position from preset preferences; Focus does not display disabled widgets.
- Added descriptive labels to numeric and opacity sliders. Clamped color channels before producing RGB hex values.
- Corrected Bash 3.2 handling of an empty optional flag array after the first GitHub CI run exposed it. The test script now uses one nonempty argument array.
- Bundle updates replace the executable by rename. CI uses read-only repository permissions, bounded execution and concurrency cancellation.

## Native window-test follow-up

Native testing exposed a misleading activation error and a restore raise timeout. The follow-up selected one modified file (`WindowService.swift`) through OCR delegation; that file was reviewed in full, with none skipped (1/1, 100%).

- Activation reporting checks whether the requested owner is already foreground before treating a redundant activation request as a failure.
- Window-list membership is collected separately from metadata time budgets. Cached presentation requires fresh exact membership and expires after 12 seconds without a new full snapshot; closed members are pruned.
- Metadata inspection advances across both applications and their individual windows, avoiding persistent starvation when budgets are exhausted.
- Window actions use a bounded one-second IPC timeout. A restored window permits one non-destructive raise retry after exact membership, owner and trust are checked again. Close is never retried.
- Successful minimize/restore updates the cached state of the exact selected window. Unknown minimized state is not assumed to be false.
- Permission guidance includes the macOS 27 label and clears its stale instruction after access connects.

## Foreground-focus follow-up

Standalone GUI testing with two disposable windows confirmed separate rows, minimize/restore continuity and closing only the selected window. A real mouse-click check confirmed that raising the selected window did not reliably give its application keyboard focus. The follow-up OCR delegation passes selected `WindowService.swift`; each complete diff was reviewed (1/1, none skipped).

- The public Workspace API brokers activation of the existing owner from the nonactivating bar. Its callback must return the requested process and bundle URL before further window work proceeds. The selected window is restored before the request and raised again afterward through exact retained AX identity.
- The default application reopen event can have app-specific effects. Preflight and callback checks do not make process reuse atomic; a changed returned process is rejected without a further window action. No private process-focus API or synthetic input event is used.
- A bounded readback requires both application frontmost state and an exact `AXFocusedWindow` match. The main thread also confirms the foreground process before reporting success.
- New TaskPane actions cancel stale activation work and delayed status updates. A foreground change to an unrelated application also cancels the pending activation. Explicit queued minimize/close commands retain their separate identity checks and are not dropped by a later command. Close is still sent only once.

## Minimized-window classification follow-up

Native testing exposed a TextEdit regression: a previously verified standard document window reported `AXDialog` after being minimized. With dialog display disabled, its taskbar button disappeared on the next refresh, preventing restore from the bar. OCR delegation selected one file (`WindowService.swift`); the implementation and independent Codex review covered the complete change and its callers: 1 selected, 1 reviewed, 0 skipped.

- A fresh minimized `AXDialog` snapshot retains standard-window presentation only when the previous verified classification belongs to the same process and exact `CFEqual` AX member in the current window list. Fresh title, bounds and minimized state are preserved.
- Action-time normalization occurs after fresh role, owner and exact membership checks, before caching minimize/restore transitions. Cached restore state therefore retains the same verified presentation without changing the action target.
- Newly discovered dialogs, newly discovered minimized dialogs, `AXSystemDialog` windows and fresh nonminimized `AXDialog` snapshots remain dialogs. The change does not relax eligible-role or action-identity checks.

The independent review found no confirmed blocker. Native taskbar minimize/restore validation with dialog display disabled is pending for this fix; source review does not establish a runtime pass.

Resolved findings were re-read and relevant tests/builds rerun. Native validation and remaining platform limits are recorded in [VALIDATION.md](VALIDATION.md). This review is not a guarantee that every third-party app or macOS version behaves identically.
