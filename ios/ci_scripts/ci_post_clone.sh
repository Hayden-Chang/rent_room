#!/bin/bash
set -euo pipefail

# Cloud workers are disposable. Never install tools on a developer Mac via this hook.
[[ "${CI_XCODE_CLOUD:-}" == "TRUE" ]] || { echo 'This hook requires Xcode Cloud.' >&2; exit 1; }
TASK_ROOT="${CI_PRIMARY_REPOSITORY_PATH:?Missing Xcode Cloud checkout}"
cd "$TASK_ROOT"

TASK_TOOLS="$(mktemp -d "${TMPDIR:-/tmp}/rentvisit-cloud-tools.XXXXXX")"
trap 'rm -rf "$TASK_TOOLS"' EXIT
TASK_NODE_MAJOR="$(tr -d '[:space:]' < .nvmrc)"
TASK_NODE_VERSION='24.22.2'
[[ "$TASK_NODE_MAJOR" == "${TASK_NODE_VERSION%%.*}" ]] || { echo 'Update the pinned Node download.' >&2; exit 1; }
# Cloud may use Intel hosts without Homebrew bottles. Use official binaries on both architectures.
case "$(uname -m)" in
  arm64) TASK_NODE_ARCH='arm64'; TASK_NODE_SHA='aa9549349e47dffaa42dcf95d6e06ade8c4bdafc980979883b88767670df385a' ;;
  x86_64) TASK_NODE_ARCH='x64'; TASK_NODE_SHA='d5e336d588c45be0c37dbd52cc29895593009ca4997a77a1fd02815131ed0e52' ;;
  *) echo 'Unsupported cloud architecture.' >&2; exit 1 ;;
esac
TASK_NODE_PACKAGE="node-v$TASK_NODE_VERSION-darwin-$TASK_NODE_ARCH"
curl --fail --silent --show-error --location --connect-timeout 15 --max-time 120 \
  "https://nodejs.org/dist/v$TASK_NODE_VERSION/$TASK_NODE_PACKAGE.tar.gz" \
  --output "$TASK_TOOLS/node.tar.gz"
[[ "$(shasum -a 256 "$TASK_TOOLS/node.tar.gz" | awk '{print $1}')" == "$TASK_NODE_SHA" ]] || { echo 'Node checksum mismatch.' >&2; exit 1; }
tar -xzf "$TASK_TOOLS/node.tar.gz" -C "$TASK_TOOLS"
export PATH="$TASK_TOOLS/$TASK_NODE_PACKAGE/bin:$PATH"
[[ "$(node -p 'process.versions.node.split(".")[0]')" == "$TASK_NODE_MAJOR" ]]
node --version
npm ci --prefix apps/wechat --no-audit --no-fund

TASK_XCODEGEN_VERSION="$(tr -d '[:space:]' < .xcodegen-version)"
[[ "$TASK_XCODEGEN_VERSION" == '2.45.4' ]] || { echo 'Update the pinned XcodeGen download checksum.' >&2; exit 1; }
curl --fail --silent --show-error --location --connect-timeout 15 --max-time 120 \
  "https://github.com/yonaskolb/XcodeGen/releases/download/$TASK_XCODEGEN_VERSION/xcodegen.zip" \
  --output "$TASK_TOOLS/xcodegen.zip"
TASK_SHA="$(shasum -a 256 "$TASK_TOOLS/xcodegen.zip" | awk '{print $1}')"
[[ "$TASK_SHA" == '090ec29491aad50aec10631bf6e62253fed733c50f3aab0f5ffc86bc170bdbef' ]] || { echo 'XcodeGen checksum mismatch.' >&2; exit 1; }
unzip -q "$TASK_TOOLS/xcodegen.zip" -d "$TASK_TOOLS"
export PATH="$TASK_TOOLS/xcodegen/bin:$PATH"
bash scripts/check-xcodegen.sh
echo "RentVisit generated project from commit $(git rev-parse HEAD)"
