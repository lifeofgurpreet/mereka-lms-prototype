# Operations & Infrastructure
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2025-11-09_

Reference this folder for anything that touches deployments, secrets, cloud infra, or shared platform toggles.

| Doc | Purpose | Last Verified |
| --- | --- | --- |
| [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) | **🚨 START HERE:** Quick diagnostic checklist and fixes for common service issues (empty endpoints, selector mismatches, timeouts). | 2025-11-11 |
| [`DEPLOYMENT_RUNBOOK.md`](DEPLOYMENT_RUNBOOK.md) | Promotion + rollout guide across local, staging, and prod Tutor stacks. | 2025-10-30 |
| [`GCP_ROADMAP.md`](GCP_ROADMAP.md) | Architecture roadmap plus open tasks for the GCP deployment. | 2025-10-15 |
| [`MONITORING.md`](MONITORING.md) | Stack monitoring plan, alerting targets, and log aggregation. | 2025-09-28 |
| [`CLOUDFLARE_DNS.md`](CLOUDFLARE_DNS.md) | DNS inventory and automation via Cloudflare's API. | 2025-09-05 |
| [`MULTISITE.md`](MULTISITE.md) | Microsite strategy, theme overrides, and shared branding tokens. | 2025-09-10 |
| [`SECRETS_SNAPSHOT.md`](SECRETS_SNAPSHOT.md) | Temporary credential inventory and rotation notes. | 2025-08-22 |

**Related tooling:**
- `ops/tutor/` for Tutor helper scripts and config overrides.
- `tools/cloudflare-*.sh` for the DNS automation referenced above.
