# Production Readiness Audit — Mereka LMS

_Date: 2026-04-04 · Auditor: Automated Agent · Scope: mereka-lms repo_

## Executive Summary

| # | Dimension | Status | Summary |
|---|-----------|--------|---------|
| 1 | Backups + Restore Proof | 🟡 YELLOW | Velero schedules active; one successful restore drill on record (Feb 2026). Monthly evidence cadence not proven. |
| 2 | Synthetic Monitoring | 🟡 YELLOW | Uptime check definitions exist but target GCP (decommissioned). No confirmed synthetic probes against RKE2 production. |
| 3 | Alerting | 🟡 YELLOW | 15+ PrometheusRules and SLO burn-rate alerts defined. Alertmanager routing config lives in bbi-infrastructure; delivery chain not auditable from this repo. |
| 4 | Rollback Path | 🟢 GREEN | 739-line emergency rollback runbook with decision tree, GitOps + DB rollback procedures, and dry-run verification scripts. |
| 5 | Certs / Secrets / SSO | 🟢 GREEN | 81 secrets via ExternalSecrets + Infisical pipeline. Classification registry, rotation checklist, pre-commit scanning, cert-manager verification all present. |
| 6 | Tenancy Isolation | 🟡 YELLOW | Nightly isolation CronJob + verification scripts exist. Pushgateway not deployed so isolation failure alerts are inert. |
| 7 | Observability | 🟡 YELLOW | Promtail logging + 10 ServiceMonitors + SLO recording rules in place. Tracing is pilot-only; Django app-level metrics missing. |
| 8 | Disaster Recovery | 🟡 YELLOW | Formal DR spec (RPO ≤24h / RTO ≤4h), monthly drill schedule, evidence bundle CI workflow. Only one recorded drill result (Feb 2026). |
| 9 | Production Change Control | 🟢 GREEN | Semver release process, CI with 4 jobs, canonical preflight, merge-group support, post-deploy gates all documented and automated. |

**Overall posture: 3 GREEN, 6 YELLOW, 0 RED.**
The platform has strong documentation and infrastructure; the primary gaps are in _ongoing proof of execution_ and _alert delivery verification_.

---

## Detailed Assessment

### 1. Backups + Restore Proof — 🟡 YELLOW

**Evidence found:**

| Asset | Path | Status |
|-------|------|--------|
| Cloud SQL export script | `scripts/infra/backup-db.sh` | Present (legacy GCS workflow; prod uses in-cluster MySQL now) |
| Velero backup audit script | `scripts/qa/audit-velero.sh` | Present |
| Critical PVC list script | `scripts/qa/list-critical-backup-pvcs.sh` | Present |
| DR evidence bundle script | `scripts/qa/build-dr-evidence-bundle.sh` | Present |
| DR evidence CI workflow | `.github/workflows/dr-evidence-bundle.yml` | Present (monthly schedule + manual dispatch) |
| Backup coverage matrix | `docs/reference/operations/BACKUP_COVERAGE_MATRIX.md` | Comprehensive — MySQL, Redis, ES, Authentik, Infisical, n8n PVCs all listed |
| Velero backup audit runbook | `docs/ops/runbooks/VELERO_BACKUP_AUDIT.md` | Present with "what good looks like" criteria |
| DR test result | `docs/status/readiness/DR_TEST_RESULTS.md` | ✅ One successful drill (2026-02-03) — restore in 7 seconds, data verified |
| Restore drill verification | `scripts/qa/verify-restore-drill.sh` | Present (PV checksum + MySQL integrity checks) |
| Velero evidence collector | `scripts/qa/collect-velero-evidence.sh` | Present |

**Velero schedule coverage (documented):**
- `velero-local-hourly-critical-databases` → hourly
- `velero-local-daily-all-apps` → daily 6 PM UTC
- `velero-local-weekly-full` → weekly Sunday 7 PM UTC

