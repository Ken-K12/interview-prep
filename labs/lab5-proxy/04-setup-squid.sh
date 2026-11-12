#!/usr/bin/env bash
# Squid forward proxy that allows only example.com. Squid is lab-only practice.
set -euo pipefail
LAB=proxy-lab
source ../common.sh; source ./ips.env
lab_ready "$SQUID_PUB"
lab_put "$SQUID_PUB" squid.conf /tmp/squid.conf
lab_ssh "$SQUID_PUB" 'bash -s' <<'REMOTE'
set -e
sudo mkdir -p /srv/squid && sudo mv /tmp/squid.conf /srv/squid/squid.conf
sudo docker run -d --name squid --restart unless-stopped -p 3128:3128 -v /srv/squid/squid.conf:/etc/squid/squid.conf:ro ubuntu/squid
sleep 5
sudo docker logs squid 2>&1 | tail -n 3
REMOTE
