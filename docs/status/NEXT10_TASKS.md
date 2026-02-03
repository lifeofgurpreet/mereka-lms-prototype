# Next 10 Tasks (Updated 2026-02-03)
_Audience: Everyone • Owner: Program Mgmt • Last verified: 2026-02-03_

## Recent Fixes (2026-02-03)
- ✅ SES SMTP relay fully configured - emails delivering via AWS SES
- ✅ Disaster recovery tested - Velero backups verified, restore successful
- ✅ CI/CD workflows added - GitHub Actions for Tutor image builds
- ✅ Terraform production setup - backend, environments, multi-env workflow documented

## Previous Fixes (2025-11-25)
- ✅ Staging restored: Fixed MySQL→Cloud SQL routing
- ✅ Staging restored: Fixed Redis host drift in configmap
- ✅ Staging restored: Fixed MFE service selector mismatch

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | MongoDB cost optimization | Infra | ✅ Complete | Already on M0 (FREE tier). Verified 2025-11-25. |
| 2 | User management & access setup | Infra | ✅ Complete | Admin users verified, access URLs documented. |
| 3 | SES SMTP deliverability | Infra | ✅ Complete | SMTP relay configured with SES credentials, test email delivered successfully. See `docs/TASK3_SES_SETUP_COMPLETE.md`. |
| 4 | Production GCP environment | Infra | ✅ Complete | Terraform backend, staging/production tfvars, multi-env workflow documented. See `infrastructure/terraform/README.md`. Ready to apply when prod project is created. |
| 5 | Tutor CI/CD workflows | DevOps | ✅ Complete | GitHub Actions for lint, validation, image builds, deployment. See `docs/operations/CI_CD_SETUP.md`. |
| 6 | Disaster recovery rehearsal | SRE | ✅ Complete | Velero backup restored to test namespace, MySQL data verified. See `docs/operations/DR_TEST_RESULTS.md`. |
| 7 | Data migrations (Kajabi/MCT) | Data | 💤 Pending | Finalize `tools/kajabi-*` + `tools/mct-*` flows, import sample cohorts, validate grading/credential issuance. |
| 8 | Observability & monitoring | SRE | 💤 Pending | Add synthetic checks for MFEs/account/login, define SLO dashboards, hook PagerDuty/Slack alerts. |
| 9 | Secrets automation & rotation | Infra | ⚙️ In progress | Move remaining secrets to Secret Manager, script rotation, schedule credential updates. |
|10 | Branding QA + accessibility | Product | 💤 Pending | Capture LMS/Studio/MFE screenshots, run WCAG checks, publish assets for marketing sign-off. |

Use this list when triaging; reorder as priorities shift, but keep statuses updated so everyone knows what “Task 1/4/7/9” refer to.
