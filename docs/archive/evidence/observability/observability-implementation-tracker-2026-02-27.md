# Observability Execution Tracker (Open-edx / Mereka LMS)

## Date
- 2026-02-27

## Scope
- `mereka-lms` repository
- Primary focus: first-class observability for dev/non-prod and runtime parity (Prometheus, Grafana, Loki, Tempo, alerting)
- This tracker records what has been validated by repo/runtime scripts and what remains.

## What has been completed in this lane

1. Fixed runtime recursion risk in `scripts/qa/validate-observability-compliance.sh`
   - File: `scripts/qa/validate-observability-compliance.sh`
   - Change: `run_negative_control_check()` now invokes `verify-observability-validation.sh` in **local mode only** and sets `VERIFY_OBS_SKIP_LIVE_CHECKS=1`, removing a nested re-entry path that could recurse into compliance checks.
   - Effect: `--mode local --strict` no longer gets stuck.

2. Confirmed local compliance checks pass with strict mode
   - Command executed: `./scripts/qa/validate-observability-compliance.sh --mode local --json --strict`
   - Result: PASS (JSON summary only 6 checks in local compliance scope, all passing)

3. Confirmed repository validation still passes after changes
   - Command executed: `./scripts/qa/verify-observability-validation.sh --mode local --strict`
   - Result: PASS across manifest-level checks
   - Summary: `PASS: 278`, `FAIL: 0`, `SKIP: 12`, `TOTAL: 290`

## Current gap status (from direct runtime probe)

1. `verify-observability-runtime.sh` shows runtime failures in this environment:
   - `AC-OVR-016`: LMS /metrics endpoint returns `000`
   - `AC-OVR-016`: CMS /metrics endpoint returns `000`
   - `AC-OVR-018`: GCP uptime checks count `0` vs expected 13
   - `AC-OVR-019`: no GCP alert policies found
   - `AC-OVR-020` did not complete within a 20s probe window and should be re-run in full-length run

2. No evidence of environment-level cluster identity/auth gating in this lane from the executed runtime quick probe (this appears to be runtime connectivity/env not repo-code driven).

## Remaining work plan (execution order)

### P0 — Runtime observability unblock for dev/non-prod
1. Validate kubectl context/profile for dev and any VPS/GKE lane targets before runtime checks.
2. Resolve LMS/CMS `/metrics` endpoint availability from pod context for both workloads.
3. Confirm `django-prometheus` and `openedx_prometheus` route wiring for both LMS and CMS in effective runtime config.
4. Add explicit cluster/runtime gating to avoid false negatives when live probes are run without auth/context.
5. Re-run: `./scripts/qa/verify-observability-runtime.sh` with lane-specific `VERIFY_*` vars.

### P1 — GCP monitoring convergence
6. Reconcile expected uptime check set from `infrastructure/monitoring/uptime/*.json` against live GCP state.
7. Verify `gcloud` auth/workload/project context used by runtime scripts for every CI lane.
8. Deploy missing uptime checks and alert policies in dev/non-prod as configured in repo payloads.
9. Add monitoring of `AC-OVR-018/019` failures in PR/ops preflight with environment-aware skips.
10. Re-run runtime script and confirm `AC-OVR-018`, `AC-OVR-019`, `AC-OVR-020`, `AC-OVR-021` status.

### P1 — Compliance and evidence hardening
11. Add small artifact generation for runtime failures (already supported by scripts) and enforce retention in `docs/archive/evidence/observability`.
12. Wire runtime evidence output path into `run-observability-first-class.sh` for non-prod lane.
13. Ensure `run-observability-first-class.sh` is used for `dev/local` and `runtime` matrix with lane-specific evidence IDs.
14. Add a one-line execution matrix in runbook for lane order: `dev -> staging(prepped) -> prod`.

### P2 — Gating and workflow robustness
15. Confirm `.github/workflows/observability-compliance.yml` remains PR-triggered and only runs strict checks on monitoring path diffs.
16. Add `timeout` wrappers with explicit fail messages around slow network/GCP queries.
17. Add a fail-fast short-path when both kubectl and gcloud are unavailable but runtime mode is requested (avoid long hangs).
18. Add dry-run mode for CI that stores artifacts even when live tooling absent.
19. Verify workflow can tolerate transient external API unavailability by using `STRICT` mode only after retries.

### P2 — Grafana and tracing coverage
20. Validate required dashboard contract in runtime lane with token-bearing API access.
21. Add one scripted smoke path for `bbi-app-mereka-lms` panel presence and required query fragments.
22. Capture Tempo/Logi pipeline evidence for at least one canonical route in each lane.

### P2 — Long-horizon reliability improvements
23. Compare `ac` check stability across repeated runs and capture non-deterministic flake patterns.
24. Reduce duplicate local checks by memoizing expensive file discovery in `verify-observability-validation.sh` if repeated in loops.
25. Add targeted tests for observability script behavior under missing `jq/python3` dependencies.
26. Add runbook step for temporary skip behavior when GCP tools are intentionally unavailable.
27. Add owner notes into `docs/operations/` for each lane’s acceptance criteria.

### P3 — Expansion and parity hardening
28. Extend `observability` evidence schema with component-level health and version tags (script, image, policy revision).
29. Add SLI/alert query smoke tests for LMS, CMS, and DB services in non-prod.
30. Add runbook-driven verification for forum/discovery/ecommerce/credentials/cms/caddy metrics parity in dev and production.
31. Add alert annotation lint across custom alert files and ensure Grafana datasource references remain valid.
32. Verify tenant-isolation observability dashboards include per-tenant attribution tags.
33. Confirm monitoring namespaces are consistently labeled across ServiceMonitors in dev/non-prod.
34. Ensure docs reflect whether observability checks are hard-required vs advisory per environment.
35. Add evidence-closeout checklist before any production rollout.
36. Define a recurring weekly observability debt triage cadence tied to AC IDs.
37. Capture known false positives and add explicit skip rationale comments in scripts.
38. Close loop with owners for every failing check and map to actionable AC IDs.
39. Keep this tracker updated with PASS/FAIL delta on each lane run.
40. Confirm no config drifts in `deploy/k8s/overlays` for monitoring manifests.

## Immediate next priorities for handoff
- P0.1, P0.2, P0.3, P1.6, P1.10, P2.15.
- If you want, I can convert these to `.beads` issue rows with exact acceptance checks next.
