# Investigation: mereka-lms HPA Restoration in Prod

**Date:** 2026-04-22
**Worktree:** `.worktrees/mereka-planning-2026-04-22`
**Related bead:** `mereka-lms-negx` (P2, open) — was under-scoped as a metrics-server bug; actual cause is narrower.

## Problem

Prod `mereka-lms` namespace has **zero HorizontalPodAutoscalers**. `kubectl get hpa -n mereka-lms` → `No resources found`. All workloads run at fixed replicas regardless of load.

## Evidence (verified)

- `kubectl --context rke2-prod get hpa -A` lists **8 working HPAs** in other namespaces (agent-e, authentik, backstage, calcom-prod, reka-slackbot, zoom-rtms) with live CPU/memory metrics rendering.
- `rke2-metrics-server-5884bffb74-*` pods are **Running** in `kube-system` with APIService `v1beta1.metrics.k8s.io` registered + `True`. One replica has 8 graceful restarts (Exit 0 Completed), no crash loop.
- App-repo base defines HPAs:
  - `deploy/k8s/base/apps/lms/hpa.yaml`
  - `deploy/k8s/base/apps/cms/hpa.yaml`
  - `deploy/k8s/base/apps/purchase-gateway/hpa.yaml`
  - `deploy/k8s/base/operational/hpa-baselines.yaml` (lms-worker, cms-worker)
- `bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/` contains **9 `remove-*-hpa.yaml`** `$patch: delete` files:
  - `remove-lms-hpa.yaml`, `remove-cms-hpa.yaml`, `remove-lms-worker-hpa.yaml`, `remove-cms-worker-hpa.yaml`
  - `remove-enterprise-access-hpa.yaml`, `remove-enterprise-catalog-hpa.yaml`, `remove-enterprise-subsidy-hpa.yaml`, `remove-license-manager-hpa.yaml`
  - `remove-payments-gateway-hpa.yaml`
- Kustomization comment claims: `# Prod RKE2 does not use HPAs (no HPA controller). Remove to prevent Argo drift.`

**That comment is wrong today.** Metrics-server is live, HPAs work for other workloads, APIService is registered.

## Root cause

Git blame identified the origin:

> Commit `2c3af486d` (2026-03-31, 3 weeks ago): *"fix: complete LMS prod hibernation — zero all services, remove HPAs, fix CronJob policy (#2242)"*

During a planned prod **hibernation**, mereka-lms replicas were scaled to 0. HPAs were removed at the same time because an HPA with `minReplicas: 2` fights a manual scale-to-0. The "no HPA controller" comment was a drive-by rationalization of the removal — **not a platform fact**.

Since then, prod has been **unhibernated** — pods are back to normal replica counts — but the HPAs never got restored. The comment + delete-patches stayed in place. Two signals this is drift:

1. Staging overlay on the **same RKE2 cluster** (nonprod) has 15+ working HPAs including staging's own `mereka-lms` HPAs (verified: `kubectl get hpa -n stg-mereka-lms`).
2. Other prod namespaces on the same cluster have functioning HPAs right now with live metrics.

## Scope — what needs restoration

All 9 HPAs deleted by the prod overlay. App-repo base already defines:

| Workload | Base file | Current replicas | Suggested min/max |
|---|---|---|---|
| lms | `apps/lms/hpa.yaml` | 2 | 2/4 (inherit base) |
| cms | `apps/cms/hpa.yaml` | 1 | 2/4 (review base value) |
| lms-worker | `operational/hpa-baselines.yaml` | 1 | 1/3 |
| cms-worker | `operational/hpa-baselines.yaml` | 1 | 1/2 |
| enterprise-access | (search in base) | 1 | 1/3 (match dev) |
| enterprise-catalog | (search in base) | 1 | 1/3 |
| enterprise-subsidy | (search in base) | 1 | 1/3 |
| license-manager | (search in base) | 1 | 1/3 |
| payments-gateway | `apps/purchase-gateway/hpa.yaml` | 1 | 1/3 |

