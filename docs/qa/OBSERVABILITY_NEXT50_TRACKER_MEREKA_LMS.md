# Observability Next-50 Tracker (Mereka LMS)

Date: 2026-03-03
Owner: Mereka LMS platform team
Scope: dev/nonprod/prod observability hardening for Open edX deployment
Execution mode: Tracker-ready implementation backlog

## Latest Runtime Snapshot (2026-03-03)

- `prod` lane (`gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`) is strict-green:
  - `./scripts/qa/run-observability-first-class.sh --mode runtime --strict` exits `0` with all six steps `PASS`.
- `dev` (`rke2-staging`) and `nonprod` (`rke2-nonprod`) remain strict-red due to runtime platform gaps:
  - `AC-OVR-016`: LMS/CMS `/metrics` return `404`.
  - runtime marker probe: `openedx-settings-lms-patched` lacks expected prometheus wiring markers.
  - logging strict failure (`AC-LOG-002`) when Loki service is absent in-lane.
- Tracing pilot (`OBS-025`) remains open; strict nonprod pilot bundle still times out (`exit 124`).

## Status Legend

- `planned`: scoped and ready
- `in_progress`: being implemented
- `blocked`: waiting on dependency/credential/infra input
- `done`: shipped and verified

## Next 50 Tasks

