# Branding Roadmap (Beads-Driven)
_Audience: Product Eng + Platform Eng • Last updated: 2026-02-07_

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
- Live checks now include revision marker parity (`--mereka-branding-rev`, `--mereka-mfe-branding-rev`)
  to explicitly detect older deployed images.
- Public audit currently reports:
  - Studio token/font drift (missing token export + legacy Google font import)
- Strict parity is now enforced in CI/scheduled checks; clearing drift is tracked by:
  - `mereka-lms-2bnq` (deploy openedx refresh to clear Studio token/Google-font drift)

## Next 10 Branding Tasks (Execution Order, Current)

Parent epic:
- `mereka-lms-3l8` Branding depth & UX polish

1. `mereka-lms-44nc` Clear strict parity gate by deploying current MFE branding revision `[open]`
2. `mereka-lms-3mz` Visual regression gate for branding (baseline + diff + fail-on-drift) `[open]`
3. `mereka-lms-2bnq` Deploy openedx refresh to clear Studio token/google-font drift on production hosts `[open]`
4. `mereka-lms-h9c9` Ecommerce checkout theming (basket/checkout/receipt) `[open]`
5. `mereka-lms-36jn` Forum UI theming (header/footer + typography) `[open]`
6. `mereka-lms-s8r` Harden multi-site governance (policy + enforcement) `[open]`
7. `mereka-lms-3l48` Studio authoring flow visual branding checks `[closed]`
8. `mereka-lms-37kj` Microsite branding parity enforcement `[closed]`
9. `mereka-lms-3m3v` Design token provenance lock `[closed]`
10. `mereka-lms-2grh` Branding release preflight CI gate `[closed]`

Supporting runbook hardening:
- `mereka-lms-36bd` Branding incident postmortem template `[closed]`
- `mereka-lms-1ywp` Strict MFE revision parity in CI `[closed]`

## Notes On Duplicates

- Ecommerce duplicate resolved (`mereka-lms-14q` closed in favor of `mereka-lms-h9c9`).
- Forum duplicate resolved (`mereka-lms-3qh` closed in favor of `mereka-lms-36jn`).
