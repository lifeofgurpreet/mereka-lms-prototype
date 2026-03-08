# Observability Closeout Queue (Mereka LMS) — 2026-02-27

## Goal
Close remaining first-class observability blockers in a strict lane-safe sequence (dev/kind → rke2-nonprod → prod), without touching non-observability application behavior.

## Current state (single-source)

- Latest strict run snapshot (2026-02-27T11:08:53Z):
  - Command: `OBSERVABILITY_ENV_LABEL=dev OBSERVABILITY_DISPATCH_PROFILE=nonprod OBSERVABILITY_K8S_CONTEXT=kind-dev OBSERVABILITY_GCP_PROJECT=mereka-lms ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`
  - Result: `pass` summary in coverage `66/81` (failures: `15`), step failures: `4`.
  - `step_results=var/ci/observability-first-class-runtime-step-results.md`
  - `observability-compliance-runtime.json`: `pass 4 / fail 5 / skip 0` (`AC-OVR-016` / `/metrics` payload and `AC-OVR-026` parser noise still failing)
  - `observability-runtime-verify-runtime.txt`: `AC-OVR-016` reports `LMS /metrics` and `CMS /metrics` both `status_code: 000`.
  - Evidence identity used: `env=dev;profile=nonprod;context=kind-dev;project=mereka-lms`.
- Important artifact naming note: this run writes `var/ci/observability-runtime-verify-runtime.txt` (not `.md`). Keep docs and checks aligned to `.txt` in all new commands.
- Blocking evidence remains:
  - `var/ci/observability-metrics-lms-runtime.md`: `status_code=000`, zero payload counters.
  - `var/ci/observability-metrics-cms-runtime.md`: `status_code=000`, zero payload counters.
  - `var/ci/observability-logging-pipeline-runtime.txt`: promtail pods `0/0`, no log-source JSON guarantees.
  - `var/ci/observability-coverage-runtime.md`: runtime misses now:
    - `xqueue-metrics`, `mux-delivery-monitor`, `mfe-metrics`, `forum-metrics`, `discovery-metrics`, `ecommerce-metrics`, `credentials-metrics`, `purchase-gateway-metrics`
    - Prometheus rules: `caddy-alerts`, `services-alerts`, `video-alerts`, `email-alerts`, `library-alerts`, `ora2-operations`, `credentials-alerts`
- Last legacy nonprod strict output (`var/ci/runtime-nonprod-check/observability-compliance-runtime.json`) remains from a previous path/context and is not the active handoff evidence set.
- Blocking status remains: LMS/CMS `/metrics` response for active strict lanes still 000 in runtime compliance; metric payload counters in `observability-metrics-*-runtime.md` remain zero, and caddy/mfe wiring target/rule match evidence is zero.
- Current acceptance condition before any lane progression: one consistent strict run with AC-OVR-016 passing and stable identity strings across all evidence artifacts.

## Execution doctrine (non-negotiable)
- One ticket per lane wave.
- No merge/push from this lane until evidence from strict runtime first-class command is attached.
- Keep evidence identity consistent: `env=${lane};profile=${OBSERVABILITY_DISPATCH_PROFILE};context=${OBSERVABILITY_K8S_CONTEXT};project=${OBSERVABILITY_GCP_PROJECT}`.
- Do not patch dev-only services outside explicit `dev` lane tasks.

Hard stop before each wave:

1. Confirm lane identity variables resolve:
   - `OBS_PARITY_NONPROD_K8S_CONTEXT` for `lane=dev`/`nonprod`, `OBS_PARITY_PROD_K8S_CONTEXT` for `lane=prod`
   - target namespace and profile in `OBSERVABILITY_DISPATCH_PROFILE`
2. Confirm runtime output file ownership and identity fields are preserved:
   - `observability-first-class-runtime-evidence-index.json`
   - `evidence_identity` must match across preflight, compliance, verifier, and index outputs.

3. Confirm no lane artifacts were stale (timestamp older than run window) before rerunning a previously passed wave.
   - If stale timestamps exist, remove only stale files for that specific lane evidence folder before rerun.

## Next 10 Large Tasks (in order)

