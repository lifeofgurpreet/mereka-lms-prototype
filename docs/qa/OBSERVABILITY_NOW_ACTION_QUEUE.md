# Observability Now Queue — Immediate Execution (2026-02-27)

_Last evidence snapshot consulted: `var/ci/runtime-nonprod-check/observability-compliance-runtime.json`, `var/ci/rke2-nonprod-runtime-check/observability-runtime-verify-runtime.txt`, `var/ci/rke2-nonprod-runtime-check/observability-metrics-lms-runtime.md`, `var/ci/rke2-nonprod-runtime-check/observability-caddy-prometheus-wiring-runtime.md`, `var/ci/rke2-nonprod-runtime-check/observability-mfe-prometheus-wiring-runtime.md`_


## Targeted 2026-02-27 run results (non-strict runtime)

Command used:
- `OBSERVABILITY_ENV_LABEL=nonprod`
- `OBSERVABILITY_DISPATCH_PROFILE=nonprod`
- `OBSERVABILITY_K8S_CONTEXT=rke2-nonprod`
- `OBSERVABILITY_GCP_PROJECT=mereka-lms`
- `OBSERVABILITY_SCRIPT_TIMEOUT=120`
- `OBSERVABILITY_K8S_TIMEOUT=30`
- `./scripts/qa/run-observability-first-class.sh --mode runtime`

Observed:
- `validate-observability-compliance.sh --mode runtime --json` returns 5 fails + exit code `1`.
- Hard failures still centered on AC-OVR-016 LMS/CMS metrics endpoint contract.
- Root corruption signal: AC-OVR-026 message contains concatenated runtime verification text blob, indicating stdout/stderr mixing in compliance pipeline.
- CMS logs also show app startup blocker: missing `XQUEUE_PASSWORD` env var in `deploy/cms` before probes recover.
- LMS `/metrics` behavior includes host-dependent failure:
  - without explicit allowed host: `DisallowedHost` (`400`);
  - with domain host header: `500` while the app is still recovering DB/site bootstrap.

This is blocking strict execution continuity because the first-class wrapper exits at compliance step and never writes runtime verify/evidence-index artifacts in strict/non-strict mode when fail count > 0.

## Live evidence snapshot (2026-02-27)

- `var/ci/observability-compliance-runtime.json`: pass 4 / fail 5 / skip 0 (strict runtime output)
- `var/ci/runtime-nonprod-check/observability-compliance-runtime.json`: pass 4 / fail 5 / skip 0 (strict nonprod output)
- `var/ci/rke2-nonprod-runtime-check/observability-runtime-verify-runtime.txt`: pass 9 / fail 28 / skip 2, identity `env=rke2-nonprod;profile=rke2-nonprod;context=rke2-nonprod;project=mereka-lms`
- `observability-metrics-lms-runtime.md`: historically `status_code=000`; in host-aware tests today, `400` due host policy and `500` when DB/site bootstrap is incomplete.
- `observability-metrics-cms-runtime.md`: historically `status_code=000` while CMS crashloops on env-contract failure.
- `observability-caddy-prometheus-wiring-runtime.md`: `target_matches: 0`, `rule_group_matches: 0`
- `observability-mfe-prometheus-wiring-runtime.md`: `target_matches: 0`, `rule_group_matches: 0`

### Live top-10 blockers (ranked)

1. LMS `/metrics` endpoint hard 000 in strict lane.
2. CMS `/metrics` endpoint hard 000 in strict lane.
3. LMS/CMS metrics payload markers absent (`help/type/sample` all zero).
4. Caddy target wiring not found by validator (`target_matches: 0`).
5. Caddy alert rule group not found (`rule_group_matches: 0`).
6. MFE target wiring not found by validator (`target_matches: 0`).
7. MFE alert rule group not found (`rule_group_matches: 0`).
8. Evidence identity still at `env=rke2-nonprod;profile=rke2-nonprod` (must be lane profile/nonprod/prod depending on run).
9. Strict runtime summary remains mismatch-prone between compliance file and runtime verify artifact.
10. No `observability-first-class-runtime-evidence-index.json` file under `var/ci/` at last check window.

## What is not done today
- App-level metrics contract is still blocked, so downstream AC-OVR-016/018+ checks cannot prove runtime readiness even when monitoring objects exist.
- Latest strict evidence is still inconsistent in identity when lane env/profile is not passed through runtime preflight (some snapshots still show `env=unknown;profile=custom` while others are lane-stable).
- 000 response in both LMS/CMS `/metrics` payload files indicates the runtime probe is not reaching a scrapeable Prometheus endpoint in this lane.
- Caddy and MFE wiring evidence currently shows zero Prometheus target and rule matches (`target_matches: 0`, `rule_group_matches: 0`) in nonprod runtime evidence.

