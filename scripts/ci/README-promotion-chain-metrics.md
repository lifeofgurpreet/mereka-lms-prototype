# Promotion Chain Metrics — Operator Guide

_Bead: mereka-lms-lb4c.6 | Subsystem: S6.1 | Owner: platform-team_

This document describes the S6.1 promotion-chain observability system: what it
measures, which workflows emit each stage, how to interpret missing stages, and
how to re-run the collector manually.

---

## The 6 Stages (in order)

| # | Stage | Description |
|---|-------|-------------|
| 1 | `app_merge` | A commit was merged to `main` on the app repo. The promotion conveyor begins here. |
| 2 | `bbi_pr_opened` | A promotion PR was opened on `bbi-infrastructure` carrying the new image digest. |
| 3 | `bbi_pr_merged` | The promotion PR was merged to `bbi-infrastructure/main`. |
| 4 | `argo_sync_started` | ArgoCD began reconciling the new revision (operationState.phase = Running). |
| 5 | `argo_sync_finished` | ArgoCD sync completed (phase = Succeeded, sync.status = Synced). |
| 6 | `pod_image_realized` | Live pods were verified to be running the expected image digest. |

**End-to-end latency** is measured from `app_merge` (stage 1) to `pod_image_realized`
(stage 6).  A healthy conveyor should complete in under 90 minutes; a warm-cache
build path typically completes in 30–45 minutes.

---

## Which Workflow Emits Each Stage

| Stage | Repo | Workflow / PR |
|-------|------|---------------|
| `app_merge` | mereka-lms | `build-tutor-images.yml` (PR #1828) |
| `bbi_pr_opened` | mereka-lms | `build-tutor-images.yml` (PR #1832) |
| `bbi_pr_merged` | bbi-infrastructure | infra-repo listener (PR #3279) |
| `argo_sync_started` | mereka-lms | `argo-sync-chain-watcher.yml` (PR #1834) |
| `argo_sync_finished` | mereka-lms | `argo-sync-chain-watcher.yml` (PR #1834) |
| `pod_image_realized` | mereka-lms | `pod-image-verify.yml` (PR #1833) |

Each emitter calls `scripts/ci/emit-promotion-chain-metrics.sh` with the
appropriate `--stage` flag and uploads a JSONL artifact named
`promotion-chain-metrics-<source>-<run_id>`.

---

## How to Interpret Missing Stages

**Missing stages are NOT approximated.**  The collector (`collect-promotion-chain-metrics.py`)
displays `missing` in any cell where a stage was not observed.  This is the
primary signal for diagnosing conveyor stalls.

### Common patterns

| Stall Pattern | What it means |
|---------------|---------------|
| `all-present` | Full conveyor completed successfully. |
| `stalled-after-app_merge` | The dispatch chain never opened a BBI PR.  Check `build-tutor-images.yml` dispatch step and `GITHUB_APP` permissions. |
| `stalled-after-bbi_pr_opened` | BBI PR opened but was never merged.  Check PR #3279 listener or auto-merge configuration. |
| `stalled-after-bbi_pr_merged` | Argo did not pick up the merge.  Check ArgoCD sync interval or manual sync required (prod). |
| `stalled-after-argo_sync_started` | Argo sync started but did not complete.  Check for Argo sync errors (`kubectl get application -n argocd`). |
| `stalled-after-argo_sync_finished` | Argo synced but pod image was never verified.  Check `verify-pods-on-digest.sh` and whether the watcher triggered. |

### Partial rows are valuable

A row with only `app_merge` + `bbi_pr_opened` tells you the first two stages
ran and the chain stalled at stage 3.  These partial rows are **always included**
in the output — do not treat them as noise.

### Production always requires manual sync

`mereka-lms-prod` has no `automated` syncPolicy in ArgoCD.  For production
promotions, `argo_sync_started` and `argo_sync_finished` will only be present if
the ArgoCD sync watcher was manually dispatched (`workflow_dispatch` on
`argo-sync-chain-watcher.yml`).  Absence of these stages on a production
release_unit_id is expected, not a bug.

---

## How to Re-run the Collector Manually

### Via GitHub Actions UI

1. Open **Actions → Promotion Chain Collector** in the mereka-lms repo.
2. Click **Run workflow**.
3. Set `since_days` to your desired lookback window (default: 7).
4. Click **Run workflow**.
5. The markdown summary will appear in the workflow step summary.
6. Both `promotion-chain-summary-<run_id>.md` and `.json` are uploaded as
   artifacts with 30-day retention.

### Via CLI

```bash
# Collect last 14 days, output to markdown
python3 scripts/ci/collect-promotion-chain-metrics.py \
    --since-days 14 \
    --repo Biji-Biji-Initiative/mereka-lms \
    --infra-repo Biji-Biji-Initiative/bbi-infrastructure \
    --output /tmp/promotion-chain-summary.md \
    --format markdown

# Same but JSON for machine consumption
python3 scripts/ci/collect-promotion-chain-metrics.py \
    --since-days 14 \
    --output /tmp/promotion-chain-summary.json \
    --format json
```

**Requirements:** `gh` CLI authenticated to both repos.  No other dependencies —
the script uses Python 3 stdlib only.

### Dispatching a single-stage emit (for testing)

```bash
bash scripts/ci/emit-promotion-chain-metrics.sh \
    --stage app_merge \
    --release-unit-id "$(git rev-parse HEAD)" \
    --out-dir /tmp/test-metrics
```

The JSONL file will be written to `/tmp/test-metrics/promotion-chain-<sha>.jsonl`.

---

## Artifact Schema

Each JSONL line written by `emit-promotion-chain-metrics.sh` follows schema
`promotion-chain/v1`:

```json
{
  "schema_version": "promotion-chain/v1",
  "stage": "app_merge",
  "release_unit_id": "<commit-sha-or-promotion-tag>",
  "timestamp_utc": "2026-04-18T02:37:00.000Z",
  "epoch_ms": 1713403020000,
  "workflow_run_id": "12345678",
  "bbi_pr_number": 3279
}
```

Fields `workflow_run_id` and `bbi_pr_number` are omitted when not applicable.

---

## Design Principles

1. **No approximation of missing stages** — absence is truth.  A missing stage
   cell is the operational signal you are looking for.
2. **Partial rows are first-class data** — a release that stalled at stage 2 is
   as important to show as a release that completed all 6 stages.
3. **`continue-on-error: true` on all observability steps** — the collector
   never gates real work (Doctrine Rule 4).
4. **Exits 0 always** — missing artifacts are not errors, they are the data.

---

## Doctrine Reference

[Truth Repair Doctrine](../../../docs/meta/standing-orders/) — **Rule 1**:
_Surface truth, do not approximate.  A gap in the evidence chain is more
valuable than a guess that hides the gap._
