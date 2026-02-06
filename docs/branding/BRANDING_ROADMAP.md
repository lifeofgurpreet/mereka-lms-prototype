# Branding Roadmap (Beads-Driven)
_Audience: Product Eng + Platform Eng • Last updated: 2026-02-07_

This roadmap decomposes the Mereka design system rollout into concrete, testable beads.

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
- Public audit still reports deep selector gaps on LMS microsites and Studio token/font drift.
- This is deployment parity drift (older `openedx` image in production), tracked by
  `mereka-lms-2hxl` and `mereka-lms-1g4b`.

## Next 10 Branding Tasks (Execution Order)

Parent epic:
- `mereka-lms-3l8` Branding depth & UX polish

1. `mereka-lms-2hxl` Deploy deep branding to prod (openedx + mfe image parity)
2. `mereka-lms-1g4b` Strip Google fonts from Studio CSS (confirm live with rebuilt openedx image)
3. `mereka-lms-2vsz` MFE account/settings theming + UX
4. `mereka-lms-2ypu` MFE learner dashboard polish
5. `mereka-lms-5t06` LMS discovery/search polish final live verification pass
6. `mereka-lms-h9c9` Ecommerce checkout theming (basket/checkout/receipt)
7. `mereka-lms-1byu` Credentials admin branding (decision + minimal implementation)
8. `mereka-lms-36jn` Forum UI theming (header/footer + typography)
9. `mereka-lms-3mz` Visual regression gate for branding (screenshots + fail-on-drift)
10. `mereka-lms-s8r` Multisite branding governance + enforcement checks

## Notes On Duplicates

- Ecommerce duplicate resolved (`mereka-lms-14q` closed in favor of `mereka-lms-h9c9`).
- Forum duplicate resolved (`mereka-lms-3qh` closed in favor of `mereka-lms-36jn`).
