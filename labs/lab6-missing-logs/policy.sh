#!/usr/bin/env bash
# Usage: source ./policy.sh; set_policy full|no-put
# full = CreateLogStream + PutLogEvents. no-put = CreateLogStream only (PutLogEvents is missing).
set_policy() {
  local acct actions
  acct=$(aws sts get-caller-identity --query Account --output text)
  if [ "$1" = full ]; then actions='"logs:CreateLogStream","logs:PutLogEvents","logs:DescribeLogStreams"'
  else actions='"logs:CreateLogStream","logs:DescribeLogStreams"'; fi
  aws iam put-role-policy --role-name "$ROLE" --policy-name logs-write --policy-document \
    "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[$actions],\"Resource\":\"arn:aws:logs:$AWS_REGION:$acct:log-group:$LOG_GROUP:*\"}]}"
}
