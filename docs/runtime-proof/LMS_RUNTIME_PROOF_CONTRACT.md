# LMS Runtime Proof Contract

This document defines the schema, semantics, and interpretation of LMS runtime proof artifacts.

## Artifact Filenames

| Environment | Proof Artifact | Host Acceptance | SiteConfig | MFE Config | Cookie | Auth Redirect |
|-------------|----------------|-----------------|------------|------------|--------|---------------|
| staging | `var/proof/staging-runtime-proof.json` | `var/proof/staging-host-acceptance.json` | `var/proof/staging-siteconfig-proof.json` | `var/proof/staging-mfe-config.json` | `var/proof/staging-cookie-proof.json` | `var/proof/staging-auth-redirect.json` |
| dev | `var/proof/dev-runtime-proof.json` | `var/proof/dev-host-acceptance.json` | `var/proof/dev-siteconfig-proof.json` | `var/proof/dev-mfe-config.json` | `var/proof/dev-cookie-proof.json` | `var/proof/dev-auth-redirect.json` |

## Consolidated Proof Schema

The main artifact (`{env}-runtime-proof.json`) contains:

```json
{
  "environment": "staging|dev",
  "namespace": "stg-mereka-lms|mereka-lms-dev",
  "timestamp": "2026-03-09T00:00:00Z",
  "lms_pod": "lms-abc123",
  "cms_pod": "cms-def456",
  "mfe_pod": "mfe-ghi789",
  "images": {
    "lms": { "image": "full-image:tag", "tag": "sha-or-digest", "ok": true },
    "cms": { "image": "...", "tag": "...", "ok": true },
    "mfe": { "image": "...", "tag": "...", "ok": true }
  },
  "results": [
    {
      "section": "image_truth|module_presence|host_acceptance|site_config|mfe_config|cookie_domain|auth_redirect",
      "check": "human-readable description",
      "status": "PASS|FAIL|SKIP",
      "critical": true|false,
      "details": {}
    }
  ],
  "tenant_classification": {
    "slug": "proven_now|app_proven_external_blocked|app_blocked|unproven"
  },
  "summary": {
    "pass": 39,
    "fail": 1,
    "fail_critical": 0,
    "skip": 0,
    "overall": "PASS|FAIL"
  }
}
```

## Tenant Classification Buckets

| Bucket | Meaning | Criteria |
|--------|---------|----------|
| `proven_now` | All checks pass including external reachability | Zero failures for this tenant across all 7 sections |
| `app_proven_external_blocked` | App-owned checks pass, infra-owned checks fail | All critical checks pass; non-critical failures are infra-owned (DNS, admin host, Caddy proxy) |
| `app_blocked` | App-owned logic has proven defects | At least one critical failure in SiteConfig, MFE config, cookie, or auth redirect |
| `unproven` | Proof has not been run or data is insufficient | Tenant was skipped or proof script could not reach the namespace |

## Critical vs Non-Critical Checks

**Critical** (block lane closure):
- Image truth (no `:latest`, no banned commits)
- Module presence (middleware importable + in MIDDLEWARE list)
- Host acceptance for LMS, Studio, MFE
- SiteConfiguration existence + enabled + correct URLs
- MFE config content correctness (wrong values = contamination)
- Cookie domain match (when Domain attribute is present)
- Auth redirect to correct tenant MFE

**Non-critical** (informational, infra-owned):
- Admin host reachability (requires DNS/ingress routing)
- MFE config endpoint unreachable (Caddy→LMS proxy timeout)
- Cookie domain host-only (middleware ordering not yet deployed)

## Non-Critical Failure Representation

Non-critical failures appear in the `results` array with `"critical": false`. They increment `summary.fail` but NOT `summary.fail_critical`. The overall result is `PASS` when `fail_critical == 0`.

## Image Truth

The `images` object captures the deployed container image tag for LMS, CMS, and MFE. Tags must:
- Not be `:latest`
- Not match `BANNED_COMMIT` (known-broken builds)
- Be a git SHA or content-addressable digest

## Cookie Domain Proof

Uses `/csrf/api/v1/token` endpoint (reliably triggers CsrfViewMiddleware to set csrftoken cookie). The proof extracts the `Domain=` attribute from the `Set-Cookie: csrftoken=...` header.

Valid states:
- **Exact match**: `Domain=.academyv2.mereka.io` matches expected `.academyv2.mereka.io`
- **Host-only**: No `Domain=` attribute (cookie scoped to exact host). Accepted when middleware ordering fix is not yet deployed.

Invalid states:
- **Mismatch**: Domain attribute present but wrong value
- **Contamination**: biji-biji tenant gets mereka domain (or vice versa)

## SiteConfiguration Truth

Checked via `kubectl exec` into the LMS pod running Django ORM queries. Verifies:
- `Site` row exists for the tenant domain
- `SiteConfiguration` row exists and is enabled
- `LMS_ROOT_URL` matches the canonical HTTPS URL
- `MFE_BASE_URL` matches the canonical MFE host

## Auth Redirect Proof

Verifies that `GET /login` on each LMS host redirects to the correct tenant-specific MFE authn URL. The `Location` header must contain the tenant's MFE host (e.g., `apps.academyv2.mereka.dev/authn`).
