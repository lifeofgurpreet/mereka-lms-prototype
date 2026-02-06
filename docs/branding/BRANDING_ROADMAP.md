# Branding Roadmap (Beads-Driven)
_Audience: Product Eng + Platform Eng • Last updated: 2026-02-06_

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

## Next 10 Branding Tasks

1. `mereka-lms-2hxl` Deploy deep branding to prod
2. `mereka-lms-3bm6` LMS course about page theming
3. `mereka-lms-5t06` LMS discovery/search UI theming
4. `mereka-lms-1cs8` LMS dashboard notices + components
5. `mereka-lms-35an` Courseware xblock typography pass
6. `mereka-lms-2hb8` Studio create flows theming
7. `mereka-lms-2vsz` MFE account/settings theming + UX
8. `mereka-lms-2ypu` MFE learner dashboard polish
9. `mereka-lms-h9c9` Ecommerce checkout theming (basket/checkout/receipt)
10. `mereka-lms-1byu` Credentials admin branding (decision + minimal implementation)

Additional backlog:
- `mereka-lms-36jn` Forum UI theming (header/footer + typography)
- `mereka-lms-1g4b` Strip Google fonts from Studio CSS (build-time patch)
- `mereka-lms-3mz` Visual regression gate for branding
