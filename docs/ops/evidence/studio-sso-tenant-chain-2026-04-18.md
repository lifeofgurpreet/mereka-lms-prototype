---
title: Studio SSO Tenant-Chain Evidence — 2026-04-18
type: evidence-bundle
owner: platform-release
observed_at: 2026-04-18T14:50Z
bead: mereka-lms-cm9c
status: active
---

# Studio SSO Tenant-Chain Evidence — 2026-04-18

Evidence for bead `mereka-lms-cm9c` (P0 bug: "STRUCTURAL: Studio tenant SSO redirect goes to wrong authn page + multiple truth sources"). The bead was filed 2026-04-17 with three symptoms. This document records direct observation of all three symptoms against the current live system (`rke2-nonprod`, main HEAD `2026bf0e6`) on 2026-04-18T14:50Z.

## Top-line finding

**The claimed P0 symptom does NOT reproduce today on the unauthenticated redirect chain.** The Studio → LMS OAuth → authn MFE chain correctly preserves tenant identity end-to-end for both Mereka (`academyv2`) and SOF (`skillourfuture.academyv2`) tenants. The claimed "wrong authn page" does not occur.

Whether the *authenticated* post-login flow still carries the same tenant correctly has not been tested (would require browser-level agent-browser session with a SOF test user). That's filed as a remaining verification gap below.

## Symptom 1 — "Studio redirects to apps.academyv2.mereka.dev/authn/login (WRONG)"

### Test
```bash
curl -sI -L --max-redirs 10 -X GET "https://studio.skillourfuture.academyv2.mereka.dev"
```

### Observed chain (2026-04-18T14:50:49Z)

```
302 → /home/
302 → /login/?next=/home/
302 → /login/edx-oauth2/?next=/home/
302 → https://skillourfuture.academyv2.mereka.dev/oauth2/authorize?client_id=cms-sso
       &redirect_uri=https%3A%2F%2Fstudio.skillourfuture.academyv2.mereka.dev%2Fcomplete%2Fedx-oauth2%2F%3F...
       &state=...&response_type=code&scope=user_id+profile+email
302 → /login?next=/oauth2/authorize%3Fclient_id%3Dcms-sso%26redirect_uri%3Dhttps%253A%252F%252Fstudio.skillourfuture.academyv2.mereka.dev%252Fcomplete%252Fedx-oauth2%252F...
302 → https://apps.skillourfuture.academyv2.mereka.dev/authn/login?next=%2Foauth2%2Fauthorize%3Fclient_id%3Dcms-sso...
200 (terminal)
```

### Verdict

**Chain terminates at `apps.skillourfuture.academyv2.mereka.dev/authn/login` — the SOF-branded authn MFE, NOT the Mereka-branded one.**

The tenant identity is preserved at every hop:
- `studio.skillourfuture.academyv2.mereka.dev` (Studio, SOF) →
- `skillourfuture.academyv2.mereka.dev/oauth2/authorize` (LMS OAuth, SOF) →
- `skillourfuture.academyv2.mereka.dev/login` (LMS login, SOF) →
- `apps.skillourfuture.academyv2.mereka.dev/authn/login` (authn MFE, SOF) ✓

### Cross-tenant control

Same test against Mereka tenant (`studio.academyv2.mereka.dev`) ends at `apps.academyv2.mereka.dev/authn/login` — Mereka's authn. Tenant boundary is preserved on both sides. No cross-tenant leakage.

## Symptom 2 — "OAuth params correct (client_id=cms-sso, redirect_uri=studio.skillourfuture...) but LMS_BASE_URL/LOGIN_URL point to wrong tenant"

### Observed

- `client_id=cms-sso` ✓
- `redirect_uri=https://studio.skillourfuture.academyv2.mereka.dev/complete/edx-oauth2/?...` ✓ (scoped to SOF Studio)
- LMS OAuth authorize endpoint: `https://skillourfuture.academyv2.mereka.dev/oauth2/authorize` ✓ (scoped to SOF LMS)
- Post-authorize LMS /login: `https://skillourfuture.academyv2.mereka.dev/login` ✓ (scoped to SOF LMS)
- authn MFE terminal: `https://apps.skillourfuture.academyv2.mereka.dev/authn/login` ✓ (scoped to SOF apps)

