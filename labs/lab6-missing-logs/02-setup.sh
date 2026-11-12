#!/usr/bin/env bash
# Starts a log generator and Fluent Bit that ships the file to CloudWatch Logs.
set -euo pipefail
source ./lab.env; source ../common.sh; source ./ips.env
lab_ready "$APP_PUB"
lab_put "$APP_PUB" fluent-bit.conf /tmp/fluent-bit.conf
lab_put "$APP_PUB" loggen.sh /tmp/loggen.sh
lab_ssh "$APP_PUB" 'bash -s' <<'REMOTE'
set -e
sudo cp /tmp/fluent-bit.conf /srv/fb/fluent-bit.conf
sudo docker run -d --name loggen --restart unless-stopped -v /srv/lab-logs:/logs -v /tmp/loggen.sh:/loggen.sh:ro alpine sh /loggen.sh
sudo docker run -d --name fb --restart unless-stopped --network host \
  -v /srv/fb:/fluent-bit/etc:ro -v /srv/lab-logs:/var/log/lab:ro fluent/fluent-bit
REMOTE
sleep 15
./04-diagnose.sh
