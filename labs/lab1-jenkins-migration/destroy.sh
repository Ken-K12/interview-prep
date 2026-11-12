#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"; source ./lab.env
aws cloudformation delete-stack --stack-name "$LAB"
aws cloudformation wait stack-delete-complete --stack-name "$LAB"
rm -f "$KEY" ips.env