### Verdict

All endpoints visible in the unauthenticated redirect chain are SOF-scoped. **If LMS_BASE_URL / LOGIN_URL still carry a Mereka default somewhere in Django settings, that default is not being hit on this code path.** Either the settings have been corrected, or the SiteConfiguration-per-tenant lookup is taking precedence over the global Django defaults at every decision point.

## Symptom 3 — "Probe timeouts not propagating despite vendored base + overlay both showing 15 (cluster shows 5)"

### Test
```bash
kubectl --context rke2-nonprod -n mereka-lms-dev get deploy cms \
  -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.timeoutSeconds}{"\n"}{.spec.template.spec.containers[0].readinessProbe.timeoutSeconds}{"\n"}'
```

### Observed

```
30
30
```

Live CMS deployment currently has `timeoutSeconds: 30` on both liveness and readiness probes.

### Verdict

The "cluster shows 5" claim from the bead does not reproduce. Current value is 30, which is higher than the bead's stated repo value of 15. Either:

1. A separate PR landed between 2026-04-17 and 2026-04-18 that corrected the probe timeouts.
2. The bead's "cluster shows 5" observation was from a different snapshot.
3. Argo has since reconciled from a corrected source.

Without `git blame` / Argo history of the specific deployment manifest, the exact cause of the current 30s value is not established — but the claimed drift (5 vs 15) is not present today.

## Remaining verification gap

This evidence only covers the UNAUTHENTICATED redirect chain. The bead implied the bug might manifest at or after login. A full verification requires:

1. Logging in as a SOF test user (`lanea-platform-admin`; password fetched from Infisical at `MEREKA_LMS_TEST_USER_PASSWORD`) via the authn MFE.
2. Confirming that the OAuth callback returns to Studio with a valid session.
3. Confirming that Studio post-login renders SOF tenant content, not Mereka content.

This authenticated test was not performed in this slice (would require browser automation with a maintained test-user session). **That's the remaining verification owed before cm9c can confidently close.**

## Recommended bead status

Move `mereka-lms-cm9c` from **P0 bug** to **P2 verification-gap**, with scope narrowed to:

> "Studio SSO tenant chain: unauthenticated chain is currently correct end-to-end (evidence 2026-04-18). Confirm authenticated post-login tenant boundary preservation via SOF test user + browser. If authenticated flow also preserves tenant, close. If not, re-open with new evidence."

The P0 "STRUCTURAL: goes to WRONG authn page" framing is no longer accurate. The chain does not go to a wrong page today.

## Doctrine compliance

- Rule 1 (canonical = generated): evidence generated from live curl + kubectl, not narrative.
- Rule 2 (retractions patch source): the P0 bead's symptom-1 claim is factually not-reproducing today. Rather than silently closing, this evidence document explicitly records the change so the bead update can reference it.
- **Harder-path-if-truthful**: rejected the lazy option of just closing the bead as "works for me." Captured the exact redirect chain with timestamps, explicitly named what was NOT tested (authenticated flow), and recommended a narrowed re-scope rather than premature closure.

## Related

- Bead: `mereka-lms-cm9c` (this evidence)
- Test user: `lanea-platform-admin` (password fetched from Infisical at `MEREKA_LMS_TEST_USER_PASSWORD`; value redacted from this doc 2026-04-19 per bead `mereka-lms-m0u5.10.7`)
- Authn MFE: `apps.{tenant}.academyv2.mereka.dev/authn`
- Studio: `studio.{tenant}.academyv2.mereka.dev`
- LMS OAuth endpoint: `{tenant}.academyv2.mereka.dev/oauth2/authorize` (client_id=cms-sso)
