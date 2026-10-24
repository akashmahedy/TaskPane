# Privacy

TaskPane 0.1.0 contains no account system, telemetry SDK, analytics, updater or cloud transport. Its collectors do not make outgoing requests.

- Window metadata is inspected locally to display and operate windows.
- Individual-window identifiers and manual window order exist only for the current TaskPane session; they are not written to preferences or exported.
- The Start menu's recent-app list tracks up to 12 apps activated or launched during the current session. It stays in memory and has no history file.
- CPU, memory, primary-interface network counters and battery readings stay in memory. Chart history is bounded to 60 samples.
- Optional hover previews capture only the selected verified window through ScreenCaptureKit after an explicit Screen Recording permission action. Snapshots stay in a short-lived, bounded memory cache; no screenshot files or continuous streams are created. Disabling previews clears the cache.
- Optional native Space queries read only topology/membership and native window IDs. Private symbols are checked at runtime; failures remain unknown and use a visibility fallback. No Space assignment or mutation calls are loaded.
- Optional badges read only the system Dock’s application-item status labels, mapped by exact local app URL; no notification contents are read.
- Preferences, including application/section ordering, pin paths and their order, exclusions, appearance and widget choices, stay in the app's own Application Support folder unless you explicitly export them.
- Exports include app paths; avoid publishing personal backup files.
- Import never grants Accessibility or executes a command from the file. Launching a pinned app requires a separate user action.
- Launcher actions ask macOS to launch the selected local application. The launched application has its own privacy behavior.
- Window and app menu commands run only on user action. Opt-in overlap avoidance can resize eligible normal windows and retains original geometry for safe restoration; it does not restore over later user edits. Quit requests normal application termination, allowing the application to handle unsaved work.
- Granting Accessibility is optional and controlled by macOS. Revoking it disables individual-window actions.
- Dock edge, auto-hide and reveal delay change through explicit Apply/Restore. Optional normal-quit restoration restores keys still owned by TaskPane and preserves later independent edits. Original values and key absence are stored locally in Dock-original.json, separately from portable preferences, for recovery after an unexpected exit. TaskPane installs no daemon and writes no fan settings.
- Standard native tab titles/group identity stay in memory. Actions revalidate exact AX tab/group membership; closing a tab uses its own native close control or a verified explicit Close Tab menu command, never a window close button or synthetic keyboard shortcut.

The source repository excludes build output, logs, diagnostic evidence and personal preferences. Report bugs without attaching private window titles or unredacted backups.
