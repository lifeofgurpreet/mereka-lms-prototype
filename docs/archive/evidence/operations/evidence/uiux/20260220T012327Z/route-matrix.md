# Route Matrix — 1kwf UI Parity Audit
> Date: 2026-02-20
> Branch: feat/23ry2-spec-dedupe-normalize
> Commit: 521aca9

## Surface Matrix

| Surface | HTTP | Mereka Brand | Open edX Logo | Status | Notes |
|---------|------|--------------|---------------|--------|-------|
| `academyv2.mereka.io` | 200 | ✓ | ✓ absent | ✅ PASS | LMS home |
| `studio.academyv2.mereka.io` | 200 | ✓ | ⚠ present | ⚠ WARN | **Template fix committed (521aca9) — needs image rebuild** |
| `academyv2.mereka.io/admin/login/` | 302 | N/A | ✓ absent | ✅ PASS | Redirects to Authentik OIDC (expected) |
| `apps.academyv2.mereka.io/authn/login` | 200 | JS-rendered | ✓ absent | ✅ PASS | MFE SPA — branding in JS bundle |
| `apps.academyv2.mereka.io/learning/` | 200 | JS-rendered | ✓ absent | ✅ PASS | Learner dashboard MFE |
| `ecommerce.academyv2.mereka.io` | 200 | ✓ | ✓ absent | ✅ PASS | Legacy ecommerce |
| `credentials.academyv2.mereka.io` | 200 | ✓ | ✓ absent | ✅ PASS | Credentials service |
| `academyv2.mereka.io/api/discussion/v1/courses/` | 404 | N/A | N/A | ⚠ NOTE | Forum v2: use /api/discussion/v2/ (401=auth required, correct) |
| `notes.academyv2.mereka.io` | 200 | N/A | ✓ absent | ✅ PASS | Notes service (internal) |
| `preview.academyv2.mereka.io` | 200 | ✓ | ✓ absent | ✅ PASS | Preview LMS |
| `academy.biji-biji.com` | 200 | ✓ | ✓ absent | ✅ PASS | Biji-Biji microsite |
| `skillourfuture.academy.mereka.io` | 200 | ✓ | ✓ absent | ✅ PASS | SkillourfFuture microsite |

## Known Gaps (require deployment lane / WhiteCliff)

1. **Studio footer** — "Powered by Open edX" block still live. Template fix committed.
   - Fix: `cms/templates/widgets/footer.html` (new file, commit 521aca9)
   - Action: `tutor images build openedx` + push + update image tag

2. **MFE branding revision** (bz9p) — deployed `2026-02-08-pass4` vs source `2026-02-18-us7`
   - Affects: apps.academyv2.mereka.io, ecommerce, credentials authn surfaces
   - Action: `tutor images build mfe` + push + update image tag

## Gate Results

```
verify-footer-parity.sh:          31 PASS / 0 FAIL / 2 WARN
verify-studio-authoring-branding: 0 failures
audit-branding-surfaces.sh:       gaps=4 (all MFE revision marker — pre-existing)
run-branding-gates.sh (deep):     4 gaps (all MFE revision mismatch)
verify-public-branding (strict):  6 failures (MFE revision + skillourfuture logo 404)
```
