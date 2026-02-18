# Multi-Site UX Consistency Contract

**Status**: Phase 1 — Audit Complete
**Owner**: Frontend Team
**Last Updated**: 2026-02-17

## Problem

Mereka LMS serves **multiple root domains**:
- **Primary**: `academyv2.mereka.io`
- **Alternative**: `academy.biji-biji.com`
- **Tenant-specific**: Future domains (e.g., `skillourfuture.academy.mereka.io`)

MFEs are **JavaScript-heavy React SPAs** that fetch configuration from `/api/mfe_config/v1` at runtime. The concern is that:
1. **Hardcoded domain references** in MFE build artifacts break on alternative domains
2. **Inconsistent branding** across domains (wrong logo, footer, cookie domain)
3. **Cross-domain auth failures** if session/CSRF cookies are domain-locked

This contract defines **multisite UX consistency rules** to ensure all domains deliver a unified experience.

---

## Architecture

### Configuration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  Browser (any domain)                                            │
│   - academyv2.mereka.io                                          │
│   - academy.biji-biji.com                                        │
│   - skillourfuture.academy.mereka.io                             │
└─────────────────────────────────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  Caddy (MFE proxy)                                               │
│   - Reverse proxies /api/mfe_config/v1 → LMS                    │
│   - Reverse proxies /login_refresh → LMS (JWT cookie refresh)   │
│   - Preserves Host header for site resolution                   │
└─────────────────────────────────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  LMS Django (production.py)                                      │
│   - Reads Host header (e.g., "academy.biji-biji.com")           │
│   - Resolves SiteConfiguration based on domain                  │
│   - Generates MFE_CONFIG with site-specific values:             │
│     * SITE_NAME: "Biji-Biji Academy"                            │
│     * LMS_BASE_URL: "https://academy.biji-biji.com"             │
│     * MFE_BASE_URL: "https://apps.academy.biji-biji.com"        │
│     * LOGO_URL: "/theming/asset/mereka/images/logo.png"         │
│     * SESSION_COOKIE_DOMAIN: None (host-only)                   │
│     * CSRF_COOKIE_DOMAIN: None (host-only)                      │
└─────────────────────────────────────────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  MFE JavaScript (runtime)                                        │
│   - Calls getConfig() to fetch MFE_CONFIG                       │
│   - Uses LMS_BASE_URL for API calls                             │
│   - Uses LOGO_URL for branding                                  │
│   - MerekaFooter reads SITE_NAME for variant mapping            │
└─────────────────────────────────────────────────────────────────┘
```

### Key Settings

**File**: `deploy/k8s/base/apps/openedx/settings/lms/production.py`

```python
# Dynamic domain resolution
MEREKA_LMS_DOMAIN = os.environ.get("MEREKA_LMS_DOMAIN", "academyv2.mereka.io")
MEREKA_BIJI_DOMAIN = os.environ.get("MEREKA_BIJI_DOMAIN", "academy.biji-biji.com")

MEREKA_LMS_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_LMS_DOMAIN}"
MEREKA_MFE_BASE_URL = f"{MEREKA_SCHEME}://apps.{MEREKA_LMS_DOMAIN}"

# MFE_CONFIG uses dynamic base URLs (NOT hardcoded)
MFE_CONFIG = {
    "BASE_URL": MEREKA_MFE_DOMAIN,
    "LMS_BASE_URL": MEREKA_LMS_BASE_URL,  # Resolved per-request
    "LOGO_URL": f"{MEREKA_LMS_BASE_URL}/theming/asset/{DEFAULT_SITE_THEME}/images/logo.png",
    "SITE_NAME": "Mereka Academy",  # Overridden by SiteConfiguration
    # ...
}

