# Next 10 Tasks (Updated 2025-11-21)
_Audience: Everyone • Owner: Program Mgmt • Last verified: 2025-11-21_

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | MongoDB cost optimization | Infra | ✅ Complete | ✅ Using in-cluster MongoDB pod (FREE). No Atlas charges. Verified via `kubectl get pods -n mereka-lms`. Atlas M10 only needed for production. |
| 2 | User management & access setup | Infra | ✅ Complete | ✅ Admin users verified (5 total), access URLs documented, forum integration verified (running, MongoDB Atlas connected). See `docs/TASK2_COMPLETION_REPORT.md`. |
| 3 | SES SMTP deliverability | Infra | ✅ Complete | ✅ SMTP credentials configured, test email sent and received successfully. Using SMTP backend. See `docs/TASK3_SES_SETUP_COMPLETE.md`. |
| 4 | Production GCP environment | Infra | ⚙️ In progress | Plan complete (see `docs/operations/PRODUCTION_INFRASTRUCTURE_PLAN.md`). Est. $1,650-2,200/month. Multi-env Terraform structure ready. Next: Provision prod GCP project. |
| 5 | Tutor CI/CD workflows | DevOps | 💤 Pending | Add GitHub Actions for Tutor lint/tests, image builds, Terraform plan jobs (manual approval before apply). |
| 6 | Disaster recovery rehearsal | SRE | 💤 Pending | Restore latest Cloud SQL dumps into scratch instance, document timings, verify course data integrity. |
| 7 | Data migrations (Kajabi/MCT) | Data | 💤 Pending | Finalize `scripts/migrations/kajabi/kajabi-*` + `scripts/migrations/mct/mct-*` flows, import sample cohorts, validate grading/credential issuance. |
| 8 | Observability & monitoring | SRE | 💤 Pending | Add synthetic checks for MFEs/account/login, define SLO dashboards, hook PagerDuty/Slack alerts. |
| 9 | Secrets automation & rotation | Infra | ⚙️ In progress | Move remaining secrets to Secret Manager, script rotation, schedule credential updates. |
|10 | Branding QA + accessibility | Product | 💤 Pending | Capture LMS/Studio/MFE screenshots, run WCAG checks, publish assets for marketing sign-off. |

Use this list when triaging; reorder as priorities shift, but keep statuses updated so everyone knows what “Task 1/4/7/9” refer to.