Dev/staging already run with these HPAs — they're proven values; this is restoration, not new design.

## Minor secondary finding — wk-03 metrics gap

`kubectl top nodes` returns `<unknown>` for `mereka-p-wk-03-sin`. Other nodes render correctly. rke2-metrics-server has had 8 graceful restarts on one replica. Possibly a pod-to-node kubelet scrape issue on that one node. Not blocking HPA restoration but file a P3 follow-up.

## Solution

**One PR to `bbi-infrastructure`:** delete the 9 `remove-*-hpa.yaml` patches + remove their `kustomization.yaml` references + update the outdated comment to reflect reality.

- Not "new work" — just reverting stale hibernation debt.
- Pre-merge validation: `kustomize build bbi-infrastructure/apps/mereka-lms/overlays/prod | grep -c "kind: HorizontalPodAutoscaler"` should return **9**.
- Post-merge validation: after ArgoCD sync, `kubectl get hpa -n mereka-lms` shows all 9 with `ACTIVE`/Ready status within 2 minutes.
- **This work is outside my lane** — touches infra repo. Bead documents it; execution belongs to infra agent.

## Acceptance criteria

- [ ] All 9 HPAs synced and visible in `kubectl get hpa -n mereka-lms`.
- [ ] None reports `unknown` targets (all get metrics from metrics-server).
- [ ] Each deployment's current replica count stays within `[minReplicas, maxReplicas]` for its HPA (no thrash on sync).
- [ ] Comment in `bbi-infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml` is accurate or removed.
- [ ] P3 follow-up bead filed for wk-03 metrics gap.
- [ ] (Optional but recommended) Add an alert `MerekaLmsHpaAbsent` that fires if the HPA count drops below 9 — prevents silent re-removal.

## Proposed beads

**Parent — P2 — task**
> Restore mereka-lms HPAs in prod overlay (post-hibernation cleanup)
>
> Body: 9 HPAs were removed during the 2026-03-31 prod hibernation (commit `2c3af486d`) and never restored post-unhibernation. The justification comment ("no HPA controller") is stale — metrics-server is live and other prod namespaces have working HPAs. Scope is a single bbi-infrastructure PR removing the 9 `remove-*-hpa.yaml` patches.
>
> Supersedes: `mereka-lms-negx` (same issue, re-scoped). Close negx and link here.

**Child .1 — P2 — task**
> Delete 9 `remove-*-hpa.yaml` patches from prod overlay + update stale comment
>
> Files: `bbi-infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml` (lines 124-133 + patch files). Pre-merge: kustomize build shows 9 HPAs. Post-merge: kubectl confirms all 9 ACTIVE.
> Lane: infra (not app). Coordinate with infra agent.

**Child .2 — P3 — task**
> Investigate wk-03 metrics-server scrape gap
>
> `kubectl top nodes` returns `<unknown>` for `mereka-p-wk-03-sin`. Other nodes render. Probably kubelet scrape config or firewall. Not urgent but causes HPA false-negatives for pods that schedule there.

**Child .3 — P3 — task**
> Add alert `MerekaLmsHpaAbsent` (prevent silent re-removal)
>
> Expression: `count(kube_horizontalpodautoscaler_info{namespace="mereka-lms"}) < 9`. Placement: `deploy/k8s/base/monitoring/`. Severity: warning. Rationale: we lost 9 HPAs for 3+ weeks with no alert; don't let that happen twice.

## Open questions

1. Does the lms HPA `minReplicas: 2` conflict with any prod `replicas: 1` patch? Need to reconcile before PR.
2. Should we keep cms `min: 1` to save prod resources, or promote to 2 to match redundancy with lms?
3. Are the enterprise service HPAs actually defined in base? (Agent claimed yes but didn't produce paths for all.) Needs a quick grep before the restoration PR.
