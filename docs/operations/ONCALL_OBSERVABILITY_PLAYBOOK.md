# On-Call Observability Playbook
_Audience: Incident responders • Last updated: 2026-02-07_

Use this sequence to understand platform health quickly.

## Step 1: External Impact

```bash
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod
```

If this fails, user-facing impact is likely.

## Step 2: Monitoring Coverage Sanity

If AC-OVR-016 is active, use `docs/qa/OBSERVABILITY_CLOSEOUT_QUEUE_2026-02-27.md` and execute `OBS-EXT-061` then `OBS-EXT-063` as the hard stop before other coverage runs.

```bash
OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod \
  OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_NONPROD_K8S_CONTEXT \
  ./scripts/qa/run-observability-first-class.sh --mode runtime --strict
./scripts/qa/audit-velero-alert-pipeline.sh
./scripts/qa/verify-alert-routing.sh
./scripts/qa/audit-grafana-dashboard.sh --strict-required
./scripts/qa/run-operations-gates.sh --env both
```

Use production lane mapping for production incidents:
- `OBSERVABILITY_ENV_LABEL=prod`
- `OBSERVABILITY_DISPATCH_PROFILE=prod`
- `OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_PROD_K8S_CONTEXT`

If this fails, monitoring blind spots may exist; fix coverage first.

## Step 3: LMS/CMS /metrics and settings-map triage

Use this when AC-OVR-016 is failing in strict runtime output.

```bash
# Re-run strict runtime gate with lane identity
OBSERVABILITY_ENV_LABEL=<lane> \
  OBSERVABILITY_DISPATCH_PROFILE=<nonprod|prod> \
  OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_<LANE>_K8S_CONTEXT \
  ./scripts/qa/run-observability-first-class.sh --mode runtime --strict

# Quick mounted settings-map inventory
LMS_CONFIGMAPS=$(kubectl -n mereka-lms get deploy lms -o json \
  | jq -r '.spec.template.spec.volumes[]? | select(.configMap.name | tostring | startswith("openedx-settings-")) | .configMap.name' | sort -u)
CMS_CONFIGMAPS=$(kubectl -n mereka-lms get deploy cms -o json \
  | jq -r '.spec.template.spec.volumes[]? | select(.configMap.name | tostring | startswith("openedx-settings-")) | .configMap.name' | sort -u)

printf 'LMS configmaps:
%s
' "$LMS_CONFIGMAPS"
printf 'CMS configmaps:
%s
' "$CMS_CONFIGMAPS"

# Prove marker presence in live mounted maps
for cm in $LMS_CONFIGMAPS $CMS_CONFIGMAPS; do
  echo "==> $cm"
  kubectl -n mereka-lms get configmap "$cm" -o json \
    | jq -r '.data["production.py"] // empty + "\n" + (.data["development.py"] // empty) + "\n" + (.data["test.py"] // empty)' \
    | rg -n "openedx_prometheus|PrometheusBeforeMiddleware|PrometheusAfterMiddleware|ROOT_URLCONF_OVERRIDES|_metrics_urlconf" || true
  done

# If only stale maps contain traffic and fresh maps are missing markers
kubectl -n mereka-lms get configmaps -l app.kubernetes.io/name=openedx --no-headers=true -o custom-columns=NAME:.metadata.name
```

Close criteria:
- both LMS and CMS `/metrics` checks show `status_code: 200` in metrics payload artifacts
- payload checks show `# HELP`, `# TYPE`, and numeric samples
- AC-OVR-016 marker probe points to healthy maps in live pods
- no stale, non-hashed map versions remain in workload wiring
- after rollback/rollout, rerun Step 2 until checks are clean

## Step 4: Core Dashboards

Open in order:
1. `Mereka LMS - Public Endpoints`
2. `Mereka LMS - Operations Signals`
3. `Mereka LMS - GKE`
4. `Mereka LMS - Auth`

## Step 5: Fast Branching by Signal

