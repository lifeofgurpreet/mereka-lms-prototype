# OBS-EXT-HANDOFF-2026-02-27: Observability Wave-2 Runtime Closure Handoff

**Owner:** Observability Team / Platform SRE
**Status:** in_progress
**Target date:** 2026-03-06
**Depends on:** `OBS-053..057`, `OBS-058`, and `docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md`

## Purpose

Close the remaining first-class observability blockers in the non-prod/dev/prod parity lanes in strict lane order, then harden strict mode gating behavior.

## Scope

- P0 execution closure tasks only: `OBS-EXT-061`, `OBS-EXT-062`, `OBS-EXT-063` and `OBS-EXT-064` through `OBS-EXT-068`.
- P1 strict-mode hardening: `OBS-EXT-069`.
- `OBS-EXT-070` is the implementation parent handoff and evidence aggregator only.
- Excludes new feature expansion (tempo/correlation roadmap) beyond current AC envelope.

## Execution sequence (lane mode)

1. `OBS-EXT-061` — close runtime app-metrics image/manifest drift.
2. `OBS-EXT-062` — make LMS `/metrics` contract concrete.
3. `OBS-EXT-063` — align CMS metrics route and monitor contract.
4. `OBS-EXT-064` — finish coverage object set `OBS-053`.
5. `OBS-EXT-065` — finish coverage object set `OBS-054`.
6. `OBS-EXT-066` — finish coverage object set `OBS-055`.
7. `OBS-EXT-067` — finish coverage object set `OBS-056`.
8. `OBS-EXT-068` — finish coverage object set `OBS-057`.
9. `OBS-EXT-069` — stabilize strict runtime/compliance JSON behavior.
10. `OBS-EXT-070` — close parent handoff with artifact references.

## Required command for each closure wave

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

Use `lane="dev"` or `lane="nonprod"` for nonprod profile and `lane="prod"` for production.

## Exit criteria per lane

- `observability-compliance-runtime.json`
- `observability-runtime-verify-runtime.md`
- `observability-first-class-runtime-evidence-index.json`
- `observability-metrics-lms-runtime.md` and `observability-metrics-cms-runtime.md`
- lane-specific per-object evidence files for each resource family above.
- `evidence_identity` equality check must pass between preflight, compliance, and runtime verifier outputs.

## Failure handling

If a lane fails an object-specific check:
- isolate and patch only that wave,
- rerun only the affected resource verification,
- do not progress to next ticket until the same lane exits without new misses.

## Immediate priorities after Wave-2 completion

- Re-run strict parity rollups and close `PAR-001` and `PAR-002` through 3 consecutive windows.
- Promote strict mode outcomes into next release checklist (`docs/operations/RELEASE_CHECKLIST.md`).
- Produce one end-to-end `observability-first-class-runtime-evidence-index.json` trend artifact per lane for operations handover.
- Start `OBS-024` completion path if tracer path evidence remains open.


## Strict-mode closure gate (OBS-EXT-069)

For `OBS-EXT-069`, run this exact sequence per lane before flipping handoff status:

1. Capture strict runtime verifier output with explicit command:
   - `lane="nonprod"; OBSERVABILITY_ENV_LABEL="${lane}"; case "${lane}" in dev|nonprod) OBSERVABILITY_DISPATCH_PROFILE="nonprod"; OBSERVABILITY_K8S_CONTEXT="$OBS_PARITY_NONPROD_K8S_CONTEXT";; prod) OBSERVABILITY_DISPATCH_PROFILE="prod"; OBSERVABILITY_K8S_CONTEXT="$OBS_PARITY_PROD_K8S_CONTEXT";; esac; if [ "${lane}" = prod ] && [ -n "$OBS_PARITY_PROD_GCP_PROJECT" ]; then OBSERVABILITY_GCP_PROJECT="$OBS_PARITY_PROD_GCP_PROJECT"; else OBSERVABILITY_GCP_PROJECT="${OBS_PARITY_NONPROD_GCP_PROJECT:-mereka-lms}"; fi; ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`
2. Confirm these required files exist and contain the strict markers:
   - `var/ci/observability-compliance-runtime.json` (or lane-specific evidence folder)
   - `var/ci/observability-runtime-verify-runtime.md`
   - `var/ci/observability-first-class-runtime-evidence-index.json`
3. Validate AC-OVR-025 determinism:
   - open `observability-compliance-runtime.json` and verify `checks` contains `AC-OVR-025` with `status == "pass"`.
   - confirm output is machine-parseable JSON without trailing log pollution.
4. Validate AC-OVR-029 strict-gate behavior:
   - open `.github/workflows/observability-compliance.yml`
   - verify `pull_request` exists and enforces strict local mode with monitoring path constraints.
5. Only when both ACs are green in the strict run may you close `OBS-EXT-069`.
