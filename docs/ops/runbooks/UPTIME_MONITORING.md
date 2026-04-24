# Uptime Monitoring Runbook

> External uptime monitoring for prod LMS domains via [Upptime](https://upptime.js.org).
> Status page: **https://status.mereka.dev**
> Bead: `mereka-lms-mx78`

## Canonical probe inventory

The authoritative list of probed URLs lives in this repo at:

```
docs/ops/monitoring/upptime-probe-inventory.yaml
```

The deployed configuration lives in the Upptime repo:

```
VPS: ~/infrastructure/upptime/.upptimerc.yml  (copy of config sent to acfs-status repo)
GitHub repo: https://github.com/Biji-Biji-Initiative/acfs-status  (or owner: gurpreet / repo: acfs-status)
```

### What is probed

| Name | URL | Expected codes |
|------|-----|----------------|
| LMS — Mereka | https://academyv2.mereka.io/ | 200, 302 |
| Studio — Mereka | https://studio.academyv2.mereka.io/ | 200, 302 |
| Authn MFE — Mereka | https://apps.academyv2.mereka.io/authn/login | 200, 302 |
| Learner Dashboard MFE — Mereka | https://apps.academyv2.mereka.io/learner-dashboard/ | 200, 302 |
| LMS — SkillOurFuture | https://skillourfuture.academy.mereka.io/ | 200, 302 |
| Authn MFE — SkillOurFuture | https://apps.skillourfuture.academy.mereka.io/authn/login | 200, 302 |
| LMS — Biji-Biji | https://academy.biji-biji.com/ | 200, 302 |
| Authn MFE — Biji-Biji | https://apps.academy.biji-biji.com/authn/login | 200, 302 |
| Discovery API — health | https://discovery.academyv2.mereka.io/health/ | 200 |

**Not probed here** (out of scope for Upptime external probes):
- Credentialled/authenticated endpoints — use the `e09t` CronJob for those
- Internal endpoints (Meilisearch, MySQL, Redis, Celery) — covered by Prometheus/Alertmanager
- Dev/staging domains (`*.mereka.dev`, `*.stg.*`) — separate ACFS DEV probe set in `.upptimerc.yml`

## What "green" vs "red" means

| Status | Meaning | Action |
|--------|---------|--------|
| Green | URL returned an expected status code within timeout | None |
| Yellow (degraded) | Response time above threshold but URL is up | Investigate performance |
| Red | URL returned an unexpected code or timed out for 2+ consecutive checks | Page on-call immediately |

Upptime opens a GitHub Issue automatically when a site goes red. GitHub Issue = active incident.

## Adding a new probe

1. Edit `docs/ops/monitoring/upptime-probe-inventory.yaml` in this repo — add the new `sites` entry.
2. Copy the updated `sites` block into `~/infrastructure/upptime/.upptimerc.yml` on the VPS.
3. Commit and push the updated `.upptimerc.yml` to the `acfs-status` GitHub repo.
4. GitHub Actions will pick up the change on the next scheduled run (within 5 minutes).

PR shape for the `acfs-status` repo:
- Title: `feat(probes): add <name>`
- Body: paste the new YAML entry, link back to this repo's `upptime-probe-inventory.yaml` diff

## Silencing a probe during scheduled maintenance

1. Open a GitHub Issue in the `acfs-status` repo with label `maintenance`.
2. Include start/end times in ISO-8601 in the issue body:
   ```
   start: 2026-01-15T10:00:00Z
   end: 2026-01-15T12:00:00Z
   ```
3. Upptime will suppress alerts during the window.
4. Close the Issue when maintenance is complete.

## When a probe goes red

1. **Confirm it is real**: check from a second network (mobile hotspot). Upptime runs from GitHub Actions IPs — some corporate firewalls or Cloudflare rules can cause false positives.
2. **Identify the component** (per `platform-debugging.md` rules):
   ```bash
   curl -svI https://<domain> 2>&1 | grep -iE 'server:|via:|x-powered-by|< HTTP'
   ```
   - `Via: Caddy` + nginx body → upstream nginx returned the error
   - `Server: Caddy` alone → Caddy could not reach upstream (502/504)
   - Timeout → likely DNS, TLS cert expiry, or ingress controller down
3. **Check ingress controller**:
   ```bash
   kubectl get pods -n ingress-nginx -o wide
   kubectl get endpoints -n mereka-lms-dev
   ```
4. **Check cert expiry**:
   ```bash
   echo | openssl s_client -connect <domain>:443 -servername <domain> 2>/dev/null | openssl x509 -noout -dates
   ```
5. Escalate to platform on-call if not resolved within 15 minutes of first alert.

## Escalation path

1. GitHub Issue opened automatically in `acfs-status` repo → triggers GitHub notification to assignees.
2. If Slack webhook is configured: `#status-alerts` channel receives alert within seconds.
3. If unacknowledged after 15 minutes: page platform on-call directly.

To wire Slack:
1. Create webhook at https://api.slack.com/apps
2. Add secret `SLACK_WEBHOOK_URL` to `acfs-status` repo secrets
3. Uncomment the `notifications` block in `.upptimerc.yml`

## Discovery health endpoint caveat

`https://discovery.academyv2.mereka.io/health/` is included conditionally. If the Discovery IDA
is behind auth or returns 401 unauthenticated, update `expectedStatusCodes` to `[200, 401]`
or remove the entry and track internally via Prometheus `up` metric instead.