| Step | Ticket | Lane target | Definition of done |
|---|---|---|---|
| 1 | OBS-EXT-061 | nonprod → prod (same pattern) | `LMS/CMS /metrics` route checks produce `status_code: 200` in strict runtime wave and payload samples in `observability-metrics-lms-runtime.md` / `observability-metrics-cms-runtime.md` with `# HELP`, `# TYPE`, and numeric samples. |
| 2 | OBS-EXT-063 | nonprod → prod | CMS `/metrics` path and route contract are normalised; `observability-metrics-cms-runtime.md` shows `status_code: 200` + valid payload; `observability-cms-prometheus-wiring-runtime.md` and `observability-lms-prometheus-wiring-runtime.md` both show CMS/LMS monitoring target+rule hits.
| 3 | OBS-EXT-064 | nonprod → prod | `caddy-metrics` exists in expected namespace and `caddy-alerts` present in Prometheus `/api/v1/rules` with evidence in `observability-caddy-prometheus-wiring-runtime.md` and index. |
| 4 | OBS-EXT-065 | nonprod → prod | `mfe-metrics` + `services-alerts` both visible in target/rules evidence; no drift in object names across namespaces. |
| 5 | OBS-EXT-066 | nonprod → prod | High-signal ServiceMonitors for forum/discovery/ecommerce/credentials/purchase-gateway present and counted in `activeTargets`. |
| 6 | OBS-EXT-067 | nonprod → prod | `slo-recording-rules`, `video-alerts`, `ora2-operations` appear in Prometheus rule groups and load cleanly by strict runtime check. |
| 7 | OBS-EXT-068 | dev/kind only | `xqueue-metrics` and `mux-delivery-monitor` are present only where expected; nonprod/prod do not regress after closing dev. |
| 8 | OBS-EXT-069 | nonprod (pilot wave), then prod | `AC-OVR-025` and `AC-OVR-029` pass in strict mode consistently with parseable `observability-compliance-runtime.json`; no schema mismatch and no non-JSON stderr pollution. |
| 9 | OBS-070 | all lanes | Publish final handoff artifact set linking `OBS-053..057`, `OBS-061..069`, and open exception list for `OBS-060`; owners confirmed for each blocked item. |
| 10 | Parity closeout | nonprod → prod (3 consecutive windows) | `PAR-001` and `PAR-002` rollups close after three consecutive no-skip/no-fail strict windows with identical identity context. |


## Execution acceptance matrix for the next 10 large tasks

| Task | Primary owner | Must-have evidence | Pass condition |
|---|---|---|---|
| OBS-EXT-061 | platform/apps + SRE | `observability-metrics-lms-runtime.md`, `observability-metrics-cms-runtime.md` | LMS/CMS `/metrics` probe returns 200 and exposition has `# HELP`, `# TYPE`, numeric samples |
| OBS-EXT-062 | platform/apps | same as above | `ROOT_URLCONF_OVERRIDES` includes `openedx_prometheus.urls` and `/metrics`/`/metrics/` probes return 200 |
| OBS-EXT-063 | SRE | `observability-cms-prometheus-wiring-runtime.md`, `observability-lms-prometheus-wiring-runtime.md` | CMS and LMS wiring target/rule matches both > 0 |
| OBS-EXT-064 | platform/observability | `observability-caddy-prometheus-wiring-runtime.md` | caddy target and `caddy-alerts` rule group detected and loaded |
| OBS-EXT-065 | platform/observability | `observability-mfe-prometheus-wiring-runtime.md` | mfe target and `services-alerts` rule group detected and loaded |
| OBS-EXT-066 | platform/observability | per-service wiring MD files | forum/discovery/ecommerce/credentials/purchase-gateway ServiceMonitors in activeTargets |
| OBS-EXT-067 | platform/observability | `observability-slo-rules-prometheus-wiring-runtime.md`, `observability-video-rules-prometheus-wiring-runtime.md`, `observability-ora2-rules-prometheus-wiring-runtime.md` | `slo-recording-rules`, `video-alerts`, `ora2-operations` in `/api/v1/rules` |
| OBS-EXT-068 | platform/observability | `observability-dev-xqueue-prometheus-wiring-runtime.md`, `observability-dev-mux-prometheus-wiring-runtime.md` | dev-only objects present in dev and intentionally absent elsewhere |
| OBS-EXT-069 | release ops | `observability-compliance-runtime.json`, `observability-runtime-verify-runtime.md` | AC-OVR-025/029 strict JSON parse + deterministic identity schema |
| OBS-070 | release ops | handoff bundle docs + evidence index | all child ACs linked, owners assigned, exception criteria published |
| PAR closeout | release ops | rollup artifacts (3 windows) | `PAR-001` and `PAR-002` closed with no-skip/no-fail for nonprod/prod |