**Gaps:**
- `evidence/` directory contains no restore drill proof artifacts (grep returned zero matches for "restore drill/test/proof")
- Only **one** DR test result on file (2026-02-03, ~2 months old); monthly cadence not demonstrated
- `scripts/infra/backup-db.sh` targets Cloud SQL (`gcloud sql export`), but production MySQL is now in-cluster — this script is effectively stale for current prod
- MongoDB Atlas backup verification is documented as "TBD" in DR runbook — no automated Atlas snapshot verification script

**Risk:** If the monthly drill CI job silently fails (e.g., Velero restore CronJob broken — noted as a past failure mode in VELERO_BACKUP_AUDIT.md), the team may not discover backup gaps until a real incident. Atlas data (modulestore + forum) has no restore proof.

---

### 2. Synthetic Monitoring — 🟡 YELLOW

**Evidence found:**

| Asset | Path | Status |
|-------|------|--------|
| Uptime check definitions | `infrastructure/monitoring/uptime/prod-*.json` | 12 checks defined (LMS, Studio, MFE, forum, credentials, discovery, ecommerce, biji, skillourfuture) |
| Public health check script | `scripts/qa/public-health-check.sh` | Present — curl-based HTTP/cert checks |
| Synthetic alert drill | `scripts/qa/synthetic-alert-drill.sh` | Present |
| SLO synthetic drills | `scripts/qa/verify-slo-synthetic-drills.sh` | Present |
| Post-deploy smoke | `scripts/qa/post-deploy-verify.sh` | Present |

**Uptime check details (sample — `prod-lms-https.json`):**
- Target: `academyv2.mereka.io:443`, SSL validated, 300s period, APAC region
- Similar checks for Studio, MFE, forum, credentials endpoints

**Gaps:**
- Uptime checks are GCP Cloud Monitoring JSON definitions — production is now on **RKE2 (Contabo VPS)**, and GKE is **decommissioned**. These checks may still work (they probe the public URL, not GKE infra), but there is no confirmation they are actually deployed/active in any monitoring system post-migration.
- No external uptime service (e.g., Upptime, BetterStack, Pingdom) is confirmed as running — the ON_CALL.md references `https://status.mereka.dev` (Upptime) but there's no deployment manifest or config for it in this repo.
- No synthetic transaction monitoring (e.g., login → enroll → view course flow).

**Risk:** If the GCP uptime checks were never re-provisioned after the RKE2 migration, there may be **zero external synthetic monitoring** in production. The public health-check script requires manual invocation.

---

### 3. Alerting — 🟡 YELLOW

**Evidence found:**

| Asset | Path | Status |
|-------|------|--------|
| PrometheusRule — LMS | `deploy/k8s/base/monitoring/prometheusrule-lms.yaml` | 309 lines — pod down, restarts, memory, CPU, disk alerts |
| PrometheusRule — SLO | `deploy/k8s/base/monitoring/prometheusrule-slo.yaml` | SLI recording rules for LMS/CMS (Tier 1, 99.95%) |
| PrometheusRule — SLO burn-rate | `deploy/k8s/base/monitoring/slo-burn-rate-rules.yaml` | 1208 lines — MFE/PurchaseGateway/Forum burn-rate alerts (P1/P2/P3) |
| PrometheusRule — Caddy | `deploy/k8s/base/monitoring/prometheusrule-caddy.yaml` | Present |
| PrometheusRule — Enterprise | `deploy/k8s/base/monitoring/prometheusrule-enterprise.yaml` | Present |
| PrometheusRule — Velero | `deploy/k8s/base/monitoring/prometheusrule-velero.yaml` | Present |
| PrometheusRule — Auth | `deploy/k8s/base/monitoring/prometheusrule-auth.yaml` | Present |
| PrometheusRule — ExternalSecrets | `deploy/k8s/base/monitoring/prometheusrule-externalsecrets.yaml` | Present |
| PrometheusRule — Services | `deploy/k8s/base/monitoring/prometheusrule-services.yaml` | Present |
| PrometheusRule — Video | `deploy/k8s/base/monitoring/prometheusrule-video.yaml` | Present |
| PrometheusRule — Credentials | `deploy/k8s/base/monitoring/prometheusrule-credentials.yaml` | Present |
| PrometheusRule — Libraries | `deploy/k8s/base/monitoring/prometheusrule-libraries.yaml` | Present |
| Alert severity matrix | `docs/reference/operations/ALERT_SEVERITY_MATRIX.md` | 30+ alerts classified with routing intent |
| Alert routing verification | `scripts/qa/verify-alert-routing.sh` | Present (requires live cluster) |
| Alert noise baseline | `infrastructure/monitoring/alert-noise-baseline.json` | Present |
| Log-based alerts | `infrastructure/monitoring/alerts/*.json` | 20+ alert definitions (5xx, auth failures, cert expiry, etc.) |

