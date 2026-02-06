# Next 10 Tasks (Updated 2026-02-06)
_Audience: Everyone • Owner: Program Mgmt • Last verified: 2026-02-06_

## Recent Fixes (2026-02-06)
- ✅ Platform admins enforced and verified (prod + dev): `gurpreet@biji-biji.com`, `malasari@mereka.my`
- ✅ Authentik redirect URI allowlist fixed for microsites + preview + dev (prevents redirect_uri mismatch)
- ✅ Public auth surface checks hardened (follows redirect into Authentik /authorize)
- ✅ Canonical Open edX hostname registry added + drift checks (prod + dev)
- ✅ SSO entrypoints verified across LMS/Studio/MFE + discovery/credentials/ecommerce (including `/admin/login/` redirect to SSO)
- ✅ Access control matrix documented + consolidated audit report added (`./scripts/qa/audit-auth-access.sh`)
- ✅ Admin login guide hardened (prod-safe verification vs local-only remediation)
- ✅ Deterministic microsite/hostname onboarding checklist added (`./scripts/qa/microsite-onboarding-checklist.sh`)
- ✅ Notes/forum expectations documented and verified (API-first surfaces)
- ✅ RFC draft added for optional claim-based role sync (Auth -> perms)
- ✅ ArgoCD GitOps sync unblocked (promtail DaemonSet selector immutability fixed)
- ✅ MySQL hardening: provisioned Notes/XQueue DBs + normalized MySQL secrets (removed trailing CR/LF)
- ✅ Observability hardening baseline: new operations-signals dashboard + log metrics/alerts for storage, MySQL/Redis connectivity, and Velero verification/restore-drill failures
- ✅ Deterministic observability audit script added: `./scripts/qa/audit-observability.sh` (local + runtime modes)

## Top 10 Next Tasks (High Impact, Non-Stripe)

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Fix modulestore persistence (prod): `mereka-lms/mongodb` uses `emptyDir` | Infra | 💤 Pending | Highest risk before any course imports. Move modulestore to Atlas or add PVC-backed MongoDB. See `docs/ARCHITECTURE_MONGODB.md`. |
| 2 | Fix Velero restore drill job (`velero/restore-test` CronJob broken) | SRE | 💤 Pending | Restore drills must be green. See `docs/operations/VELERO_BACKUP_AUDIT.md`. |
| 3 | Formalize DR: backups + restore drills (with evidence artifacts + runbook) | SRE | ⚙️ In progress | Make this boring: scripted restore into a throwaway namespace, verify key queries, attach outputs. Bead: `mereka-lms-usv`. |
| 4 | Course data recovery runbook hardening (hybrid Mongo reality) | Data/Infra | 💤 Pending | Keep docs accurate and deterministic. Start from `docs/operations/COURSE_DATA_RECOVERY.md`. |
| 5 | Modulestore cutover decision + migration plan (in-cluster Mongo -> Atlas) | Infra | 💤 Pending | Must include safety gates. Do not delete in-cluster Mongo until verified. Beads: `mereka-lms-m1q`, `mereka-lms-dnt`. |
| 6 | GitOps pin hygiene: automate/standardize “bump base ref SHA” + guardrails | Infra | 💤 Pending | Reduce Argo `ComparisonError` risk; add a helper script + docs. |
| 7 | Multi-site governance hardening (domain onboarding + config drift prevention) | Infra | 💤 Pending | Bead: `mereka-lms-s8r`. |
| 8 | Observability: synthetic checks for login + admin access across all hostnames | SRE | ⚙️ In progress | Auth/TLS CronJob metrics+alerts are live, plus saturation/freshness signals. Remaining hardening is exporter-level depth and restore-drill reliability. |
| 9 | Visual regression gate for branding (LMS/Studio/Authn MFE) | Product/SRE | 💤 Pending | Generate screenshots, diff, and fail PRs on big regressions. Bead: `mereka-lms-3mz`. |
| 10 | CI: authenticated browser E2E smoke test (Authentik login + admin access) | Infra | 💤 Deferred | Bead: `mereka-lms-24r` (explicitly skipped for now). |

## Observability Top 10 (Epic: `mereka-lms-16g`)

| # | Task | Bead | Priority | Status |
|---|------|------|----------|--------|
| 1 | Ship observability audit in CI (nightly + manual) | `mereka-lms-2nmy` | P1 | ✅ Closed |
| 2 | Add Grafana dashboard-as-code sync checklist and ownership | `mereka-lms-mp6b` | P1 | ✅ Closed |
| 3 | Implement PVC utilization signal path (metrics + alert) | `mereka-lms-1d7x` | P1 | ✅ Closed |
| 4 | Deploy MySQL saturation telemetry (connections/latency) | `mereka-lms-3rx3` | P1 | ✅ Closed |
| 5 | Deploy Redis saturation telemetry (memory/evictions/latency) | `mereka-lms-1zfq` | P1 | ✅ Closed |
| 6 | Add Velero backup freshness + restore-drill status dashboard panels | `mereka-lms-w2xf` | P1 | ✅ Closed |
| 7 | Define alert severity matrix and routing policy | `mereka-lms-3dxx` | P2 | ✅ Closed |
| 8 | Build on-call single-pane operations dashboard playbook | `mereka-lms-36ln` | P2 | ✅ Closed |
| 9 | Create noisy alert tuning SOP + weekly review cadence | `mereka-lms-15fv` | P2 | ✅ Closed |
| 10 | Add PR guardrail for monitoring-as-code lint + dry-run plan | `mereka-lms-2vej` | P2 | ✅ Closed |

## Product / Content Backlog (Still Valid, Not in the “Auth Hardening” Top 10)

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Restore MCT/Kajabi courses into Atlas | Data | 💤 Pending | Bead: `mereka-lms-hd3` (awaiting export artifacts). |
| 2 | Ecommerce checkout readiness validation | Infra | ✅ Verified | Stripe keys + webhook secret are injected and webhook delivery is accepted (HTTP 200). Bead: `mereka-lms-xw6` (closed). Remaining: run a real test checkout and confirm order state transitions. |
| 3 | MFE theming hardening (authn/account/learning) | Product | 💤 Pending | Bead: `mereka-lms-29o`. |
| 4 | Learner dashboard + courseware styling | Product | 💤 Pending | Bead: `mereka-lms-2t0`. |
| 5 | Studio authoring UI polish | Product | 💤 Pending | Bead: `mereka-lms-3ou`. |
| 6 | Credentials + forum theming | Product | 💤 Pending | Beads: `mereka-lms-3ur`, `mereka-lms-3qh`. |
| 7 | Visual regression gate for branding | Product | 💤 Pending | Bead: `mereka-lms-3mz`. |
| 8 | Formalize DR: backups + restore drills | SRE | ⚙️ In progress | Bead: `mereka-lms-usv`. |
| 9 | Multi-site governance hardening | Infra | 💤 Pending | Bead: `mereka-lms-s8r`. |
| 10 | Studio create button no-op | Infra | 💤 Pending | Bead: `mereka-lms-3oc` (verify in fresh session). |

## Legacy / Archive

Older task tracking (pre-2026 hardening) is kept in:
- `docs/status/LEGACY_TASKS_2025.md`