## Lane command sequence

Run exactly this after each ticket closure attempt:

```bash
lane="nonprod" # dev | nonprod | prod

OBSERVABILITY_ENV_LABEL="${lane}"
case "${lane}" in
  dev|nonprod)
    OBSERVABILITY_DISPATCH_PROFILE="nonprod"
    OBSERVABILITY_K8S_CONTEXT="$OBS_PARITY_NONPROD_K8S_CONTEXT"
    ;;
  prod)
    OBSERVABILITY_DISPATCH_PROFILE="prod"
    OBSERVABILITY_K8S_CONTEXT="$OBS_PARITY_PROD_K8S_CONTEXT"
    ;;
  *)
    echo "Unknown lane: ${lane}" >&2
    exit 1
    ;;
esac

OBSERVABILITY_GCP_PROJECT="${OBS_PARITY_NONPROD_GCP_PROJECT:-mereka-lms}"
if [ "${lane}" = prod ] && [ -n "${OBS_PARITY_PROD_GCP_PROJECT:-}" ]; then
  OBSERVABILITY_GCP_PROJECT="$OBS_PARITY_PROD_GCP_PROJECT"
fi

./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```
Use `lane="dev"` or `lane="nonprod"` for nonprod profile and `lane="prod"` for production profile.

Then verify these artifacts exist and pass:
- `var/ci/observability-compliance-runtime.json`
- `var/ci/observability-runtime-verify-runtime.txt`
- `var/ci/observability-first-class-runtime-evidence-index.json`
- `var/ci/observability-metrics-lms-runtime.md`
- `var/ci/observability-metrics-cms-runtime.md`
- component wiring evidence files referenced by the active ticket (for example `observability-caddy-prometheus-wiring-runtime.md`, `observability-mfe-prometheus-wiring-runtime.md`, ...).


## Most recent executed blocker evidence (2026-02-27)

- `./scripts/qa/validate-observability-compliance.sh --mode runtime --json` (non-strict) output now explicitly reports:
  - LMS `/metrics`: `status=fail`, `expected 200`, got `000`.
  - CMS `/metrics`: `status=fail`, `expected 200`, got `000`.
  - Prometheus payload validation fails for both endpoints (`help/type/sample` unavailable).
  - AC-OVR-026 pass/fail message contains inline runtime verification text, which is evidence-noise and should be treated as a parser determinism issue before `AC-OVR-025`/`AC-OVR-029` can be closed.
- Compliance JSON now fails fast with exit code 1 and blocks downstream runtime verification and first-class evidence-index generation.

## Known hard stops

1. Do not move to nonprod/prod service coverage until `OBS-EXT-061` shows passing `/metrics` payload checks in at least one non-prod strict run.
2. Do not move to `OBS-EXT-068` before core coverage (`OBS-063` through `OBS-067`) is clear.
3. Do not move to handoff (`OBS-070`) until lane evidence identity is stable across all artifact files.

### Wave 2.1 evidence acceptance checks for OBS-EXT-063

After each `OBS-EXT-063` run:

- `observability-metrics-cms-runtime.md`:
  - `status_code: 200`
  - payload counters for `# HELP`, `# TYPE`, and numeric sample rows
  - `metric_path` shows `/metrics` or `/metrics/`
- `observability-cms-prometheus-wiring-runtime.md`:
  - target match count > 0 for `cms-metrics`
  - rule match count > 0 for `cms-alerts`
- `observability-lms-prometheus-wiring-runtime.md`:
  - no regression vs previously passing LMS targets/rules
- `observability-first-class-runtime-evidence-index.json`:
  - includes all expected file names for LMS/CMS metrics and wiring evidence
  - identity strings are equal across preflight, compliance, and wiring outputs

## Operator ownership

- **Observability runtime wave owner:** platform SRE
- **App instrumentation owner (LMS/CMS):** platform/apps
- **Workflow and evidence owner:** release operations
- **Exception log owner:** on-call lead at run close
