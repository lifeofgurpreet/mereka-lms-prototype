# Branding Verification Checklist
_Audience: Design + Platform Eng • Owner: Branding Guild • Last verified: 2026-02-07 • Status: canonical_

Use this checklist for any branding PR or branding deployment.

## Canonical Command

```bash
./scripts/branding/run-branding-gates.sh prod
```

This runs source checks, live checks, and a branding surface audit.

Strict parity mode (recommended for CI/scheduled runs):

```bash
STRICT_MFE_BRANDING_REV=1 ./scripts/branding/run-branding-gates.sh prod
```

## Pass Criteria

- Source gate passes (`verify-branding-health` with `BRANDING_LEVEL=deep`).
- Public endpoint checks pass (`public-health-check`).
- Live branding checks pass (`verify-public-branding`).
- No high-severity gaps in surface audit.

## Quick Manual Spot Checks

1. `https://academyv2.mereka.io/`
2. `https://studio.academyv2.mereka.io/`
3. `https://apps.academyv2.mereka.io/authn/login`
4. `https://ecommerce.academyv2.mereka.io/dashboard/`
5. `https://forum.academyv2.mereka.io/heartbeat`
6. `https://credentials.academyv2.mereka.io/health/`
7. `https://academy.biji-biji.com/`
8. `https://skillourfuture.academy.mereka.io/`

## Known Non-Blocking Behavior

- Credentials is API-first; `/` may redirect to `/health/`.
- Non-strict MFE checks allow revision mismatch but still require branding markers.

## If Any Check Fails

1. Re-run asset sync:
   - `./scripts/branding/sync-brand-assets.sh`
2. Re-run source gate:
   - `BRANDING_LEVEL=deep ./scripts/branding/verify-branding-health.sh`
3. Rebuild/push images as needed (`openedx`, `openedx-mfe`).
4. Update GitOps pinned ref and verify rollout.
5. Re-run:
   - `./scripts/branding/run-branding-gates.sh prod`

## References

- `docs/guides/branding/BRANDING_OPERATING_MODEL.md`
- `docs/guides/branding/BRANDING_GUARDRAILS.md`
- `docs/guides/branding/BRANDING_ROADMAP.md`
- `docs/ops/runbooks/THEME_DEPLOYMENT.md`
