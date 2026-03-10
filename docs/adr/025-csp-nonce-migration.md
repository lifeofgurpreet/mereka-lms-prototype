---
id: ADR-025
title: CSP Nonce Migration — Removing unsafe-eval / unsafe-inline
decision_status: accepted
decision_type: domain
rollout_state: active
owner: engineering
created: '2026-03-05'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on: []
read_next:
- ADR-021
- ADR-022
governs:
- frontend.csp
- auth.cookie-boundary
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions: []
expiry_date: null
removal_condition: null
---

# ADR-025: CSP Nonce Migration — Removing unsafe-eval / unsafe-inline

**Status**: Accepted
**Date**: 2026-03-05
**Deciders**: Gurpreet Singh (Founder / Platform Owner)

<!-- Last verified: 2026-03-05 -->

## Context

The Mereka LMS Content Security Policy (configured in
`infrastructure/tutor/plugins/_mereka_lms/lms_settings.py`) currently includes
`'unsafe-inline'` and `'unsafe-eval'` in `CSP_SCRIPT_SRC`. These directives
significantly weaken XSS protection — `'unsafe-eval'` in particular allows
`eval()`, `setTimeout(string)`, and `new Function(string)`.

### Why unsafe-inline and unsafe-eval exist today

Open edX (Ulmo / Django Waffle / XBlock runtime) generates inline scripts in
several places that cannot be trivially externalised:

| Source | Directive needed | Notes |
|--------|-----------------|-------|
| RequireJS bootstrap | `'unsafe-inline'` | Initial `require.config({...})` block injected into `<head>` |
| XBlock runtime JS | `'unsafe-inline'` | `XBlock.initialize()` calls in `<script>` tags |
| Django template tags | `'unsafe-inline'` | `{% javascript_tag %}` used in legacy Mako templates |
| Legacy Waffle flags | `'unsafe-inline'` | `window.WAFFLE_FLAGS = {...}` JSON blob |
| MathJax / CodeMirror | `'unsafe-eval'` | Dynamic code compilation at runtime |
| Studio drag-drop | `'unsafe-eval'` | Sortable/DnD libraries use `new Function()` |

Removing these without nonce support would break LMS rendering, XBlock
interactivity, Studio authoring, and math rendering across all courses.

## Decision

We adopt a **phased nonce-based migration** rather than a flag day:

### Phase 0 — Scaffold (this ADR, current) ✓

- Add `CSP_REPORT_URI` (env-configurable, defaults to disabled).
- Add `CSP_INCLUDE_NONCE_IN = ["script-src"]` so django-csp injects nonces
  into `<script>` tags — **nonces coexist safely with `'unsafe-inline'`**.
- Deploy `Content-Security-Policy-Report-Only` alongside the permissive
  enforcement header to collect real violation data without breaking anything.
- Add `verify-csp-headers.sh` QA gate to CI.

### Phase 1 — Report-Only enforcement (future)

- Stand up a CSP report collector (e.g. sentry-csp-endpoint or a lightweight
  FastAPI endpoint behind `/csp-report`).
- Ensure `CSP_REPORT_URI` derivation is robust for both sentry.io and
  self-hosted Sentry DSN hosts (implemented via URL parsing + CI gate).
- Switch the enforcement header to a strict nonce-based policy in report-only
  mode: `'strict-dynamic' 'nonce-{value}'` with `'unsafe-inline'` as fallback
  for legacy browsers.
- Monitor violation reports for 2–4 weeks across all tenants.
- Goal: zero violations from first-party code before Phase 2.

### Phase 2 — Remove unsafe-inline (future)

- Only after Phase 1 violation report shows zero first-party hits:
  - Remove `'unsafe-inline'` from `CSP_SCRIPT_SRC`.
  - Keep `'strict-dynamic'` + nonce.
  - Keep `'unsafe-eval'` temporarily until MathJax/Studio audit is complete.
- Flip enforcement header from report-only to enforced.

### Phase 3 — Remove unsafe-eval (future)

- Replace MathJax 2.x with MathJax 3.x (CSP-safe, no eval).
- Audit Studio drag-drop / Sortable for eval-free alternatives.
- Remove `'unsafe-eval'` from `CSP_SCRIPT_SRC`.
- Final policy: `default-src 'self'; script-src 'strict-dynamic' 'nonce-{value}'`.

## Scope

This ADR governs the decision boundary described by ADR-025.

## Non-goals

This document does not replace broader platform standards, runbooks, or implementation evidence.

## Verification

- No dedicated automated fitness function is registered yet; use linked specs and runbooks for review.

## Consequences

### Positive
- Phase 0 gives us violation telemetry at zero risk.
- Nonce injection is idempotent — templates that adopt `{% csp_nonce %}` work
  before `'unsafe-inline'` is removed.
- `'strict-dynamic'` means scripts loaded by a nonced bootstrap script inherit
  trust, eliminating the CDN allowlist maintenance burden.

### Negative / Risks
- Report-only violations from third-party MFE code (Paragon, Analytics) will
  appear as noise — operators must triage before Phase 2.
- XBlock third-party plugins may use inline scripts that are outside our
  control; those authors must be notified before Phase 2.
- MathJax 3 migration is a non-trivial open-edx-platform fork change.

## Rollback Plan

- **Phase 0**: No enforcement change — nothing to roll back.
- **Phase 1**: Remove `Content-Security-Policy-Report-Only` header from Caddy
  or set `CSP_REPORT_URI=""` env var to disable report endpoint.
- **Phase 2**: Re-add `'unsafe-inline'` to `CSP_SCRIPT_SRC` in plugin and
  redeploy (one env var change + pod restart, no image rebuild needed via
  ExternalSecrets / ConfigMap).
- **Phase 3**: Re-add `'unsafe-eval'` to `CSP_SCRIPT_SRC` in plugin.

## Implementation Notes

- django-csp (`csp.middleware.CSPMiddleware`) is already installed by
  `lms_settings.py`; no new dependencies required for Phase 0.
- `CSP_REPORT_URI` must point to an endpoint that accepts `POST` with
  `Content-Type: application/csp-report`.
- Sentry's CSP endpoint (via `/_/csp-report/`) is a drop-in option if Sentry
  DSN is already configured.
- Runtime collector smoke checks are documented in
  `docs/runbooks/operations/CSP_REPORTING_RUNBOOK.md` and enforced statically by
  `scripts/qa/verify-csp-report-pipeline.sh`.
- The `Content-Security-Policy-Report-Only` header is emitted by django-csp
  when `CSP_REPORT_ONLY = True`; the enforcement header is emitted when
  `CSP_REPORT_ONLY = False`. Both can coexist if Caddy adds the report-only
  header as a separate response header.
