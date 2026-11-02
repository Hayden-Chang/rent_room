#!/bin/bash
set -euo pipefail

# Cloud workers are disposable. Never install tools on a developer Mac via this hook.
[[ "${CI_XCODE_CLOUD:-}" == "TRUE" ]] || { echo 'This hook requires Xcode Cloud.' >&2; exit 1; }
TASK_ROOT="${CI_PRIMARY_REPOSITORY_PATH:?Missing Xcode Cloud checkout}"
cd "$TASK_ROOT"

TASK_NODE_MAJOR="$(tr -d '[:space:]' < .nvmrc)"
if ! command -v node >/dev/null || [[ "$(node -p 'process.versions.node.split(".")[0]')" != "$TASK_NODE_MAJOR" ]]; then
  brew install "node@$TASK_NODE_MAJOR"
  export PATH="$(brew --prefix "node@$TASK_NODE_MAJOR")/bin:$PATH"
fi
[[ "$(node -p 'process.versions.node.split(".")[0]')" == "$TASK_NODE_MAJOR" ]]
npm ci --prefix apps/wechat --no-audit --no-fund

TASK_XCODEGEN_VERSION="$(tr -d '[:space:]' < .xcodegen-version)"
[[ "$TASK_XCODEGEN_VERSION" == '2.45.4' ]] || { echo 'Update the pinned XcodeGen download checksum.' >&2; exit 1; }
TASK_TOOLS="$(mktemp -d "${TMPDIR:-/tmp}/rentvisit-cloud-tools.XXXXXX")"
trap 'rm -rf "$TASK_TOOLS"' EXIT
curl --fail --silent --show-error --location --connect-timeout 15 --max-time 120 \
  "https://github.com/yonaskolb/XcodeGen/releases/download/$TASK_XCODEGEN_VERSION/xcodegen.zip" \
  --output "$TASK_TOOLS/xcodegen.zip"
TASK_SHA="$(shasum -a 256 "$TASK_TOOLS/xcodegen.zip" | awk '{print $1}')"
[[ "$TASK_SHA" == '090ec29491aad50aec10631bf6e62253fed733c50f3aab0f5ffc86bc170bdbef' ]] || { echo 'XcodeGen checksum mismatch.' >&2; exit 1; }
unzip -q "$TASK_TOOLS/xcodegen.zip" -d "$TASK_TOOLS"
export PATH="$TASK_TOOLS/xcodegen/bin:$PATH"
bash scripts/check-xcodegen.sh
echo "RentVisit generated project from commit $(git rev-parse HEAD)"
