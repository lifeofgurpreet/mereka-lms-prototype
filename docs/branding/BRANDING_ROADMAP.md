# Branding Roadmap (Beads-Driven)
_Audience: Product Eng + Platform Eng • Last updated: 2026-02-08_

This roadmap decomposes the Mereka design system rollout into concrete, testable beads.

Execution standard:
- `docs/branding/BRANDING_OPERATING_MODEL.md`

## Global Gates (Do Not Skip)

Source gates (repo truth):
```bash
BRANDING_LEVEL=deep ./scripts/branding/verify-branding-health.sh
```

Live gates (prod truth):
```bash
CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
BRANDING_LEVEL=deep ./scripts/qa/verify-public-branding.sh prod
./scripts/qa/capture-branding-screenshots.sh prod
```

## Hosts / Surfaces

Primary (academyv2):
- `academyv2.mereka.io` (LMS)
- `studio.academyv2.mereka.io` (Studio)
- `apps.academyv2.mereka.io` (MFEs)
- `ecommerce.academyv2.mereka.io` (Ecommerce)
- `credentials.academyv2.mereka.io` (Credentials)
- `forum.academyv2.mereka.io` (Forum)

Client subsites (separate clients, still must be branded):
- `academy.biji-biji.com`
- `skillourfuture.academy.mereka.io`

## Recently Completed (Source-Level, 2026-02-07)

- `mereka-lms-1cs8` LMS dashboard notices + components
- `mereka-lms-35an` Courseware xblock typography pass
- `mereka-lms-1d7x` PVC utilization signal path (branding-adjacent reliability signal)
- `mereka-lms-3ou` Studio authoring base polish (navigation/forms/actions)
- `mereka-lms-2hb8` Studio create course/library flow selectors + modal/card polish
- MFE deep pass for authn/account/dashboard in `infrastructure/tutor/themes/mereka/mfe/mereka.scss`
  (auth card hierarchy, account dropdown/alerts, learner course/status chip polish)
- Credentials baseline: branded root landing content wired in Caddy + checks in
  `scripts/qa/verify-public-branding.sh` and `scripts/qa/audit-branding-surfaces.sh`

## Live Status Snapshot (2026-02-07)

- Source gates pass at `BRANDING_LEVEL=deep`.
- Live checks include revision marker parity (`--mereka-branding-rev`, `--mereka-mfe-branding-rev`)
  to explicitly detect stale deployed images.
- Strict parity rollout fixes are complete (`mereka-lms-44nc`, `mereka-lms-2bnq`, `mereka-lms-3mz` closed).
- Current follow-up is service-domain authn asset proxy parity for `ecommerce.*` + `credentials.*`
  (`mereka-lms-3020`), then enabling strict enforcement in branding gates.
- Fresh non-repair MFE rollout is complete (`mereka-lms-vy6m` closed); production runs
  `openedx-mfe:20260208-mfe-nonrepair-931f55e` with strict revision parity gate passing.

## Next 10 Branding Tasks (Execution Order, Current)

Parent epic:
- `mereka-lms-3l8` Branding depth & UX polish

1. `mereka-lms-44nc` Clear strict parity gate by deploying current MFE branding revision `[closed]`
2. `mereka-lms-3mz` Visual regression gate for branding (baseline + diff + fail-on-drift) `[closed]`
3. `mereka-lms-2bnq` Deploy openedx refresh to clear Studio token/google-font drift on production hosts `[closed]`
4. `mereka-lms-3020` Service-domain authn asset proxy parity (ecommerce/credentials) `[open]`
5. `mereka-lms-vy6m` Build and deploy fresh authn-branded MFE image without repair fallback `[closed]`
6. `mereka-lms-h9c9` Ecommerce checkout theming (basket/checkout/receipt) `[open]`
7. `mereka-lms-36jn` Forum UI theming (header/footer + typography) `[open]`
8. `mereka-lms-s8r` Harden multi-site governance (policy + enforcement) `[closed]`
9. `mereka-lms-3l48` Studio authoring flow visual branding checks `[closed]`
10. `mereka-lms-37kj` Microsite branding parity enforcement `[closed]`

Recently closed:
- `mereka-lms-2oqx` Fix academy.biji-biji.com deep branding revision drift `[closed]`

Supporting runbook hardening:
- `mereka-lms-36bd` Branding incident postmortem template `[closed]`
- `mereka-lms-1ywp` Strict MFE revision parity in CI `[closed]`
- `mereka-lms-2grh` Branding release preflight CI gate `[closed]`

## Notes On Duplicates

- Ecommerce duplicate resolved (`mereka-lms-14q` closed in favor of `mereka-lms-h9c9`).
- Forum duplicate resolved (`mereka-lms-3qh` closed in favor of `mereka-lms-36jn`).
