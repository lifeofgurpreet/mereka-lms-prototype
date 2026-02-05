# Branding Coverage Audit (2026-02-05)

Environment: **production (GKE)**

This audit captures baseline screenshots across key surfaces and records where branding is strong vs. default.

## Screenshots

| Surface | Screenshot | Notes |
| --- | --- | --- |
| LMS home | [lms-home.png](lms-home.png) | Branded hero/footer; palette + typography visible. |
| Studio home | [studio-home.png](studio-home.png) | Partially branded (fonts + header/footer); deep authoring pages still default. |
| MFE authn | [mfe-authn-login.png](mfe-authn-login.png) | Branded shell and tokens; needs deeper authn/account styling. |
| Ecommerce | [ecommerce-login-redirect.png](ecommerce-login-redirect.png) | Redirected to MFE authn (branding ok); ecommerce checkout UI still default. |
| Credentials admin | [credentials-admin-login.png](credentials-admin-login.png) | Default Django admin styling (not branded). |
| Forum | [forum-home.png](forum-home.png) | Default forum UI (not branded). |
| Notes | [notes-root.png](notes-root.png) | Service root (not branded). |

## Gaps (Priority)

1. **Learner dashboard + courseware** (MFE + LMS course pages)
2. **Course cards + catalog** (LMS and discovery flows)
3. **Studio authoring UI**
4. **Ecommerce checkout + receipts**
5. **Credentials UI/admin**
6. **Forum UI**

## Next Steps

- Track work under epic `mereka-lms-3l8` (Branding depth & UX polish).
- Implement per-surface theming tasks and re-run this audit after each milestone.