## Current blocking signal
- AC-OVR-016 is failing in strict runtime (`PASS 4 / FAIL 5 / SKIP 0`):
  - LMS `/metrics` previously `status_code=000`, then `400`, then `500` as host and DB state shift.
  - CMS `/metrics` currently blocked by env-contract recovery (`XQUEUE_PASSWORD` not set in runtime pod before this fix).
  - Payload proof missing (`help_count=0`, `type_count=0`, `numeric_sample_count=0`)
- Same `/metrics` failures repeat under lane-stable nonprod run (`status_code=000`, `evidence_identity=env=rke2-nonprod;profile=rke2-nonprod;context=rke2-nonprod`) with same zero-byte payloads.
- AC-OVR-026 fail signal in strict output is from downstream strict wrapper output mismatch rather than direct schema failure; requires deterministic evidence-index and evidence filename integrity to avoid false negatives.
- Wiring verification artifacts for `caddy-metrics` and `mfe-metrics` report `target_matches: 0` and `rule_group_matches: 0` before object closure is claimed.
- `run-observability-first-class.sh --mode runtime --strict` currently does not complete in our environment unless externally bounded; do lane-safe per run with short `OBSERVABILITY_SCRIPT_TIMEOUT` when debugging command hangs.

## Execution contract before wave advancement
- Set lane identity per run before any strict wave:
  - `OBSERVABILITY_ENV_LABEL=nonprod` (or `prod`)
  - `OBSERVABILITY_DISPATCH_PROFILE=nonprod|prod`
  - `OBSERVABILITY_K8S_CONTEXT=<context>`
  - `OBSERVABILITY_GCP_PROJECT=<gcp-project>`
- For first-wave stabilization, cap runtimes:
  - `OBSERVABILITY_SCRIPT_TIMEOUT=120`
  - `OBSERVABILITY_K8S_TIMEOUT=30`
- Add a hard check before each run:
  - `[[ -n "$OBSERVABILITY_ENV_LABEL" && -n "$OBSERVABILITY_DISPATCH_PROFILE" && -n "$OBSERVABILITY_K8S_CONTEXT" ]] || { echo "Missing lane vars"; exit 1; }`
- Required identity baseline for any pass artifact:
  - `env=<lane>;profile=<nonprod|prod>;context=<context>;project=<project>`
- Require evidence identity normalization to remain stable:
  - `env=<lane>;profile=<nonprod|prod>;context=<context>;project=<project>`

## Immediate next 10 tasks (do in order)

1. **Close AC-OVR-016 in LMS (P0)**
   - Target: `LMS /metrics` returns HTTP 200 and Prometheus exposition in strict runtime check.
   - Run command and artifact:
     `OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod OBSERVABILITY_K8S_CONTEXT=<nonprod_ctx> OBSERVABILITY_GCP_PROJECT=<nonprod_project> ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`
   - Deliverable: `var/ci/observability-metrics-lms-runtime.md`

2. **Close AC-OVR-016 in CMS (P0)**
   - Target: CMS `/metrics` returns HTTP 200 and valid payload with payload markers.
   - Same command as above with lane identity set to nonprod/prod; artifact: `var/ci/observability-metrics-cms-runtime.md`

3. **Validate runtime URL mount (P0, `OBS-EXT-061`/`OBS-EXT-062`/`OBS-EXT-063`)**
   - Confirm `ROOT_URLCONF_OVERRIDES` + `openedx_prometheus.urls` + trailing-slash route are effective in built manifests/images used in nonprod/prod.

4. **Complete `OBS-EXT-064` (`OBS-053`) — caddy metrics/rules wave**
   - Artifact set: `observability-caddy-prometheus-wiring-runtime.md`, monitoring target evidence for caddy SM and alerts.
   - Blocker right now: target/rule match evidence is zero in active nonprod snapshots.

5. **Complete `OBS-EXT-065` (`OBS-054`) — mfe metrics/rules wave**
   - Artifact set: `observability-mfe-prometheus-wiring-runtime.md` + services-alerts rule evidence.
   - Blocker right now: target/rule match evidence is zero in active nonprod snapshots.

6. **Complete `OBS-EXT-066` (`OBS-055`) — commerce/forum surface monitors wave**
   - Ensure required service ServiceMonitors appear in runtime evidence and active Prometheus targets.

7. **Complete `OBS-EXT-067` (`OBS-056`) — rules wave**
   - Verify `slo-recording-rules`, `video-alerts`, `ora2-operations` names in `/api/v1/rules` evidence.

