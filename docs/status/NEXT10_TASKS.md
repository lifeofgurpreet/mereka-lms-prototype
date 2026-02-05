# Next 10 Tasks (Updated 2026-02-05)
_Audience: Everyone • Owner: Program Mgmt • Last verified: 2026-02-05_

## Recent Fixes (2026-02-05)
- ✅ Authentik redirect URIs updated for academyv2 domains
- ✅ Admin login + Authn MFE verified with shared test credentials

## Next 10 Most Awesome Things (2026-02-05)

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | Fix ecommerce OAuth 500 | Infra | ⚙️ In progress | Bead: `mereka-lms-1am`. Need repro + logs. |
| 2 | Credentials service routing/SSO | Infra | ⚙️ In progress | Bead: `mereka-lms-30c`. Health OK; SSO validation pending. |
| 3 | Forum strategy | Infra | ⚙️ In progress | Bead: `mereka-lms-u2f`. Decide keep + DNS vs remove. |
| 4 | Synthetic checks + SLO dashboards | SRE | 💤 Pending | Bead: `mereka-lms-24s`. |
| 5 | Cert/SAN monitoring | SRE | 💤 Pending | Bead: `mereka-lms-147`. |
| 6 | Remove staging language | Docs | ⚙️ In progress | Bead: `mereka-lms-363` (legacy refs remain). |
| 7 | Formalize DR | SRE | ⚙️ In progress | Bead: `mereka-lms-usv` (Atlas backups not enabled). |
| 8 | Multi-site governance | Infra | 💤 Pending | Bead: `mereka-lms-s8r`. |
| 9 | Release checklist | Infra | 💤 Pending | Bead: `mereka-lms-2bq`. |
| 10 | Log-based alerting | SRE | 💤 Pending | Bead: `mereka-lms-ds7`. |

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