**Quarantined (not active):**
- `prometheusrule-email.yaml` — SES exporter not deployed
- `prometheusrule-ora2.yaml` — custom ORA2 metrics not emitted
- `prometheusrule-tenant-isolation.yaml` — Pushgateway not deployed

**Gaps:**
- **No Alertmanager configuration in this repo** — alert routing (receivers, Slack/PagerDuty channels) is managed in `bbi-infrastructure`. Cannot audit the full alert delivery chain from this repo alone.
- 3 PrometheusRules quarantined because dependencies (SES exporter, Pushgateway) are not deployed.
- No evidence of alert delivery testing (e.g., "fire test alert → confirm Slack message received").

**Risk:** Alerts may fire in Prometheus but never reach an operator if Alertmanager routing is misconfigured in the infra repo. The tenant isolation alert (a P0 security signal) is explicitly inert.

---

### 4. Rollback Path — 🟢 GREEN

**Evidence found:**

| Asset | Path | Status |
|-------|------|--------|
| Emergency rollback runbook | `docs/ops/runbooks/emergency-rollback.md` | 739 lines — comprehensive decision tree, GitOps + DB procedures |
| Rollback dry-run verification | `scripts/qa/verify-rollback-dry-run.sh` | Present — validates rollback script has --dry-run |
| CI/CD release rollback verification | `scripts/qa/verify-cicd-release-rollback.sh` | Present |
| Migration rollback verification | `scripts/qa/verify-migration-rollback.sh` | Present |
| Deployment runbook | `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md` | Present |
| Release execute runbook | `docs/ops/runbooks/RELEASE_EXECUTE_RUNBOOK.md` | Present |
| Rollback import script | `scripts/migrations/rollback-openedx-imports.py` | Present with --dry-run support |
| GitOps workflow runbook | `docs/ops/runbooks/GITOPS_WORKFLOW.md` | Present |

**Strengths:**
- Clear immediate rollback triggers (5xx >10%, data corruption, security incident, cascading failures)
- Decision tree separating "rollback now" from "discuss first"
- GitOps rollback: `git revert` → ArgoCD auto-sync (documented step-by-step)
- Database migration rollback: `bin/lms-ops migrate` with reverse operations
- Communication templates for stakeholder notification
- Post-rollback verification checklist

**Gaps:** Minor — no automated rollback trigger (human-in-the-loop only). This is appropriate for the current scale.

---

### 5. Certs / Secrets / SSO — 🟢 GREEN

**Evidence found:**

| Asset | Path | Status |
|-------|------|--------|
| ExternalSecret manifest | `deploy/k8s/base/secrets/external-secrets.yaml` | 589 lines, 81+ secret keys mapped from Infisical → GCP SM → K8s |
| ClusterSecretStore | `deploy/k8s/base/secrets/cluster-secret-store.yaml` | GCP Secret Manager backend |
| Secret classification registry | `deploy/k8s/base/secrets/SECRET_CLASSIFICATION.yaml` | All 81 secrets classified (env_unique, shared_by_design, generated_at_deploy) |
| Secret rotation checklist | `docs/ops/runbooks/SECRET_ROTATION_CHECKLIST.md` | 5-step contain/rotate/propagate/invalidate/evidence procedure |
| Secret scanning pre-commit | `.githooks/pre-commit` | Blocks hardcoded secrets in commits |
| cert-manager readiness check | `scripts/qa/verify-cert-manager-readiness.sh` | Verifies 5 TLS certificates (LMS, Studio, MFE, forum, enterprise) |
| Secrets management spec | `specs/secrets-management_spec.md` | Formal spec |
| Infisical validation script | `scripts/infra/infisical-validate-mereka-lms.sh` | Referenced in rotation checklist |
| TruffleHog in CI | `.github/workflows/ci.yml` (security-scans job) | HEAD-only scan per PR |
| Multiple secrets verification scripts | `scripts/qa/verify-secrets-*.sh`, `scripts/qa/scan-secrets-fast.sh` | 10+ scripts |

