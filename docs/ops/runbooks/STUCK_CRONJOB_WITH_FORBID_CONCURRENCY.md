# Stuck CronJob with concurrencyPolicy=Forbid — runbook

## Symptom

`KubeJobFailed` / `KubeJobNotCompleted` / `PodImagePullBackOff` alerts firing
for days or weeks on a mereka-lms CronJob-spawned Job. The stuck pod shows
an image tag that looks like a template placeholder (e.g. `:pin-required`)
or an image that doesn't exist in the registry.

## Root cause

`concurrencyPolicy: Forbid` on a CronJob means Kubernetes will not spawn a
new Job while a previous one is still in `Running` state. If a Job's pod
gets stuck (ImagePullBackOff, Pending due to missing ConfigMap, Longhorn
PVC stuck, etc.), the Job stays `Running` forever from kube-controller's
view, blocking every future scheduled run.

A kustomize image-tag update (e.g. bumping the overlay's `newTag`) updates
the **CronJob**, but any already-spawned Jobs keep the old pod template
frozen in their `spec.template`. So the stuck Job retries with the old
template, forever.

## Confirmed instances (2026-04-22)

- `aspects-event-sink-sync-29596320` — created 2026-04-10, image
  `docker.io/overhangio/openedx:pin-required` (upstream placeholder),
  79,525 image-pull retries over 12 days. Blocked every 6-hour scheduled
  run.
- `course-reindex-29596350` — created 2026-04-10, same class: stuck with
  `:pin-required` image literal.

Both cleared by this runbook, immediately followed by fresh Jobs spawning
with the correct pinned digest (`ghcr.io/.../openedx:d6e9f14f...@sha256:...`).

## Fix

```bash
# 1. Identify all stuck jobs (Running for > 1 day) in mereka-lms namespace
kubectl --context rke2-prod get jobs -n mereka-lms \
  -o json | jq -r '.items[] | select(.status.conditions == null or (.status.conditions[] | select(.type=="Complete") | .status != "True")) | "\(.metadata.creationTimestamp) \(.metadata.name)"' \
  | sort | head

# 2. Confirm the CronJob's current spec has a sane image (not a placeholder)
kubectl --context rke2-prod get cronjob <name> -n mereka-lms \
  -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[*].image}'

# 3. Confirm the stuck Job has NO argocd tracking (spawned by controller,
#    not managed by ArgoCD — safe to delete)
kubectl --context rke2-prod get job <stuck-job-name> -n mereka-lms \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'
# Expect empty output

# 4. Delete the stuck Job. The CronJob controller will spawn a fresh Job at
#    the next scheduled time (or sooner if catchup is enabled).
kubectl --context rke2-prod delete job <stuck-job-name> -n mereka-lms

# 5. Verify the new Job spawns with the correct image
kubectl --context rke2-prod get jobs -n mereka-lms | grep <cronjob-basename>
```

## Why NOT fix by patching the CronJob

The CronJob's `spec.jobTemplate` is the template for FUTURE Jobs; it cannot
retroactively change an already-spawned stuck Job's `spec.template`. Even if
you correct the CronJob's image, the stuck Job keeps retrying with its
captured (old) template. You MUST delete the stuck Job.

Also: CronJobs in the `deploy/k8s/` tree are ArgoCD-managed; patching them
directly is forbidden per `gitops-enforcement.md`. CronJob-spawned Jobs are
not ArgoCD-managed — they are spawned by the kube-controller-manager and
tracked by ownerReference to the CronJob. They can be deleted directly
without breaking the GitOps boundary.

## Why alerts didn't get human attention

This pattern went 12 days on prod before this runbook was written. Root
causes:

- `KubeJobFailed` is severity=warning and the prod Slack channel has ~185
  alerts firing total (platform + services-wide). Noise drowns the signal.
- `ImagePullBackOff` is usually transient; operators scroll past it.
- No alerting rule specific to "Job stuck > 1 day" — existing rules fire on
  first fail and repeatedly.

## Follow-up worth filing

A PrometheusRule that fires ONCE when a mereka-lms Job has been in `Running`
state for > `activeDeadlineSeconds` or > 4h (whichever is sooner) with
severity=critical → routed to a channel that isn't the current warning
firehose.

## Related evidence

- 2026-04-22 SLO truthfulness audit (live Prometheus `/api/v1/alerts` snapshot):
  15 firing alerts in mereka-lms namespace, 0 of them SLO-family. 9 were
  KubeJobFailed against these 2 stuck Jobs + their aftermath.
- Prior session closed `mereka-lms-krco` (Velero DR), today's session closed
  these Job ghosts — both "silent for days before discovered" patterns.
