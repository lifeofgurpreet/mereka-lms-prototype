# Route Matrix — UI Parity Audit
> Date: 2026-02-20T10:37Z
> Branch: feat/23ry2-spec-dedupe-normalize
> Commit: 113fde8
> Bead: 1kwf

## Surface Matrix

| Surface | Expected HTTP | Mereka Brand | "Powered by Open edX" | Status | Notes |
|---------|--------------|--------------|----------------------|--------|-------|
| `academyv2.mereka.io` | 200 | ✓ | absent | ✅ PASS | LMS home |
| `studio.academyv2.mereka.io` | 200 | ✓ | absent (source) | ⚠ SOURCE-FIXED | Footer template fix committed 113fde8 — awaiting `tutor images build openedx` |
| `academyv2.mereka.io/admin/login/` | 302 | N/A | absent | ✅ PASS | Redirects to Authentik OIDC (expected) |
| `apps.academyv2.mereka.io/authn/login` | 200 | JS-rendered | absent | ✅ PASS | MFE SPA — branding in JS bundle |
| `apps.academyv2.mereka.io/learning/` | 200 | JS-rendered | absent | ✅ PASS | Learner dashboard MFE |
| `ecommerce.academyv2.mereka.io` | 200 | ✓ | absent | ✅ PASS | Legacy Oscar ecommerce |
| `credentials.academyv2.mereka.io` | 200 | ✓ | absent | ✅ PASS | Credentials service |
| `academyv2.mereka.io/api/discussion/v2/courses/` | 401 | N/A | N/A | ✅ PASS | Forum v2 auth required (correct) |
| `notes.academyv2.mereka.io` | 200 | N/A | absent | ✅ PASS | Notes service (internal) |
| `preview.academyv2.mereka.io` | 200 | ✓ | absent | ✅ PASS | Preview LMS |
| `academy.biji-biji.com` | 200 | Biji-Biji brand | absent | ✅ PASS | Biji-Biji microsite |
| `skillourfuture.academy.mereka.io` | 200 | Skill Our Future | absent | ✅ PASS | SOF microsite |

## Footer Surface Status

| Surface | Source State | Live State | Gap |
|---------|-------------|------------|-----|
| LMS Mako footer | ✅ No "Powered by"; copyright dynamic | Not checked (live footer is HTML; needs curl+grep) | Awaiting image build |
| Studio footer | ✅ `widgets/footer.html` override committed (113fde8) | ⚠ Still shows "Powered by Open edX" (live) | **Deployment blocker: `tutor images build openedx`** |
| MFE footer | ✅ MerekaFooter 4-zone v2 structure, SITE_VARIANTS per-tenant | MFE image `1c66529-20260220023917` not yet deployed | **Deployment blocker: ArgoCD sync bz9p** |
| Enterprise MFE portals | ⚠ No MerekaFooter wiring (accepted) | Open edX default | Accepted exception; P4 backlog |

## Open Deployment Gates (WhiteCliff lane)

1. **Studio footer** — `tutor images build openedx` → push → update kustomization.yaml tag → ArgoCD sync
2. **MFE branding rev** (bz9p) — deploy image `1c66529-20260220023917` via ArgoCD

## Source-Gate Verification (current commit)

```
verify-footer-parity.sh:   32 PASS / 0 FAIL / 1 WARN (accepted: Enterprise MFE)
verify-mfe-footer-slot.sh: 30 PASS / 0 FAIL / 0 WARN
verify-studio-branding:    0 failures (source checks)
verify-public-branding:    9 failures (ALL live-site — deployment blocked)
```
