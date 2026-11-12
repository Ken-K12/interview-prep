#!/usr/bin/env bash
# Server drift: edit one server by hand, detect it, then fix it by running Ansible again.
set -euo pipefail
LAB=iac-lab
source ../common.sh
echo "== Manual change on web1"
ansible web1 -b -m ansible.builtin.shell -a "echo 'Hello from a manual edit' > /usr/share/nginx/html/index.html"
echo "== Dry run: --check --diff shows the drift without changing anything"
ansible-playbook site.yml --check --diff || true
echo "== Converge"
ansible-playbook site.yml
echo "== Run again: changed=0 means the playbook is idempotent"
ansible-playbook site.yml | tail -n 4
