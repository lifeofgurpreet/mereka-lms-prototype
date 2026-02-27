# OBS-EXT-HANDOFF-2026-02-27: Observability Wave-2 Runtime Closure Handoff

**Owner:** Observability Team / Platform SRE
**Status:** ready_for_implementation
**Target date:** 2026-03-06
**Depends on:** `OBS-053..057`, `OBS-058`, and `docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md`

## Purpose

Close the remaining first-class observability blockers in the non-prod/dev/prod parity lanes in strict lane order, then harden strict mode gating behavior.

## Scope

- P0 execution closure tasks only: `OBS-EXT-061` through `OBS-EXT-062` and `OBS-EXT-064` through `OBS-EXT-068`.
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
OBSERVABILITY_ENV_LABEL=<lane> \
OBSERVABILITY_DISPATCH_PROFILE=nonprod \
OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_<LANE>_K8S_CONTEXT \
./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

Use `lane=dev` then `nonprod` then `prod` where environment is available.

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
