# Privacy

TaskPane 0.1.0 contains no account system, telemetry SDK, analytics, updater or cloud transport. Its collectors do not make outgoing requests.

- Window metadata is inspected locally to display and operate windows.
- Individual-window identifiers and manual window order exist only for the current TaskPane session; they are not written to preferences or exported.
- The Start menu's recent-app list tracks up to 12 apps activated or launched during the current session. It stays in memory and has no history file.
- CPU, memory, primary-interface network counters and battery readings stay in memory. Chart history is bounded to 60 samples.
- No screenshot or screen-recording collector is present in this alpha.
- Preferences, including application/section ordering, pin paths and their order, exclusions, appearance and widget choices, stay in the app's own Application Support folder unless you explicitly export them.
- Exports include app paths; avoid publishing personal backup files.
- Import never grants Accessibility or executes a command from the file. Launching a pinned app requires a separate user action.
- Launcher actions ask macOS to launch the selected local application. The launched application has its own privacy behavior.
- Window and app menu commands run only on user action. Quit requests normal application termination, allowing the application to handle unsaved work.
- Granting Accessibility is optional and controlled by macOS. Revoking it disables individual-window actions.
- TaskPane does not change the system Dock, install a daemon or write fan settings.

The source repository excludes build output, logs, diagnostic evidence and personal preferences. Report bugs without attaching private window titles or unredacted backups.