**Strengths:**
- Complete pipeline: Infisical (source of truth) → GCP SM → ExternalSecrets → K8s Secrets → Pods
- Every secret classified with cross-environment copy prevention rules
- Automated rotation procedure with verification at each step
- Pre-commit hook + CI TruffleHog for defense in depth
- Caddy TLS handled by cert-manager (not manual certs)

**Gaps:** Minor — cert-manager Certificate resources are managed in the infra repo, not visible here. Rotation is documented but not automated on a schedule (manual trigger only).

---

### 6. Tenancy Isolation — 🟡 YELLOW

**Evidence found:**

| Asset | Path | Status |
|-------|------|--------|
| Tenant registry ConfigMap | `deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml` | 3 tenants: Mereka Academy, Biji-Biji, Skill Our Future |
| Multisite settings (LMS) | `deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py` | Present |
| Multisite settings (CMS) | `deploy/k8s/base/apps/openedx/settings/cms/mereka_multisite.py` | Present |
| Multi-tenancy spec | `specs/multi-tenancy-architecture_spec.md` | Formal spec |
| Nightly isolation CronJob | `deploy/k8s/base/monitoring/cronjob-tenant-isolation.yaml` | Runs at 2 AM UTC daily |
| Tenant isolation alerts | `deploy/k8s/base/monitoring/prometheusrule-tenant-isolation.yaml` | Defined (P0 severity for cross-tenant leakage) |
| Isolation verification scripts | `scripts/qa/verify-tenant-isolation.sh` (464 lines), `verify-secrets-isolation.sh`, `verify-tenant-isolation-gates.sh`, `verify-enterprise-tenant-isolation.sh` | Multiple |
| Kyverno policies | `deploy/k8s/base/policies/` | 4 policies (seccomp, non-root, capabilities, no-privileged) |
| Network policy | `deploy/k8s/base/apps/xqueue-graders/networkpolicy.yaml` | Present (xqueue only) |
| Tenant provisioning runbook | `docs/ops/runbooks/TENANT_PROVISIONING.md` | Present |

**Gaps:**
- **Pushgateway not deployed** — the tenant isolation CronJob pushes metrics to Pushgateway, but the `prometheusrule-tenant-isolation.yaml` is explicitly quarantined in kustomization.yaml. The `TenantIsolationFailure` alert (P0 critical) will **never fire**.
- Base ConfigMap uses `PLACEHOLDER-*-UUID` values — overlays must replace these; no automated check that overlays actually do.
- NetworkPolicy exists only for xqueue-graders; no default-deny policy for the `mereka-lms` namespace found in this repo (may be in infra repo).
- Tenant isolation evidence file (`evidence/operations/TENANT_ISOLATION_EVIDENCE.md`) is superseded and redirects elsewhere.

**Risk:** A cross-tenant data leak would not trigger an automated alert. The nightly CronJob runs but its results cannot propagate to the alerting system without Pushgateway.

---

### 7. Observability — 🟡 YELLOW

**Evidence found:**

