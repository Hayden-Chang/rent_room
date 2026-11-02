#!/bin/bash
set -euo pipefail

[[ "${CI_XCODE_CLOUD:-}" == "TRUE" ]] || exit 0
[[ "${CI_XCODE_SCHEME:-}" == 'XunjuLiveUSSearch' ]] || exit 0
[[ "${CI_XCODEBUILD_ACTION:-}" == 'test-without-building' ]] || exit 0

# This runs on the test worker, which is distinct from the build worker.
# It observes HTTP egress, not MapKit's internal service route or physical GPS.
echo "RentVisit test worker: commit=${CI_COMMIT:-unknown} device=${CI_TEST_DESTINATION_DEVICE_TYPE:-unknown} runtime=${CI_TEST_DESTINATION_RUNTIME:-unknown}"
echo "Observation time: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
if TASK_TRACE="$(curl --fail --silent --show-error --connect-timeout 5 --max-time 15 https://www.cloudflare.com/cdn-cgi/trace)"; then
  # Do not retain the source IP, full trace, proxy settings, or credentials.
  TASK_REGION="$(printf '%s\n' "$TASK_TRACE" | awk -F= '$1 == "loc" && $2 ~ /^[A-Z][A-Z]$/ { print $2 }')"
  TASK_COLO="$(printf '%s\n' "$TASK_TRACE" | awk -F= '$1 == "colo" && $2 ~ /^[A-Z][A-Z][A-Z]$/ { print $2 }')"
  echo "HTTP egress country=${TASK_REGION:-unknown} edge=${TASK_COLO:-unknown}"
else
  echo 'HTTP egress country=unknown (probe failed); do not classify this as a US-network test.'
fi
