#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_VERSION="$(tr -d '[:space:]' < "$TASK_ROOT/.xcodegen-version")"
TASK_INSTALLED="$(xcodegen --version | awk '{print $NF}')"
if [[ "$TASK_INSTALLED" != "$TASK_VERSION" ]]; then
  echo "XcodeGen $TASK_VERSION required; found $TASK_INSTALLED" >&2
  exit 1
fi
if [[ -n "$(git -C "$TASK_ROOT" ls-files 'ios/Xunju.xcodeproj/*')" ]]; then
  echo 'Generated Xunju.xcodeproj must not be tracked' >&2
  exit 1
fi
git -C "$TASK_ROOT" check-ignore -q ios/Xunju.xcodeproj/project.pbxproj
xcodegen generate --spec "$TASK_ROOT/ios/project.yml" --project "$TASK_ROOT/ios" --quiet
TASK_FIRST="$(shasum -a 256 "$TASK_ROOT/ios/Xunju.xcodeproj/project.pbxproj" | awk '{print $1}')"
xcodegen generate --spec "$TASK_ROOT/ios/project.yml" --project "$TASK_ROOT/ios" --quiet
TASK_SECOND="$(shasum -a 256 "$TASK_ROOT/ios/Xunju.xcodeproj/project.pbxproj" | awk '{print $1}')"
[[ "$TASK_FIRST" == "$TASK_SECOND" ]] || { echo 'XcodeGen generation is not deterministic' >&2; exit 1; }
for TASK_TARGET in Xunju XunjuTests XunjuUITests; do
  /usr/bin/grep -q "name = $TASK_TARGET;" "$TASK_ROOT/ios/Xunju.xcodeproj/project.pbxproj"
done
echo "XcodeGen $TASK_VERSION: deterministic project verified"
