# Build Authority — Phase 2 Coordination Brief

**Status**: Draft — awaiting infra team RFC
**Date**: 2026-04-16
**Author**: LMS agent (client-side)
**Scope**: Cross-repo coordination artifact — NOT an authoritative RFC
**Authoritative follow-up**: `bbi-infrastructure/docs/adr/025-*.md` (to be written by infra team) + `bbi-infrastructure/docs/rfcs/…` if needed

---

## Why this brief exists

Phase 1 (RFC-BUILD-AUTHORITY-001 + ADR-024) delivered shared GHCR cache + webhook receiver
+ Prometheus rules. Phase 2 extends this from "works for LMS" to "works across every
namespace on the platform." This document states what remains, who owns each piece, and
what the LMS side will do when the infra-side contract lands.

This is a brief, not a plan. The platform decisions live in `bbi-infrastructure`.

---

## What Phase 1 proved

- Shared GHCR registry cache is authoritative for mereka-lms builds (ADR-024).
- Trusted-write-only policy holds: PRs read, main pushes.
- Webhook receiver (`ci-metrics-receiver` on VPS, port 9250) ingests `workflow_run` +
  `workflow_job` events, classifies runner class (`fastlane` / `arc-standard` /
  `arc-heavy`), emits Prometheus metrics.
- Prometheus scrapes the receiver (VPS observability stack).
- Grafana dashboard wired (31 panels, 6 rows).
- Blast radius validated: post-merge main build 24536619263 ran green end-to-end after
  PR #1782 fixed the emit-build-metrics path traversal bug.

Live artifacts today:
- `https://ci-metrics.mereka.dev/webhooks/github` (webhook endpoint, TLS via Cloudflare)
- `pm2 status ci-metrics-receiver` (port 9250)
- Prometheus groups: `ci-layer-metrics`, `ci-build-quantiles`, `ci-queue-quantiles`,
  `ci-scan-quantiles`, `ci-cache-health`, `ci-benchmark-class-indicators`,
  `ci-cache-alerts`, `ci-performance-alerts`, `ci-conveyor-alerts`

---

## What Phase 1 did NOT close (the debt)

### 1. Cache scope is app-local, not platform-shared

ADR-024 defines cache refs under `ghcr.io/biji-biji-initiative/mereka-lms/cache/*`. This
is correct for LMS but cannot be imported by `team-analytics`, `reka-slackbot`, or any
other app that shares base layers (Python 3.11, Node 20, Debian base, pip wheels, etc.).

Every app repays the same expensive first-layer download on every cold build. The
platform is paying N× the cost of a single cold build per base image.

**Proper fix** (infra-owned): publish shared base-layer caches at
`ghcr.io/biji-biji-initiative/platform/cache/<toolchain>-base` and teach every app's
bake file to import from `platform/cache/*` first, `<app>/cache/*` second. Define the
shared bases, their update policy, and who can push.

### 2. Cache-health metrics have no data path into Prometheus

`emit-build-metrics` composite action produces `build-metrics-<family>.json` as a
workflow artifact. That artifact never reaches Prometheus. Affected gauges stay empty:

- `ci_cache_source_found{source="registry|local|none"}`
- `ci_cache_export_success`
- `ci_layer_reuse_count` / `ci_layer_total_count` → `ci:layer_reuse_ratio`

Grafana Row 2 ("Cache Truth") and Row 4 ("Benchmark classes") render empty until this
closes. Three viable bridges (see §4 below).

### 3. Runner-class taxonomy has no platform authority

Today the receiver regex is the only source:

```
mereka-k8s-heavy*   → arc-heavy
mereka-k8s*         → arc-standard
*fastlane*          → fastlane
(anything else)     → other
```

Problems:
- Does not distinguish ARC on `rke2-nonprod` from ARC on `rke2-prod` (both currently
  collapse to `arc-standard`/`arc-heavy`).
- If infra renames an ARC scaleset, the receiver silently stops classifying correctly —
  no drift gate.
- The same taxonomy is also referenced by `docs/ops/ci-cd/BENCHMARK_CLASSES.md` for
  benchmark-class classification rules. Two sources of truth.

### 4. No Prometheus federation decision between clusters

Today: one Prometheus on VPS scrapes the receiver. Each RKE2 cluster also runs its own
Prometheus for cluster-native observability. ADR-022 covers federation strategy but
doesn't specify whether CI metrics should federate out of the VPS into the cluster
Prometheus (for SLO scoring) or stay only on VPS. Untouched in Phase 1.

### 5. No runbook / on-call surface for the receiver

`ci-metrics-receiver` is a production dependency for the build observability surface.
No one is paged if it crashes. No backup; PM2 + Infisical secret + Cloudflare tunnel is
the whole HA story.

### 6. Stale `GKE` refs across repos

Eliminate lingering "GKE" language everywhere. GKE is decommissioned. Every `*.md` /
config comment / status doc referencing GKE as live is a future-agent confusion source.

Known hits:
- `~/CLAUDE.md` line 75 — "K8s (Kind/GKE)"
- `~/.claude/CLAUDE.md` line 36 — "Kind/GKE deployments" agent description
- `vps-infrastructure/prometheus/prometheus.yml` lines 187, 197, 208
- Multiple `vps-infrastructure` docs under `docs/platform/`
- Likely more across `bbi-infrastructure` and `mereka-lms`

---

## Proposed ownership split

