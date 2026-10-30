#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$TASK_ROOT/scripts/check-xcodegen.sh"
node "$TASK_ROOT/ios/scripts/refresh-test-runner.mjs" "$@"
exec /usr/bin/xcodebuild "$@"
