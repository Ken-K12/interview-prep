#!/usr/bin/env bash
# Practice order: scope (status codes) -> error log -> container state -> config test.
set -euo pipefail
LAB=incident-drill
source ../common.sh; source ./ips.env
lab_ssh "$APP_PUB" '
echo "== 1. Status codes in the access log"
awk "{print \$6}" /srv/app/logs/access.log | sort | uniq -c
echo "== 2. Last errors"
tail -n 5 /srv/app/logs/error.log
echo "== 3. Containers"
sudo docker ps -a --format "table {{.Names}}\t{{.Status}}"
echo "== 4. Config test"
sudo docker exec front nginx -t 2>&1 || true'
