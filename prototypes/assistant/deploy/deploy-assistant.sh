#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
remote="${XUNJU_SSH_TARGET:?Set XUNJU_SSH_TARGET explicitly before deployment}"
release="$(date -u +%Y%m%dT%H%M%SZ)"
env_file="${XUNJU_ENV_FILE:-server/.env.local}"
ssh -o BatchMode=yes "$remote" bash -s <<'REMOTE'
set -euo pipefail
if ! id xunju-ai >/dev/null 2>&1; then useradd --system --create-home --home-dir /var/lib/xunju-assistant --shell /usr/sbin/nologin xunju-ai; fi
install -d -o xunju-ai -g xunju-ai -m 700 /var/lib/xunju-assistant
if [ ! -x /opt/xunju-runtime/node-v24.21.0-linux-x64/bin/node ]; then
  echo 'fd8e59d5a511510f6a298afb548f18c7d2b1be404d8b4a27d94fbe49f56cb2d6  /tmp/xunju-node.tar.xz' | sha256sum -c -
  mkdir -p /opt/xunju-runtime
  tar -xJf /tmp/xunju-node.tar.xz -C /opt/xunju-runtime
fi
REMOTE
ssh "$remote" "mkdir -p /opt/xunju-assistant/releases/$release"
rsync -az --exclude node_modules --exclude '.env*' --exclude .data server/ "$remote:/opt/xunju-assistant/releases/$release/"
scp deploy/xunju-assistant.service "$remote:/tmp/xunju-assistant-$release.service"
if [ -f "$env_file" ]; then
  scp -q "$env_file" "$remote:/tmp/xunju-env-$release"
  ssh "$remote" "install -m 600 -o root -g root /tmp/xunju-env-$release /etc/xunju-assistant.env && rm /tmp/xunju-env-$release"
fi
ssh "$remote" bash -s -- "$release" <<'REMOTE'
set -euo pipefail
release="$1"
target="/opt/xunju-assistant/releases/$release"
previous="$(readlink -f /opt/xunju-assistant/current || true)"
test -s /etc/xunju-assistant.env
chown -R xunju-ai:xunju-ai "$target"
runuser -u xunju-ai -- env PATH="/opt/xunju-runtime/node-v24.21.0-linux-x64/bin:/usr/bin:/bin" npm ci --prefix "$target" --omit=dev --no-audit --no-fund --cache /var/lib/xunju-assistant/npm-cache
install -m 644 "/tmp/xunju-assistant-$release.service" /etc/systemd/system/xunju-assistant.service
ln -sfn "$target" /opt/xunju-assistant/current.next
mv -Tf /opt/xunju-assistant/current.next /opt/xunju-assistant/current
systemctl daemon-reload
systemctl enable xunju-assistant >/dev/null
systemctl restart xunju-assistant
for attempt in 1 2 3 4 5; do
  if curl --fail --silent http://127.0.0.1:3188/assistant-api/health | /opt/xunju-runtime/node-v24.21.0-linux-x64/bin/node --input-type=module -e 'let text="";for await(const c of process.stdin)text+=c;try{const r=JSON.parse(text);if(!r.ok||!r.configured||r.maxConcurrent!==3)process.exit(1);}catch{process.exit(1);}'; then
    printf 'Assistant release %s ready\n' "$release"
    exit 0
  fi
  sleep 1
done
if [ -n "$previous" ]; then ln -sfn "$previous" /opt/xunju-assistant/current; systemctl restart xunju-assistant; fi
exit 1
REMOTE
