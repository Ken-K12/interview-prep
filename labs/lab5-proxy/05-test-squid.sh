#!/usr/bin/env bash
# Allowed domain -> 200. Other domain -> 403 (TCP_DENIED in the access log).
set -euo pipefail
LAB=proxy-lab
source ../common.sh; source ./ips.env
P="http://$SQUID_PUB:3128"
echo "example.com (http):  $(curl -s -o /dev/null -m 10 -x "$P" -w '%{http_code}' http://example.com)"
echo "example.com (https): $(curl -s -o /dev/null -m 10 -x "$P" -w '%{http_code}' https://example.com)"
echo "example.org (http):  $(curl -s -o /dev/null -m 10 -x "$P" -w '%{http_code}' http://example.org)"
echo "--- access log (last 5): client, result/status, URL"
lab_ssh "$SQUID_PUB" "sudo docker exec squid tail -n 5 /var/log/squid/access.log"
