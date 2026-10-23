# Privacy

TaskPane 0.1.0 contains no account system, telemetry SDK, analytics, updater or cloud transport. Its collectors do not make outgoing requests.

- Window metadata is inspected locally to display and operate windows.
- CPU, memory, primary-interface network counters and battery readings stay in memory. Chart history is bounded to 60 samples.
- No screenshot or screen-recording collector is present in this alpha.
- Preferences stay in the app's own Application Support folder unless you explicitly export them.
- Exports include app paths; avoid publishing personal backup files.
- Import never grants Accessibility or executes a command from the file. Launching a pinned app requires a separate user action.
- Launcher actions ask macOS to launch the selected local application. The launched application has its own privacy behavior.
- Granting Accessibility is optional and controlled by macOS. Revoking it disables individual-window actions.
- TaskPane does not change the system Dock, install a daemon or write fan settings.

The source repository excludes build output, logs, diagnostic evidence and personal preferences. Report bugs without attaching private window titles or unredacted backups.