- Storage signal (`stateful-storage-errors`):
  - inspect MySQL/Redis/Elasticsearch logs
  - check PVC status and free capacity
  - follow DR runbook if data-risk
- Saturation signal (`mysql-saturation-high` / `redis-saturation-high`):
  - inspect CPU/memory request utilization trends in `operations-signals`
  - correlate with pod restarts and connection-error spikes
  - scale resources or reduce pressure before user-facing failures
- MySQL/Redis connection errors:
  - check pod readiness/restarts
  - confirm service endpoints
  - verify config drift (hosts/ports)
- Velero verification/restore-test failures:
  - inspect `velero` CronJob/job logs
  - run `./scripts/qa/audit-velero.sh`
  - run `./scripts/qa/audit-velero-alert-pipeline.sh`
- Atlas allowlist drift (dev/forum risk):
  - run `./scripts/qa/audit-atlas-allowlist-monitor.sh`
  - run strict routing check: `STRICT_WEBHOOK=1 ./scripts/qa/audit-atlas-allowlist-monitor.sh`
  - remediate with `./scripts/infra/ensure-atlas-allowlist-vps.sh` and re-run monitor/audit
- Velero stale-success signal (`velero-*-stale`):
  - confirm `lastSuccessfulTime` for `backup-verification` and `restore-test`
  - run strict freshness checks: `STRICT_RUNTIME=1 ./scripts/qa/audit-velero-alert-pipeline.sh`
  - inspect `velero` CronJob history and recent job logs
  - treat as data-risk until success signal is restored
- CrashLoopBackOff / Pending pods / unavailable critical deployments:
  - check `kubectl get pods -n mereka-lms` for stuck/pending pods
  - check `kubectl get deploy -n mereka-lms` and unavailable replicas
  - inspect rollout history/events and recent image/config changes
- Synthetic/backup job failures (`auth-verify-prod`, `cert-verify-prod`, `backup-verification`, `restore-test`):
  - inspect failed jobs: `kubectl get jobs -A | rg 'auth-verify|cert-verify|backup-verification|restore-test'`
  - inspect logs for latest failed run in owning namespace
  - restore success signals before closing incident
- Auth/TLS synthetic failures:
  - run auth/cert verify scripts and check redirect/cert drift

## Step 6: Evidence Bundle

Attach:
- `observability-compliance-runtime.json`
- `observability-first-class-runtime-evidence-index.json`
- `observability-correlation-headers-runtime.txt`
- `audit-velero-alert-pipeline` output
- `verify-alert-routing` output
- `public-health-check` output
- relevant dashboard screenshots
- any `audit-velero` output if data-risk
- DR bundle path (if generated): `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`

## Step 7: Recurring Operator Drill (Monthly)

Drill objective: prove a full observability-driven incident response path from first alert to runbook close in one sitting.

Preparation (within 3 business days before drill):
- Select one active P1/P2 historical scenario from `parity-drill-scaffold.md` or last month incident write-up.
- Open one issue using the `Observability Parity Weekly Review` template and label it `observability-drill`.
- Prepare a shared evidence directory:
  - `docs/operations/evidence/observability-drills/<YYYY-MM-DD>/`

Execution sequence:
1. Receive synthetic alert (Slack/on-call channel) and log alert metadata (`alertname`, `fingerprint`, firing timestamp).
2. Run the first 3 steps of this playbook without skipping.
3. Validate at least one critical dashboard action and one remediation command.
4. Capture evidence files:
  - `drill-runbook-checklist.md`
  - `evidence-index.md`
  - `dashboard-screenshots.md`
5. Capture attendance (operator names + duration) and finalize drill outcome in the issue.

Completion criteria:
- Drill log links are stored in `docs/operations/evidence/observability-drills/`.
- At least one failure-injection path and one recovery path are demonstrated.
- Action items are assigned with due dates where the drill exposed risk.

Evidence bundle minimum:
- `drill-runbook-checklist.md`
- `evidence-index.md`
- `operator-attendance.csv`
- command transcripts for mitigation actions
