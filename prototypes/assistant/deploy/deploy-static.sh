#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
remote="${XUNJU_SSH_TARGET:?Set XUNJU_SSH_TARGET explicitly before deployment}"
release="$(date -u +%Y%m%dT%H%M%SZ)"
if [ "${1:-}" != "--use-existing-build" ]; then
  npm run build
  node --test tests/model.test.mjs
fi
test -f dist/index.html
ssh -o BatchMode=yes "$remote" "mkdir -p /var/www/xunju/releases/$release"
rsync -az --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r dist/ "$remote:/var/www/xunju/releases/$release/"
scp deploy/xunju.nginx.conf "$remote:/tmp/xunju-nginx-$release.conf"
ssh -o BatchMode=yes "$remote" bash -s -- "$release" <<'REMOTE'
set -euo pipefail
release="$1"
previous="$(readlink -f /var/www/xunju/current || true)"
config=/etc/nginx/sites-available/xunju
backup="/etc/nginx/sites-available/xunju.backup-$release"
if [ -f "$config" ]; then cp -p "$config" "$backup"; fi
install -m 644 "/tmp/xunju-nginx-$release.conf" "$config"
ln -sfn "$config" /etc/nginx/sites-enabled/xunju
ln -sfn "/var/www/xunju/releases/$release" /var/www/xunju/current.next
mv -Tf /var/www/xunju/current.next /var/www/xunju/current
if ! nginx -t; then
  if [ -n "$previous" ] && [ -d "$previous" ]; then ln -sfn "$previous" /var/www/xunju/current; fi
  if [ -f "$backup" ]; then cp -p "$backup" "$config"; else rm -f /etc/nginx/sites-enabled/xunju "$config"; fi
  exit 1
fi
systemctl reload nginx
healthy=0
for attempt in 1 2 3 4 5; do
  if curl --fail --silent -H 'Host: keeline.xyz' http://127.0.0.1/ >/dev/null; then healthy=1; break; fi
  sleep 1
done
[ "$healthy" = 1 ]
printf 'Published release %s\n' "$release"
REMOTE
