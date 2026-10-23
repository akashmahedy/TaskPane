#!/bin/bash
set -euo pipefail
TASKPANE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASKPANE_ROOT"
TASKPANE_CONFIGURATION="${1:-debug}"
case "$TASKPANE_CONFIGURATION" in debug|release) ;; *) echo "Usage: scripts/build.sh [debug|release]" >&2; exit 2;; esac
mkdir -p .build/ModuleCache .build/cache .build/config .build/security dist
export CLANG_MODULE_CACHE_PATH="$TASKPANE_ROOT/.build/ModuleCache"
swift build --disable-sandbox --configuration "$TASKPANE_CONFIGURATION" --cache-path "$TASKPANE_ROOT/.build/cache" --config-path "$TASKPANE_ROOT/.build/config" --security-path "$TASKPANE_ROOT/.build/security" -Xswiftc -module-cache-path -Xswiftc "$CLANG_MODULE_CACHE_PATH"
TASKPANE_BINARY_DIR="$(swift build --disable-sandbox --configuration "$TASKPANE_CONFIGURATION" --cache-path "$TASKPANE_ROOT/.build/cache" --config-path "$TASKPANE_ROOT/.build/config" --security-path "$TASKPANE_ROOT/.build/security" --show-bin-path)"
TASKPANE_APP="$TASKPANE_ROOT/dist/TaskPane.app"
mkdir -p "$TASKPANE_APP/Contents/MacOS" "$TASKPANE_APP/Contents/Resources"
cp "$TASKPANE_BINARY_DIR/TaskPane" "$TASKPANE_APP/Contents/MacOS/TaskPane.new"
mv -f "$TASKPANE_APP/Contents/MacOS/TaskPane.new" "$TASKPANE_APP/Contents/MacOS/TaskPane"
cp Resources/Info.plist "$TASKPANE_APP/Contents/Info.plist"
if [ ! -f "$TASKPANE_APP/Contents/Resources/AppIcon.icns" ]; then
  swift -module-cache-path "$CLANG_MODULE_CACHE_PATH" scripts/make-icon.swift "$TASKPANE_ROOT/dist/TaskPane.iconset" "$TASKPANE_APP/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - --identifier io.akashmahedy.TaskPane "$TASKPANE_APP"
printf 'Built %s\n' "$TASKPANE_APP"
