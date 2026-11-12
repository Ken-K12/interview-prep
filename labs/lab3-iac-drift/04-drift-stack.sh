#!/usr/bin/env bash
# Resource drift: change the security group outside CloudFormation, then run drift detection.
set -euo pipefail
LAB=iac-lab
source ../common.sh
SG=$(aws cloudformation describe-stack-resource --stack-name "$LAB" --logical-resource-id WebSG \
     --query StackResourceDetail.PhysicalResourceId --output text)
MY_IP=$(curl -s https://checkip.amazonaws.com)/32
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 8080 --cidr "$MY_IP" >/dev/null
echo "Added port 8080 by hand to $SG"

ID=$(aws cloudformation detect-stack-drift --stack-name "$LAB" --query StackDriftDetectionId --output text)
until [ "$(aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id "$ID" \
      --query DetectionStatus --output text)" != DETECTION_IN_PROGRESS ]; do sleep 3; done
aws cloudformation describe-stack-resource-drifts --stack-name "$LAB" \
  --stack-resource-drift-status-filters MODIFIED --query 'StackResourceDrifts[].{Resource:LogicalResourceId,Status:StackResourceDriftStatus,Diff:PropertyDifferences[].PropertyPath}'
echo "Fix: remove the manual rule, or add it to template.yml and redeploy."
aws ec2 revoke-security-group-ingress --group-id "$SG" --protocol tcp --port 8080 --cidr "$MY_IP" >/dev/null
