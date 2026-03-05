# Operations Documentation

<!-- Last verified: 2026-02-13 -->

Runbooks, troubleshooting guides, and operational procedures for managing the Mereka Academy Open edX platform.

## Key Documents

- [`CAPABILITY_MATRIX.md`](CAPABILITY_MATRIX.md) - **Complete inventory** of all Open edX capabilities (deployed vs planned)
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - **🚨 SITE DOWN?** Start here for quick diagnostics
- [`ACCESS_URLS.md`](ACCESS_URLS.md) - Quick reference for all URLs and access
- [`ENTERPRISE_MULTI_TENANCY_NAVIGATION.md`](ENTERPRISE_MULTI_TENANCY_NAVIGATION.md) - One-page map for enterprise, tenant, licensing, branding, and enterprise runbooks
- [`DEPLOYMENT_RUNBOOK.md`](runbooks/DEPLOYMENT_RUNBOOK.md) - How we deploy Tutor environments

## Categories

### Access & URLs
- [`ACCESS_URLS.md`](ACCESS_URLS.md) - All URLs (LMS, Studio, Forum, Admin)
- [`ADMIN_LOGIN_GUIDE.md`](guides/ADMIN_LOGIN_GUIDE.md) - Admin access instructions
- [`LOCAL_ACCESS_INFO.md`](LOCAL_ACCESS_INFO.md) - Local development URLs

### Troubleshooting
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) - Common issues and fixes
- [`MFE_LOGIN_FIX.md`](../archive/MFE_LOGIN_FIX.md) - MFE authentication issues
- [`MFE_REBUILD_SUCCESS.md`](../archive/MFE_REBUILD_SUCCESS.md) - MFE rebuild guide

### Deployment & Infrastructure
- [`DEPLOYMENT_RUNBOOK.md`](runbooks/DEPLOYMENT_RUNBOOK.md) - Deployment procedures
- [`THEME_DEPLOYMENT.md`](THEME_DEPLOYMENT.md) - Branding/theme deployment flow
- [`../branding/BRANDING_OPERATING_MODEL.md`](../branding/BRANDING_OPERATING_MODEL.md) - Canonical branding execution contract
- [`GCP_ROADMAP.md`](GCP_ROADMAP.md) - Cloud architecture plan
- [`MONITORING.md`](MONITORING.md) - Monitoring and alerting
- [`OBSERVABILITY_QUICKSTART.md`](OBSERVABILITY_QUICKSTART.md) - Fast health/audit flow for operators
- [`OBSERVABILITY_OWNERSHIP.md`](OBSERVABILITY_OWNERSHIP.md) - Source-of-truth and sync model
- [`ALERT_SEVERITY_MATRIX.md`](ALERT_SEVERITY_MATRIX.md) - Severity/routing policy
- [`ONCALL_OBSERVABILITY_PLAYBOOK.md`](ONCALL_OBSERVABILITY_PLAYBOOK.md) - Incident triage sequence
- [`ALERT_TUNING_SOP.md`](ALERT_TUNING_SOP.md) - Weekly noise reduction process
- [`CLOUDFLARE_DNS.md`](CLOUDFLARE_DNS.md) - DNS management
- [`SECRETS_SNAPSHOT.md`](SECRETS_SNAPSHOT.md) - Secret handling policy (redacted, no values)
- [`SECRET_ROTATION_CHECKLIST.md`](SECRET_ROTATION_CHECKLIST.md) - Incident-ready secret rotation flow

### Local Development
- [`LOCAL_PRODUCTION_PARITY.md`](LOCAL_PRODUCTION_PARITY.md) - Parity guide
- [`LOCAL_WORK_REMAINING.md`](LOCAL_WORK_REMAINING.md) - Current tasks

### CI/CD & Cost Optimization
- [`CI_CD_SETUP.md`](CI_CD_SETUP.md) - GitHub Actions workflows overview, secrets, and self-hosted runner setup
- [`CI_CD_RUNNERS.md`](CI_CD_RUNNERS.md) - ARC self-hosted runner architecture, GitHub App setup, PVC caching, troubleshooting
- [`GITHUB_ACTIONS_COST_MONITORING.md`](GITHUB_ACTIONS_COST_MONITORING.md) - Usage monitoring, budget thresholds, alert setup
- [`CI_PIPELINE_COST_OPTIMIZATION.md`](CI_PIPELINE_COST_OPTIMIZATION.md) - Analysis and rationale for the optimization plan
- [`CI_OPTIMIZATION_TRACKER.md`](CI_OPTIMIZATION_TRACKER.md) - Phase-by-phase implementation tracker with file mappings
- [`WORKLOAD_IDENTITY_FEDERATION.md`](WORKLOAD_IDENTITY_FEDERATION.md) - WIF migration guide (replaces JSON SA key in CI)
