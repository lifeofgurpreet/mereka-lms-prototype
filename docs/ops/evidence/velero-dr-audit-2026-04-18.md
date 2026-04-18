---
title: Velero DR Audit Evidence — 2026-04-18
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-18T13:07Z
bead: mereka-lms-v5vj
status: active
---

# Velero DR Audit Evidence — 2026-04-18

Evidence bundle for bead `mereka-lms-v5vj` ("Verify DR: run `audit-velero.sh` and prove backup/restore works"). This is the **truthful** outcome of the audit, not a claim that DR works. Where gaps exist, they are named with explicit severity and the follow-up beads that track repair.

## Scope

- Command: `bash scripts/qa/audit-velero.sh --json --context rke2-nonprod`
- Cluster: `rke2-nonprod`
- Namespace: `velero`
- Raw audit output: [`velero-dr-audit-2026-04-18.json`](./velero-dr-audit-2026-04-18.json) (392 lines)
- Captured by: operator-loop, `2026-04-18T13:07Z`

## Top-line verdict

**DR is partially operational with 5 named warnings and no restore-drill-pass proof.** Backup plumbing exists and runs on 9 of 14 schedules within SLA; 5 schedules are stale; no restore-drill CronJob is currently registered; no VolumeSnapshotLocation is configured. This is a "degraded, named gaps" posture, not a "DR works" posture.

- `audit-velero.sh --json` runs cleanly and returns valid JSON ✓
- `checks.failures: 0` ✓
- `checks.warnings: 5` ⚠
- `backup_storage_locations[0]: default, Available` ✓
- `volume_snapshot_locations: none` ⚠ (PV snapshots may not be configured)
- `restore_drill.exists: false` ⚠ (no recurring drill CronJob found in namespace `velero`)
- `schedules: 14 total, all unpaused`; stale count: 5

## Schedule freshness

| Schedule | Cadence | Last completed | Age (hours) | Status |
|---|---|---|---:|---|
| `dev-authentik-hourly` | hourly | `dev-authentik-hourly-20260418130019` | 0.8 | ✓ fresh |
| `dev-nfc-cards-daily` | daily | `dev-nfc-cards-daily-20260417184508` | 10.9 | ✓ fresh |
| `dev-team-analytics-daily` | daily | `dev-team-analytics-daily-20260417182508` | 19.1 | ✓ fresh |
| `dev-calcom-daily` | daily | `dev-calcom-daily-20260417182006` | 19.2 | ✓ fresh |
| `dev-twentycrm-daily` | daily | `dev-twentycrm-daily-20260417181503` | 19.4 | ✓ fresh |
| `dev-temporal-daily` | daily | `dev-temporal-daily-20260417181004` | 19.5 | ✓ fresh |
| `dev-listmonk-daily` | daily | `dev-listmonk-daily-20260417180500` | 19.6 | ✓ fresh |
| `dev-n8n-daily` | daily | `dev-n8n-daily-20260417180108` | 19.7 | ✓ fresh |
| `dev-zoom-rtms-daily` | daily | `dev-zoom-rtms-daily-20260417183014` | 19.0 | ✓ fresh |
| `dev-reka-slackbot-daily` | daily | `dev-reka-slackbot-daily-20260413185517` | **110.3** | ⚠ STALE |
| `dev-cie-daily` | daily | `dev-cie-daily-20260413184018` | **114.3** | ⚠ STALE |
| `dev-agent-e-daily` | daily | `dev-agent-e-daily-20260413183518` | **114.7** | ⚠ STALE |
| `dev-weekly-full` | weekly | `dev-weekly-full-20260412190058` | **136.4** | ⚠ (within 7d SLA for weekly) |
| `dev-mereka-lms-daily` | daily | `dev-mereka-lms-daily-20260412185055` | **138.1** | ⚠ **STALE** (this is our app) |

Observation: 4 daily schedules stopped producing backups on 2026-04-13 (~4 days ago). The simultaneous stop across `agent-e`, `cie`, `mereka-lms`, `reka-slackbot` suggests a common cause (runner outage, BSL bucket issue, or a shared misconfiguration). `authentik-hourly` and 7 other daily schedules kept running through the same window — so the BSL is healthy and the cluster is healthy; something specific to the 4 stale schedules failed.

