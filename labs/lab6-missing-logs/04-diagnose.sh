#!/usr/bin/env bash
# Same order as the story: 1) IAM  2) network  3) data path.
set -uo pipefail
source ./lab.env; source ../common.sh; source ./ips.env
set +e
ACCT=$(aws sts get-caller-identity --query Account --output text)

echo "== 1. IAM: can the role write logs? (simulation)"
aws iam simulate-principal-policy --policy-source-arn "arn:aws:iam::$ACCT:role/$ROLE" \
  --action-names logs:CreateLogStream logs:PutLogEvents \
  --resource-arns "arn:aws:logs:$AWS_REGION:$ACCT:log-group:$LOG_GROUP:*" \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' --output text

echo "== 2. Network: can the instance reach the CloudWatch Logs endpoint? (000 = no)"
lab_ssh "$APP_PUB" "curl -s -o /dev/null -m 5 -w 'HTTP %{http_code}\n' https://logs.$AWS_REGION.amazonaws.com"

echo "== 3. Data path: source file, Fluent Bit log, and the latest events"
lab_ssh "$APP_PUB" "ls -l /srv/lab-logs/app.log; echo '-- fluent-bit:'; sudo docker logs --tail 5 fb 2>&1"
echo "-- CloudWatch (lag = ingestionTime - timestamp, in seconds):"
aws logs get-log-events --log-group-name "$LOG_GROUP" --log-stream-name app-1 --limit 3 --start-from-head false \
  --query 'events[].[timestamp,ingestionTime]' --output text 2>&1 \
  | awk 'NF==2{printf "event %s  lag %.0fs\n", strftime("%T", $1/1000), ($2-$1)/1000; next}{print}'
echo "-- now: $(date +%T)"
