# Integrations
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2026-03-10 • Status: canonical_

Use this root for third-party integration guidance that engineers or operators actively apply. Put deep configuration, integration-specific troubleshooting, and platform contracts here. Do not use this root for architecture policy, secret values, or one-off migration notes.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Set up, rotate, or troubleshoot Google OAuth for LMS or Studio | [`GOOGLE_OAUTH_SETUP.md`](GOOGLE_OAUTH_SETUP.md) | [`../admin/SECRETS_MANAGEMENT_GUIDE.md`](../admin/SECRETS_MANAGEMENT_GUIDE.md) |
| Configure or troubleshoot LTI launches and grade passback | [`LTI.md`](LTI.md) | [`LTI_STORE.md`](LTI_STORE.md) |
| Check the operational contract for the LTI store | [`LTI_STORE.md`](LTI_STORE.md) | [`../../reference/operations/`](../../reference/operations/README.md) |

## Integration Guides

| Doc | Purpose | Last Verified |
|---|---|---|
| [`GOOGLE_OAUTH_SETUP.md`](GOOGLE_OAUTH_SETUP.md) | Deep-dive setup for Google Sign-In, including Cloud Console, secrets, and Tutor settings. | 2025-08-30 |
| [`LTI.md`](LTI.md) | LTI 1.1 and LTI 1.3 integration guide: Studio setup, grade passback, SAML SP alignment, and troubleshooting. | 2026-02-24 |
| [`LTI_STORE.md`](LTI_STORE.md) | Operational contract for the LTI store and related platform integration posture. | 2026-03-09 |

## What This Root Is Not

- Not the source of architecture policy. Use [`../../concepts/architecture/`](../../concepts/architecture/README.md) for control-plane and authority questions.
- Not the place for secrets or secret values. Use the documented secret-management flow and [`../admin/SECRETS_MANAGEMENT_GUIDE.md`](../admin/SECRETS_MANAGEMENT_GUIDE.md).
- Not a dumping ground for one-off notes. If an item is time-bound status or proof, route it to `docs/status/**` or `docs/evidence/**` instead.

## Adding a New Integration Guide

1. Put the guide in this root if it explains a live third-party integration.
2. Link it from this README so it is discoverable from the front door.
3. Follow [`../standards/STYLE_GUIDE.md`](../standards/STYLE_GUIDE.md) and [`../standards/DOCUMENTATION_STANDARDS.md`](../standards/DOCUMENTATION_STANDARDS.md).
4. If the integration changes runtime behavior materially, update the relevant reference, policy, or evidence/status surface too.
