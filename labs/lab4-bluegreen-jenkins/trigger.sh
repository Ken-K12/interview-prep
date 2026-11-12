#!/usr/bin/env bash
# Usage: ./trigger.sh bg-deploy | bg-deploy-broken | bg-rollback
set -euo pipefail
LAB=bluegreen-lab
source ../common.sh; source ./ips.env
lab_ssh "$APP_PUB" "JOB=${1:?job name required} bash -s" <<'REMOTE'
J=localhost:8080
C=$(curl -s -c /tmp/c $J/crumbIssuer/api/json | jq -r '.crumbRequestField+":"+.crumb')
NEXT=$(curl -s $J/job/$JOB/api/json | jq .nextBuildNumber)
curl -s -b /tmp/c -H "$C" -X POST $J/job/$JOB/build -o /dev/null -w "queued HTTP %{http_code}\n"
until [ -n "$(curl -s $J/job/$JOB/$NEXT/api/json 2>/dev/null | jq -r '.result // empty' 2>/dev/null)" ]; do sleep 3; done
echo "Result: $(curl -s $J/job/$JOB/$NEXT/api/json | jq -r .result)"
curl -s $J/job/$JOB/$NEXT/consoleText | tail -n 6
REMOTE