| ID | Priority | Workstream | Task | Depends on | Deliverable | Definition of done | Status |
|---|---|---|---|---|---|---|---|
| OBS-001 | P0 | Parity | Wire `OBS_PARITY_DEV_K8S_CONTEXT` in GitHub variables | none | parity workflow var set | dev lane no longer skipped in scheduled parity workflow | done |
| OBS-002 | P0 | Parity | Wire `OBS_PARITY_NONPROD_K8S_CONTEXT` in GitHub variables | none | parity workflow var set | nonprod lane no longer skipped in scheduled parity workflow | done |
| OBS-003 | P0 | Parity | Validate `OBS_PARITY_PROD_K8S_CONTEXT` against current prod context | OBS-001 | runbook evidence | prod lane succeeds without context resolution errors | done |
| OBS-004 | P0 | Parity | Wire `OBS_PARITY_*_GCP_PROJECT` overrides where needed | OBS-001 | variable map in workflow setup doc | parity runs use expected project per env without manual override | done |
| OBS-005 | P0 | Parity | Enforce 3 consecutive no-skip/no-fail rollups and close PAR-001/PAR-002 | OBS-001, OBS-002 | readiness report update | three scheduled rollups pass and gaps marked closed | done |
| OBS-006 | P0 | Coverage | Audit missing ServiceMonitor coverage vs required services in each env | OBS-005 | env gap report | report lists missing/extra monitors with owners and dates | done |
| OBS-007 | P0 | Coverage | Add missing ServiceMonitors for uncovered critical workloads | OBS-006 | k8s manifests | runtime gate passes monitor presence for all critical services | done |
| OBS-008 | P0 | Coverage | Add scrape label consistency checks to validation scripts | OBS-007 | script rule updates | validation fails if required labels/selectors drift | done |
| OBS-009 | P1 | Coverage | Add monitor endpoint latency/error budget panels for all critical services | OBS-007 | dashboard contract update | dashboard audit passes with new required panels | planned |
| OBS-010 | P1 | Coverage | Add per-service metrics cardinality watchlist | OBS-007 | monitoring doc + alert rule | cardinality drift alert is present and tested | planned |
| OBS-011 | P0 | Alert quality | Wire runtime data feed for `ALERT_NOISE_RUNTIME_SOURCE` in CI | OBS-004 | workflow/env secret wiring | alert-noise runtime audit runs in strict mode in CI | done |
| OBS-012 | P0 | Alert quality | Define severity-specific noise thresholds (`critical`, `error`, `warning`) | OBS-011 | updated baseline config + strict runtime validation | baseline schema includes required severities and per-severity thresholds | done |
| OBS-013 | P1 | Alert quality | Add duplicate-alert detector by fingerprint/window | OBS-012 | script enhancement | runtime audit reports duplicate ratio by severity | done |
| OBS-014 | P1 | Alert quality | Add false-positive classification inputs contract (manual/operator label feed) | OBS-012 | contract doc + parser | runtime audit ingests classification feed without schema errors | done |
| OBS-015 | P0 | Alert quality | Close PAR-003 via codified threshold + strict runtime evidence | OBS-011, OBS-012 | readiness report update | PAR-003 moved to closed with evidence links | done |
| OBS-016 | P0 | SLO | Define Tier-1 user journeys and owning SLI metrics | OBS-006 | SLO mapping doc | each Tier-1 journey mapped to explicit SLI query | done |
| OBS-017 | P0 | SLO | Implement missing SLI recording rules for uncovered journeys | OBS-016 | PrometheusRule updates | recording rules present and queryable in runtime | done |
| OBS-018 | P1 | SLO | Add burn-rate alerts for all Tier-1 journeys (multi-window) | OBS-017 | PrometheusRule updates | burn-rate alerts loaded and visible in Prometheus API | done |
| OBS-019 | P1 | SLO | Add SLO dashboard contract section per journey | OBS-018 | dashboard contract update | audit script enforces journey SLO panels | done |
| OBS-020 | P1 | SLO | Add SLO breach runbook links in alert annotations | OBS-018 | alert annotation updates | each SLO alert links to concrete remediation runbook | done |
| OBS-021 | P1 | Logs/errors | Enforce structured log keys for critical failure classes | OBS-006 | logging contract doc + lints | CI fails on missing required log fields in key services | done |
| OBS-022 | P1 | Logs/errors | Expand Sentry runtime coverage matrix by service | OBS-021 | service matrix + audit rules | sentry wiring audit verifies all required services | done |
| OBS-023 | P1 | Logs/errors | Add correlation ID propagation checks across ingress->app | OBS-021 | runtime check script | check fails when correlation headers missing | done |
| OBS-024 | P2 | Tracing | Define minimal tracing scope for Tier-1 flows | OBS-016 | tracing ADR | tracing scope approved with sampling policy | done |
| OBS-025 | P2 | Tracing | Pilot trace ingestion for one Tier-1 flow in nonprod | OBS-024 | nonprod tracing evidence | one flow trace appears end-to-end in selected backend | in_progress (pilot-wrapper added, waiting on captured trace/id proof) |
| OBS-026 | P0 | DB/cache | Validate mysql exporter metric completeness vs panel queries | OBS-007 | exporter audit updates | no dashboard query references missing metrics | planned |
| OBS-027 | P0 | DB/cache | Validate redis exporter metric completeness vs panel queries | OBS-007 | exporter audit updates | no dashboard query references missing metrics | planned |
| OBS-028 | P1 | DB/cache | Add saturation forecast panel (7d trend) for MySQL/Redis | OBS-026 | dashboard update | forecast panels present and query-valid | planned |
| OBS-029 | P1 | DB/cache | Add alert for persistent high connection-utilization with cooldown | OBS-026 | alert rule update | alert fires only on sustained condition; no flap | planned |
| OBS-030 | P1 | DB/cache | Add atlas connectivity trend panel with failure histogram | OBS-006 | dashboard update | panel appears in contract and passes audit | planned |
| OBS-031 | P0 | DR | Add strict identity verification to parity rollup artifacts | OBS-005 | rollup script update | rollup fails on identity mismatch across env artifacts | done |
| OBS-032 | P0 | DR | Add DR evidence manifest schema check (required files + hashes) | OBS-031 | DR script enhancement | bundle creation fails if manifest contract breaks | done |
| OBS-033 | P1 | DR | Add restore-drill trend panel (last 6 runs) | OBS-032 | dashboard panel | operator sees pass/fail trend in one view | planned |
| OBS-034 | P1 | DR | Add RTO/RPO evidence fields to DR bundle manifest | OBS-032 | manifest extension | manifest includes measured RTO/RPO per drill | planned |
| OBS-035 | P1 | DR | Enforce monthly DR bundle review SLA in operations checklist | OBS-034 | runbook update | missed monthly review raises explicit gate warning | planned |
| OBS-036 | P1 | Dashboards | Refactor dashboard contract to include ownership tags per panel | OBS-009 | contract schema update | each required panel has owner metadata | done |
| OBS-037 | P1 | Dashboards | Add panel freshness audit (query returns data within N min) | OBS-036 | audit script update | audit fails on stale/no-data required panels | done |
| OBS-038 | P2 | Dashboards | Add onboarding dashboard: “Platform health in 5 panels” | OBS-036 | new dashboard json | dashboard deployed and linked in on-call playbook | planned |
| OBS-039 | P2 | Dashboards | Add env comparison dashboard (dev vs nonprod vs prod) | OBS-005 | new dashboard json | same KPI appears side-by-side across environments | planned |
| OBS-040 | P2 | Dashboards | Add dashboard snapshot export automation for incidents | OBS-038 | export script/workflow | incident workflow can attach snapshot artifact automatically | planned |
| OBS-041 | P0 | Governance | Add CI lint for non-canonical observability command drift in `docs/` (global) | OBS-005 | lint script/workflow | CI blocks non-canonical runtime command references | done |
| OBS-042 | P1 | Governance | Add AC coverage map for observability scripts -> specs | OBS-041 | coverage map doc/json | each AC has at least one enforcing check mapped | done |
| OBS-043 | P1 | Governance | Add script contract tests for parity-delta/review/rollup tools | OBS-042 | scripts/qa/test-observability-parity-contracts.sh | tools fail fast on malformed inputs and pass valid fixtures | done |
| OBS-044 | P1 | Governance | Add artifact retention policy matrix (CI + long-term archive) | OBS-032 | docs/policies/operations/OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md | retention windows defined and enforceable per artifact class | done |
| OBS-045 | P1 | Governance | Add "observability release checklist" gate to deployment playbook | OBS-041 | docs/runbooks/operations/RELEASE_CHECKLIST.md | release process requires observability sign-off step | done |
| OBS-046 | P1 | Ops | Add weekly parity review issue template in repo | OBS-005 | template markdown | weekly review can be opened in <2 minutes with standard fields | done |
| OBS-047 | P1 | Ops | Add incident postmortem section for observability misses | OBS-046 | postmortem template update | postmortems classify monitoring detection gap explicitly | done |
| OBS-048 | P2 | Ops | Add operator training drill for alert triage with evidence artifacts | OBS-046 | drill runbook | drill completed once per month with attendance log | done |
| OBS-049 | P2 | Ops | Add service owner ack process for new alert rules | OBS-014 | process doc | no new high-severity alert merges without owner ack | done |
| OBS-050 | P0 | Ops | Publish “Observability GA” readiness gate (exit criteria for roadmap) | OBS-005, OBS-015, OBS-020, OBS-035, OBS-041 | readiness decision doc | explicit go/no-go with objective evidence links | done |


