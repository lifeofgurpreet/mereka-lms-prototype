# Accessibility Exceptions Register

> Canonical registry of temporary accessibility exceptions acknowledged by the
> accessibility gates.

**Owner**: docs-platform team  
**Status**: Active  
**Last updated**: 2026-03-06  

## Policy

1. Exceptions are temporary and documented with explicit expiry dates.
2. Every exception must include owner, rationale, and ticket reference.
3. Exceptions are reviewed during each release and removed whenever the underlying
   issue is resolved.
4. New exceptions require platform lead approval.

## Active Exceptions

_No active exceptions are currently listed._

## Template

When adding a new exception, use this template:

```text
- ID:
- Surface:
- Severity:
- Owner:
- Rationale:
- Evidence:
- Filed:
- Expires:
- Tracking ID:
- Resolution path:
```

## Related Gates

- `scripts/qa/verify-a11y-contrast-focus.sh`
- `scripts/qa/verify-a11y-tenant-branding.sh`
- `scripts/qa/verify-a11y-authenticated-routes.sh`
- `scripts/qa/verify-authenticated-sso-canary.sh`
