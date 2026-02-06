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

## Next 10 High-Impact Hardening Tasks (Auth + Ecosystem)

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Authentik config as code (blueprints or equivalent) | Infra | ✅ Complete | Implemented as idempotent ensure scripts + `scripts/infra/ensure-authentik-hardening.sh`. Bead: `mereka-lms-1fs`. |
| 2 | Enforce MFA for Authentik admins (Gurpreet only) | Security | ✅ Complete | Enforced via gated stage + policy. Script: `scripts/infra/ensure-authentik-admin-mfa.sh`. Bead: `mereka-lms-104`. |
| 3 | In-cluster scheduled verification + alerts (verify-only CronJob + observability) | SRE | ✅ Complete | CronJobs deployed in prod (`auth-verify-prod`, `cert-verify-prod`) + failure alerts via log metrics. Docs: `docs/operations/IN_CLUSTER_AUTH_VERIFICATION.md`. Bead: `mereka-lms-2gu`. |
| 4 | Auth dashboards + alerts (redirect_uri mismatch, OIDC 500s, CSRF spikes, 403s) | SRE | ✅ Complete | Added log metrics + alert policies + `infrastructure/monitoring/dashboards/auth.json`. Bead: `mereka-lms-2fm9`. |
| 5 | CI: authenticated browser E2E smoke test (Authentik login + admin access) | Infra | 💤 Deferred | Bead: `mereka-lms-24r` (skipped for now). |
| 6 | Formalize DR: backups + restore drills | SRE | ⚙️ In progress | Bead: `mereka-lms-usv`. |
| 7 | Multi-site governance hardening | Infra | 💤 Pending | Bead: `mereka-lms-s8r`. |
| 8 | Ecommerce checkout readiness validation | Infra | 💤 Pending | Bead: `mereka-lms-xw6`. |
| 9 | Visual regression gate for branding | Product | 💤 Pending | Bead: `mereka-lms-3mz`. |
| 10 | Fix Argo sync blocked by promtail DaemonSet selector immutability | SRE | ✅ Complete | Argo app `mereka-lms-local` is back to Synced; GitOps applies cleanly. Bead: `mereka-lms-2df4`. |

## Product / Content Backlog (Still Valid, Not in the “Auth Hardening” Top 10)

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Restore MCT/Kajabi courses into Atlas | Data | 💤 Pending | Bead: `mereka-lms-hd3` (awaiting export artifacts). |
| 2 | Ecommerce checkout readiness validation | Infra | 💤 Pending | Bead: `mereka-lms-xw6`. |
| 3 | MFE theming hardening (authn/account/learning) | Product | 💤 Pending | Bead: `mereka-lms-29o`. |
| 4 | Learner dashboard + courseware styling | Product | 💤 Pending | Bead: `mereka-lms-2t0`. |
| 5 | Studio authoring UI polish | Product | 💤 Pending | Bead: `mereka-lms-3ou`. |
| 6 | Credentials + forum theming | Product | 💤 Pending | Beads: `mereka-lms-3ur`, `mereka-lms-3qh`. |
| 7 | Visual regression gate for branding | Product | 💤 Pending | Bead: `mereka-lms-3mz`. |
| 8 | Formalize DR: backups + restore drills | SRE | ⚙️ In progress | Bead: `mereka-lms-usv`. |
| 9 | Multi-site governance hardening | Infra | 💤 Pending | Bead: `mereka-lms-s8r`. |
| 10 | Studio create button no-op | Infra | 💤 Pending | Bead: `mereka-lms-3oc` (verify in fresh session). |

## Previous Fixes (2025-11-25)
- ✅ Production restored: Fixed MySQL→Cloud SQL routing
- ✅ Production restored: Fixed Redis host drift in configmap
- ✅ Production restored: Fixed MFE service selector mismatch

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | MongoDB cost optimization | Infra | ✅ Complete | Already on M0 (FREE tier). Verified 2025-11-25. |
| 2 | User management & access setup | Infra | ✅ Complete | Admin users verified, access URLs documented. |
| 3 | SES SMTP deliverability | Infra | ✅ Complete | SMTP relay configured with SES credentials, test email delivered successfully. See `docs/TASK3_SES_SETUP_COMPLETE.md`. |
| 4 | Production GCP environment | Infra | ✅ Complete | Terraform backend, dev/production tfvars, multi-env workflow documented (legacy tfvars file retained). See `infrastructure/terraform/README.md`. Ready to apply when prod project is created. |
| 5 | Tutor CI/CD workflows | DevOps | ✅ Complete | GitHub Actions for lint, validation, image builds, deployment. See `docs/operations/CI_CD_SETUP.md`. |
| 6 | Disaster recovery rehearsal | SRE | ✅ Complete | Velero backup restored to test namespace, MySQL data verified. See `docs/operations/DR_TEST_RESULTS.md`. |
| 7 | Data migrations (Kajabi/MCT) | Data | 💤 Pending | Finalize `scripts/migrations/kajabi/kajabi-*` + `scripts/migrations/mct/mct-*` flows, import sample cohorts, validate grading/credential issuance. |
| 8 | Observability & monitoring | SRE | 💤 Pending | Add synthetic checks for MFEs/account/login, define SLO dashboards, hook PagerDuty/Slack alerts. |
| 9 | Secrets automation & rotation | Infra | ⚙️ In progress | Move remaining secrets to Secret Manager, script rotation, schedule credential updates. |
|10 | Branding QA + accessibility | Product | 💤 Pending | Capture LMS/Studio/MFE screenshots, run WCAG checks, publish assets for marketing sign-off. |

Use this list when triaging; reorder as priorities shift, but keep statuses updated so everyone knows what “Task 1/4/7/9” refer to.