## Current Execution Wave (Next 10 Large Tasks)

1. Define and publish a **Tracing Scope Decision Record** for Tier-1 journeys (owner: observability, target date: immediate). **Done** (ADR-020).
2. Finalize non-prod trace backend for the pilot and document ingress/egress contract (OTLP endpoints, auth, sampling, retention).
3. Add or validate Tempo runtime manifests in `deploy/k8s/base/monitoring` for the selected pilot route (LMS/CMS → DB/cache/Forum path).
4. Extend `scripts/qa/verify-observability-contracts.sh` so tracing checks are explicit (present config, runtime service presence, rule/docs existence), not only `SKIP`. **Done** (`scripts/qa/verify-observability-contracts.sh`)
5. Add a first-class evidence script for tracing (`scripts/qa/verify-observability-tracing.sh`) and hook it into `run-observability-first-class.sh` + first-class artifact set. **Done** (already wired in `scripts/qa/run-observability-first-class.sh`)
6. Complete `scripts/qa/verify-logging-pipeline.sh` by wiring existing AC-LOG checks (log source presence, label schema, structured JSON, retention) and strict-mode behavior.
7. Update `verification/catalogs/OBSERVABILITY_SCRIPT_AC_COVERAGE_MAP.md` and `specs/_generated/testmaps/observability-stack_spec.testmap.yml` for OBS-024/025 and AC-LOG/AC-005 evidence paths. **Done** (`verification/catalogs/OBSERVABILITY_SCRIPT_AC_COVERAGE_MAP.md` updated; generated testmap already maps `verify-observability-contracts.sh` and `verify-observability-tracing.sh` to AC-005/AC-007)
8. Add nonprod tracing evidence runbook step to `docs/runbooks/operations/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md` and `OBSERVABILITY_PARITY_MATRIX.md`. **Done** (nonprod step and tracing artifact requirements documented).
9. Produce the first pilot evidence artifact bundle (`docs/archive/evidence/observability/`), including one canonical flow trace ID + log correlation proof.
10. Prepare handoff ticket set `OBS-PILOT-TRACING-01` in docs/qa tracker for implementation agents with explicit acceptance gates and ownership. **Done** (`docs/qa/OBS-PILOT-TRACING-01.md`)


