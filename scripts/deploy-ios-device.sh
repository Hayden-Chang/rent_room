#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec /usr/bin/python3 "$TASK_ROOT/scripts/ios-device/deploy.py" "$@"
