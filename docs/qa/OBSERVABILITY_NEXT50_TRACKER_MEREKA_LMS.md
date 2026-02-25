# Observability Next-50 Tracker (Mereka LMS)

Date: 2026-02-25
Owner: Mereka LMS platform team
Scope: dev/nonprod/prod observability hardening for Open edX deployment
Execution mode: Tracker-ready implementation backlog

## Status Legend

- `planned`: scoped and ready
- `in_progress`: being implemented
- `blocked`: waiting on dependency/credential/infra input
- `done`: shipped and verified

## Next 50 Tasks

| ID | Priority | Workstream | Task | Depends on | Deliverable | Definition of done | Status |
|---|---|---|---|---|---|---|---|
| OBS-001 | P0 | Parity | Wire `OBS_PARITY_DEV_K8S_CONTEXT` in GitHub variables | none | parity workflow var set | dev lane no longer skipped in scheduled parity workflow | planned |
| OBS-002 | P0 | Parity | Wire `OBS_PARITY_NONPROD_K8S_CONTEXT` in GitHub variables | none | parity workflow var set | nonprod lane no longer skipped in scheduled parity workflow | planned |
| OBS-003 | P0 | Parity | Validate `OBS_PARITY_PROD_K8S_CONTEXT` against current prod context | OBS-001 | runbook evidence | prod lane succeeds without context resolution errors | planned |
| OBS-004 | P0 | Parity | Wire `OBS_PARITY_*_GCP_PROJECT` overrides where needed | OBS-001 | variable map in workflow setup doc | parity runs use expected project per env without manual override | planned |
| OBS-005 | P0 | Parity | Enforce 3 consecutive no-skip/no-fail rollups and close PAR-001/PAR-002 | OBS-001, OBS-002 | readiness report update | three scheduled rollups pass and gaps marked closed | done |
| OBS-006 | P0 | Coverage | Audit missing ServiceMonitor coverage vs required services in each env | OBS-005 | env gap report | report lists missing/extra monitors with owners and dates | done |
| OBS-007 | P0 | Coverage | Add missing ServiceMonitors for uncovered critical workloads | OBS-006 | k8s manifests | runtime gate passes monitor presence for all critical services | done |
| OBS-008 | P0 | Coverage | Add scrape label consistency checks to validation scripts | OBS-007 | script rule updates | validation fails if required labels/selectors drift | done |
| OBS-009 | P1 | Coverage | Add monitor endpoint latency/error budget panels for all critical services | OBS-007 | dashboard contract update | dashboard audit passes with new required panels | planned |
| OBS-010 | P1 | Coverage | Add per-service metrics cardinality watchlist | OBS-007 | monitoring doc + alert rule | cardinality drift alert is present and tested | planned |
| OBS-011 | P0 | Alert quality | Wire runtime data feed for `ALERT_NOISE_RUNTIME_SOURCE` in CI | OBS-004 | workflow/env secret wiring | alert-noise runtime audit runs in strict mode in CI | done |
| OBS-012 | P0 | Alert quality | Define severity-specific noise thresholds (`critical`, `error`, `warning`) | OBS-011 | updated baseline config + strict runtime validation | baseline schema includes required severities and per-severity thresholds | done |
| OBS-013 | P1 | Alert quality | Add duplicate-alert detector by fingerprint/window | OBS-012 | script enhancement | runtime audit reports duplicate ratio by severity | done |
| OBS-014 | P1 | Alert quality | Add false-positive classification inputs contract (manual/operator label feed) | OBS-012 | contract doc + parser | runtime audit ingests classification feed without schema errors | planned |
| OBS-015 | P0 | Alert quality | Close PAR-003 via codified threshold + strict runtime evidence | OBS-011, OBS-012 | readiness report update | PAR-003 moved to closed with evidence links | done |
| OBS-016 | P0 | SLO | Define Tier-1 user journeys and owning SLI metrics | OBS-006 | SLO mapping doc | each Tier-1 journey mapped to explicit SLI query | planned |
| OBS-017 | P0 | SLO | Implement missing SLI recording rules for uncovered journeys | OBS-016 | PrometheusRule updates | recording rules present and queryable in runtime | planned |
| OBS-018 | P1 | SLO | Add burn-rate alerts for all Tier-1 journeys (multi-window) | OBS-017 | PrometheusRule updates | burn-rate alerts loaded and visible in Prometheus API | planned |
| OBS-019 | P1 | SLO | Add SLO dashboard contract section per journey | OBS-018 | dashboard contract update | audit script enforces journey SLO panels | planned |
| OBS-020 | P1 | SLO | Add SLO breach runbook links in alert annotations | OBS-018 | alert annotation updates | each SLO alert links to concrete remediation runbook | done |
| OBS-021 | P1 | Logs/errors | Enforce structured log keys for critical failure classes | OBS-006 | logging contract doc + lints | CI fails on missing required log fields in key services | planned |
| OBS-022 | P1 | Logs/errors | Expand Sentry runtime coverage matrix by service | OBS-021 | service matrix + audit rules | sentry wiring audit verifies all required services | planned |
| OBS-023 | P1 | Logs/errors | Add correlation ID propagation checks across ingress->app | OBS-021 | runtime check script | check fails when correlation headers missing | planned |
| OBS-024 | P2 | Tracing | Define minimal tracing scope for Tier-1 flows | OBS-016 | tracing ADR | tracing scope approved with sampling policy | planned |
| OBS-025 | P2 | Tracing | Pilot trace ingestion for one Tier-1 flow in nonprod | OBS-024 | nonprod tracing evidence | one flow trace appears end-to-end in selected backend | planned |
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
| OBS-044 | P1 | Governance | Add artifact retention policy matrix (CI + long-term archive) | OBS-032 | docs/operations/OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md | retention windows defined and enforceable per artifact class | done |
| OBS-045 | P1 | Governance | Add "observability release checklist" gate to deployment playbook | OBS-041 | docs/operations/RELEASE_CHECKLIST.md | release process requires observability sign-off step | done |
| OBS-046 | P1 | Ops | Add weekly parity review issue template in repo | OBS-005 | template markdown | weekly review can be opened in <2 minutes with standard fields | done |
| OBS-047 | P1 | Ops | Add incident postmortem section for observability misses | OBS-046 | postmortem template update | postmortems classify monitoring detection gap explicitly | done |
| OBS-048 | P2 | Ops | Add operator training drill for alert triage with evidence artifacts | OBS-046 | drill runbook | drill completed once per month with attendance log | done |
| OBS-049 | P2 | Ops | Add service owner ack process for new alert rules | OBS-014 | process doc | no new high-severity alert merges without owner ack | done |
| OBS-050 | P0 | Ops | Publish “Observability GA” readiness gate (exit criteria for roadmap) | OBS-005, OBS-015, OBS-020, OBS-035, OBS-041 | readiness decision doc | explicit go/no-go with objective evidence links | done |

## Execution Order Recommendation

1. P0 tasks first: `OBS-001..OBS-008`, `OBS-011`, `OBS-015..OBS-017`, `OBS-026..OBS-027`, `OBS-031..OBS-032`, `OBS-041`, `OBS-050`.
2. Then P1 tasks by workstream.
3. Then P2 optimization tasks.