## Runtime Blocking Findings (2026-02-27 evidence)

- `verify-observability-runtime.sh` on `rke2-nonprod` remains with `PASS 8 / FAIL 29 / SKIP 2`.
- AC-OVR-016 (`LMS/CMS /metrics`) still fails in live runtime payload checks (`status_code: 000` for observed paths).
- LMS runtime still appears to use stock settings path and not repo-applied app instrumentation in the live pod, so `django_prometheus`/`openedx_prometheus` wiring is not guaranteed from runtime images.
- CMS has partial middleware/install presence but still lacks consistent `/metrics` exposure semantics in the checked runtime lane.
- `infrastructure/tutor/custom-apps/openedx_prometheus/urls.py` now exposes both `metrics` and `metrics/`; rerun strict runtime checks to verify route normalization closes CMS/LMS payload path ambiguity.
- `scripts/qa/verify-observability-runtime.sh` now uses namespace fallback for both ServiceMonitor and PrometheusRule lookups (monitoring/app namespaces + all-namespace fallback with duplicate-match detection) to remove a false-negative class in wiring checks. Runtime verification still needs a live re-run to confirm closure.
- AC-OVR-025 (`validate-observability-compliance.sh --json`) and AC-OVR-029 strict gating behavior were unreliable, but runtime verifier now enforces strict JSON extraction/path handling; re-run strict wave to confirm closure.
- Continue with sequencing: first close runtime app-metrics drift, then close coverage objects (`OBS-053..057`), then harden strict JSON/parity gating.



## Systematic Execution Wave 2 — Handoff Queue (2026-02-27)

This is the next ordered 10-task handoff in terms of implementation scope, not micro-steps. Keep each task in lane mode: close one ticket, rerun proof command, then move to the next.

1. **OBS-EXT-061 — Close app-metrics image drift (P0, in_progress)**
  - Definition of done: LMS/CMS pods in dev/nonprod/prod show expected `/metrics` settings wiring and middleware chain from repo-produced manifests; evidence from `observability-metrics-lms-runtime.md` and `observability-metrics-cms-runtime.md` both shows status_code `200`.
   - Current implementation status: Django route now exposes both `metrics` and `metrics/`; remaining closure requires strict live runtime proof in all lanes.

2. **OBS-EXT-062 — Make LMS metrics endpoint contract concrete (P0, in_progress)**
  - Definition of done: `openedx_prometheus.urls` is explicitly mounted at `/metrics` in runtime URLConf and `/metrics` returns Prometheus exposition with both `# HELP` and numeric sample rows.
   - Current implementation status: URLConf contract now includes explicit `/metrics` and trailing-slash variant; verification still requires `status_code: 200` + sample payload evidence in live strict run.

3. **OBS-EXT-063 — Normalize CMS metrics route and ServiceMonitor alignment (P0, in_progress)**
  - Definition of done: CMS `/metrics` route exists with service/monitor naming matching the lane, and runtime checks emit `status_code: 200` for CMS with valid Prometheus exposition (`# HELP`, `# TYPE`, numeric sample count).
   - Current implementation status: awaiting strict nonprod/prod evidence closure; route/path is validated via runtime payload probing and wiring checks.

4. **OBS-EXT-064 — Finish OBS-053 (P0, planned)**
   - Definition of done: `caddy-metrics` + `caddy-alerts` deployed and visible across dev/nonprod/prod in monitor targets and runtime evidence objects.

5. **OBS-EXT-065 — Finish OBS-054 (P0, planned)**
   - Definition of done: `mfe-metrics` ServiceMonitor + `services-alerts` PrometheusRule exist in each parity lane where required and pass strict runtime verification.

6. **OBS-EXT-066 — Finish OBS-055 (P1, planned)**
   - Definition of done: Surface service monitors for Forum/Discovery/Ecommerce/Credentials/Purchase Gateway are present and confirmed in Prometheus scrape targets per lane profile.

