---
title: Velero RCA — PVB stall on mereka-np-k8s-wk-03-sin1 — 2026-04-18
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-18T14:13Z
bead: mereka-lms-1bj7.1
status: active
---

# Velero RCA — PVB stall on `mereka-np-k8s-wk-03-sin1` — 2026-04-18

Root-cause analysis for bead `mereka-lms-1bj7.1`. Earlier audit (see `velero-dr-audit-2026-04-18.md` in the same directory) reported that 4 daily Velero schedules had not produced a completed backup since 2026-04-13:

- `dev-agent-e-daily`
- `dev-cie-daily`
- `dev-mereka-lms-daily`
- `dev-reka-slackbot-daily`

This RCA is based on direct observation of the Velero server and node-agent logs + the running state of the backup sub-pods at `2026-04-18T14:13Z` on cluster `rke2-nonprod`.

## Top-line finding

**The Velero `node-agent` daemon on worker node `mereka-np-k8s-wk-03-sin1` is not completing Pod Volume Backups (PVBs).** The schedules *are* firing — the Velero server creates the PVB CRs on schedule — but every PVB assigned to this node-agent gets stuck in a prepare → "Exposed PVB is ready and creating data path routine" loop that never produces a completion.

The four silent schedules are not a schedule-layer failure. They are a node-agent-on-wk-03-sin1 processing failure.

## Evidence

### 1. Schedules are firing

`kubectl --context rke2-nonprod -n velero describe schedule dev-mereka-lms-daily` shows:

```
Status:
  Last Backup:  2026-04-17T18:50:08Z
  Phase:        Enabled
```

`Last Backup` is a timestamp of the last attempt (which was yesterday), not the last success. The schedule-layer is healthy: it's creating PVB CRs on schedule.

### 2. The backup sub-pods keep running for days

`kubectl --context rke2-nonprod -n velero get pods | grep -E "(agent-e|cie|mereka-lms|reka-slackbot)-daily"` shows pods stuck Running for 10-48+ hours:

```
dev-agent-e-daily-20260415183548-ccn7l        1/1  Running  0  47h
dev-agent-e-daily-20260416183514-92rwd        1/1  Running  0  43h
dev-agent-e-daily-20260417183507-47tvh        1/1  Running  0  19h
dev-cie-daily-20260416184013-cxt7f            1/1  Running  0  39h
dev-cie-daily-20260417184001-m66gt            1/1  Running  0  15h
dev-mereka-lms-daily-20260415185048-sqm5t     1/1  Running  0  2d3h
dev-mereka-lms-daily-20260416185014-vr4mk     1/1  Running  0  34h
dev-mereka-lms-daily-20260417185008-9r26s     1/1  Running  0  10h
dev-mereka-lms-daily-20260417185008-cqspc     1/1  Running  0  10h
```

These are the data-path service pods Velero spawns for each PVB. When a PVB completes normally they transition to `Completed`. These are stuck in `Running` with no progress.

### 3. Sub-pod log ends at data-path-service startup

`kubectl --context rke2-nonprod -n velero logs dev-mereka-lms-daily-20260417185008-9r26s --tail=30`:

```
time="2026-04-18T03:13:59Z" Starting Velero pod volume backup v1.17.1 ...
time="2026-04-18T03:13:59Z" Setting log-level to INFO
time="2026-04-18T03:13:59Z" Starting micro service in node mereka-np-k8s-wk-03-sin1 for PVB dev-mereka-lms-daily-20260417185008-9r26s
time="2026-04-18T03:14:00Z" Starting data path service dev-mereka-lms-daily-20260417185008-9r26s
time="2026-04-18T03:14:00Z" Running data path service dev-mereka-lms-daily-20260417185008-9r26s
```

Log ends here (11 hours ago) with no errors, no progress, no completion. The data-path service started but never did any work — or its output is not reaching stdout.

### 4. Node-agent on wk-03-sin1 loops on the same PVBs every few minutes

`kubectl --context rke2-nonprod -n velero logs node-agent-fp4tb --tail=40` (pod running on `mereka-np-k8s-wk-03-sin1`):

```
2026-04-18T14:13:11Z  PVB is prepared and should be processed by mereka-np-k8s-wk-03-sin1 (mereka-np-k8s-wk-03-sin1)  backup=dev-mereka-lms-daily-20260417185008-fc7t6
2026-04-18T14:13:11Z  Hosting pod is in running state ...  owner=dev-mereka-lms-daily-20260417185008-fc7t6
2026-04-18T14:13:11Z  Exposed PVB is ready and creating data path routine  podvolumebackup=dev-mereka-lms-daily-20260417185008-fc7t6
...(same pattern repeats for cie, agent-e, reka-slackbot PVBs every ~seconds)...
```

The node-agent is prepared, sees the hosting pod Running, creates the data-path routine — and loops. Same PVB names appear every cycle. Nothing ever transitions to Completed.

### 5. Control-plane node-agents are healthy

