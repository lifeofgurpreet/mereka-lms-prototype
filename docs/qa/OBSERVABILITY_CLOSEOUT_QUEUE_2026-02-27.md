# Observability Closeout Queue (Mereka LMS) — 2026-02-27

## Goal
Close remaining first-class observability blockers in a strict lane-safe sequence (dev/kind → rke2-nonprod → prod), without touching non-observability application behavior.

## Execution doctrine (non-negotiable)
- One ticket per lane wave.
- No merge/push from this lane until evidence from strict runtime first-class command is attached.
- Keep evidence identity consistent: `env=<lane>;profile=<profile>;context=<context>;project=<project>`.
- Do not patch dev-only services outside explicit `dev` lane tasks.

## Next 10 Large Tasks (in order)

| Step | Ticket | Lane target | Definition of done |
|---|---|---|---|
| 1 | OBS-EXT-061 | nonprod → prod (same pattern) | `LMS/CMS /metrics` route checks produce `status_code: 200` in strict runtime wave and payload samples in `observability-metrics-lms-runtime.md` / `observability-metrics-cms-runtime.md` with `# HELP`, `# TYPE`, and numeric samples. |
| 2 | OBS-EXT-063 | nonprod → prod | Prometheus rule for LMS/CMS (`lms-alerts`) and route visibility pass for `observability-cms-prometheus-wiring-runtime.md` with target + rule hit count > 0. |
| 3 | OBS-EXT-064 | nonprod → prod | `caddy-metrics` exists in expected namespace and `caddy-alerts` present in Prometheus `/api/v1/rules` with evidence in `observability-caddy-prometheus-wiring-runtime.md` and index. |
| 4 | OBS-EXT-065 | nonprod → prod | `mfe-metrics` + `services-alerts` both visible in target/rules evidence; no drift in object names across namespaces. |
| 5 | OBS-EXT-066 | nonprod → prod | High-signal ServiceMonitors for forum/discovery/ecommerce/credentials/purchase-gateway present and counted in `activeTargets`. |
| 6 | OBS-EXT-067 | nonprod → prod | `slo-recording-rules`, `video-alerts`, `ora2-operations` appear in Prometheus rule groups and load cleanly by strict runtime check. |
| 7 | OBS-EXT-068 | dev/kind only | `xqueue-metrics` and `mux-delivery-monitor` are present only where expected; nonprod/prod do not regress after closing dev. |
| 8 | OBS-EXT-069 | nonprod (pilot wave), then prod | `AC-OVR-025` and `AC-OVR-029` pass in strict mode consistently with parseable `observability-compliance-runtime.json`; no schema mismatch and no non-JSON stderr pollution. |
| 9 | OBS-070 | all lanes | Publish final handoff artifact set linking `OBS-053..057`, `OBS-061..069`, and open exception list for `OBS-060`; owners confirmed for each blocked item. |
| 10 | Parity closeout | nonprod → prod (3 consecutive windows) | `PAR-001` and `PAR-002` rollups close after three consecutive no-skip/no-fail strict windows with identical identity context. |

## Lane command sequence

Run exactly this after each ticket closure attempt:

```bash
OBSERVABILITY_ENV_LABEL=<lane> \
OBSERVABILITY_DISPATCH_PROFILE=<nonprod|prod> \
OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_<LANE>_K8S_CONTEXT \
./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

Then verify these artifacts exist and pass:
- `var/ci/observability-compliance-runtime.json`
- `var/ci/observability-runtime-verify-runtime.md`
- `var/ci/observability-first-class-runtime-evidence-index.json`
- `var/ci/observability-metrics-lms-runtime.md`
- `var/ci/observability-metrics-cms-runtime.md`
- component wiring evidence files referenced by the active ticket (for example `observability-caddy-prometheus-wiring-runtime.md`, `observability-mfe-prometheus-wiring-runtime.md`, ...).

## Known hard stops

1. Do not move to nonprod/prod service coverage until `OBS-EXT-061` shows passing `/metrics` payload checks in at least one non-prod strict run.
2. Do not move to `OBS-EXT-068` before core coverage (`OBS-063` through `OBS-067`) is clear.
3. Do not move to handoff (`OBS-070`) until lane evidence identity is stable across all artifact files.

## Operator ownership

- **Observability runtime wave owner:** platform SRE
- **App instrumentation owner (LMS/CMS):** platform/apps
- **Workflow and evidence owner:** release operations
- **Exception log owner:** on-call lead at run close