8. **Complete `OBS-EXT-068` (`OBS-057`) — dev-only monitor wave**
   - Verify `xqueue-metrics` and `mux-delivery-monitor` are present in dev lane and intentionally absent elsewhere if expected.

9. **Harden strict JSON determinism (`OBS-EXT-069`)**
   - Confirm `AC-OVR-025` and `AC-OVR-029` pass cleanly on strict re-run and `observability-compliance-runtime.json` is machine-parseable with no log pollution.

10. **Publish GA exception log (`OBS-060`)**
    - Produce/refresh exception list with concrete close criteria while object waves remain open so release readiness has explicit transparency.

## Hard stop before moving to next wave
- Do not advance from Priority A → B before at least one nonprod proof has both LMS/CMS `/metrics` payload checks passing with status 200.
- For each ticket, capture the strict proof artifacts and include them in the handoff package.

## Day-1 completion set
1. Clear `AC-OVR-016` for LMS/CMS in one nonprod strict run.
2. Confirm `observability-first-class-runtime-evidence-index.json` includes: compliance/runtime JSON+MD + both LMS/CMS metrics payload artifacts + current wiring checks.
3. Confirm every strict evidence file carries the same `evidence_identity` values.
4. Only then execute `OBS-EXT-064` → `OBS-EXT-068` in that same lane.


## Single authoritative lane run (copy/paste)

```bash
lane="nonprod"  # dev | nonprod | prod
OBSERVABILITY_ENV_LABEL="${lane}"

case "${lane}" in
  dev|nonprod)
    OBSERVABILITY_DISPATCH_PROFILE="nonprod"
    OBSERVABILITY_K8S_CONTEXT="${OBS_PARITY_NONPROD_K8S_CONTEXT}"
    ;;
  prod)
    OBSERVABILITY_DISPATCH_PROFILE="prod"
    OBSERVABILITY_K8S_CONTEXT="${OBS_PARITY_PROD_K8S_CONTEXT}"
    ;;
  *)
    echo "unsupported lane: ${lane}" >&2
    exit 1
    ;;
esac

OBSERVABILITY_GCP_PROJECT="${OBS_PARITY_NONPROD_GCP_PROJECT:-mereka-lms}"
if [ "${lane}" = "prod" ] && [ -n "${OBS_PARITY_PROD_GCP_PROJECT:-}" ]; then
  OBSERVABILITY_GCP_PROJECT="${OBS_PARITY_PROD_GCP_PROJECT}"
fi

export OBSERVABILITY_SCRIPT_TIMEOUT=120
export OBSERVABILITY_K8S_TIMEOUT=30

./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

### Required artifact checklist for each strict wave

- `var/ci/observability-compliance-runtime.json`
- `var/ci/observability-runtime-verify-runtime.md`
- `var/ci/observability-first-class-runtime-evidence-index.json`
- `var/ci/observability-metrics-lms-runtime.md`
- `var/ci/observability-metrics-cms-runtime.md`
- `var/ci/observability-caddy-prometheus-wiring-runtime.md`
- `var/ci/observability-mfe-prometheus-wiring-runtime.md`
- `var/ci/observability-slo-rules-prometheus-wiring-runtime.md` (when running OBS-EXT-067)

### Current lane-unsafe signals to clear first

- Nonprod `status_code=000` for LMS/CMS `/metrics` in strict evidence.
- `help_count`, `type_count`, and `numeric_sample_count` still zero in `observability-metrics-*-runtime.md`.
- `target_matches: 0` and `rule_group_matches: 0` for caddy/mfe wiring files.
- Mixed evidence identity values (legacy `env=unknown;profile=custom`) in any strict artifact.

## Lane ownership and decision gates

- **SRE owner (runtime command + cluster-safe evidence execution):** platform SRE
- **LMS/CMS instrumentation owner (endpoint fixes and middleware visibility):** platform/apps
- **Monitoring manifests owner (ServiceMonitors/PrometheusRules/targets):** platform/observability
- **Release/readiness owner (rollups + exception gating):** release ops
- **Evidence integrity owner (identity + artifact schema + JSON cleanliness):** release ops

## Exact close criteria before moving to the next task

1. AC-OVR-016 pass for LMS/CMS in the active lane (`status_code: 200`, non-zero `# HELP`/`# TYPE`/sample evidence).
2. Evidence identity in all strict artifacts is exactly:
   `env=<lane>;profile=nonprod|prod;context=<k8s_context>;project=<gcp_project>`.
3. At least one strict run in the active lane completed with full file set above present.
4. Any task that passes must include a dated evidence note in `docs/evidence` or `var/ci` for handoff.
