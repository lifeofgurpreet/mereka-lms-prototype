# Mereka LMS Observability Roadmap (First-Class)

Date: 2026-02-25

## Metadata

- last_updated: 2026-02-25
- owner: Mereka LMS platform team
- canonical_runtime_gate: `scripts/qa/run-observability-first-class.sh`
- canonical_ci_workflow: `.github/workflows/observability-compliance.yml`
- canonical_readiness_report: `docs/qa/OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md`

## Objective

Build and operate a first-class observability system for Mereka LMS so operators can answer:
1. What is broken now?
2. Which user journeys are impacted?
3. What changed?
4. Is recovery complete?

## Scope and Constraints

- Platform: Open edX custom deployment for Mereka LMS.
- Environments: `dev/nonprod/prod` parity target (with current infra constraints respected).
- Monitoring stack spans:
  - K8s/Prometheus rules + ServiceMonitors
  - GCP Monitoring (dashboards, alerts, uptime, log metrics)
  - Grafana contract dashboards
  - Sentry wiring
  - Velero/DR evidence

## Strategic Principles

1. One runtime gate contract: all runtime checks converge on `run-observability-first-class.sh`.
2. Evidence-first operations: every gate emits machine-readable evidence index + human summary.
3. Parity before polish: dev/nonprod/prod command paths and evidence identity must match.
4. Backward-compatible migration: preserve legacy artifact aliases while consumers migrate.
5. Operationally testable plans: each phase has clear definition-of-done criteria.

## Phase Plan

### Phase 0: Contract Foundation (Completed)

Goal:
- Canonicalize runtime checks and evidence shape.

Status:
- Completed.

Exit criteria achieved:
- Runtime checks routed via `run-observability-first-class.sh` in key CI/runtime gates.
- Evidence identity normalization implemented (`env/profile/context/project`).
- Observability compliance workflow supports runtime preflight + strict runtime evidence checks.

### Phase 1: Environment Parity (In Progress)

Goal:
- Make observability execution and evidence parity explicit across `dev/nonprod/prod`.

Work items:
1. Add environment-specific runbooks for runtime gate invocation:
   - `dev`: expected context/project/profile labels.
   - `nonprod`: expected context/project/profile labels.
   - `prod`: expected context/project/profile labels.
2. Add parity audit document/table:
   - required dashboards, alerts, rules, monitors per environment.
   - what is intentionally absent and why.
3. Add CI/manual checklist that validates parity labels in evidence artifacts.

Definition of done:
- Every environment has one canonical command and expected evidence identity.
- Parity matrix exists and is referenced by operations docs.
- No environment ambiguity in runtime execution.

### Phase 2: Service Coverage Completeness

Goal:
- Ensure all critical service surfaces are measured, scraped, and alerting.

Work items:
1. Validate ServiceMonitor coverage for all critical workloads and edges.
2. Validate PrometheusRule coverage for:
   - availability
   - saturation
   - errors
   - synthetic/backup failures
3. Validate Grafana dashboard contract maps to active PromQL signal sources.
4. Add/close gaps for Open edX service families:
   - LMS/CMS/MFE/Caddy
   - Discovery/Ecommerce/Credentials/Forum
   - supporting infra (DB/cache exporters where applicable)

Definition of done:
- Coverage audit shows no critical blind spots for required service families.
- Runtime gate fails on missing critical monitor/rule coverage.

### Phase 3: Alert Quality and Routing Hardening

Goal:
- Reduce noisy alerts and guarantee high-severity routing correctness.

Work items:
1. Baseline alert quality:
   - false positive rate
   - duplicate alerts
   - missing route/channel mapping
2. Harden high-severity routing checks:
   - enabled policy + enabled channel guarantees
   - production-safe channel checks in runtime gate
3. Define suppression windows and escalation policy linkage.

Definition of done:
- High-severity alerts have deterministic route integrity.
- Alert routing verifier passes consistently under strict mode.

### Phase 4: SLO and User-Journey Observability

Goal:
- Tie monitoring to learner/operator impact, not only component health.

Work items:
1. Define top user journeys and SLI ownership:
   - login/auth
   - course access
   - content authoring path
   - purchase/credentials flow
2. Ensure SLO burn-rate alerts map to actionable runbooks.
3. Add evidence linking from runtime gates to SLO posture snapshots.

Definition of done:
- Each Tier-1 journey has SLI/SLO mapping and burn-rate alert coverage.
- Operators can classify incidents by journey impact quickly.

### Phase 5: Error Tracking + Logs + Traces Cohesion

Goal:
- Unify application-level debugging across metrics/logs/errors/traces.

Work items:
1. Finish Sentry runtime wiring enforcement where required services must comply.
2. Standardize structured log contracts for top incident classes.
3. Decide and document tracing scope:
   - minimum viable tracing for critical flows
   - phased rollout with sampling controls

Definition of done:
- Required services pass runtime Sentry/log wiring checks.
- Incident triage path from alert -> logs/errors is documented and repeatable.

### Phase 6: DR Observability and Evidence Governance

Goal:
- Make DR evidence generation repeatable, auditable, and first-class.

