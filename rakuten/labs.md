# Hands-on Refresher Labs (one per story)

Each lab is small (30–60 min), runs on a laptop with Docker (plus Ansible for Lab 3), and costs nothing. Goal: rebuild the idea from the story so you can explain it from real, recent practice.

Honesty rule: these are **lab exercises**. Say "I practiced this in a lab" in the interview, not "in production".

## Contents
1. Lab 1 – Parallel run and cutover (Jenkins migration)
2. Lab 2 – Incident drill with log analysis
3. Lab 3 – Ansible, CloudFormation, and drift detection
4. Lab 4 – Jenkins pipeline and Blue/Green switch
5. Lab 5 – Nginx reverse proxy and Squid
6. Lab 6 – Missing logs with Fluent Bit and IAM checks

## Setup (once)

```bash
mkdir -p ~/labs && cd ~/labs
docker --version && docker compose version
pip install ansible ansible-lint cfn-lint
docker network create labnet
```

---

## Lab 1 – Parallel run and cutover (Story 1)

**Goal:** Run "old" and "new" Jenkins side by side, check the new one, then switch users with no downtime.

```bash
# Old server (stands in for CentOS 7)
docker run -d --name jenkins-old --network labnet -v jenkins_old:/var/jenkins_home jenkins/jenkins:lts
# Copy its data to the new server (stands in for Amazon Linux 2023)
docker run --rm -v jenkins_old:/from -v jenkins_new:/to alpine sh -c "cp -a /from/. /to/"
docker run -d --name jenkins-new --network labnet -v jenkins_new:/var/jenkins_home jenkins/jenkins:lts
```

Put Nginx in front as the switch (`~/labs/nginx-switch.conf`, upstream set to `jenkins-old:8080`):

```nginx
server {
  listen 80;
  location / { proxy_pass http://jenkins-old:8080; }
}
```

```bash
docker run -d --name front --network labnet -p 8080:80 -v ~/labs/nginx-switch.conf:/etc/nginx/conf.d/default.conf:ro nginx
# Cutover: change upstream to jenkins-new:8080, then
docker exec front nginx -s reload
# Rollback: change it back and reload
```

**Check:** Run `while true; do curl -s -o /dev/null -w "%{http_code}\n" localhost:8080/login; sleep 1; done` during the switch. No non-200/403 codes means no downtime.

**Explain:** announce, rehearse, parallel run, cutover, rollback. Write down your own checklist for the [TODO] in Story 1.

---

## Lab 2 – Incident drill with log analysis (Story 2)

**Goal:** Practice "alert → check logs → find cause → recover → report".

```bash
docker run -d --name app --network labnet -p 8081:80 nginx
# Generate traffic and errors
for i in $(seq 1 50); do curl -s -o /dev/null localhost:8081/ok$((i%3)); done
# Break it
docker exec app sh -c "rm /etc/nginx/conf.d/default.conf && nginx -s reload"
for i in $(seq 1 20); do curl -s -o /dev/null localhost:8081/; done
# Investigate
docker logs app 2>&1 | grep -E " (404|500|502) " | awk '{print $9}' | sort | uniq -c
docker logs app 2>&1 | grep -i error | tail
```

Write a simple alert script that checks `curl -f localhost:8081/` every 5 seconds and prints "ALERT" on failure (stand-in for Zabbix/Opsgenie).

**Check:** Restore the config (`docker restart app`) and write a 5-line incident report: time, impact, cause, fix, prevention.

**Explain:** how you read logs first, and what "recovery time" means. Pick a real incident from memory for the [TODO] in Story 2.

---

## Lab 3 – Ansible, CloudFormation, and drift detection (Story 3)

**Goal:** Define a server in code, change it by hand, and detect the drift.

```bash
docker run -d --name web1 --network labnet ubuntu:22.04 sleep infinity
docker exec web1 sh -c "apt-get update -qq && apt-get install -y -qq python3 >/dev/null"
```

`inventory.ini`:

```ini
[web]
web1 ansible_connection=docker
```

`site.yml`:

```yaml
- hosts: web
  tasks:
    - name: Install nginx
      apt: { name: nginx, state: present, update_cache: true }
    - name: Config file
      copy: { dest: /etc/nginx/conf.d/app.conf, content: "server { listen 8080; }\n" }
```

