# Migration Jobs

> **IMPORTANT**: The one-shot migration Jobs in this directory are intentionally
> excluded from `deploy/k8s/base/kustomization.yaml`.  They must be applied
> manually during releases — **not** via `kubectl apply -k` or ArgoCD sync.
>
> Reason: Kubernetes Jobs are immutable once created.  Re-applying a completed Job
> via kustomize/ArgoCD fails with `field is immutable`, breaking every sync after
> the first run.  The `discovery-sync-cronjob.yaml` **is** included in kustomize
> because it is a CronJob (recurring), not a one-shot Job.

This directory contains one-shot database migration Jobs for every service that
manages a schema.  Jobs run to completion once; they are NOT run on pod startup.

## Why Jobs instead of initContainers

Running `manage.py migrate` as a Deployment initContainer causes three problems:

1. **Every pod restart re-runs migrations** — even when nothing changed.
2. **Multiple replicas race** — two pods starting simultaneously both try to
   apply the same migration, one will lose with a table-already-exists error.
3. **Migration failures crash pods** — the Deployment enters CrashLoopBackOff
   rather than failing the release cleanly.

A Kubernetes Job fails the release at the right moment (before Pods start),
runs exactly once per release, and produces a clear success/failure signal.

## Correct release sequence

```bash
# 1. Apply the migration Job for each affected service
kubectl apply -f deploy/k8s/base/jobs/enterprise-catalog-migrate.yaml -n mereka-lms

# 2. Wait for the Job to complete (fails fast on error — no || true)
kubectl wait --for=condition=complete \
  job/enterprise-catalog-migrate \
  -n mereka-lms \
  --timeout=300s

# 3. Roll out the updated Deployment
kubectl apply -k deploy/k8s/overlays/production   # or the relevant overlay
```

For a full release involving all enterprise services:

```bash
for svc in enterprise-catalog enterprise-access enterprise-subsidy license-manager; do
  kubectl apply -f deploy/k8s/base/jobs/${svc}-migrate.yaml -n mereka-lms
  kubectl wait --for=condition=complete job/${svc}-migrate -n mereka-lms --timeout=300s
done
kubectl apply -k deploy/k8s/overlays/production
```

## Jobs in this directory

| File | Service | Settings module |
|------|---------|-----------------|
| `lms-migrate.yaml` | lms | `lms.envs.tutor.production` |
| `cms-migrate.yaml` | cms | `cms.envs.tutor.production` |
| `enterprise-catalog-migrate.yaml` | enterprise-catalog | `enterprise_catalog.settings.production` |
| `enterprise-access-migrate.yaml` | enterprise-access | `enterprise_access.settings.production` |
| `enterprise-subsidy-migrate.yaml` | enterprise-subsidy | `enterprise_subsidy.settings.production` |
| `license-manager-migrate.yaml` | license-manager | `license_manager.settings.production` |
| `discovery-sync-cronjob.yaml` | discovery | Scheduled catalog sync (CronJob, not a migration) |

## Job design notes

- `restartPolicy: Never` — a failed container is not retried within the same Pod;
  Kubernetes creates a new Pod up to `backoffLimit: 3` times instead.
- `backoffLimit: 3` — three retries before the Job is marked Failed.
- `ttlSecondsAfterFinished: 86400` — completed Jobs are cleaned up after 24 hours.
- Each Job uses the **same image** as its corresponding Deployment.  When
  overlays pin image tags (e.g. `rke2-nonprod`), the kustomize image transformer
  rewrites the Job image alongside the Deployment image automatically.
- Migration Jobs are **not** part of the ArgoCD auto-sync wave.  Apply them
  manually before triggering a Deployment rollout.
