# Next 10 Tasks (Updated 2025-11-07)

| # | Task | Owner | Status | Notes |
|---|------|-------|--------|-------|
| 1 | MongoDB Atlas migration/cutover | Infra | ⚙️ In progress | NAT egress IPs (`35.247.164.211`, `34.142.147.42`) captured, `tools/mongodb-to-atlas.sh` ready, `mongodb-atlas-uri` secret created. Waiting on Atlas cluster + DB user credentials to run the dump/restore and flip `RUN_MONGODB=false`. |
| 2 | Ingress/DNS hardening (Cloudflare automation, TLS monitoring) | Infra | ✅ Done (2025-11-07) | `tools/cloudflare-sync.sh` idempotently applies the records in `ops/cloudflare/records.json`; HTTPS uptime + cert-expiry alert templates live under `ops/monitoring`. Run the gcloud commands in `docs/MONITORING.md`. |
| 3 | Budget & cost guardrails (RM250 alert, RM400 cap) | FinOps | ✅ Done (2025-11-08) | Terraform budget applied to billing account `01A879-A82798-7962E2` (RM400 cap, <=RM1k validation). Notifications go to `techadmin@biji-biji.com` + `team@mereka.io`; rerun `terraform apply` with `GOOGLE_CLOUD_QUOTA_PROJECT=mereka-lms` after edits. |
| 4 | Cloud SQL backup automation & retention | Infra | ✅ Done (2025-11-07) | Service account `cloud-sql-backup@mereka-lms.iam.gserviceaccount.com` created, GitHub secret `GCP_SA_KEY` loaded, lifecycle policy deletes backups older than 60 days, workflow scheduled every 3 days (~10 runs/month). |
| 5 | Monitoring & alerting rollout | SRE | ✅ Done (2025-11-07) | Dashboards + alert policies deployed (see `docs/MONITORING.md`); email notifications wired to techadmin@biji-biji.com & team@mereka.io. |
| 6 | SES SMTP deliverability | Infra | ⛔ Blocked | AWS SES keeps returning `535 Authentication Credentials Invalid`; awaiting AWS support/domain sandbox removal before retrying. |
| 7 | GitHub repo + CI scaffolding | DevOps | ✅ Done (2025-11-07) | Repo `Biji-Biji-Initiative/mereka-lms` created, all local work committed/pushed, backup workflow secret configured. Next: add Tutor build/test workflow + Terraform plan job. |
| 8 | Branding + MFEs alignment | Product | ✅ Done (2025-11-07) | LMS/Studio templates + hero/footer shipped, Indigo plugin now imports `mereka.scss` across MFEs, and assets sync via `tools/sync-brand-assets.sh`. Screenshots remain a nice-to-have. |
| 9 | Documentation & knowledge base | Infra | ⚙️ In progress | `docs/DEPLOYMENT_RUNBOOK.md`, `docs/MONGODB_ATLAS.md`, `docs/SECRETS_SNAPSHOT.md`, and `docs/NEXT10_TASKS.md` kept current so hand-offs stay clear. |
|10 | Data migrations (Kajabi/MCT ingestion into Open edX) | Data | 💤 Pending | Export tooling exists under `tools/mct-*` and `ops/migrations/`; waiting on staging stability before bulk loads. |

Use this list when triaging: higher numbers can reshuffle, but keep statuses accurate so everyone knows what “1/4/7/9” refer to.
