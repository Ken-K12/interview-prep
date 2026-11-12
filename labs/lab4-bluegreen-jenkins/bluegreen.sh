#!/usr/bin/env bash
# Usage: bluegreen.sh deploy VERSION [--broken] | rollback | status
# Two app containers (blue, green) sit behind Nginx. Only one is live.
set -euo pipefail
CONF=/srv/nginx/conf.d/default.conf
ACTIVE_FILE=/srv/nginx/active
docker network create bg >/dev/null 2>&1 || true
active=$(cat "$ACTIVE_FILE" 2>/dev/null || echo none)

switch_to() {
  printf 'server {\n  listen 80;\n  location / {\n    proxy_pass http://app-%s:5678;\n    add_header X-Color %s always;\n  }\n}\n' "$1" "$1" > "$CONF"
  if docker ps --format '{{.Names}}' | grep -qx front; then
    docker exec front nginx -t && docker exec front nginx -s reload
  else
    docker run -d --name front --network bg --restart unless-stopped -p 80:80 -v /srv/nginx/conf.d:/etc/nginx/conf.d nginx >/dev/null
  fi
  echo "$1" > "$ACTIVE_FILE"
}

healthy() {
  local i
  for i in 1 2 3 4 5 6; do
    docker run --rm --network bg curlimages/curl -sf "http://app-$1:5678" >/dev/null && return 0
    sleep 2
  done
  return 1
}

case "${1:-}" in
  deploy)
    ver=${2:?version required}
    if [ "$active" = blue ]; then idle=green; else idle=blue; fi
    docker rm -f "app-$idle" >/dev/null 2>&1 || true
    if [ "${3:-}" = --broken ]; then
      docker run -d --name "app-$idle" --network bg alpine sleep 3600 >/dev/null
    else
      docker run -d --name "app-$idle" --network bg hashicorp/http-echo -text="$idle $ver" >/dev/null
    fi
    if ! healthy "$idle"; then
      echo "Health check FAILED for $idle. $active stays live."
      docker rm -f "app-$idle" >/dev/null
      exit 1
    fi
    switch_to "$idle"
    echo "Switched $active -> $idle (version $ver). Old color kept for rollback."
    ;;
  rollback)
    [ "$active" != none ] || { echo "nothing to roll back"; exit 1; }
    if [ "$active" = blue ]; then prev=green; else prev=blue; fi
    docker ps --format '{{.Names}}' | grep -qx "app-$prev" || { echo "app-$prev is not running"; exit 1; }
    switch_to "$prev"
    echo "Rolled back $active -> $prev"
    ;;
  status) echo "active: $active"; docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'NAMES|app-|front' ;;
  *) echo "usage: $0 deploy VERSION [--broken] | rollback | status"; exit 1 ;;
esac
