# Observability Metrics Route Hardening (Mereka LMS) — 2026-02-27

## Scope

- Objective: make Open edX LMS/CMS Prometheus endpoint contract explicit and avoid `/metrics` path ambiguity in runtime strict checks.
- Impacted files:
  - `infrastructure/tutor/custom-apps/openedx_prometheus/urls.py`
  - `docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md`

## Implementation Notes

- Added route entries for both:
  - `metrics`
  - `metrics/`
- Keeping both paths preserves compatibility with:
  - direct container probes using bare path
  - ingress/reverse-proxy path-normalized probes using trailing slash

## Closure condition

- This change is complete in code, but not yet closure-ready until live strict evidence verifies:
  - `AC-OVR-016` passes in all required lanes (`status_code: 200` for LMS/CMS `/metrics`)
  - payload samples include both `# HELP` and `# TYPE` blocks plus numeric sample rows
  - runtime evidence identity matches parity lane identity in:
    - `observability-metrics-lms-runtime.md`
    - `observability-metrics-cms-runtime.md`

## Next verifier command

```bash
OBSERVABILITY_ENV_LABEL=<lane> \
OBSERVABILITY_DISPATCH_PROFILE=nonprod \
OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_<LANE>_K8S_CONTEXT \
./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

Replace `<lane>` with `dev`, `nonprod`, or `prod`.
