# XQueue Health Runbook
_Audience: Platform Eng • Owner: Engineering Lead • Last verified: 2026-02-18_

> **Bead**: mereka-lms-1si5.2

Companion surfaces:

- [ASSESSMENT_OPERATIONS_RUNBOOK.md](ASSESSMENT_OPERATIONS_RUNBOOK.md)
- [../../guides/platform/ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md](../../guides/platform/ADVANCED_ASSESSMENT_AUTHORING_GUIDE.md)

## Quick Status Check

```bash
# Pod status
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" get pods -n mereka-lms -l app.kubernetes.io/name=xqueue

# Both containers should be Running
# - xqueue: uWSGI web server (port 8000)
# - xqueue-consumer: Polls for submissions to process

# Submission count (0 = normal if no code assessments exist)
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" exec -n mereka-lms deployment/xqueue -c xqueue -- bash -c 'cd /openedx/xqueue && python manage.py shell -c "from submission_queue.models import Submission; print(\"Total:\", Submission.objects.count()); print(\"Queued:\", Submission.objects.filter(retired=False, lms_ack=False).count())"'
```

## Architecture

```
LMS → POST /xqueue/submit/ → XQueue (uWSGI) → MySQL → xqueue-consumer (polling)
                                                          ↓
                                                    [Grader — NOT DEPLOYED]
                                                          ↓
                                                    XQueue → POST callback_url → LMS
```

**Current state**: XQueue and consumer are running. No external grader is deployed (no courses use code assessments yet).

## Alert Reference

### Deployed Alerts (PrometheusRule: xqueue-alerts)

| Alert | Expr | Severity | Works? | Notes |
|-------|------|----------|--------|-------|
| `XQueuePodDown` | `up{job="xqueue-metrics"} == 0` | critical | No | ServiceMonitor label mismatch — no scrape target. Relies on `up` metric which is absent when no target exists. |
| `XQueuePodRestarting` | `rate(kube_pod_container_status_restarts_total{pod=~"xqueue-.*"}[15m]) > 0` | warning | **Yes** | Uses kube-state-metrics |
| `XQueueMemoryHigh` | `container_memory_working_set_bytes / limit > 0.85` | warning | **Yes** | Uses cadvisor |
| `XQueueCPUHigh` | `container_cpu_usage_seconds_total / quota > 0.85` | warning | **Yes** | Uses cadvisor |
| `XQueueQueueBacklog` | `count(kube_pod_info{pod=~"xqueue-.*"}) > 100` | warning | **Placeholder** | Counts pods not queue depth — needs real queue depth metric |

### Known Issue: ServiceMonitor Not Scraping

The `xqueue-metrics` ServiceMonitor selects labels:
```yaml
app.kubernetes.io/instance: mereka-lms
app.kubernetes.io/name: xqueue
```

But the XQueue service only has:
```yaml
app.kubernetes.io/instance: mereka-lms
app.kubernetes.io/managed-by: tutor
```

Missing: `app.kubernetes.io/name: xqueue` label on the Service. Also, the service port has no `name` field but the ServiceMonitor expects `port: http`.

**Fix** (when needed): Add label to XQueue service and name the port.

## Troubleshooting

### XQueue Pod Not Starting

```bash
# Check events
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" describe pod -n mereka-lms -l app.kubernetes.io/name=xqueue

# Check logs
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" logs -n mereka-lms deployment/xqueue -c xqueue --tail=50
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" logs -n mereka-lms deployment/xqueue -c xqueue-consumer --tail=50
```

**Common causes**:
- MySQL connection failure (check `database-secrets` sync)
- Secret reference mismatch (check ExternalSecrets)
- Image pull error (check GHCR / active registry auth)

### XQueue Consumer Not Processing

The consumer logs should show "running consumers" in a loop. If stuck:

```bash
# Check consumer is running
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" logs -n mereka-lms deployment/xqueue -c xqueue-consumer --tail=10

# Check MySQL connectivity
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" exec -n mereka-lms deployment/xqueue -c xqueue -- bash -c 'cd /openedx/xqueue && python manage.py dbshell <<< "SELECT 1;"'
```