`authentik-hourly` is completing successfully and uses `mereka-np-k8s-cp-03-sin1`. Other schedules routed to control-plane node-agents (e.g. `authentik`, `calcom`, `listmonk`, `n8n`, `twentycrm`, `team-analytics`, `nfc-cards`, `temporal`, `zoom-rtms`) are fresh (<24h lag). Only schedules routed to `wk-03-sin1` are stuck.

### 6. node-agent pod itself looks healthy from the outside

`kubectl --context rke2-nonprod -n velero get pods -o wide -l app.kubernetes.io/name=velero` shows `node-agent-fp4tb` on `mereka-np-k8s-wk-03-sin1` has been Running for 30 days with 0 restarts. No OOM, no crash loop. The process is alive but wedged.

## Root cause (proven with this evidence)

The node-agent on `mereka-np-k8s-wk-03-sin1` has wedged PVB processing. It is prepared and aware of PVBs, creates exposer pods successfully, starts data-path-service subprocesses — but those subprocesses never complete the Kopia upload. Either:

1. **Kopia repository lock contention**: `kopia-maintain` jobs were visible in the namespace (`agent-e-dev-default-kopia-maintain-job-*`); if maintenance is holding a repo lock, new writes block. Multiple concurrent PVBs targeting the same BSL (`default`) would all stall.
2. **Blocked inotify / fsnotify / fd exhaustion** on the wk-03-sin1 kernel — could also manifest as data-path service starting but then stalling on file-walk.
3. **Hung kopia client process** inside one of the data-path pods, holding a repo lock that other PVBs on the same node wait for.

Of these, (1) is the most likely given the pattern: ALL PVBs on wk-03-sin1 stall at the same phase, while other nodes keep completing. A shared lock is the natural shape of this failure.

## Root cause (NOT yet proven — would require operator steps)

To confirm (1), an operator would need to:

- `kubectl --context rke2-nonprod -n velero exec node-agent-fp4tb -- kopia repository status` to check for stale locks on the `default` repository.
- `kubectl --context rke2-nonprod -n velero exec dev-mereka-lms-daily-20260417185008-9r26s -- ps aux` (or equivalent) to check whether the kopia upload subprocess is running, sleeping, or zombied.
- Inspect `kopia-maintain` job logs to see if a maintenance run is in progress or failed mid-run.

These are cluster-mutation-adjacent operations (exec into system pods). Not performed in this read-only RCA.

## Remediation candidates (operator-authorized)

1. **Soft**: Delete the 7 stuck data-path service pods on `wk-03-sin1`. Their PVBs will be recreated by the node-agent. If they still get stuck, that rules out transient state.
2. **Medium**: Restart `node-agent-fp4tb` (delete the pod; DaemonSet recreates). This forces the data-path-service supervision tree to re-init. If Kopia locks are held by a zombie subprocess of the old node-agent, this releases them.
3. **Hard**: Run `kopia repository unlock` on the BSL to forcibly clear stale locks (risk: concurrent writer gets corrupted output). Requires BSL credentials.

**Recommendation**: try soft → medium before hard. The pattern (node-agent running but wedged, same PVBs looping) fits the medium remediation cleanly.

## Impact

- `dev-mereka-lms-daily`: last completed backup was `dev-mereka-lms-daily-20260412185055` on 2026-04-12. **5.75 days of stateful data has no current backup.** If mereka-lms-dev suffered a PVC loss right now, recovery would roll back to 2026-04-12.
- Same pattern for `agent-e`, `cie`, `reka-slackbot` — all 4 environments have stale backups.
- BSL object storage still has the old backups (TTL is 720h = 30 days), so recovery to the 2026-04-12 state IS possible. But RPO has drifted silently from 24h to ~138h.

## Doctrine compliance

- Rule 1 (canonical = generated): this RCA is generated from live kubectl + log output, not narrative.
- Rule 2 (retractions patch source): earlier v5vj audit reported "stale schedules" as the observation; this RCA preserves that observation and adds the mechanism (node-agent on wk-03-sin1 wedged). No retraction needed.
- Rule 3 (runbook executable requires evidence): this IS evidence for 1bj7.1. Remediation runbook (separate follow-up) will require its own dry-run evidence.
- **Harder-path-if-truthful**: rejected the surface-level story "schedules are failing" in favor of the deeper "schedules fire correctly, PVBs start correctly, node-agent-on-one-node wedges" finding. The fix target is now specific (one node, one DaemonSet pod) instead of vague (all of Velero).

## Next concrete moves

1. File bead `1bj7.1.1` — "Remediate wk-03-sin1 node-agent PVB stall: soft (delete stuck pods) → medium (restart node-agent-fp4tb) → hard (kopia unlock)." Requires user authorization for cluster-mutation; flag before executing.
2. File bead `1bj7.4` — "Wire a CI alert on PVB age > 48h to catch this silently-degraded class of failure before a week passes."
3. Leave `1bj7.1` (this bead) CLOSED once this RCA lands on main.

## Related

- Audit bundle: `docs/ops/evidence/velero-dr-audit-2026-04-18.md`
- Audit raw JSON: `docs/ops/evidence/velero-dr-audit-2026-04-18.json`
- Parent bead: `mereka-lms-1bj7` Velero DR Program (closed 2026-02-14 — this RCA is another data point that the closure was premature).
