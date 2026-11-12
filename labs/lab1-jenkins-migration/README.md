# Lab 1 – Zero-downtime Jenkins migration (Story 1)

Runs on AWS EC2 from Codespaces. Moves Jenkins from an "old" server (Java 11) to a "new" server (newer LTS, Java 17) behind an Nginx switch.
This is practice. In the interview, tell the NRI story first and mention this lab as extra practice.

## Design
| Server | Role | Simulates |
|---|---|---|
| old (EC2 t3.medium) | Jenkins 2.426.3 LTS, Java 11 | Old server |
| new (EC2 t3.medium) | Jenkins latest LTS, Java 17 | New server |
| front (EC2 t3.micro) | Nginx | Load balancer or DNS |

```
Codespaces --curl--> front:80 (Nginx) --> old:8080 (before cutover)
                                      \-> new:8080 (after cutover)
```

Security: ports 22 and 80 are open only to your IP. Port 8080 is open only inside the security group.

## Hands-on plan (step by step)
Run everything in the Codespace, in this folder. Open `http://<FRONT_PUB>` in your PC browser (see the next section) and keep it open.

| Step | Command | What happens | Check in the browser / terminal |
|---|---|---|---|
| 0 | `chmod +x *.sh` then `./allow-ip.sh browser <PC_IP>` | Lets your PC reach port 80 | Page opens |
| 1 | `./01-create.sh` (3-5 min) | Creates 3 EC2 servers: old, new, front | `ips.env` has 10 lines |
| 2 | `./02-start-old.sh` | Starts Jenkins 2.426.3 on **old**, Nginx on **front** | `HTTP/1.1 200`, `X-Jenkins: 2.426.3` |
| 3 | `./03-create-jobs.sh` | Creates 3 sample jobs on old (see below) | Dashboard shows 3 jobs. Wait ~5 min for builds |
| 4 | `./04-migrate.sh` | Stops new builds on old, backs up, copies data to **new**, starts newer Jenkins on new | Script prints the new version and 3 jobs |
| 5 | `./06-enable-login.sh new` (optional) | Creates user `admin` with a random password on new | Note the printed password |
| 6 | `./monitor.sh` in a **second terminal** | Prints an HTTP code every 0.5 s | Stays at 200 |
| 7 | `./05-cutover.sh new` | Points Nginx from old to new | Monitor keeps 200; version changes; builds continue |
| 8 | `./05-cutover.sh old`, then `./05-cutover.sh new` | Rollback test and back | Version flips each time |
| 9 | `./99-cleanup.sh` | Deletes everything | EC2 costs money while running |

Why login is step 5, not earlier: `03` and `04` call the Jenkins API without a password, so they only work while Jenkins has no login. Until step 5 the Jenkins UI needs no password. The old server stays open, so the rollback test needs no login.

### What step 3 does (no need to read the script)
Jenkins stores each job as a folder with a `config.xml` in `JENKINS_HOME/jobs/<name>/`. The script writes three such files on the old server, restarts Jenkins so it loads them, and lists the jobs:

| Job | Schedule | Does |
|---|---|---|
| `hello-world` | every 5 min | Prints the server name (`old`/`new`) and Java version |
| `disk-check` | every 5 min | Prints disk usage |
| `heartbeat` | every minute | Appends the time to a file, so you can see history survive the migration |

Prefer the GUI? Skip step 3 and create the jobs yourself: **New Item > Freestyle project > Build Triggers > Build periodically > Build > Execute shell**. Use the commands from the table. Then continue with step 4.

## Access Jenkins from your PC browser
Ports 22/80 are open only to the Codespace IP, so your PC cannot connect by default.
`curl https://checkip.amazonaws.com` inside the Codespace returns the Codespace (Azure) egress IP, **not your PC's IP**. Get your PC IP on the PC (PowerShell):
```powershell
(Invoke-RestMethod https://checkip.amazonaws.com).Trim() | Set-Clipboard
```
Then, in the Codespace:
```bash
./allow-ip.sh browser <PC_IP>   # tcp 80 only; replaces the previous browser IP; saves BROWSER_IP to lab.env
./allow-ip.sh codespace         # run again when the Codespace restarts (new egress IP): tcp 22 and 80
```
Open `http://<FRONT_PUB>` (printed by the script, also in `ips.env`).
`./allow-ip.sh browser` refuses the Codespace IP. If `BROWSER_IP` is set in `lab.env`, `deploy.sh` applies it after deploying.

Warnings:
- HTTP is unencrypted. Do not reuse real passwords in this lab.
- A corporate VPN IP is shared by many people; everyone behind it can reach port 80. Prefer a non-shared network.

## What to verify
- After 02: `HTTP/1.1 200` and `X-Jenkins: 2.426.3`.
- After 03: three jobs listed (`hello-world`, `disk-check`, `heartbeat`). After a few minutes they have builds.
- After 04: newer `X-Jenkins`, three jobs, and `nextBuildNumber` continues from the old server.
- During cutover: `monitor.sh` shows 200 all the time, with no `000` or 502, and the version changes.
- `hello-world` log on the new server shows `Running on: new` and Java 17.

## Key points for migrating Jenkins to a newer version
| # | Point | Why it matters |
|---|---|---|
| 1 | Back up all of JENKINS_HOME | Jobs, settings, plugins, and build history are stored there. |
| 2 | Include `secrets/` (for example `master.key`) | Credentials are encrypted with these keys. |
| 3 | Check the Java version | Newer Jenkins needs newer Java. Check the upgrade guide. |
| 4 | Read the LTS upgrade guides for every skipped version | They list breaking changes. |
| 5 | Check plugin compatibility | Pin plugin versions in `plugins.txt`. |
| 6 | Check agents too | They need a compatible Java and remoting version. |
| 7 | Quiet down before the final copy | No data changes during the copy. |
| 8 | Prevent duplicate runs in a parallel run | Timer jobs could run on both servers. |
| 9 | Update the Jenkins URL and webhooks | They must point to the new server. |
| 10 | Verify, then cut over | Compare job count, run test builds, read plugin errors. |
| 11 | Keep the old server for rollback | Also take an EBS snapshot. |

## Say it in English
"I rebuilt the process on EC2, including a Java 11 to 17 upgrade, and verified zero downtime with a monitoring loop."

## Docs
- [Migrating scheduled jobs without duplicate or missed executions](docs/scheduled-job-migration.md)
