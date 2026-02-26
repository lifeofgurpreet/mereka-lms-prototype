# Observability Runtime Parity Gap Evidence

Date: 2026-02-26
Environment: `mereka-lms` repo
Command: `./scripts/qa/audit-observability.sh --mode runtime --json`

## Result

- Repo JSON validity: OK
- Runtime GCP monitoring/logging objects check: **PASS** (after script fix; no longer mis-reported missing dashboard)
- Keynote:
- `video-cost.json` and `video-operations.json` now no longer cause null-parity failures in `dashboards` comparison after extraction hardening.

## Re-check (post-script fix)

Date: 2026-02-26

- Command: `./scripts/qa/audit-observability.sh --mode runtime --json`
- Result: `failures=0` with checks:
  - repo: monitoring json files are valid ✅
  - runtime: gcp monitoring/logging objects exist ✅
  - runtime: key in-cluster cronjobs exist ✅
  - runtime: velero cronjob freshness is within SLO ✅
- Root cause of prior FAIL was deterministic script return-path issue in
  `runtime_gcp_check` (non-zero from trailing loop test when debug was disabled).
- Follow-up strict run:
- `./scripts/qa/audit-observability.sh --mode runtime --strict-runtime --json` fails only on stale velero backup freshness (unrelated legacy timing condition), not on GCP parity.

## Cross-lane runtime revalidation (lane-by-lane)

Executed on 2026-02-26 with current cluster contexts:

- `./scripts/qa/audit-observability.sh --mode runtime --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster --json`  
  - Result: `failures=0`
- `./scripts/qa/audit-observability.sh --mode runtime --context rke2-nonprod --json`  
  - Result: `failures=0`
- `./scripts/qa/audit-observability.sh --mode runtime --context kind-dev --json`  
  - Result: `failures=0`

Strict variant results (for environment contract):

- `./scripts/qa/audit-observability.sh --mode runtime --context gke... --strict-runtime --json`  
  - Fails on stale `backup-verification lastSuccessfulTime` freshness.
- `./scripts/qa/audit-observability.sh --mode runtime --context rke2-nonprod --strict-runtime --json`  
  - Fails on missing `backup-verification` and `restore-test` cronjobs in namespace `velero`.
- `./scripts/qa/audit-observability.sh --mode runtime --context kind-dev --strict-runtime --json`  
  - Fails because namespace `velero` is absent (expected for non-prod local lane).

Interpretation:
- GCP parity and core cronjob existence checks are healthy across all three lanes in non-strict mode.
- Remaining strict-runtime failures are environmental (backup verification artifacts/pipeline shape), not the SLO dashboard parity path fixed in this pass.

## Evidence JSON (excerpt)

```json
{"project":"mereka-lms","context":"gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster","app_namespace":"mereka-lms","velero_namespace":"velero","include_legacy":0,"checks":[{"name":"repo: monitoring json files are valid","ok":1,"exit_code":0},{"name":"runtime: gcp monitoring/logging objects exist","ok":1,"exit_code":0},{"name":"runtime: key in-cluster cronjobs exist","ok":1,"exit_code":0},{"name":"runtime: velero cronjob freshness is within SLO","ok":1,"exit_code":0}],"failures":0}
```

## Next actions

1. Confirm parity rerun remains stable after any dashboard or monitoring manifest changes.
2. Use the deterministic remediation sequence captured at:
  - `docs/evidence/observability/observability-monitoring-dashboard-plan-2026-02-26.md`
3. Continue with tracking tasks `OBS-052` to `OBS-060` in `docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md`.
