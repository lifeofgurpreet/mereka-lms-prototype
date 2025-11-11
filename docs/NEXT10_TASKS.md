# Next 10 Tasks (Updated 2025-11-11)
_Audience: Everyone • Owner: Program Mgmt • Last verified: 2025-11-11_

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | MongoDB cost optimization | Infra | 🔥 Urgent | **M10 costs \$87/month** - Downgrade to M0 (FREE) for staging. Script ready: `./tools/downgrade-mongodb-to-m0.sh`. Keep M10 only for production. |
| 2 | User management & access setup | Infra | ⚙️ In progress | Create admin users, document access URLs (see `docs/ACCESS_URLS.md`), verify forum integration works. |
| 3 | SES SMTP deliverability | Infra | ⛔ Blocked | AWS SES returns `535 Authentication Credentials Invalid`. Need AWS support/domain verification before enabling email. |
| 4 | Production GCP environment | Infra | 💤 Pending | Clone staging infrastructure into prod project: parameterize Terraform, add state backend + service accounts, document cutover. |
| 5 | Tutor CI/CD workflows | DevOps | 💤 Pending | Add GitHub Actions for Tutor lint/tests, image builds, Terraform plan jobs (manual approval before apply). |
| 6 | Disaster recovery rehearsal | SRE | 💤 Pending | Restore latest Cloud SQL dumps into scratch instance, document timings, verify course data integrity. |
| 7 | Data migrations (Kajabi/MCT) | Data | 💤 Pending | Finalize `tools/kajabi-*` + `tools/mct-*` flows, import sample cohorts, validate grading/credential issuance. |
| 8 | Observability & monitoring | SRE | 💤 Pending | Add synthetic checks for MFEs/account/login, define SLO dashboards, hook PagerDuty/Slack alerts. |
| 9 | Secrets automation & rotation | Infra | ⚙️ In progress | Move remaining secrets to Secret Manager, script rotation, schedule credential updates. |
|10 | Branding QA + accessibility | Product | 💤 Pending | Capture LMS/Studio/MFE screenshots, run WCAG checks, publish assets for marketing sign-off. |

Use this list when triaging; reorder as priorities shift, but keep statuses updated so everyone knows what “Task 1/4/7/9” refer to.
