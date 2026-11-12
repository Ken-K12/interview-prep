#!/usr/bin/env bash
# 40 requests, 20 at a time. Expect a mix of 200 and 429 (rate limit hit).
set -euo pipefail
source ./ips.env
seq 40 | xargs -P 20 -I{} curl -s -o /dev/null -w '%{http_code}\n' "http://$GW_PUB/" | sort | uniq -c
echo "--- access log (last 5)"
ssh -i ./proxy-lab.pem -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR "ec2-user@$GW_PUB" "tail -n 5 /srv/gw/logs/access.log"
