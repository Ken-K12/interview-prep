#!/usr/bin/env bash
# A work-instruction style change: edit, parse-check, reload, test.
set -euo pipefail
LAB=proxy-lab
source ../common.sh; source ./ips.env
lab_ssh "$SQUID_PUB" 'bash -s' <<'REMOTE'
set -e
sudo sed -i 's#^acl allowed_dst dstdomain .*#acl allowed_dst dstdomain .example.com .example.org#' /srv/squid/squid.conf
sudo docker restart squid >/dev/null
sleep 5
sudo docker exec squid squid -k parse 2>&1 | tail -n 2
REMOTE
echo "example.org (http): $(curl -s -o /dev/null -m 10 -x "http://$SQUID_PUB:3128" -w '%{http_code}' http://example.org)"