The platform-level decisions live in `bbi-infrastructure`. Each app repo implements its
client side.

| Workstream | Home | Owner |
|---|---|---|
| Platform cache strategy (shared bases + update policy) | `bbi-infrastructure` | infra |
| Runner-class taxonomy contract | `bbi-infrastructure` | infra |
| Webhook topology decision (1 vs 2 org webhooks) | `bbi-infrastructure` | infra |
| Prometheus federation decision for CI metrics | `bbi-infrastructure` | infra |
| ARC scaleset label alignment | `bbi-infrastructure` | infra |
| Runbook + on-call surface for receiver | `bbi-infrastructure` | infra |
| Receiver `/webhooks/build-metrics` endpoint | `vps-infrastructure` | infra |
| `emit-build-metrics` trailing-push step | `mereka-lms` | LMS agent (me) |
| LMS bake config honors shared cache layout | `mereka-lms` | LMS agent (me) |
| LMS benchmark class definitions | `mereka-lms` | LMS agent (me) |
| GKE doc cleanup per repo | each repo | respective owner |
| team-analytics: implement client side of contract | `team-analytics` | that repo's owner |

The platform decisions **block** the client-side work. LMS cannot implement shared-cache
import until the shared-cache layout exists.

---

## Webhook topology: three options for the infra RFC to pick between

| Option | Pros | Cons |
|---|---|---|
| **A. Add 2nd org webhook** pointing at `ci-metrics.mereka.dev/webhooks/github`, scoped to `workflow_run` + `workflow_job`. Leave existing `team.mereka.io` webhook alone. | Zero coupling; failures isolated; 2 secret rotations. Fastest to production. | Two payload copies delivered by GitHub. |
| **B. Relay via team-analytics** — team-analytics fans out `workflow_*` events to `ci-metrics.mereka.dev`. | Single org webhook. | CI observability now depends on team-analytics uptime. Wrong failure direction. |
| **C. Relay via ci-metrics-receiver** — receiver fans out to team-analytics for events team-analytics cares about. | Single ingestion. Receiver owns observability so less cross-contamination. | Receiver becomes dependency of productivity analytics (more consumers, more risk). |

LMS-side recommendation: **A** (two webhooks). Infra RFC should pick for real.

---

## Phase-2 metrics bridge: three options for the infra RFC to pick between

| Option | How | Pros | Cons |
|---|---|---|---|
| **α. Trailing push from workflow** | Add step at end of build job: `curl -X POST https://ci-metrics.mereka.dev/webhooks/build-metrics -d @build-metrics-<family>.json` with shared secret | Synchronous, fleet-agnostic, simple. | Another HMAC secret to rotate. |
| **β. Receiver polls GitHub Artifacts API** | On `workflow_run.completed` event, receiver downloads build-metrics artifact | Workflow doesn't need to know receiver URL. | Adds GitHub token mgmt. ~30s latency. |
| **γ. Prometheus Pushgateway** | Composite action pushes directly via StatsD/Pushgateway protocol | Native Prometheus idiom. | Pushgateway footguns: stuck metrics, no churn. Extra infra component. |

LMS-side recommendation: **α** (trailing push). Symmetrical with webhook architecture,
shortest code path, no new infra. Infra RFC should pick for real.

---

## LMS-side implementation plan (client epic, dependent)

These do not start until infra RFC freezes:

1. `mereka-lms-jj98.1` — consume runner-class taxonomy contract (add label registry import)
2. `mereka-lms-jj98.2` — update bake files to import from `platform/cache/*` (if Option exists)
3. `mereka-lms-jj98.3` — add trailing `/webhooks/build-metrics` push step to
   `build-tutor-images.yml` (if Option α chosen)
4. `mereka-lms-jj98.4` — add CI drift gate: fail build-workflow-contract verifier if
   local runner-class regex diverges from upstream taxonomy
5. `mereka-lms-jj98.5` — purge stale GKE references in mereka-lms docs

---

## Coordination artifact

This brief is intentionally in `mereka-lms/docs/status/active/` for visibility. The
authoritative platform follow-up (ADR-025 or equivalent) must land in
`bbi-infrastructure`. When it does, amend this brief with a link + supersede notice.

Agent-mail notification to infra lane is attached to the PR that introduces this brief.

---

## Appendix — verified Phase 1 state snapshot (2026-04-16)

Historical snapshot only. This appendix records what was proved on
2026-04-16; it is not the current live-health authority for
`ci-metrics-receiver`, Prometheus scrape status, or Grafana data freshness.
Use [`CURRENT-OPERATOR-STATE.md`](./CURRENT-OPERATOR-STATE.md) plus live infra
checks for present-tense status.

- PR mereka-lms#1779 merged (Build Authority foundation)
- PR mereka-lms#1782 merged (emit-build-metrics path fix — post-merge blocker)
- PR vps-infrastructure#107 merged (ci-metrics-receiver + Prometheus rules + Grafana)
- PR vps-infrastructure#108 merged (wire rules + scrape target into prometheus.yml)
- PR vps-infrastructure#109 open (start.sh launcher + Caddy block) — ready to merge
- Main build 24536619263 on commit 8a4edd9c: 11 success / 3 skipped / 0 fail
- `curl -sf https://ci-metrics.mereka.dev/health` → `{"status":"ok"}`
- Prometheus scrape target `ci-metrics-receiver` → `health=up`