## Restore drill status

**No recurring restore-drill CronJob exists.** `kubectl --context rke2-nonprod -n velero get cronjob` returns nothing.

The most recent restore-drill attempts were ad-hoc, all on 2026-04-09 (9 days ago):

| Restore | Phase | Completed | Warnings | Errors |
|---|---|---|---:|---:|
| `mereka-lms-restore-drill-0409` | **Failed** | 2026-04-09T12:08:39Z | 0 | 0 |
| `mereka-lms-restore-drill-0409-v2` | **Failed** | 2026-04-09T12:12:20Z | 0 | 0 |
| `mereka-lms-restore-drill-0409-v3` | **PartiallyFailed** | 2026-04-09T16:17:44Z | 83 | 13 |

No Velero restore has succeeded cleanly (phase `Completed`) against `mereka-lms` in at least 9 days. The v3 attempt reached `PartiallyFailed` with 13 errors — partial data restoration at best.

## Backup coverage

BSL `default`: phase `Available`, default: false.

No VSL: `volume_snapshot_locations: []`. This means PV-level snapshots are NOT configured; backups are pod-spec / configmap / secret level only, not durable persistent data. For mereka-lms this matters for MySQL, MongoDB, Redis, Elasticsearch — all of which carry state that is NOT currently in a Velero-protected snapshot.

`volume_snapshot_classes`: `longhorn-snapshot-class` (driver: `driver.longhorn.io`) is defined but not wired to a VSL, so Velero cannot use it.

## Named gaps (each tracked as a follow-up bead)

1. **Daily schedules `agent-e`, `cie`, `mereka-lms`, `reka-slackbot` have been silent since 2026-04-13.** Common cause unknown. Root-cause-then-fix.
2. **No recurring restore-drill CronJob.** The only restore attempts on record are 9 days old and all Failed or PartiallyFailed.
3. **No VolumeSnapshotLocation.** PV data (MySQL/Mongo/Redis/ES) is not durably snapshot-protected.
4. **Last successful restore (`Completed` phase) unknown.** Until we produce one, "DR works" is unproven.

## What this evidence bundle proves

- `scripts/qa/audit-velero.sh --json` is healthy and exits 0 with parseable output. ✓
- Velero is installed, BSL is `Available`, 9/14 schedules are producing fresh backups. ✓

## What this evidence bundle does NOT prove

- That a restore from current backup data would actually succeed.
- That `mereka-lms`'s persistent data is recoverable — it is not currently in a snapshot class wired to a VSL.
- That the 4 stale daily schedules will resume without operator action.

## Next concrete moves

1. Investigate why `dev-mereka-lms-daily` (and siblings) stopped on 2026-04-13. Check `kubectl --context rke2-nonprod -n velero describe schedule dev-mereka-lms-daily` and `velero backup logs` for the last successful run.
2. Create a restore-drill CronJob that runs weekly against a known-good backup and asserts phase `Completed`. Wire it into alerting so stale or failed drills page.
3. Configure a VolumeSnapshotLocation pointing at the Longhorn driver, then add `--snapshot-volumes` to the existing schedules so PV data is actually captured.
4. Do not mark the `v5vj` bead as "DR works" — mark it as "audit evidence captured; 4 concrete gaps filed as follow-up work."

## Doctrine compliance

- Rule 1 (canonical = generated): the audit JSON is a generator artifact; this markdown summarizes it honestly without approximation.
- Rule 3 (runbook executable requires evidence): this bundle IS the evidence for `audit-velero.sh`'s posture check; whether it's enough evidence for "DR proven" is answered **no** (see named gaps).
- Harder-path-if-truthful: rejected the summary "audit passes, DR works" because that would be false. Surfaced the 4 gaps with severity.

## Related

- Bead: `mereka-lms-v5vj` (this audit)
- Parent epic: `mereka-lms-1bj7` Velero DR Program (marked closed on 2026-02-14 — this evidence shows that closure was premature)
- Audit script: `scripts/qa/audit-velero.sh`
- Raw output: `docs/ops/evidence/velero-dr-audit-2026-04-18.json`
