# Durable Mutation Ledger — Agent 1 VNext

_Owner: Agent 1. Created: 2026-04-10. Status: active_

This ledger records every manual cluster mutation, bootstrap replay, and
operational intervention executed during the Agent 1 VNext session(s),
with the corresponding durable git trace and current status.

A mutation is "durable" when the same state would be produced by a clean
GitOps reconcile from main — i.e., the source of truth reflects the
runtime. Mutations that only exist in the live cluster are flagged
**TRANSIENT** until a commit captures them.

## Format

| When | What | Where | Git trace | Durable? |
|------|------|-------|-----------|----------|

## Ledger

| When | What | Where | Git trace | Durable? |
|------|------|-------|-----------|----------|
| 2026-04-09 11:31Z | `apply-multisite-config.sh --apply` on prod (RCB-01 fix) — added 9 missing MFE_CONFIG keys for biji-biji + SOF SiteConfiguration | `rke2-prod / mereka-lms` | Replay path is the canonical script. Source definitions are in `infrastructure/tutor/multisite-sites.yml`. | YES — replay is idempotent from source |
| 2026-04-09 12:18Z | Manual trigger: `kubectl create job --from=cronjob/tenant-isolation-nightly` on prod (verification) | `rke2-prod / mereka-lms` | N/A — test trigger, not a mutation | N/A |
| 2026-04-09 ~12:00Z | `kubectl uncordon mereka-np-k8s-cp-01-sin1` to unblock staging pod scheduling | `rke2-nonprod` (control plane node) | **NOT IN GIT** — node state is imperative | **TRANSIENT**: re-cordon would break staging scheduling again |
| 2026-04-09 ~12:15Z | `kubectl rollout restart deploy/caddy` on staging to clear stale CNI state after cp-01 uncordon | `rke2-nonprod / stg-mereka-lms` | N/A — rollout restart is idempotent, no state change | DURABLE by nature (no spec change) |
| 2026-04-09 14:22Z | Second `apply-multisite-config.sh --apply` on prod (brand colors + SITE_NAME + logo subpath) | `rke2-prod / mereka-lms` | Source in mereka-lms PR #1498 (merged). Replay is canonical. | YES — replay from source produces same state |
| 2026-04-09 ~15:00Z | `kubectl delete pod --force` on 3 stale staging pods (lms-worker x2, notes x1) | `rke2-nonprod / stg-mereka-lms` | N/A — deletion of stuck Terminating pods; controllers recreated them. | DURABLE by nature |
| 2026-04-09 ~16:00Z | Emergency `kubectl patch deploy mfe,enterprise-admin-portal,enterprise-learner-portal --type json -p '[{"op":"add","path":"/spec/template/spec/imagePullSecrets",...}]'` on prod to unblock ImagePullBackOff | `rke2-prod / mereka-lms` | **Durable fix**: bbi-infrastructure PR #2598 adds `imagePullSecrets` to the default ServiceAccount in prod overlay. Subsequent ArgoCD sync replaces the deploy-level patch with the SA-level approach. | YES — source fix merged before session end |
| 2026-04-10 00:04Z | `kubectl set image deploy/enterprise-access enterprise-access=...:main-20260311@sha256:e2eb4121...` on dev | `rke2-nonprod / mereka-lms-dev` | **Durable fix**: bbi-infrastructure PR #2609 sets `main-20260311` in all three overlay kustomization.yaml files. ArgoCD reconciles on next sync. | YES |
| 2026-04-10 00:06Z | Same image set on prod enterprise-access + enterprise-access-worker | `rke2-prod / mereka-lms` | Same PR #2609 | YES |

## Sync Drift Check

Commands to verify runtime matches source at session end:

```bash
# Prod
kubectl --context rke2-prod get app mereka-lms-prod -n argocd \
  -o jsonpath='{.status.sync.status}'

# Dev
kubectl --context rke2-nonprod get app mereka-lms-dev -n argocd \
  -o jsonpath='{.status.sync.status}'

# Staging
kubectl --context rke2-nonprod get app mereka-lms-staging -n argocd \
  -o jsonpath='{.status.sync.status}'
```

If any shows `OutOfSync`, run `scripts/qa/verify-deployment-lanes.sh` to
identify which specific resource has drifted.

## Rules for Adding to This Ledger

1. Every `kubectl patch/set/edit/delete/uncordon` against a cluster MUST
   be logged here.
2. Every bootstrap replay (apply-multisite-config, bootstrap-enterprise-tenants)
   MUST be logged — they mutate DB state.
3. Every live image promotion (`kubectl set image`) MUST be logged along
   with the bbi-infrastructure PR that captures the same tag in git.
4. If the durable column is NO, raise an issue to make it YES before
   ending the session.
