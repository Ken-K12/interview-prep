#!/usr/bin/env bash
set -euo pipefail
LAB=incident-drill
source ../common.sh
lab_cleanup_base
rm -f alert.log
echo "cleanup done"
