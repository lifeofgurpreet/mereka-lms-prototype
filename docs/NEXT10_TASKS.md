# Next 10 Tasks (Updated 2025-11-08)

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | MongoDB Atlas migration/cutover | Infra | ⚙️ In progress | NAT egress IPs captured, `tools/mongodb-to-atlas.sh` ready, `mongodb-atlas-uri` secret stubbed. Waiting on Atlas cluster + DB creds to dump/restore, set `RUN_MONGODB=false`, and delete the StatefulSet PVCs. |
| 2 | SES SMTP deliverability | Infra | ⛔ Blocked | AWS SES returns `535 Authentication Credentials Invalid` even for raw AUTH LOGIN. Need AWS support/domain verification before enabling Tutor email tasks + password resets. |
| 3 | Production GCP environment (Terraform plan/apply) | Infra | 💤 Pending | Clone staging infrastructure into a prod project: parameterize Terraform, add state backend + service accounts, and document cutover approvals. |
| 4 | Tutor CI/CD workflows | DevOps | 💤 Pending | Add GitHub Actions for Tutor lint/tests, image builds, and Terraform plan jobs (manual approval before apply). Reuse `GCP_SA_KEY` or add scoped robots. |
| 5 | Disaster recovery rehearsal | SRE | 💤 Pending | Restore latest Cloud SQL dumps into a scratch instance, document timings, and verify course data integrity. Include object-store restore + DNS failover steps. |
| 6 | Data migrations (Kajabi/MCT ingestion) | Data | 💤 Pending | Finalize `tools/kajabi-*` + `tools/mct-*` flows, import sample cohorts, and validate grading/credential issuance end-to-end. |
| 7 | Observability & SLO instrumentation | SRE | 💤 Pending | Add synthetic checks for MFEs/account/login, define SLO dashboards (availability + latency), and hook PagerDuty/Slack targets. |
| 8 | Secrets automation & rotation | Infra | ⚙️ In progress | Move remaining plaintext secrets into Secret Manager, script `tutor config save --set KEY=$(gcloud secrets versions access ...)`, and rotate `cloud-sql-backup` + future Atlas credentials on a schedule. |
| 9 | Branding QA + accessibility screenshots | Product | 💤 Pending | Capture LMS/Studio/MFE screenshots, run WCAG quick checks, and publish assets for marketing sign-off. |
|10 | Cloudflare advanced security roadmap | Infra | 💤 Pending | Evaluate WAF/Firewall Rulesets upgrade, page rules for caching MFEs, and long-term plan for Argo Smart Routing once budget allows. |

Use this list when triaging; reorder as priorities shift, but keep statuses updated so everyone knows what “Task 1/4/7/9” refer to.
