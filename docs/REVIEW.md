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

The independent review found no confirmed blocker. Native testing on `a9d292f` then passed grouped taskbar minimize/restore with dialog display disabled: the same button remained available through approximately nine seconds of refreshes and restored the selected window with its application foreground. The basic local P0 smoke test is accepted; broader inventory and app/platform coverage remains pending. See [VALIDATION.md](VALIDATION.md) for the tested executable and scope.

## Taskbar behavior follow-up

The follow-up OCR delegation selection contained 12 production files: 12 reviewed, 0 skipped. Two test files and five documentation files excluded by OCR defaults received additional manual review. Codex reviewed the selected changes, with independent review of the interaction, ordering and application-identity paths.

- Separate adjacent grouping from combining windows into one app button. Automatic combining now measures the available window-section space, including vertical layout, fixed item widths, labels and spacing, rather than using a fixed window-count threshold.
- Keep individual-window order in memory using exact session tokens. Filtered live windows retain their place; confirmed identity loss prunes old tokens. Cross-application dragging in adjacent mode moves the complete supplied block atomically. Independent review caught a forward-move bug in the first-member proxy approach; the replacement `movingBlock` helper has four regression tests covering both directions, hidden siblings and invalid/no-op moves.
- Present the searchable Start menu from the clicked bar, with pinned and recent applications. Open Start/group popovers keep auto-hide from retracting that bar. Presentation and request tokens prevent an older asynchronous launch completion from dismissing a later Start-menu presentation.
- Window context commands retain exact AX identity for activation, minimize/restore, close and full-screen requests. Full-screen changes require a fresh eligible window, current exact membership and owner, a settable `AXFullScreen` attribute and a strict Boolean state read. Unsupported windows receive no full-screen request; no synthetic shortcut is used.
- Hide and normal Quit take a captured `RunningAppEntry`, including an opaque process-instance token. Tokens survive refresh only while `NSRunningApplication.isEqual` identifies the same instance. Commands also recheck the current instance, bundle metadata, liveness and policy, and refuse TaskPane itself. Quit uses normal termination without retries or force termination; messages report request acceptance rather than claiming the application has exited.

The optimized release build and strict ad-hoc signature check passed. The repository test script and isolated core suite each passed **40 tests in 3 suites**. Comprehensive native acceptance of these new interactions remains pending; later partial checks are recorded below and in [VALIDATION.md](VALIDATION.md). Earlier native smoke acceptance applies to the executable recorded above, not automatically to this follow-up. These changes do not establish full reference-app parity or broader app, display and Spaces reliability.

## Native UI performance follow-up

A separate Start accessibility-labeling and Overview More-menu follow-up (`fb61`) was fully reviewed: 2 files reviewed, 0 skipped. Subsequent native testing exposed high CPU and Layout-page timeouts. The process profile placed **521 of 521 main-thread samples** in the metrics publication → appearance assignment → native slider tick-cache rebuilding path. This identifies an expensive appearance traversal, rather than establishing an AX/menu recursion.

- Theme and refresh-interval updates now have separate deduplicated subscriptions. Metrics updates refresh status-item content without reassigning `NSApp.appearance`.
- Layout and Appearance sliders now use continuous native controls with quantization in their bindings, retaining the configured value increments without generating dense tick-mark caches. Unchanged quantized values are not written back.

