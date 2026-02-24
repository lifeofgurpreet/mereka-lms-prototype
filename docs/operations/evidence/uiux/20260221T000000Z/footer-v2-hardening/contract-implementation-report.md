# Tenant Footer Data Contract — Implementation Report

Generated: 2026-02-21T01:20Z
Branch: feat/23ry2-spec-dedupe-normalize
Commit: (pending — see git log)
Assignment: msg 3365 "[ASSIGNMENT][3-4h] UI lane: footer-v2 fidelity + plugin-first tenant branding hardening"

---

## Summary

Source verifier: **60/0/1/1 PASS/FAIL/WARN/SKIP** (gate: PASS, up from 38/0/1/1)
Nonprod cluster: running old image (baseline screenshot captured — deployment gap confirmed)

**Contract implemented in code.** All 3 domains wired. LMS footer SiteConfiguration-aware.

---

## Contract Implementation

### SITE_VARIANTS — extended (mereka_lms.py)

Each domain now carries the full footer data contract:

| Field | Type | Purpose |
|-------|------|---------|
| `brand` | string | Footer brand name + logo alt text |
| `copyrightHolder` | string | Legal copyright entity |
| `whatsapp` | string | WhatsApp contact number |
| `supportEmail` | string | Support contact email |
| `helpUrl` | string | Help Centre URL |
| `privacyUrl` | string | Privacy Policy URL |
| `termsUrl` | string | Terms of Use URL |
| `cookiesUrl` | string | Cookies Policy URL |

**Domain values:**

| Domain | supportEmail | helpUrl | privacyUrl / termsUrl / cookiesUrl |
|--------|-----------|---------|------------------------------------|
| academyv2.mereka.io | support@mereka.io | https://help.mereka.io/ | legal.mereka.io/{pp,tos,cookie} |
| academy.biji-biji.com | techadmin@biji-biji.com | https://help.mereka.io/ | legal.mereka.io/{pp,tos,cookie} |
| skillourfuture.academy.mereka.io | support@mereka.io | https://help.mereka.io/ | legal.mereka.io/{pp,tos,cookie} |
| (fallback) | support@mereka.io | https://help.mereka.io/ | legal.mereka.io/{pp,tos,cookie} |

### MFE Footer — wired (mereka_lms.py)

| Zone | Change | Before | After |
|------|--------|--------|-------|
| Zone 2 navLinks | Help Centre URL | hardcoded `https://help.mereka.io/` | `variant.helpUrl` (tenant contract) |
| Zone 2 navLinks | Support link | absent | `mailto:${variant.supportEmail}` (new entry) |
| Zone 4 legal | Terms of Use URL | hardcoded `https://legal.mereka.io/` | `variant.termsUrl` |
| Zone 4 legal | Privacy Policy URL | hardcoded `https://legal.mereka.io/privacy-policy/` | `variant.privacyUrl` |
| Zone 4 legal | Cookies Policy URL | hardcoded `https://legal.mereka.io/#cookie-policy` | `variant.cookiesUrl` |

**Plugin-first compliance:** All wiring is in `mereka_lms.py`. No stealth fork. No `apply-patches.sh` changes.

### LMS Footer — SiteConfiguration-aware (footer.html)

| Field | Mechanism | SiteConfiguration key | Default |
|-------|-----------|----------------------|---------|
| Support email | `configuration_helpers.get_value()` | `SUPPORT_EMAIL` | support@mereka.io |
| Help Centre URL | `configuration_helpers.get_value()` | `HELP_CENTER_URL` | https://help.mereka.io/ |
| Privacy Policy URL | `configuration_helpers.get_value()` | `PRIVACY_POLICY_URL` | https://legal.mereka.io/privacy-policy/ |

To override per-tenant (no image rebuild needed):
Django admin → Sites → Site Configuration → add key `SUPPORT_EMAIL` = tenant support email.

---

## Verification Gates

### AC-FTPAR-008 (new) — contract fields in SITE_VARIANTS + LMS footer

```
  PASS: Domain 'academyv2.mereka.io' has contract field 'supportEmail'   [+5 fields]
  PASS: Domain 'academy.biji-biji.com' has contract field 'supportEmail' [+5 fields]
  PASS: Domain 'skillourfuture...' has contract field 'supportEmail'      [+5 fields]
  PASS: Fallback variant has contract field 'supportEmail'                [+5 fields]
  PASS: LMS footer imports configuration_helpers
  PASS: LMS footer reads SUPPORT_EMAIL / HELP_CENTER_URL from SiteConfiguration
```

### Full source gate result (verify-footer-parity.sh)

```
Footer parity: 60 PASS / 0 FAIL / 1 WARN / 1 SKIP
```
(Previously: 38/0/1/1 — +22 checks from AC-FTPAR-008)

---

## Screenshot Evidence

### nonprod-lms-footer-current.png

**URL**: https://academyv2.mereka.dev
**State**: Current deployed image (old — deployment gap)
**Shows**: Default Open edX footer — "Powered by Open edX" logo, About/Blog/Contact/Donate links
**Expected after rebuild**: Mereka v2 footer (mereka-footer class, all 4 zones, custom support email links)

### nonprod-studio-footer-current.png

**URL**: https://studio.academyv2.mereka.dev
**Shows**: Studio login page (image has not been rebuilt with themed Studio footer)

---

## Residual Gaps (post-image-rebuild tasks)

| Gap | Root cause | Owner |
|-----|-----------|-------|
| Nonprod/prod showing default Open edX footer | Old image, theme not compiled | WhiteCliff (image rebuild) |
| Partner URL not in MFE SITE_VARIANTS | LMS footer uses Partners links from template; MFE Zone 3 has Corporate/Academy columns instead | Future: extend SITE_VARIANTS with `partnerUrl` if needed |
| `academy.biji-biji.com` legal URLs use mereka.io domain | No biji-biji.com legal URL configured | Low priority: add `privacyUrl/termsUrl` pointing to biji-biji.com policy if they have one |
| LMS footer privacyUrl SiteConfiguration not tested live | No live nonprod with SiteConfiguration override set | Test after image rebuild: set `PRIVACY_POLICY_URL` in SiteConfiguration and verify |

---

## AC Mapping

| AC | Gate | Status |
|----|------|--------|
| AC-FTPAR-001 | SITE_VARIANTS + MerekaFooter + slot ref | PASS |
| AC-FTPAR-002 | LMS Mako footer + CMS footer widget | PASS |
| AC-FTPAR-003 | Copyright fields (brand/holder/whatsapp) | PASS |
| AC-FTPAR-004 | Enterprise MFE env config | PASS |
| AC-FTPAR-005 | No "Powered by Open edX" in source | PASS |
| AC-FTPAR-006 | Positive allowlist (structure, zones, legal) | PASS |
| AC-FTPAR-007 | Live footer content (--live) | SKIP (deploy gap) |
| AC-FTPAR-008 | Tenant contract fields in code | PASS (22/22) |