7. **OBS-EXT-067 — Finish OBS-056 (P1, planned)**
   - Definition of done: Rule sets (`caddy-alerts`, `slo-recording-rules`, `video-alerts`, `ora2-operations`) appear in `/api/v1/rules` and match expected object names in proof evidence.

8. **OBS-EXT-068 — Finish OBS-057 (P1, planned)**
   - Definition of done: dev-only monitor coverage includes `xqueue-metrics` and `mux-delivery-monitor` checks with no accidental nonprod/prod regressions.

9. **OBS-EXT-069 — Stabilize strict runtime/compliance JSON and deterministic fail behavior (P1, in_progress)**
   - Definition of done: `AC-OVR-025` and `AC-OVR-029` pass consistently with strict mode and canonical runner outputs remain machine-parseable.
   - Current implementation status: `validate-observability-compliance.sh` supports deterministic JSON-only strict output (`VALIDATE_OBS_JSON_ONLY=1`), runtime verification no longer exits early on payload-shape checks under `set -e`, and compliance failure summaries are ANSI-stripped and deterministic. `prod` strict lane now passes end-to-end; remaining red lanes are runtime environment gaps, not parser instability.

10. **OBS-EXT-070 — Publish implementation handoff epic (P0, planned)**
    - Definition of done: one parent issue set in tracker references `OBS-053..057`, `OBS-EXT-061..069`, and `OBS-058` with explicit evidence paths + closure criteria.

### Current execution state (2026-02-27)

- OBS-EXT-061 / OBS-EXT-062 moved from blocked state to **implementation in progress**:
  - LMS/CMS `ROOT_URLCONF_OVERRIDES` now includes `openedx_prometheus.urls` in runtime settings.
  - `infrastructure/tutor/custom-apps/openedx_prometheus/urls.py` now exposes the endpoint at `/metrics` explicitly.
  - `scripts/qa/verify-observability-runtime.sh` now includes path-aware `/metrics` payload capture (`status_code` + `metric_path` + body), dual `/metrics`/`/metrics/` probing, and curl-first + wget fallback; remains unverified against live lanes until next strict run.
- Keep `OBS-EXT-063` as next verification target; validate both `/metrics` endpoints via strict runtime command before closing.
- `OBS-EXT-069` has parser and evidence-index hardening implemented; next action is proof runs in nonprod/runtime to close with `observability-compliance-runtime.json`, `observability-first-class-runtime-evidence-index.json`, and all wired component artifact files (per `observability-first-class-evidence-index-hardening-2026-02-27.md`).

### Lane command for every wave

Use this exact check after each closure wave:

