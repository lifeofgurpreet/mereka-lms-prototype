---
title: Observability Stack World-Class Audit — Mereka LMS
date: 2026-04-20
author: Agent 1 (operator loop) + 4 parallel research agents
scope: Sentry + Prometheus/Grafana + Logs/Tracing/SLO + Synthetic/Uptime
inputs:
  - agent a221071f2924a73b6 — Sentry cross-env wiring audit
  - agent a699e3116767beb70 — Prometheus + Grafana stack audit
  - agent a493973ffe59c8996 — Logging + tracing + SLO observability audit
  - agent abdd22bc3833db468 — Synthetic monitoring + uptime checks audit
status: audit-complete; bead filing pending
---

# Observability Stack Audit — Mereka LMS (2026-04-20)

## Overall Verdict

**Partial-world-class.** Internals (metrics, SLOs, log aggregation) are production-grade.
Edges (client-side errors, synthetic journeys, redirect-chain probing, prod verification)
have gaps that would let a real user-facing outage go silent.

Concrete exhibit: the in-flight `getMerekaShellCopy` Authn MFE crash (RCB-10 successor,
PR #1906) would not have paged anyone. No client-side Sentry in the MFE bundle, no
browser-based synthetic on the login flow, `/healthz` and Blackbox still green.

## Scorecard (consolidated)

| Pillar | Grade | Notes |
|---|---|---|
| Server-side Sentry (Django/workers) | World-class | Tutor plugin wires 7 services; DSN per env; PII scrubbed; allowlist enforced |
| Client-side Sentry (MFEs) | **Gap (P1)** | Authn/Learning bundles have NO SDK. Confirmed via `grep SENTRY_DSN /openedx/dist/authn/*.js` = empty |
| Prometheus scrape topology | World-class | 18 ServiceMonitors, 13 PrometheusRules, kube-prometheus-stack live |
| SLO math & burn-rate alerting | World-class | Google SRE multi-window (5m/30m/1h/6h), Tier 1/2/3, journey-level SLIs |
| Loki log aggregation | World-class | Promtail DaemonSet v2.9.6, 30d retention, JSON pipeline, PII masking |
| Distributed tracing | Partial (pilot) | Tempo deployed but ADR-020 defers prod rollout to Phase 2. No OTEL middleware in plugin |
| Structured logging uptake | **Gap (P1)** | AC-LOG-004 claims Django emits JSON; no evidence plugin configures JSON formatter |
| Synthetic browser tests | **Gap (P1)** | `smoke-authenticated.yml` runs every 6h only. Authn MFE smoke is manual-only |
| External uptime | **Gap (P1)** | Upptime config exists at `~/infrastructure/upptime` but NOT deployed for prod LMS domains |
| Blackbox content validation | Partial | Status-code probes only; would miss Caddy "200-but-502-body" |
| Cross-subdomain OAuth chain probe | **Gap (P1)** | No end-to-end monitor of Studio→LMS→Authentik→back |
| Alertmanager routing | Partial | Rules exist; no verified smoke test from rule fire → Slack/PagerDuty |
| Production observability labels | **Gap (stale)** | Promtail still labels `environment: gke-production`; GKE decommissioned |
| ArgoCD prod sync drift alerting | Gap | Prod is manual-sync by policy; no alert if `OutOfSync` > 30 min |

## Critical Gaps (would hide a real incident)

### P1-A. MFE bundles ship without Sentry SDK
- Evidence: `kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/mfe -- sh -c 'grep -l "SENTRY_DSN" /openedx/dist/authn/*.js'` returns empty.
- Impact: the exact class of bug currently gating runtime proof (`getMerekaShellCopy`
  ReferenceError from PR #1906) would produce a blank white screen with zero alerts.
  Server logs show 200 OK; no exception flows to Sentry.
- Fix: inject `@sentry/browser` into MFE common config, DSN per env via MFE_CONFIG.

### P1-B. Structured JSON logging claim is unverified
- Evidence: `grep -rln "JSONFormatter\|python-json-logger" infrastructure/tutor/plugins/_mereka_lms/` — zero hits.
- Impact: Promtail's JSON-extract pipeline silently no-ops on free-text logs. Fields
  `request_id`, `trace_id`, `level` never populate — all the correlation promises
  downstream break without visible failure.
- Fix: add Tutor plugin hook that installs `python-json-logger` and rewrites `LOGGING_CONFIG`.

### P1-C. No browser synthetic on login flow
- Evidence: only `smoke-authenticated.yml` scheduled, every 6h; `smoke-authn-mfe.yml`
  is `workflow_dispatch` only.
- Impact: a broken login takes up to 6h to detect. `getMerekaShellCopy` would go undetected.
- Fix: cron `smoke-authn-mfe.yml` every 5m against dev + every 15m against prod;
  assert specific DOM: "Sign in with Mereka" button present, post-login dashboard has `[data-testid="learner-dashboard"]`.

### P1-D. Production LMS domains missing from Upptime
- Evidence: `~/infrastructure/upptime/.upptimerc.yml` tracks VPS dev apps only;
  `academyv2.mereka.io`, `studio.academyv2.mereka.io`, `apps.academyv2.mereka.io` not present.
- Impact: external internet would not detect a prod LMS outage.
- Fix: add prod LMS endpoints to upptimerc, deploy, point status.mereka.dev at it.

### P1-E. Authentik availability not probed from outside cluster
- Evidence: Blackbox Exporter has TCP probes for MongoDB Atlas, HTTP probes for
  in-cluster `/healthz`; no probe against `auth0.mereka.io` / `auth0.mereka.dev` externally.
- Impact: Authentik pod OOMKills → in-cluster LMS `/healthz` still green → all
  logins silently fail → no alerts fire.
- Fix: Blackbox `http_2xx` module against Authentik well-known OIDC discovery URL.

### P1-F. Production config labels stale after GKE decommissioning
- Evidence: `promtail-configmap.yaml` line 121-122 has `environment: gke-production`.
- Impact: Grafana filters and alert routing keyed on `environment` label miss prod
  data or route to dead dashboards.
- Fix: rename to `rke2-production` in overlay; verify bbi-infrastructure mirror.

## Additional Gaps (would extend MTTR)

- Alertmanager has no `inhibition_rules` → LMS outage triggers duplicate MFE P1 page.
- No SLO for enterprise services (catalog, subsidy, access), notes, credentials, discovery, xqueue.
- No long-term metrics storage (Thanos / GCS remote-write); SLO math uses `[30d]` windows;
  after day 31, historical budgets vanish.
- Purchase Gateway webhook SLO measures handler response time, not Stripe event receipt — silent delivery failures invisible.
- No error-budget policy document (what happens at 25%? 0%? deployment freeze?).

## Strengths Worth Preserving

- **SLI recording rules are mathematically sound** — availability = (total - 5xx) / (total - 4xx),
  burn-rate per Google SRE. Do not rewrite; extend.
- **Journey-level SLOs already exist** for login, course-access, CMS authoring,
  purchase checkout/webhook. Add enterprise services to this pattern.
- **Loki retention + PII masking + structured-pipeline stages** are all correctly
  configured at the scrape layer. Only gap is the Django side not emitting JSON.
- **Post-deploy smoke tests via `smoke-authenticated.yml`** use real canary users,
  not synthetic fakes. Pattern is good; just needs higher frequency and broader coverage.
- **Prometheus scrape topology** (18 ServiceMonitors, 13 PrometheusRules) is comprehensive
  and covers MySQL/Redis saturation, PVC usage, cert-manager, Velero, kube-state-metrics.

## Bead Roster to File

Priority mapping: P0 = file and work this week; P1 = file and schedule in next 2 sprints; P2 = file, defer to backlog review.

| Bead | Title | Priority | Owner | Source agent |
|---|---|---|---|---|
| OBS-001 | MFE client-side Sentry SDK + DSN injection | **P0** | Frontend + Platform | Sentry audit |
| OBS-002 | Structured JSON logging in Django via Tutor plugin | **P0** | LMS + Platform | Logs audit |
| OBS-003 | Browser synthetic on Authn MFE login flow (5-min cron) | **P0** | QA | Synthetic audit |
| OBS-004 | Deploy Upptime for prod LMS domains | **P0** | Platform/SRE | Synthetic audit |
| OBS-005 | Blackbox probe for Authentik OIDC discovery URL | **P0** | Platform/Auth | Synthetic audit |
| OBS-006 | Rename stale `environment: gke-production` labels → `rke2-production` | **P0** | Platform | Logs audit |
| OBS-007 | Sentry event-ingestion synthetic test (trigger + verify) | P1 | Platform Eng | Logs audit |
| OBS-008 | Alertmanager grouping + inhibition rules | P1 | Platform | Logs audit |
| OBS-009 | Blackbox content validation (regex body match on login page) | P1 | Platform/QA | Synthetic audit |
| OBS-010 | End-to-end OAuth redirect chain probe (custom Playwright) | P1 | QA + Auth | Synthetic audit |
| OBS-011 | ArgoCD prod OutOfSync alerting (>30 min) | P1 | Platform/GitOps | Synthetic audit |
| OBS-012 | django-prometheus live verification on prod (assumption audit) | P1 | Platform | Prom audit |
| OBS-013 | Alertmanager routing destination smoke test | P1 | Platform | Prom audit |
| OBS-014 | Enable Caddy metrics ServiceMonitor | P1 | Platform | Prom audit |
| OBS-015 | Forum metrics SLI validation | P1 | Platform | Prom audit |
| OBS-016 | Phase 2 distributed tracing rollout to prod | P2 | Platform Eng | Logs audit |
| OBS-017 | SLOs for notes, credentials, discovery, enterprise services | P2 | Service owners | Logs audit |
| OBS-018 | Long-term metrics remote-write (Thanos / GCS) | P2 | Platform Eng | Logs audit |
| OBS-019 | Purchase Gateway webhook receipt-confirmation SLO | P2 | Purchase Gateway | Logs audit |
| OBS-020 | Error-budget policy document (deployment restrictions per budget state) | P2 | Product Eng | Logs audit |
| OBS-021 | Canary Kubernetes CronJob running Playwright every 5 min | P2 | QA | Synthetic audit |
| OBS-022 | Unify alert routing (Upptime + Prometheus + Sentry → one channel) | P2 | Platform | Synthetic audit |

## "What Would We Miss" Scenarios (from agent 4)

1. **Caddy returns 200 with error body** — all monitoring silent; only 6-hour smoke catches it. OBS-009 closes.
2. **Authentik pod down, in-cluster health green** — LMS redirects to a dead auth0. OBS-005 closes.
3. **MFE shell JS crash (current `getMerekaShellCopy`)** — blank screen, server-side silent. OBS-001 + OBS-003 close.
4. **MongoDB Atlas IP whitelist mismatch** — Blackbox TCP catches it; routing to Slack unverified. OBS-013 closes.
5. **Studio SSO redirect loop** — Blackbox can't detect loops; only browser probe catches. OBS-010 closes.

## Linked Artifacts

- PR #1906 (MFE `getMerekaShellCopy` fix) — in flight at audit time; illustrates the gap.
- MEMORY key: `rcb-10-mfe-error-boundary.md` — prior regression same class.
- Specs: `specs/observability-stack_spec.md`, `docs/reference/operations/LOGGING_AND_SENTRY.md`, `docs/adr/020-TRACING_PILOT_DECISION.md`.
- Agent outputs (large, preserved on disk):
  - `/tmp/claude-1001/-home-gurpreet-projects-k8s-mereka-lms/f5a0c55e-2b00-4721-a1e2-fff9b00e5f4c/tasks/a221071f2924a73b6.output`
  - `/tmp/claude-1001/-home-gurpreet-projects-k8s-mereka-lms/f5a0c55e-2b00-4721-a1e2-fff9b00e5f4c/tasks/a699e3116767beb70.output`
  - `/tmp/claude-1001/-home-gurpreet-projects-k8s-mereka-lms/f5a0c55e-2b00-4721-a1e2-fff9b00e5f4c/tasks/a493973ffe59c8996.output`
  - `/tmp/claude-1001/-home-gurpreet-projects-k8s-mereka-lms/f5a0c55e-2b00-4721-a1e2-fff9b00e5f4c/tasks/abdd22bc3833db468.output`

## Immediate Actions This Loop

1. Ship this evidence doc as a PR (no code changes; docs-only; uses CI deny-list).
2. File beads OBS-001 through OBS-006 (all P0) once tracker SQLite is repaired or using JSONL fallback.
3. Update `docs/status/active/CURRENT-OPERATOR-STATE.md` with audit-complete milestone + P0 bead pointer.
4. Continue monitoring PR #1906 build (in-flight); once landed and rolled out, manually verify MFE runtime via `kubectl exec deploy/mfe -- grep -rln getMerekaShellCopy /openedx/dist/authn/`.
