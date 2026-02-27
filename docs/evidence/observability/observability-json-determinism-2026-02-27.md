# Observability strict-mode JSON determinism update

Scope: Open edX `scripts/qa/validate-observability-compliance.sh` and
`scripts/qa/verify-observability-runtime.sh`.

Generated: 2026-02-27T00:00:00Z

## Change summary

- Added strict JSON-only mode support to compliance validator via
  `VALIDATE_OBS_JSON_ONLY=1`.
  - Validator now writes non-JSON console chatter to `/dev/null` when
    `--json` is requested with strict-only mode enabled.
  - Validator prints machine-parseable JSON to a dedicated file descriptor so
    caller output parsers receive deterministic payload.
- Hardened runtime extractor in `verify-observability-runtime.sh`:
  - Trim trailing whitespace before JSON extraction.
  - Validate full trimmed JSON text quickly when output is pure JSON.
  - Keep fallback brace-scanning and plain-text extraction paths for legacy/log-mixed outputs.
- Wired `verify-observability-runtime.sh` to invoke compliance validator with
  `VALIDATE_OBS_JSON_ONLY=1` for strict JSON checks.

## Closure criteria for OBS-EXT-069

1. Strict runtime compliance wave produces:
   - `observability-compliance-runtime.json` with valid schema for `AC-OVR-025`.
   - No `AC-OVR-029` regressions from monitoring-path PR gate enforcement.
2. `run-observability-first-class.sh --mode runtime --strict` in nonprod and prod
   does not emit parse-failures for compliance JSON payload extraction.
3. `python3` and `jq` remain mandatory dependencies where strict JSON checks are
   enabled.

## Notes for operators

- This is a determinism hardening pass only; no service or manifest behavior
  changes were made.
- Live proof is still required to formally close strict-mode ACs.
