# CSP Reporting Runbook (Phase 1)

This runbook validates that CSP violation reports are collectable before we remove
`'unsafe-inline'` or `'unsafe-eval'`.

## Scope

- Verify static wiring of `CSP_REPORT_URI` derivation.
- Optionally send a synthetic CSP report to the configured collector endpoint.
- Keep enforcement in report-only mode while collecting signal.

## Gates

- Static (CI-safe):

```bash
./scripts/qa/verify-csp-headers.sh
./scripts/qa/verify-csp-report-pipeline.sh
```

- Runtime (collector smoke check):

```bash
RUN_RUNTIME_CHECK=1 SENTRY_DSN="$SENTRY_DSN" \
  ./scripts/qa/verify-csp-report-pipeline.sh
```

or with explicit endpoint:

```bash
RUN_RUNTIME_CHECK=1 CSP_REPORT_URI="https://<sentry-host>/api/<project>/security/?sentry_key=<public_key>" \
  ./scripts/qa/verify-csp-report-pipeline.sh
```

## Expected Outcome

1. Static checks pass and confirm no hardcoded `sentry.io` assumptions.
2. Runtime check returns HTTP 2xx from report collector.
3. `CSP_REPORT_ONLY=true` remains enabled until violation baseline is clean.

## Rollback

If report collector fails or becomes noisy:

1. Keep `CSP_REPORT_ONLY=true`.
2. Set `CSP_REPORT_URI=""` to disable report submissions.
3. Re-run static gate to ensure policy remains structurally valid.