| Layer | Assets | Status |
|-------|--------|--------|
| **Logging** | Promtail DaemonSet + ConfigMap (`deploy/k8s/base/logging/`) | Active — structured JSON parsing, label extraction, forward to Loki |
| **Metrics** | 10 active ServiceMonitors (LMS, CMS, MySQL, Redis, Caddy, Credentials, Discovery, Enterprise, Notes, Purchase Gateway) | Active in kustomization.yaml |
| **SLO** | `prometheusrule-slo.yaml` + `slo-burn-rate-rules.yaml` | Multi-window burn-rate alerts (Google SRE Workbook §6) for 4 services across 3 tiers |
| **Dashboards** | 8 Grafana dashboards (`infrastructure/monitoring/dashboards/`, `grafana/`) | SLO overview, operations, auth, video, Redis, CloudSQL, public endpoints |
| **Logging metrics** | 15+ log-based metrics (`infrastructure/monitoring/logging-metrics/`) | Auth failures, connection errors, 5xx spikes, cert/backup verification |
| **Tracing** | `scripts/qa/verify-observability-tracing.sh`, `OBSERVABILITY_TRACING_PILOT_CONTRACT.md` | Pilot only — `traceparent` header propagated in Caddy |
| **OTel** | `infrastructure/monitoring/otel-metric-registry.yaml` | Metric naming registry defined |

**Quarantined ServiceMonitors (not active):**
- `servicemonitor-xqueue.yaml` — xqueue disabled
- `servicemonitor-forum.yaml` — forum is in-process with LMS
- `servicemonitor-mfe.yaml` — MFE has no /metrics endpoint

**Gaps:**
- **Tracing is pilot-phase only** — Tempo traces referenced in ON_CALL.md but no Tempo deployment in this repo. `traceparent` header forwarded by Caddy but no instrumentation in LMS/CMS Django code.
- **Application-level Django metrics missing** — HTTP request rate by endpoint, response time distributions, DB query times, cache hit/miss ratios. The `IMPLEMENTATION_STATUS.md` explicitly lists these as "What Metrics Are Missing."
- Promtail forwards to `http://localhost:3100` by default (overlays must replace with real Loki endpoint).

**Risk:** Without application-level HTTP metrics, SLO recording rules that depend on `django_http_responses_total_by_status_total` may produce no data if django-prometheus is not correctly wired in the running image. SLO alerts would silently produce no signal.

---

### 8. Disaster Recovery — 🟡 YELLOW

**Evidence found:**

| Asset | Path | Status |
|-------|------|--------|
| DR spec | `specs/disaster-recovery-business-continuity_spec.md` | 551 lines — RPO/RTO, scenarios, acceptance criteria |
| DR runbook | `docs/ops/runbooks/DISASTER_RECOVERY.md` | 429 lines — procedures, Velero + Atlas restore, monthly drills |
| DR drill schedule | `docs/ops/runbooks/DR_DRILL_SCHEDULE.md` | 383 lines — monthly rotating focus (Velero/MySQL/Atlas/PG) |
| DR test results | `docs/status/readiness/DR_TEST_RESULTS.md` | ✅ One successful drill (2026-02-03, 7s restore, data verified) |
| DR verification script | `scripts/qa/verify-disaster-recovery.sh` | 769 lines — 22 acceptance criteria checked |
| DR evidence bundle | `scripts/qa/build-dr-evidence-bundle.sh` | Present with --tar output |
| DR evidence CI workflow | `.github/workflows/dr-evidence-bundle.yml` | Monthly schedule + manual dispatch |
| Course data recovery runbook | `docs/ops/runbooks/COURSE_DATA_RECOVERY.md` | Present |
| Cloud SQL restore drill | `docs/ops/runbooks/CLOUD_SQL_RESTORE_DRILL.md` | Present |
| Incident response runbook | `docs/ops/runbooks/INCIDENT_RESPONSE.md` | 219 lines — severity levels, 5-command diagnostic, common patterns |
| On-call guide | `docs/ops/runbooks/ON_CALL.md` | 133 lines — shift handoff, dashboard links, alert routing |
| Incident templates | `docs/ops/runbooks/INCIDENT_TEMPLATES.md` | Present |

**Defined targets:**
- **RPO ≤ 24 hours** for LMS data
- **RTO ≤ 4 hours** for core LMS availability
- MongoDB Atlas: RPO 1 hour (continuous point-in-time restore)