Work items:
1. Keep DR bundle on canonical observability artifacts:
   - `observability-compliance-runtime.json`
   - `observability-runtime-verify-runtime.md`
   - `observability-first-class-runtime-evidence-index.json`
   - `observability-correlation-headers-runtime.txt`
   - legacy alias retained for compatibility.
2. Add monthly artifact review checklist with owners.
3. Add retention and archival procedure for long-term compliance needs.

Definition of done:
- Monthly DR evidence is generated and review-tracked.
- Evidence consumers are fully migrated to canonical artifact names.

### Phase 7: Governance and Change Safety

Goal:
- Prevent observability regressions from silently shipping.

Work items:
1. Add CI enforcement for canonical observability docs and command references.
2. Add lint checks for non-canonical runtime observability command drift.
3. Add release gate quality checks for observability artifacts presence/shape.

Definition of done:
- PRs that regress observability contract fail deterministically.
- Canonical command drift is prevented automatically.

## Next 14-Day Execution Focus

Priority order:
1. Phase 1 completion (parity matrix + env-specific runtime identities).
2. Phase 2 coverage closure for remaining critical blind spots.
3. Phase 3 routing hardening + noise reduction baseline.

Expected outputs:
1. `docs/ops/monitoring/OBSERVABILITY_PARITY_MATRIX.md` (created)
2. Updated runtime runbooks with env-scoped canonical commands.
3. Gap closure report appended to `OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md`.

## Blocking Defect Register

1. **Critical (P0): LMS/CMS `/metrics` endpoint not contract-compliant in live prod render**
   - **Observed:** `deploy/lms` / `deploy/cms` are not returning valid Prometheus payload from `/metrics` in one runtime path, and configmap snapshots show stale variants without current route wiring markers.
   - **Hypothesis:** Live settings configmaps (`openedx-settings-lms-patched-...` and `openedx-settings-cms-...`) are out of sync with the current source render.
   - **Impact:** Prometheus scraping can silently pass only intermittently and runtime gates cannot reliably reflect reality.
   - **Owner:** Platform SRE + Observability.
   - **Remediation:** Reconcile rendered settings through the normal GitOps release path and verify with strict runtime evidence.

2. **Critical (P0): Drift between source render and deployed settings**
   - **Observed:** Source config in `deploy/k8s/base/apps/openedx/settings/*.py` now contains latest Prometheus patch wiring.
   - **Hypothesis:** Deployment is using a previously rendered configmap; expected marker lines (`openedx_prometheus.urls` in `ROOT_URLCONF_OVERRIDES`) are missing in live payload.
   - **Owner:** Platform CI/Delivery.
   - **Remediation:** Add source fingerprint/required-marker assertion to runtime evidence and treat mismatch as high severity.

3. **High (P1): Environment signal-parity ambiguity**
   - **Observed:** Nonprod/prod command context and identity labels can be misapplied in ad-hoc checks.
   - **Impact:** false confidence in partial environment checks.
   - **Remediation:** Enforce single source for env/context/profile identity inputs across strict gates and documented runbooks.

## Execution Track (next 10 large tasks)

1. Complete `/metrics` source-to-runtime reconciliation in the live lane with one GitOps-sourced rollout.
2. Add required-settings fingerprint check in strict runtime evidence for LMS/CMS.
3. Add direct `/metrics` functional check with DisallowedHost-safe pod-call flow. ✅ (runtime check path now captures payload + validation path in `scripts/qa/verify-observability-runtime.sh`).
4. Add gate-level assertion that `openedx-settings-lms|cms` live payload includes `openedx_prometheus` + root override markers. ✅ (implemented marker check in `scripts/qa/verify-observability-runtime.sh`).
5. Expand parity matrix for nonprod and prod `/metrics` evidence shape and required labels.
6. Expand Phase 2 coverage map with explicit LMS/CMS route-contract tests.
7. Add owner/date/impact tags to every observability defect in this roadmap.
8. Add runbook page for `/metrics` + Prometheus wiring triage.
9. Enforce no-stale-metrics-gate in `run-observability-first-class.sh` execution path.
10. Close residual evidence debt in `OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md` with pass/no-pass proof links.

## Risk Register (Current)

1. Environment ambiguity risk:
   - Different context/project assumptions can produce false confidence.
2. Alert fatigue risk:
   - High volume/low quality alerts can hide real incidents.
3. Evidence contract drift risk:
   - Mixed artifact names break downstream review workflows.
4. Runtime dependency risk:
   - gcloud/kubectl availability in CI/runtime environments.

## Immediate Next Actions

1. Keep `OBSERVABILITY_PARITY_MATRIX.md` current with required/actual per environment.
2. Review and tune `daily-infrastructure-audit.yml` parity matrix variables (`OBS_PARITY_*_K8S_CONTEXT`, `OBS_PARITY_*_GCP_PROJECT`) for each environment. (Previously configured in `observability-parity-runtime.yml` — merged in Phase 6.4.)
3. Promote parity rollup artifacts into weekly operator review and close PAR-001/PAR-002 after 3 consecutive no-skip/no-fail scheduled rollups.