# Multi-site cookie domains (host-only)
SESSION_COOKIE_DOMAIN = None  # NOT ".academyv2.mereka.io"
CSRF_COOKIE_DOMAIN = None     # NOT ".academyv2.mereka.io"
```

**File**: `infrastructure/tutor/plugins/mereka_lms.py`

```javascript
// MerekaFooter v2 — reads hostname at runtime
const MerekaFooter = () => {
  const config = getConfig();
  const hostname = typeof window !== 'undefined' ? window.location.hostname : '';

  const SITE_VARIANTS = {
    'academyv2.mereka.io': { brand: 'Mereka Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
    'academy.biji-biji.com': { brand: 'Biji-Biji Academy', copyrightHolder: 'Biji-Biji Initiative', whatsapp: '601135271981' },
    'skillourfuture.academy.mereka.io': { brand: 'Skill Our Future Academy', copyrightHolder: 'MEREKA', whatsapp: '601135271981' },
  };
  const variant = SITE_VARIANTS[hostname] || { brand: siteName, copyrightHolder: 'MEREKA', whatsapp: '601135271981' };

  // Footer renders with variant-specific branding
  return <footer className="mereka-footer">...</footer>;
};
```

---

## Audit Findings

### ✅ PASS: Dynamic Configuration (Low Risk)

**Locations**: Environment-driven settings in `production.py`

| File | Line | Finding | Risk |
|------|------|---------|------|
| `production.py` | 110-112 | `MEREKA_LMS_DOMAIN = os.environ.get(...)` | **LOW** — Configurable via env vars |
| `production.py` | 118-119 | `MEREKA_MFE_DOMAIN = os.environ.get(...)` | **LOW** — Configurable via env vars |
| `production.py` | 162-164 | `MEREKA_LMS_BASE_URL = f"{MEREKA_SCHEME}://{MEREKA_LMS_DOMAIN}"` | **LOW** — Dynamically constructed |
| `production.py` | 661-689 | `MFE_CONFIG = { "BASE_URL": MEREKA_MFE_DOMAIN, "LMS_BASE_URL": MEREKA_LMS_BASE_URL, ... }` | **LOW** — Uses dynamic variables |
| `production.py` | 649-650 | `SESSION_COOKIE_DOMAIN = None`, `CSRF_COOKIE_DOMAIN = None` | **LOW** — Host-only cookies (correct) |
| `mereka_lms.py` | 619-623 | `SITE_VARIANTS` hostname mapping in MerekaFooter | **LOW** — Runtime hostname check |

**Explanation**: These are **environment-variable-driven** settings that resolve dynamically per-request. They don't break on alternative domains.

### ⚠️ WARN: Default Fallbacks (Medium Risk)

**Locations**: Hardcoded defaults in env var calls

| File | Line | Finding | Risk |
|------|------|---------|------|
| `production.py` | 110 | `os.environ.get("MEREKA_LMS_DOMAIN", "academyv2.mereka.io")` | **MEDIUM** — Falls back to primary domain if env var missing |
| `production.py` | 112 | `os.environ.get("MEREKA_BIJI_DOMAIN", "academy.biji-biji.com")` | **MEDIUM** — Fallback acceptable (alternative domain) |
| `production.py` | 119 | `os.environ.get("MEREKA_MFE_DOMAIN", f"apps.{MEREKA_LMS_DOMAIN}")` | **MEDIUM** — Derived from LMS domain (acceptable) |
| `mereka_lms.py` | 47 | `("MEREKA_SESSION_COOKIE_DOMAIN", ".academyv2.mereka.io")` | **HIGH** — Plugin default breaks multi-site (see below) |
| `mereka_lms.py` | 48 | `("MEREKA_CSRF_COOKIE_DOMAIN", ".academyv2.mereka.io")` | **HIGH** — Plugin default breaks multi-site (see below) |

**Explanation**:
- **production.py fallbacks** are **acceptable** because they only activate when env vars are missing (dev/local environments).
- **mereka_lms.py cookie domain defaults** are **OVERRIDDEN** by `production.py` lines 649-650 (`SESSION_COOKIE_DOMAIN = None`), so they don't affect production. However, they create risk if `production.py` patch is accidentally removed.

### 🔴 FAIL: Hardcoded Domains (High Risk)

**Locations**: Plugin code with hardcoded domain strings

| File | Line | Finding | Risk |
|------|------|---------|------|
| `apply-patches.sh` | 200 | `DISCUSSIONS_MICROFRONTEND_URL` — **RESOLVED** (2026-02-18): now uses `MEREKA_MFE_BASE_URL` | ~~HIGH~~ **FIXED** |
| `mereka_lms.py` | 823 | `apps.academyv2.mereka.io { reverse_proxy /profile/api/* lms:8000 { header_up Host academyv2.mereka.io } }` | **HIGH** — Caddy config hardcoded |
| `mereka_lms.py` | 862 | `proxy_set_header Host academyv2.mereka.io;` | **HIGH** — Nginx proxy hardcoded |

**Impact**:
- **Line 79**: Discussions MFE always points to `apps.academyv2.mereka.io`, even when accessed from `academy.biji-biji.com`. Users on alternative domains get redirected to the wrong MFE origin.
- **Line 823**: Profile API proxy only works for `apps.academyv2.mereka.io`. Alternative domains (`apps.academy.biji-biji.com`) get **404** on `/profile/api/*` calls.
- **Line 862**: Nginx always sends `Host: academyv2.mereka.io` to LMS backend, breaking SiteConfiguration resolution.

**Recommended Fix**:
```python
# Line 79 — Use dynamic domain
DISCUSSIONS_MICROFRONTEND_URL = f"{MEREKA_MFE_BASE_URL}/discussions"

# Lines 823-828 — Dynamic Caddy block (template with MEREKA_LMS_EXTRA_HOSTS)
{% for host in [MEREKA_LMS_DOMAIN, MEREKA_BIJI_DOMAIN, MEREKA_SKILLOURFUTURE_DOMAIN] %}
apps.{{ host }} {
    reverse_proxy /profile/api/* lms:8000 {
        header_up Host {{ host }}  # Preserve original host
    }
    reverse_proxy nginx:80
}
{% endfor %}

# Line 862 — Preserve original Host header
proxy_set_header Host $http_host;  # NOT "academyv2.mereka.io"
```

### 📝 INFO: Documentation/Comment References (Low Risk)

**Locations**: Comments, help text, examples

| File | Line | Finding | Risk |
|------|------|---------|------|
| `patch-manifest.yml` | 3 | `"Proxies /profile/api/ from apps.academyv2.mereka.io to LMS"` | **LOW** — Comment only |
| `custom-apps/mfe_oauth_fix/views.py` | 14 | `for the academyv2.mereka.io site (site_id=6).` | **LOW** — Docstring only |
| `custom-apps/openedx_video_protection/utils.py` | 18 | `audience: Domain restriction (e.g., "academyv2.mereka.io")` | **LOW** — Example only |
| `custom-apps/openedx_mobile_api/ios_offline.py` | 22 | `help_text="Domain being verified (e.g., academyv2.mereka.io)"` | **LOW** — Help text only |
| `multisite-sites.yml` | 2 | `- domain: academyv2.mereka.io` | **LOW** — Config file for testing |

**Explanation**: These are **documentation strings** that don't affect runtime behavior. Safe to leave as-is.

---

## Multi-Site Contract Rules

### Rule 1: No Hardcoded Production Domains in MFE Config/Build Artifacts

**Requirement**: MFE build artifacts (`index.html`, `main.*.js`) MUST NOT contain hardcoded `academyv2.mereka.io` or `apps.academyv2.mereka.io` strings.

**Verification**:
```bash
# Check MFE pod for hardcoded domains
kubectl exec -n mereka-lms <mfe-pod> -- \
  grep -r "academyv2.mereka.io" /openedx/dist/
# Expected: 0 matches
```

**Compliance**:
- ✅ **MFE JavaScript**: Uses `getConfig()` to fetch runtime configuration
- ✅ **env.config.jsx**: MerekaFooter reads `window.location.hostname` at runtime
- ✅ **FIXED** (2026-02-18): `apply-patches.sh` now uses `MEREKA_MFE_BASE_URL` for `DISCUSSIONS_MICROFRONTEND_URL`

### Rule 2: All User-Facing URLs Must Come from MFE_CONFIG or Environment Variables

**Requirement**: Any URL displayed to users (login, dashboard, API endpoints) MUST be sourced from:
- `getConfig().LMS_BASE_URL` (MFE JavaScript)
- `os.environ.get("MEREKA_LMS_BASE_URL")` (Python)
- `MFE_CONFIG["LMS_BASE_URL"]` (Django template)

**Verification**:
```bash
# Check for hardcoded https:// URLs in templates
rg 'https://(academyv2|apps)\.mereka\.io' \
  infrastructure/tutor/themes/mereka/ \
  deploy/k8s/base/apps/openedx/settings/
# Expected: Only in comments/docs
```

**Compliance**:
- ✅ **LMS settings**: `MFE_CONFIG` uses dynamic `MEREKA_LMS_BASE_URL`
- ✅ **MerekaFooter v2**: Reads `config.LMS_BASE_URL` for links
- 🔴 **FAIL**: Caddy/Nginx configs hardcode `academyv2.mereka.io`

### Rule 3: CSRF/Session Cookie Domains Must Be Dynamic

**Requirement**: `SESSION_COOKIE_DOMAIN` and `CSRF_COOKIE_DOMAIN` MUST be **host-only** (`None`) or dynamically set per-request via middleware.

**Why**: A single static cookie domain (e.g., `.academyv2.mereka.io`) is invalid on `academy.biji-biji.com`. Browsers will drop the cookie.

**Verification**:
```python
# Check production.py
assert SESSION_COOKIE_DOMAIN is None, "Multi-site requires host-only session cookies"
assert CSRF_COOKIE_DOMAIN is None, "Multi-site requires host-only CSRF cookies"
```

**Compliance**:
- ✅ **production.py**: Lines 649-650 set `None` (host-only)
- ⚠️ **WARN**: `mereka_lms.py` lines 47-48 have `.academyv2.mereka.io` defaults (overridden in production.py)

### Rule 4: Footer/Header Links Must Use Relative Paths or Config-Provided Base URLs

**Requirement**: Navigation links in MerekaFooter MUST NOT hardcode `https://academyv2.mereka.io/...`.

**Compliant patterns**:
```javascript
// ✅ Relative path
<a href="/dashboard">Dashboard</a>

// ✅ Config-provided base URL
const baseUrl = getConfig().LMS_BASE_URL;
<a href={`${baseUrl}/courses`}>Courses</a>

// ❌ Hardcoded absolute URL
<a href="https://academyv2.mereka.io/courses">Courses</a>
```

**Compliance**:
- ✅ **MerekaFooter v2**: All external links go to `corporate.mereka.io` (external site, OK)
- ✅ **Internal links**: Use `baseUrl` from `getConfig()`

---

## Quick Wins

### Fix 1: Dynamic Discussions MFE URL — RESOLVED (2026-02-18)

**File**: `infrastructure/tutor/apply-patches.sh` (patched into `lms/production.py`)

**Before**:
```python
DISCUSSIONS_MICROFRONTEND_URL = "https://apps.academyv2.mereka.io/discussions"
```

**After** (applied in `apply-patches.sh`):
```python
if "DISCUSSIONS_MICROFRONTEND_URL" not in globals():
    _mfe_base = globals().get("MEREKA_MFE_BASE_URL", "https://apps.academyv2.mereka.io")
    DISCUSSIONS_MICROFRONTEND_URL = f"{_mfe_base}/discussions"
```

**Impact**: Discussions MFE now works on `academy.biji-biji.com`. Uses dynamic `MEREKA_MFE_BASE_URL` variable.

### Fix 2: Dynamic Caddy Profile API Proxy

**File**: `infrastructure/tutor/plugins/mereka_lms.py:823-828`

**Before**:
```caddyfile
apps.academyv2.mereka.io {
    reverse_proxy /profile/api/* lms:8000 {
        header_up Host academyv2.mereka.io
    }
}
```

**After**:
```caddyfile
{% for host in [MEREKA_LMS_DOMAIN, MEREKA_BIJI_DOMAIN, MEREKA_SKILLOURFUTURE_DOMAIN] %}
apps.{{ host }} {
    reverse_proxy /profile/api/* lms:8000 {
        header_up Host {{ host }}  # Preserve original host for SiteConfiguration
    }
    reverse_proxy nginx:80
}
{% endfor %}
```

**Impact**: Profile API works on all domains.

### Fix 3: Dynamic Nginx Host Header

**File**: `infrastructure/tutor/plugins/mereka_lms.py:862`

**Before**:
```nginx
proxy_set_header Host academyv2.mereka.io;
```

**After**:
```nginx
proxy_set_header Host $http_host;  # Preserve original host
```

**Impact**: LMS can resolve correct SiteConfiguration for each domain.

---

## Verification

**Script**: `scripts/qa/verify-multisite-ux-consistency.sh`

**Coverage**:
- AC-MSUX-001: Contract documents multisite UX requirements
- AC-MSUX-002: Verifier detects hardcoded domain references
- AC-MSUX-003: CI gate prevents new hardcoded references

**Expected result**: 15+ PASS / 0 FAIL after Quick Wins applied

---

## Change History

| Date | Author | Change |
|------|--------|--------|
| 2026-02-18 | Bead 8jao.16 | Domain hardening: fixed DISCUSSIONS_MICROFRONTEND_URL, CSRF origins, Caddyfile split docs, resolved spec contradictions |
| 2026-02-17 | Bead 1rda | Initial audit — 3 HIGH-risk findings documented |

---

## Caddyfile Split: Local vs K8s

**Important**: There are two separate Caddyfile configurations that diverge in multi-site behavior:

| Surface | Path | Multi-site safe? |
|---------|------|------------------|
| **K8s production** | `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` | YES — uses `{http.request.host}` |
| **Tutor local** | Generated from `mereka_lms.py` caddy-caddyfile patch | PARTIAL — profile API block hardcoded to `apps.academyv2.mereka.io` |

Developers testing locally with Tutor get different Caddy routing behavior than K8s production. The K8s Caddyfile is the canonical source of truth. The local Caddy block is acceptable for dev-only use since only `academyv2.mereka.io` is configured locally.

---

## Related Documents

- `docs/architecture/MFE_ROUTE_TO_DIST_CONTRACT.md` — MFE routing contract
- `specs/branding-system_spec.md` — Branding system spec (AC-UI-*, AC-MSUX-*)
- `scripts/qa/verify-mfe-branding.sh` — MFE branding verifier
- `AGENTS.md` — Repository guidelines