The three changed files (`Main.swift`, `CustomizationViews.swift`, `SettingsView.swift`) received independent review: 3 reviewed, 0 skipped, no confirmed remaining finding. Full source-only app typechecking passed. After these performance edits, the optimized release build and **40 tests in 3 suites** passed on source `7a7d0b8`; [GitHub CI run 39956023920](https://github.com/akashmahedy/TaskPane/actions/runs/39956023920) also passed. Final packaging retained the same executable across the source bundle, packaged bundle and extracted ZIP, with strict ad-hoc signature checks accepted.

The final GUI accepted Layout numeric edits and Dark → System appearance changes. A 12.02-second CPU-time sample during GUI interaction averaged 11.23% of one core. This is partial native evidence; it does not establish idle usage, long-run performance or all interaction behavior. Exact minimize/restore observations, a full-screen/Spaces inventory boundary, and pending physical drag/right-click, full-screen/hide/quit and user acceptance checks are recorded in [VALIDATION.md](VALIDATION.md).

Validation status and remaining platform limits are recorded in [VALIDATION.md](VALIDATION.md). This review is not a guarantee that every third-party app or macOS version behaves identically.

## Combined ordering and hidden-launcher Start fixes

A fresh OCR delegation review of `b2dd392..0631508` covered all 12 selected source files, with no skipped files. Two test files and six documentation files were also reviewed. It confirmed two medium bugs: retained individual-window order overrode combined app dragging, and the hidden-launcher Start command had no popover owner while leaving auto-hide expanded.

Source `8815aa4` addresses both. Combined movement validates both current keys, clears the earlier session window order and explicitly starts from the displayed application order, retaining dormant application keys. The first fix attempt exposed a stale saved-order jump; re-review caught it, and the regression test covers saved ABC/session CAB/B-before-C producing BCA without moving an unrelated app to its old position.

Start now has one persistent bar overlay presenter. It resolves the visible launcher button's bounds through an anchor preference and falls back to the bar bounds when the button is absent. Hit testing is disabled only for the clear anchor before the presentation modifier; the presented Start controls remain interactive.

Final OCR delegation selected three production files (`TaskbarView.swift`, `SettingsStore.swift`, `Preferences.swift`): **3 reviewed, 0 skipped, 100% coverage, no confirmed remaining findings**. The excluded regression-test diff received manual review. The optimized release build, strict signature verification, **41 tests in 3 suites**, and [CI run 39965872433](https://github.com/akashmahedy/TaskPane/actions/runs/39965872433) passed. Native Start/Focus results and the remaining permission-dependent combined-drag check are recorded in [VALIDATION.md](VALIDATION.md).

## Native drag-start follow-up

The user's physical drag attempt on `8815aa4` produced no drag preview and left the order unchanged. The subsequent one-file `TaskbarView.swift` patch moves the Start presenter from `overlayPreferenceValue` to `backgroundPreferenceValue` and attaches all four drag sources to their label content, using rectangular content shapes and explicit `onDrag` NSString providers. String payloads, drop destinations and panel modes remain unchanged.

The final OCR delegation preview and rules (`ocr-native-drag-start-preview` and `ocr-native-drag-start-rules`) covered **1 selected production file, 1 reviewed, 0 skipped, 100% coverage, no confirmed findings**. Two documentation files excluded by OCR defaults received additional manual review by the coordinating agent and independent reviewer. The optimized release build and **41 tests in 3 suites** passed. The release executable SHA-256 is `dbb670573384b0a021c4de05f537efcd5981a3cbd8e85fd4872fb264521c92f9`.

After re-registering only TaskPane's Accessibility record, the rebuilt GUI reported **Connected** and initially displayed 12 windows. On source `4c169fb2451dc2f9e5da35ceeedc7413ca444d74`, the user confirmed that a physical individual-window drag showed a preview and moved System Settings first. An independent AX readback showed System Settings, Finder, TextEdit B and TextEdit A. The user then dragged the last combined TextEdit group onto Finder: the independent readback changed from System Settings → Finder → TextEdit to System Settings → TextEdit → Finder. All four windows remained: one System Settings, two TextEdit and one Finder. Saved preferences matched that application order, retained dormant Calendar and kept `autoArrange` false. This passes the controlled user-assisted physical individual-window and combined-app drag checks; the sequence of any intervening individual drags is not inferred. Pin dragging, both movement directions and broader filtering/Spaces/display coverage remain unverified. Start/Focus search, dismissal, reopening, Escape and the auto-hide transition were repeated successfully after the presenter change; normal Start passed after the original preferences were restored exactly. The private acceptance record is `local-evidence/native-drag-final-acceptance-2026-10-24.json`.

[CI run 40062127577](https://github.com/akashmahedy/TaskPane/actions/runs/40062127577) passed for `4c169fb`. The final local package preserves the same verified executable across the app, packaged app and extracted ZIP.
