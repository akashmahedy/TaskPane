#!/bin/bash
set -euo pipefail
TASKPANE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASKPANE_ROOT"
mkdir -p .build/ModuleCache .build/cache .build/config .build/security
export CLANG_MODULE_CACHE_PATH="$TASKPANE_ROOT/.build/ModuleCache"
TASKPANE_EXTRA_FLAGS=()
TASKPANE_DEVELOPER_DIR="$(xcode-select -p)"
TASKPANE_TESTING_PLUGIN="$TASKPANE_DEVELOPER_DIR/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
TASKPANE_TESTING_FRAMEWORKS="$TASKPANE_DEVELOPER_DIR/Library/Developer/Frameworks"
if [ -f "$TASKPANE_TESTING_PLUGIN" ]; then
  TASKPANE_EXTRA_FLAGS+=( -Xswiftc -load-plugin-library -Xswiftc "$TASKPANE_TESTING_PLUGIN" )
  TASKPANE_EXTRA_FLAGS+=( -Xswiftc -F"$TASKPANE_TESTING_FRAMEWORKS" )
  TASKPANE_EXTRA_FLAGS+=( -Xlinker -F"$TASKPANE_TESTING_FRAMEWORKS" -Xlinker -rpath -Xlinker "$TASKPANE_TESTING_FRAMEWORKS" )
fi
swift test --build-system native --disable-xctest --enable-swift-testing --disable-sandbox --cache-path "$TASKPANE_ROOT/.build/cache" --config-path "$TASKPANE_ROOT/.build/config" --security-path "$TASKPANE_ROOT/.build/security" -Xswiftc -module-cache-path -Xswiftc "$CLANG_MODULE_CACHE_PATH" "${TASKPANE_EXTRA_FLAGS[@]}"
