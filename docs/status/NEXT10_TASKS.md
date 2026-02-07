# Next 10 Tasks (Updated 2026-02-07)
_Audience: Everyone • Owner: Program Mgmt • Last verified: 2026-02-07_

## Recent Fixes (2026-02-07)
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
- ✅ Velero alert pipeline audit added: `./scripts/qa/audit-velero-alert-pipeline.sh` (runtime metrics/policies + cron freshness + hourly recency)
- ✅ Monitoring apply flow hardened (`apply-monitoring-configs.sh`): unsupported long-window alert templates are skipped with explicit messaging
- ✅ Multisite verification hardened: strict checks now enforce `SiteConfiguration.enabled`, LMS/CMS/MFE roots, `THEME_NAME`, `course_org_filter`, and duplicate-config detection
- ✅ Org governance hardening: deterministic org role ownership audit (`./scripts/qa/verify-org-role-ownership.sh`) wired into auth audits and enforcement
- ✅ Unified operator gate: `./scripts/qa/run-operations-gates.sh` (auth + multisite + observability + Velero + Grafana)
- ✅ Velero restore drill hardening updated for PV-aware validation (restore PVC/PV resources + read-only restored MySQL probe)
- ✅ Atlas modulestore CI guardrail added: `./scripts/qa/verify-atlas-modulestore-path.sh` + CI job `atlas-modulestore-guardrails`
- ✅ Alert routing one-command verifier added: `./scripts/qa/verify-alert-routing.sh` + runtime workflow `.github/workflows/alert-routing-audit.yml`
- ✅ DR evidence bundle pipeline added: `./scripts/qa/build-dr-evidence-bundle.sh` + monthly workflow `.github/workflows/dr-evidence-bundle.yml`
- ✅ Operations gate hardened for timeout-safe execution + per-check artifacts (`var/operations-gates/*`)
- ✅ Microsite branding parity enforcement expanded (Biji Studio + Biji MFE) and strict audit wired into public-health workflow
- ✅ Studio authoring branding contract added (`./scripts/qa/verify-studio-authoring-branding.sh`) and integrated into branding gates
- ✅ Design token provenance lock added (`assets/branding/tokens.provenance.json` + `verify-token-drift.sh`)
- ⚙️ New follow-up: deploy refreshed openedx image to clear live Studio token/Google-font drift (`mereka-lms-2bnq`)
- ✅ GitOps follow-through completed: `bbi-infrastructure` pinned ref + overlay patch now prune legacy `Service/mongodb` in production (`mereka-lms-3ax6`)

## Top 10 Next Tasks (High Impact, Non-Stripe)

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Retire or persist legacy in-cluster MongoDB (`mereka-lms/mongodb` uses `emptyDir`) | Infra | ✅ Delivered (prod) | Production `Deployment/mongodb` retired after Velero backup; overlay patch now deletes legacy `Service/mongodb` in prod to prevent drift. See `docs/ARCHITECTURE_MONGODB.md`. |
| 2 | Fix Velero restore drill job (`velero/restore-test` CronJob broken) | SRE | ✅ Delivered (monitoring) | PV-aware restore-test config + strict audit checks are live; evidence publication is now tracked under DR formalization. |
| 3 | Formalize DR: backups + restore drills (with evidence artifacts + runbook) | SRE | ⚙️ In progress | `build-dr-evidence-bundle.sh` + monthly GH workflow now publish artifacts; remaining: sustained monthly artifact review + restore-drill proof of execution cadence. Bead: `mereka-lms-usv`. |
| 4 | Course data recovery runbook hardening (env-aware Mongo reality) | Data/Infra | ⚙️ In progress | Production is Atlas-only; dev may still use in-cluster Mongo. Keep recovery flow explicit per environment in `docs/operations/COURSE_DATA_RECOVERY.md`. |
| 5 | Modulestore cutover closure + decommission plan (legacy in-cluster Mongo) | Infra | ✅ Delivered (prod) | Cutover and decommission are complete in production; continue watching atlas guard + ops gates for regression. Beads: `mereka-lms-m1q`, `mereka-lms-dnt`. |
| 6 | GitOps pin hygiene: automate/standardize “bump base ref SHA” + guardrails | Infra | ✅ Delivered | Helper + docs are in place (`scripts/infra/prepare-bbi-infra-ref-bump.sh`, AGENTS + troubleshooting notes for exact `git rev-parse HEAD` pinning). |
| 7 | Multi-site governance hardening (domain onboarding + config drift prevention) | Infra | ✅ Delivered | Strict multisite + org-role ownership + consolidated operations gate are CI/runtime-enforced (`atlas-modulestore-guardrails` + `.github/workflows/operations-gates-runtime.yml`). Beads: `mereka-lms-s8r`, `mereka-lms-2q6`. |
| 8 | Observability: synthetic checks for login + admin access across all hostnames | SRE | ⚙️ In progress | Runtime observability + Velero pipeline audits + alert-routing verifier are live; remaining: keep routing contacts fresh and incident-response drill cadence. |
| 9 | Visual regression gate for branding (LMS/Studio/Authn MFE) | Product/SRE | ✅ Delivered | Canonical gate now supports screenshot+diff flow (`RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=1`) and VPS scheduler tooling is in place (`scripts/infra/setup-vps-branding-visual-regression-cron.sh`). Bead: `mereka-lms-3mz`. |
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
| 7 | Visual regression gate for branding | Product | ✅ Delivered | `run-branding-gates.sh` now supports visual diff mode + bootstrap-safe baseline seeding; VPS cron wrapper available for continuous checks. Bead: `mereka-lms-3mz`. |
| 8 | Formalize DR: backups + restore drills | SRE | ⚙️ In progress | Bead: `mereka-lms-usv`. |
| 9 | Multi-site governance hardening | Infra | ⚙️ In progress | Strict governance drift checks now block on core config mismatches and org-ownership validation. |
| 10 | Studio create button no-op | Infra | 💤 Pending | Bead: `mereka-lms-3oc` (verify in fresh session). |

## Legacy / Archive

Older task tracking (pre-2026 hardening) is kept in:
- `docs/status/LEGACY_TASKS_2025.md`