### Submissions Queued But Not Graded

If `Queued > 0` and growing:

1. **No grader deployed**: Expected if no `xqueue-graders` pods exist
2. **Grader crashed**: Check grader pod logs (if deployed)
3. **Grader auth failed**: Check grader MySQL credentials

```bash
# Check for grader pods
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" get pods -n mereka-lms -l app.kubernetes.io/name=xqueue-graders

# If no grader exists, submissions will stay queued indefinitely
```

### LMS Cannot Submit to XQueue

```bash
# Verify LMS XQueue config
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" exec -n mereka-lms deployment/lms -- python manage.py lms shell -c "
from django.conf import settings
xq = settings.XQUEUE_INTERFACE
print('URL:', xq.get('url'))
print('Callback:', xq.get('callback_url'))
print('Auth user:', xq.get('django_auth', {}).get('username'))
"

# Verify XQueue endpoint is reachable from LMS
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" exec -n mereka-lms deployment/lms -- curl -s -o /dev/null -w "%{http_code}" http://xqueue:8000/xqueue/status/

# Verify XQueue Django user exists
kubectl --context "${OBS_PARITY_PROD_K8S_CONTEXT:-rke2-prod}" exec -n mereka-lms deployment/xqueue -c xqueue -- bash -c 'cd /openedx/xqueue && python manage.py shell -c "from django.contrib.auth.models import User; print([u.username for u in User.objects.all()])"'
```

## Configuration Reference

| Setting | Value | Source |
|---------|-------|--------|
| XQueue URL | `http://xqueue:8000` | LMS `XQUEUE_INTERFACE.url` |
| Callback URL | `http://lms:8000` | LMS `XQUEUE_INTERFACE.callback_url` |
| Auth username | `lms` | LMS `XQUEUE_INTERFACE.django_auth.username` |
| MySQL DB | `xqueue` | XQueue Django settings |
| Image | `openedx-xqueue` | GHCR / current image registry |

## Future: Grader Deployment

When code assessment courses are created, deploy the grader:

1. Build `xqueue-graders` image with `xqueue-watcher` + grading scripts
2. Add to kustomization (manifests already scaffolded at `deploy/k8s/base/apps/xqueue-graders/`)
3. Simplify deployment: use `RuntimeDefault` seccomp (not cluster-specific localhost profiles)
4. Verify end-to-end: submit code → XQueue → grader → callback → LMS gradebook
5. Enable HPA + monitoring alerts for grader pods

See `docs/evidence/operations/ASSESSMENT_XQUEUE_EVIDENCE.md` for full deployment analysis.

## Grader Deployment Procedure (Gated)

Use this section only for a coordinated rollout. Do not treat it as permission
to self-enable code graders in a launch lane.

### Build And Push

1. Build the `xqueue-graders` image from the governed grader source.
2. Push the image to the active registry used by the current lane.
3. Record the exact image reference in the rollout handoff so queue behavior can
   be traced back to a concrete grader build.

### Deploy Workers

1. Apply the manifests under `deploy/k8s/base/apps/xqueue-graders/`.
2. Confirm deployment, HPA, NetworkPolicy, and PrometheusRule objects exist.
3. Confirm the sandbox policy or sanctioned replacement isolation model is
   loaded before declaring the deployment valid.

### Scale And Queue Depth Checks

After rollout, confirm:

- worker replicas are running and stable
- queue depth is not growing unbounded
- grading latency and callback behavior are consistent with the launch target
- dead letters and grader errors remain within the rollout tolerance

Use the existing verifier and metrics surfaces before calling the lane healthy.

### Rollback

Rollback is required when:

- queue depth keeps growing without successful callbacks
- grader images crash or fail readiness repeatedly
- callback payloads or scores are malformed
- the sandbox policy cannot be proved in the current lane

Rollback order:

1. stop or scale down grader workers
2. preserve queue evidence and failing submission samples
3. move the launch back to a non-grader fallback if one exists
4. do not call the XQueue authoring path live again until a new verified build
   is deployed