```bash
ansible-playbook -i inventory.ini site.yml          # apply
docker exec web1 sh -c "echo '# manual edit' >> /etc/nginx/conf.d/app.conf"
ansible-playbook -i inventory.ini site.yml --check --diff   # detects drift
ansible-playbook -i inventory.ini site.yml          # converge; run again = no changes (idempotent)
```

CloudFormation (validate only, no AWS cost): save a small template with one `AWS::S3::Bucket`, then run `cfn-lint template.yml`. Optional with an AWS account: deploy it, change a tag in the console, and run drift detection (`aws cloudformation detect-stack-drift`).

**Explain:** idempotency, `--check --diff`, and how AWS Config / CloudFormation drift compare IaC with real resources. Write down the real Ansible tasks you used for the [TODO] in Story 3.

---

## Lab 4 – Jenkins pipeline and Blue/Green switch (Story 4)

**Goal:** A Jenkins job that builds, deploys "green", checks health, and switches traffic.

```bash
docker run -d --name jenkins --network labnet -p 8090:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts
```

Use two app containers `app-blue` and `app-green` (both `nginx`, different index pages) and an Nginx `front` like Lab 1. A `Jenkinsfile` with stages: Build → Deploy to idle color → Health check (`curl -f`) → Switch (`sed` the upstream, `nginx -s reload`) → Keep the old color for rollback. Use a shell script for each stage, as you did in work.

**Check:** `curl localhost:8082` shows blue, run the job, it shows green, rollback shows blue again.

**Explain:** why Blue/Green makes rollback fast, and where CodeBuild/CodeDeploy for ECS fit the same idea. Note one real pipeline for the [TODO] in Story 4.

---

## Lab 5 – Nginx reverse proxy and Squid (Story 5)

**Goal:** Know the difference between a reverse proxy (Nginx) and a forward proxy (Squid). Squid is lab-only knowledge.

Nginx reverse proxy with a basic rate limit:

```nginx
limit_req_zone $binary_remote_addr zone=one:10m rate=5r/s;
server {
  listen 80;
  location / { limit_req zone=one burst=10; proxy_pass http://app:80; }
}
```

Squid forward proxy:

```bash
docker run -d --name squid --network labnet -p 3128:3128 ubuntu/squid
curl -x localhost:3128 -I http://example.com        # goes through the proxy
docker exec squid tail -n 5 /var/log/squid/access.log
```

Add an ACL that allows only `example.com` (edit `/etc/squid/squid.conf`, `acl okdst dstdomain example.com`, `http_access allow okdst`, `http_access deny all`, then `squid -k reconfigure`) and test that another site returns 403.

**Explain:** reverse vs forward proxy, ACLs, access log fields (client, status, cache HIT/MISS). Keep AWS WAF and API Gateway notes from your real work separate from this lab.

---

## Lab 6 – Missing logs with Fluent Bit and IAM checks (Story 6)

**Goal:** Build a log pipeline, break each part, and find the break using your IAM → network → data path order.

`fluent-bit.conf`:

```ini
[INPUT]
    Name  tail
    Path  /logs/app.log
[OUTPUT]
    Name  stdout
    Match *
```

```bash
mkdir -p ~/labs/logs && echo "hello" >> ~/labs/logs/app.log
docker run --rm --name fb --network labnet -v ~/labs/logs:/logs -v ~/labs/fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro fluent/fluent-bit
```

Break drills (one at a time, write down the symptom):
1. Wrong `Path` → no logs at all.
2. Make the file unreadable (`chmod 000`) → permission problem.
3. Change the output to an unreachable host (`Name http`, `Host 10.255.255.1`) → retries and delay.

Optional with AWS: send to CloudWatch Logs, remove the `logs:PutLogEvents` permission, and watch the error. Useful commands: `aws sts get-caller-identity`, `aws iam simulate-principal-policy`.

**Explain:** your order of checks (IAM → network → data path), plus buffering and retries as a cause of delay. Write the real root cause from your PoC for the [TODO] in Story 6.

---

## Cleanup

```bash
docker rm -f jenkins-old jenkins-new front app web1 jenkins squid fb 2>/dev/null
docker volume rm jenkins_old jenkins_new jenkins_home 2>/dev/null
docker network rm labnet
```
