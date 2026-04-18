# RC-05 Worker Probe Diagnosis — 2026-04-18

## Probe time

2026-04-18T05:35Z (verified live from `ssh mereka`, kubectl against `rke2-nonprod` namespace `mereka-lms-dev`).

## Status Summary

| Deployment | Ready / Desired | Restart counts (per pod) |
|---|---|---|
| `cms-worker` | 0 / 2 | bjcff=2, qhz5b=3 |
| `lms-worker` | 0 / 3 | njx2q=3, zbrlv=5, l7xkg=3, lc8nm=4 |

Additional signal:
- Two `lms-worker` pods still running the **previous artifact digest** (`sha256:d17ae77f…`) — rolling update is stuck because new pods cannot pass the readiness gate.
- Argo app `mereka-lms-dev` is reporting `health=Degraded`.

## Measured Probe Latency

Executed from inside a live worker pod at 05:35Z:

```
$ time celery -A cms inspect ping -t 15
... 6 nodes online.
real  0m34.397s
user  0m2.332s
sys   0m0.528s
```

**34 seconds end-to-end.** That's:
- 14s over the `celery inspect ping -t 15` application-level timeout
- 14s over `timeoutSeconds: 20` (probe timeout)
- At the liveness `-t 25` / `timeoutSeconds: 45` boundary too

## Root-Cause Re-Diagnosis (supersedes earlier wk-04 theory)

The earlier write-up in `RUNTIME_MATRIX_ADDENDUM_2026-04-18T02.md` said the problem was "highest-density on wk-04". That was incomplete. Fresh data:

**Pods NotReady by node:**
| Node | Pods scheduled | Worker pods NotReady |
|---|---|---|
| `wk-04-sin1` | 11 | 3 (cms-worker, 2× lms-worker) |
| `cp-01-sin1` | 11 | 0 |
| `cp-03-sin1` | 8 | 0 |
| `cp-02-sin1` | 8 | 0 |
| `wk-02-sin1` | 6 | 2 (lms-worker-njx2q, lms-worker-l7xkg) |
| `wk-01-sin1` | 3 | 1 (cms-worker-bjcff) |

Workers on three different worker nodes (wk-01, wk-02, wk-04) all fail the probe. This is **NOT** wk-04-specific. **Node density is not the cause — at least not the whole cause.**

## Correct Root Cause

`celery inspect ping` is a broker-traversal cluster-wide operation. With 5+ worker replicas:
1. Pod's probe process spawns: `celery -A cms inspect ping -t 15`
2. Sends a `ping` broadcast on the Redis broker's control queue
3. Every worker (cms-worker × 2 + lms-worker × 3 + itself) is expected to reply via a reply queue
4. Probe process waits up to 15s for ALL replies
5. The aggregate reply round-trip consistently exceeds 15s under normal cluster load

At the current cluster size + broker latency + replica count, the probe is mathematically incapable of succeeding within its own timeout. **This is not a transient issue; it's a design flaw.**

Evidence this is a design flaw, not an environmental flake:
- 34s measured latency exceeds all three timeout boundaries (`-t 15`, `timeoutSeconds: 20`, any reasonable retry)
- Restart counts climbing on ALL pods (not just wk-04): zbrlv=5, lc8nm=4, njx2q=3, qhz5b=3, bjcff=2
- Rollout safety empirically broken: 2 `lms-worker` pods can't replace the previous digest because the new ones can't pass the gate

## Probes Are Doing MORE Harm Than Good Right Now

1. **False negative on readiness:** web surfaces are healthy; workers process tasks (kernel-visible celery main PID 1, `--without-gossip --without-mingle`); probe just can't confirm it
2. **Liveness-kills causing restart storms:** pod `lms-worker-6b497b648f-zbrlv` has restarted 5 times in ~5.5 hours because the liveness probe's `-t 25 / timeoutSeconds: 45` eventually exceeds too
3. **Rolling update gate is blocked:** new pods never pass readiness, old pods never get drained, rollout is stuck

## Fix Options (revised from earlier memo)

### Option 1 — Lengthen probes

```yaml
readinessProbe:
  exec:
    command: ["celery", "-A", "cms", "inspect", "ping", "-t", "60", "--destination=celery@$HOSTNAME"]
  timeoutSeconds: 90
  periodSeconds: 60
livenessProbe:
  exec:
    command: ["celery", "-A", "cms", "inspect", "ping", "-t", "60", "--destination=celery@$HOSTNAME"]
  timeoutSeconds: 90
  periodSeconds: 120
  failureThreshold: 3
```

**Rejected.** Still grows with cluster size even with `--destination=celery@$HOSTNAME` if broker reply queue is shared and congested. And a 60s probe is rotten operational hygiene.

### Option 2 — Local-only readiness (RECOMMENDED)

Replace the probe with a local-only signal that does not traverse the broker:

```yaml
readinessProbe:
  exec:
    command:
      - bash
      - -c
      - "ps -o comm= -p 1 | grep -q celery && test -e /proc/1/status"
  timeoutSeconds: 5
  periodSeconds: 10
  failureThreshold: 3
livenessProbe:
  exec:
    command:
      - bash
      - -c
      - "ps -o comm= -p 1 | grep -q celery"
  timeoutSeconds: 5
  periodSeconds: 30
  failureThreshold: 5
```

**Pros:**
- Doesn't grow with cluster size.
- Measures what we actually care about: is the worker process alive on THIS pod?
- Sub-second execution.
- Removes the pathological restart storm.

**Cons:**
- Weaker liveness contract: won't detect broker-connectivity failures (worker alive but can't reach Redis).

**Mitigation for the cons:** add a separate Prometheus alert on `celery_worker_last_heartbeat_seconds` (already emitted by `celery.events.receiver` if enabled) — this is an alerting concern, not a k8s-lifecycle concern.

### Option 3 — Single-destination broker ping

```yaml
command: ["celery", "-A", "cms", "inspect", "ping", "-t", "10", "--destination=celery@$HOSTNAME"]
```

Still broker-traversal but only waits for this pod's own reply.

**Partial mitigation.** Works if Redis reply queue is not congested. Today's measurement shows reply-queue congestion, so this alone is not enough.

## Recommendation

**Land Option 2 (local-only readiness) as a surgical overlay patch in `bbi-infrastructure`.**

Change surface: `bbi-infrastructure/apps/mereka-lms/base/deploy/k8s/base/apps/{lms,cms}/worker-deployment.yaml` (per Operator Brief, Week 1 file list).

After landing:
1. Wait for rolling update to complete
2. Re-measure pod readiness
3. Argo app `mereka-lms-dev` should flip from `Degraded` → `Healthy`
4. Take a snapshot of restart counts — they should stabilize

This closes RC-05 honestly, unblocks rolling updates, and stops liveness-kill restart storms. It does NOT require any change on the mereka-lms side.

## Work Items

- `mereka-lms-1li5` (P1): this diagnosis is the plan. Implementation goes in `bbi-infrastructure` (not this repo).
- Follow-up Prometheus alert on `celery_worker_last_heartbeat_seconds` — file as separate reliability observation, not part of this memo.