**Gaps:**
- Only **one** restore drill result documented (Feb 2026); the monthly schedule implies there should be at least one per month since then.
- `evidence/` directory has no DR-specific artifacts — monthly evidence bundles may be generated but not committed to the repo.
- Atlas backup verification is "TBD" in the DR runbook and there's no dedicated Atlas restore drill result.
- RPO/RTO are documented targets but there's no continuous SLA compliance dashboard proving they are met.
- On-call rotation table in `ON_CALL.md` uses placeholder names (`_@name_`) — unclear if actually filled.

**Risk:** The DR framework is excellent on paper, but the gap between "documented process" and "proven execution" is the primary risk. If the monthly drills are not actually happening, a real disaster could reveal untested restore paths.

---

### 9. Production Change Control — 🟢 GREEN

**Evidence found:**

| Asset | Path | Status |
|-------|------|--------|
| Release process | `docs/reference/operations/RELEASE_PROCESS.md` | 289 lines — semver, cadence, checklist, preflight |
| Release workflow | `.github/workflows/release.yml` | 323 lines — tag-triggered, changelog, GitHub Release, image build |
| CI pipeline | `.github/workflows/ci.yml` | 907 lines — 4 jobs (scope detection, static validation, tutor config, security scans) |
| Canonical preflight | `scripts/infra/canonical-release.sh` | Branch/worktree validation |
| Release automation verification | `scripts/qa/verify-release-automation.sh` | Present |
| Release workflow invocation check | `scripts/qa/verify-release-workflow-invocation.sh` | Present |
| Build workflow contract | `scripts/qa/verify-build-workflow-contract.sh` | Present |
| Post-deploy gate | `scripts/qa/verify-post-deploy-gate.sh` | Present |
| Post-deploy smoke | `scripts/qa/verify-post-deploy-smoke.sh` | Present |
| Branch protection verification | `scripts/qa/verify-branch-protection.sh` | Present |
| Deployment verification runbook | `docs/ops/runbooks/DEPLOYMENT_VERIFICATION.md` | Present |
| Release checklist runbook | `docs/ops/runbooks/RELEASE_CHECKLIST.md` | Present |
| Merge group / queue support | CI `on: merge_group` | Present |
| Concurrency control | CI `cancel-in-progress: true` | Prevents stale runs |
| Script governance | `scripts/governance/canonical-entrypoints.yaml`, `script-registry.yaml` | Script registry + CI inventory |
| 3 composite actions | `.github/actions/gcp-gke-auth/`, `setup-python-env/`, `setup-playwright/` | DRY CI building blocks |

**Strengths:**
- Clear release cadence (weekly minor, ad-hoc patch, planned major)
- 5-step release checklist: structural verification → review → canonical preflight → tag → publish
- CI runs 200+ verification scripts via parallel xargs runner
- Merge group support prevents broken `main`
- Post-deploy gates verify the deployment succeeded
- Script governance registry ensures every verification script is tracked

**Gaps:** Minor — branch protection is now explicit and machine-readable in `config/branch-protection-contract.yaml`; the current owner-merged policy intentionally keeps `required_approving_review_count: 0`, so reviewer count is a governance choice rather than a missing in-repo contract surface.

---

## Top 5 Recommendations (Priority Order)

| Priority | Action | Addresses |
|----------|--------|-----------|
| **P1** | Deploy Pushgateway and un-quarantine `prometheusrule-tenant-isolation.yaml` | Tenancy Isolation (#6) — P0 security alert is currently dead |
| **P2** | Confirm synthetic uptime checks are active on RKE2 production (not just GCP JSON definitions). Deploy an external uptime service or verify Upptime at `status.mereka.dev` | Synthetic Monitoring (#2) |
| **P3** | Execute and commit monthly DR drill evidence to `evidence/` or verify the CI workflow artifact retention. Run an Atlas restore drill and document results | Backups (#1), Disaster Recovery (#8) |
| **P4** | Verify Alertmanager routing delivers to actual Slack/PagerDuty channels. Run `scripts/qa/synthetic-alert-drill.sh` and confirm receipt | Alerting (#3) |
| **P5** | Instrument LMS/CMS with django-prometheus to activate SLO recording rules. Without app-level HTTP metrics, burn-rate alerts produce no signal | Observability (#7) |
