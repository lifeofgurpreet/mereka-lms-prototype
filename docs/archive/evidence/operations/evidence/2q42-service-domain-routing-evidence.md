Service-domain authn routing + surface evidence (2026-02-19)

- Date: 2026-02-19
- Branch: feat/23ry2-spec-dedupe-normalize
- Source of truth bead: mereka-lms-2q42

Checks run:
- branding gates: BRANDING_LEVEL=deep STRICT=1 ./scripts/branding/run-branding-gates.sh prod
- manual probes against production hosts

Key results:
- ecommerce dashboard route now returns branded authn shell:
  - https://ecommerce.academyv2.mereka.io/dashboard/
  - HTTP 200, includes /authn/app.* assets
  - no undefined_license_key in payload
- credentials admin login route now returns branded authn shell:
  - https://credentials.academyv2.mereka.io/admin/login/
  - HTTP 200, includes /authn/app.* assets
  - no undefined_license_key in payload
- https://ecommerce.academyv2.mereka.io/api/v2/webhooks/stripe/ returns 405 (expected API-only endpoint)
- No manual runtime HTML mutation workarounds in use

Branding gates (prod, deep):
- Public checks: PASS for all route and branding assertions including ecommerce dashboard and credentials admin authn shell.
- audit-branding-surfaces reported 4 WARNs:
  - MFE authn branding revision marker drift:
    - apps.academyv2.mereka.io expected 2026-02-18-us7 missing
    - apps.academy.biji-biji.com expected 2026-02-18-us7 missing
    - ecommerce and credentials authn css marker differs from source
- These are tracked separately under branding parity lane.

Outcome:
- AC-LIVE-201/203/205: PASS
- AC-LIVE-205: no runtime workaround; fix remains GitOps-backed via Caddyfile + manifests.
- AC-LIVE-202: /302/405-like chain behavior explained below:
  - endpoints are authn-first flows; 405 only appears in non-browser redirect edge cases and is expected behavior.
