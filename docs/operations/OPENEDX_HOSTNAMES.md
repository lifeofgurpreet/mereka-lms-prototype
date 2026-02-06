# Open edX Hostnames Registry
_Audience: Platform Eng • Last updated: 2026-02-06_

This is the canonical list of **public hostnames** for the Open edX ecosystem we operate here.

Why this exists:
- We run **multiple microsites** on one Open edX stack.
- Missing or wrong hostnames cause confusing “SSO is missing” symptoms (because redirects depend on Host).
- We want deterministic verification: no guessing, no tribal knowledge.

## Source Of Truth

1. `scripts/shared/config.sh` is the human-editable defaults for domains.
2. The deployed truth is the cluster ingress host list (prod + dev).

To validate drift:
```bash
./scripts/qa/list-openedx-hostnames.sh
```

## Production (GKE)

LMS microsites (tenant roots):
- `academyv2.mereka.io`
- `academy.biji-biji.com`
- `skillourfuture.academy.mereka.io`

LMS aliases (same LMS, extra hostnames):
- `preview.academyv2.mereka.io`

Studio:
- `studio.academyv2.mereka.io`
- `studio.academy.biji-biji.com`

MFE apps:
- `apps.academyv2.mereka.io`
- `apps.academy.biji-biji.com`

Shared ecosystem services (still part of the Open edX ecosystem):
- Discovery: `discovery.academyv2.mereka.io`
- Ecommerce: `ecommerce.academyv2.mereka.io`
- Credentials: `credentials.academyv2.mereka.io`
- Notes: `notes.academyv2.mereka.io`
- Forum (cs_comments_service): `forum.academyv2.mereka.io`

SSO / IdP:
- Authentik: `auth0.mereka.io`

## Development (VPS kind)

Public dev hostnames:
- `academyv2.mereka.dev`
- `preview.academyv2.mereka.dev`
- `studio.academyv2.mereka.dev`
- `apps.academyv2.mereka.dev`
- `discovery.academyv2.mereka.dev`
- `ecommerce.academyv2.mereka.dev`
- `credentials.academyv2.mereka.dev`
- `notes.academyv2.mereka.dev`
- `forum.academyv2.mereka.dev`

## Development (kind-local)

When working against the kind cluster locally, these wildcard hostnames can exist too:
- `lms.lvh.me`
- `preview.lms.lvh.me`
- `studio.lms.lvh.me`
- `apps.lms.lvh.me`

These are convenience hostnames for local testing and are not part of the public `.mereka.dev` surface.

