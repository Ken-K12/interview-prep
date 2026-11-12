#!/usr/bin/env bash
set -uo pipefail
source ./lab.env; source ../common.sh
set +e
lab_cleanup_base
aws iam remove-role-from-instance-profile --instance-profile-name "$PROFILE" --role-name "$ROLE"
aws iam delete-instance-profile --instance-profile-name "$PROFILE"
aws iam delete-role-policy --role-name "$ROLE" --policy-name logs-write
aws iam delete-role --role-name "$ROLE"
aws logs delete-log-group --log-group-name "$LOG_GROUP"
echo "cleanup done"
