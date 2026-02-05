# Next 10 Tasks (Updated 2026-02-05)
_Audience: Everyone • Owner: Program Mgmt • Last verified: 2026-02-05_

## Recent Fixes (2026-02-05)
- ✅ Public health checks pass (prod + dev) for LMS/Studio/MFE/Discovery/Ecommerce/Credentials/Forum
- ✅ TLS SAN monitoring wired and verified for all academyv2 microsites
- ✅ Authentik admin credentials synced; Authn MFE login verified
- ✅ Account/Profile MFE redirects re-applied; CourseCreator granted for admin

## Next 10 Most Awesome Things (2026-02-05)

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
| 9 | Multi-site governance + cookie strategy | Infra | 💤 Pending | Beads: `mereka-lms-s8r`, `mereka-lms-4pj`. |
| 10 | MFE uptime checks + domain-change runbook | SRE | 💤 Pending | Beads: `mereka-lms-1jo`, `mereka-lms-pqt`. |

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