```bash
OBSERVABILITY_ENV_LABEL=nonprod \
OBSERVABILITY_DISPATCH_PROFILE=nonprod \
OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_NONPROD_K8S_CONTEXT \
OBSERVABILITY_GCP_PROJECT=${OBS_PARITY_NONPROD_GCP_PROJECT:-mereka-lms} \
./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

Use `nonprod` for `lane=dev|nonprod`; use `prod` for `lane=prod`.

Required artifacts to close each wave:
- Hand-off issue set: `reports/2026/closures/OBS-EXT-WAVE-2-HANDOFF.md` for implementation sequencing and sign-off closure criteria.
- `observability-compliance-runtime.json`
- `observability-runtime-verify-runtime.md`
- `observability-first-class-runtime-evidence-index.json`
- `observability-metrics-lms-runtime.md`
- `observability-metrics-cms-runtime.md`
- relevant per-object evidence file(s)

## Execution Order Recommendation

1. P0 tasks first: `OBS-001..OBS-008`, `OBS-011`, `OBS-015..OBS-017`, `OBS-026..OBS-027`, `OBS-031..OBS-032`, `OBS-041`, `OBS-050`.
2. Then P1 tasks by workstream.
3. Then P2 optimization tasks.

## Priority Next Steps After Current Commit (Lane-safe, execute one ticket at a time)

- **Priority A — unblock runtime app instrumentation evidence**
  - `OBS-EXT-061` / `OBS-EXT-062` / `OBS-EXT-063`
  - Must finish with `LMS/CMS /metrics` payload checks returning `200` and valid Prometheus samples in all lanes.

- **Priority B — close remaining runtime object coverage**
  - `OBS-053`, `OBS-054`, `OBS-055`, `OBS-056`, `OBS-057`
  - Must finish in order, each with fresh per-lane evidence from
    `run-observability-first-class.sh --mode runtime --strict`.

- **Priority C — gate hardening + handoff finalization**
  - `OBS-069` (`AC-OVR-025`, `AC-OVR-029` strict determinism)
  - `OBS-070` (implementation parent handoff closure): all child rows linked with evidence IDs and exit criteria.

- **Priority D — evidence retention and trending**
  - Re-run strict scheduled parity rollup after each wave and capture 3 consecutive non-failing windows to close `PAR-001`/`PAR-002`.
  - Archive evidence artifacts with lane/dispatch hash and timestamp for operator trend review.

### Hard stop rules

- Do not progress to `Priority B` until `Priority A` has a clean lane signal in at least one nonprod proof run.
- Do not progress to `Priority C` until all `OBS-053..057` blockers are evidence-closed in `nonprod`, then `prod`, then `dev`.
- Do not modify unrelated service or application behavior from these tickets (observability-only scope).

## Runtime Recovery Wave (2026-02-26 evidence-driven, large tasks)

| ID | Priority | Workstream | Task | Depends on | Deliverable | Definition of done | Status |
|---|---|---|---|---|---|---|---|
| OBS-051 | P0 | Parity | Restore GCP monitoring dashboard `Open edX SLO Dashboard - Service Level Objectives` in production/runtime environments | OBS-041 | Dashboard definition + deployment command in infra playbook | `OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod ./scripts/qa/run-observability-first-class.sh --mode runtime --strict` no longer fails on missing SLO dashboard in prod/nonprod/dev and returns false positives in non-strict mode | done |
| OBS-052 | P0 | Parity | Define and document dashboard parity scope: GCP dashboards vs Grafana dashboards (artifact classification) | OBS-051 | `docs/runbooks/operations/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md` update | Runtime parity script and parity matrix ignore/handle non-GCP dashboard artifacts without silent false negatives | done |
| OBS-053 | P1 | Coverage | Deploy `caddy-metrics` ServiceMonitor and `caddy-alerts` PrometheusRule in dev/nonprod/prod where required | OBS-051 | monitoring manifests + runtime evidence files | kind-dev, rke2-nonprod, and production report both resources in Prometheus targets/rules and identity-stable evidence | in_progress (wiring checks now asserted by `verify-observability-runtime.sh`) |
| OBS-054 | P1 | Coverage | Deploy `mfe-metrics` ServiceMonitor and `services-alerts` PrometheusRule in dev/nonprod/prod where missing | OBS-053 | monitoring manifests + runtime evidence files | runtime coverage checks pass for both objects in all parity lanes | in_progress (script now checks for `services-alerts`) |
| OBS-055 | P1 | Coverage | Deploy `forum-metrics`, `discovery-metrics`, `ecommerce-metrics`, `credentials-metrics`, `purchase-gateway-metrics` where missing by environment | OBS-054 | monitoring manifests + namespace selectors | runtime coverage checks show all required ServiceMonitors in Prometheus targets | in_progress (checks added in runtime verifier sequence) |
| OBS-056 | P1 | Coverage | Deploy `caddy-alerts`, `slo-recording-rules`, `video-alerts`, `ora2-operations` and service-specific rule files where absent | OBS-055 | PrometheusRule resources + policy labels | `PrometheusRule` names appear in `/api/v1/rules` for all lanes with health alerts loaded | in_progress (runtime script now emits explicit `/api/v1/rules` evidence) |
| OBS-057 | P1 | Coverage | Close `xqueue-metrics` and `mux-delivery-monitor` gaps in dev lane without impacting nonprod/prod expectations | OBS-056 | environment docs + monitoring manifest deltas | kind-dev runtime coverage shows zero missing `xqueue-metrics`/`mux-delivery-monitor` | in_progress (lane-gated in runtime script) |
| OBS-058 | P0 | Reliability | Gate runtime rollout on `verify-observability-runtime.sh` passing LMS/CMS `/metrics` payload checks in all parity lanes | OBS-057 | workflow inputs and evidence folder strategy | strict runtime lane never marks pass with endpoint failures; each run generates metrics payload evidence | done |
| OBS-059 | P2 | Governance | Add a tracked evidence lane matrix for `OBSERVABILITY_*` context values (`dev/rke2-nonprod/prod`) and required auth/project overrides | OBS-058 | docs + CI matrix job config | parity workflow matrix fails fast when context/project/env mapping is invalid | done |
| OBS-060 | P2 | GA Gate | Publish `Observability GA` exception log for pending runtime gaps until all parity objects are deployed | OBS-051, OBS-059 | readiness report + decision notes | stakeholders have explicit exception list and close criteria before claiming cross-environment first-class observability | planned |

### Immediate implementation sequence

1. Run runtime validation with strict mode to reproduce expected vs actual and generate evidence artifacts after each deployment wave.
2. Execute runtime verifier sequence for `OBS-053..057` in order:
   - `caddy-metrics` + `caddy-alerts`
   - `mfe-metrics` + `services-alerts`
   - `forum/discovery/ecommerce/credentials/purchase-gateway` ServiceMonitors
   - `slo-recording-rules` + `video-alerts` + `ora2-operations`
   - dev-only `xqueue-metrics` + `mux-delivery-monitor`
3. Re-run parity matrix and close tasks as each missing object set clears.
4. Keep OBS-052 scope lock active so `video-cost`/`video-operations` stay in the appropriate local monitoring artifact path and are not treated as GCP parity failures.
5. `OBS-051` recovery artifact generated from offline plan: `docs/archive/evidence/observability/observability-monitoring-dashboard-plan-2026-02-26.md`.

### Runtime-object evidence checks (per lane)

- Execute:
  - `lane="nonprod"; OBSERVABILITY_ENV_LABEL="${lane}"; case "${lane}" in dev|nonprod) OBSERVABILITY_DISPATCH_PROFILE="nonprod"; OBSERVABILITY_K8S_CONTEXT="$OBS_PARITY_NONPROD_K8S_CONTEXT";; prod) OBSERVABILITY_DISPATCH_PROFILE="prod"; OBSERVABILITY_K8S_CONTEXT="$OBS_PARITY_PROD_K8S_CONTEXT";; esac; if [ "${lane}" = prod ] && [ -n "${OBS_PARITY_PROD_GCP_PROJECT:-}" ]; then OBSERVABILITY_GCP_PROJECT="$OBS_PARITY_PROD_GCP_PROJECT"; else OBSERVABILITY_GCP_PROJECT="${OBS_PARITY_NONPROD_GCP_PROJECT:-mereka-lms}"; fi; ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`
- Then attach these artifacts for closure review:
  - `observability-runtime-verify-runtime.md` (must include `Runtime wiring check` lines for each object)
  - `observability-first-class-runtime-evidence-index.json` (identity check must match)
  - `observability-metrics-lms-runtime.md` and `observability-metrics-cms-runtime.md` (`status_code: 200`, payload sample present)
  - Per-object evidence files:
    - `observability-caddy-prometheus-wiring-runtime.md`
    - `observability-mfe-prometheus-wiring-runtime.md`
    - `observability-forum-prometheus-wiring-runtime.md`
    - `observability-discovery-prometheus-wiring-runtime.md`
    - `observability-ecommerce-prometheus-wiring-runtime.md`
    - `observability-credentials-prometheus-wiring-runtime.md`
    - `observability-purchase-gateway-prometheus-wiring-runtime.md`
    - `observability-slo-rules-prometheus-wiring-runtime.md`
    - `observability-video-rules-prometheus-wiring-runtime.md`
    - `observability-ora2-rules-prometheus-wiring-runtime.md`
    - dev-only `observability-dev-xqueue-prometheus-wiring-runtime.md`
    - dev-only `observability-dev-mux-prometheus-wiring-runtime.md`

If a lane fails on one object:
- verify namespace scoping in `deploy/k8s/base/monitoring/kustomization.yaml`,
- validate resource name consistency in overlays for that lane,
- rerun only the targeted deployment wave and re-run the same runtime command.

## Reference for next execution sprint

For the strict, lane-safe next-wave task runbook, use:
- `reports/2026/closures/OBSERVABILITY_CLOSEOUT_QUEUE_2026-02-27.md`
