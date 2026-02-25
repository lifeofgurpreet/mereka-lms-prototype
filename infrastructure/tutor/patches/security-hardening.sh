#!/usr/bin/env bash
# Patch: Security hardening — HSTS, security headers, and Django security settings.
# Adds HSTS + security response headers to the Caddy Caddyfile template,
# and injects CSP / rate-limiting / session-cookie hardening into production.py.

apply_security_hardening_patch() {
  local targets=(
    "$CADDY_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/caddy/Caddyfile"
    "$LMS_SETTINGS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/openedx/settings/lms/production.py"
  )

  python - "${targets[@]}" <<'PY'
from pathlib import Path
import textwrap
import sys

targets = sys.argv[1:]

# Security headers snippet inserted into the Caddy global options or top-level snippet.
# We inject a named snippet that site blocks can import via `import security_headers`.
# The snippet is appended once if not already present.
CADDY_SECURITY_SNIPPET = textwrap.dedent("""
    # Security hardening headers (Mereka LMS)
    # Imported by LMS, Studio, and MFE site blocks via `import security_headers`.
    (security_headers) {
        header {
            # HSTS: 1 year, include sub-domains, allow preload
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
            # Prevent MIME-type sniffing
            X-Content-Type-Options "nosniff"
            # Deny embedding in iframes from other origins (overridden per-block where SAMEORIGIN needed)
            X-Frame-Options "SAMEORIGIN"
            # Disable legacy XSS filter (rely on CSP instead)
            X-XSS-Protection "0"
            # Restrict Referer to same-origin for cross-origin requests
            Referrer-Policy "strict-origin-when-cross-origin"
            # Limit browser feature access
            Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=()"
        }
    }
""").lstrip()

# Django security settings block to append to production.py.
# CSP uses report-only mode initially to avoid breaking existing MFE assets.
DJANGO_SECURITY_SETTINGS = textwrap.dedent("""

    # ── Security Hardening (T119) ────────────────────────────────────────────────
    # Session and CSRF cookie flags.
    # SESSION_COOKIE_SECURE / CSRF_COOKIE_SECURE are already set above based on
    # MEREKA_SCHEME; we enforce them unconditionally here for production safety.
    SESSION_COOKIE_SECURE = True
    SESSION_COOKIE_HTTPONLY = True
    CSRF_COOKIE_SECURE = True
    CSRF_COOKIE_HTTPONLY = False  # MFEs read the CSRF token from JS — must stay False

    # Content Security Policy.
    # Open edX ships django-csp (openedx/csp-middleware) but does not enable it by
    # default.  We configure it here in report-only mode first so that any directive
    # violations surface in browser DevTools / Sentry without blocking learners.
    # To enforce, change CSP_REPORT_ONLY to False after validating the report feed.
    CSP_REPORT_ONLY = os.environ.get("CSP_REPORT_ONLY", "true").lower() not in ("false", "0", "no")

    _lms_url = MEREKA_LMS_BASE_URL
    _mfe_url = MEREKA_MFE_BASE_URL
    _studio_url = MEREKA_STUDIO_BASE_URL

    # Allowlist sources used by Open edX + Mereka MFEs.
    # 'unsafe-inline' is required for legacy Open edX inline scripts/styles;
    # remove it incrementally as Waffle flags migrate pages to MFEs.
    CSP_DEFAULT_SRC = ("'self'",)
    CSP_SCRIPT_SRC = (
        "'self'",
        "'unsafe-inline'",  # Required by Open edX legacy courseware
        "'unsafe-eval'",    # Required by some xblocks and the Studio MFE
        _mfe_url,
        "https://cdn.jsdelivr.net",
        "https://cdnjs.cloudflare.com",
        "https://www.google-analytics.com",
        "https://www.googletagmanager.com",
    )
    CSP_STYLE_SRC = (
        "'self'",
        "'unsafe-inline'",  # Required by Open edX legacy theming
        _mfe_url,
        "https://fonts.googleapis.com",
        "https://cdn.jsdelivr.net",
    )
    CSP_FONT_SRC = (
        "'self'",
        _mfe_url,
        "https://fonts.gstatic.com",
        "data:",
    )
    CSP_IMG_SRC = (
        "'self'",
        "data:",
        "blob:",
        _lms_url,
        _mfe_url,
        "https:",  # Courses embed images from many CDNs; restrict further over time
    )
    CSP_CONNECT_SRC = (
        "'self'",
        _lms_url,
        _mfe_url,
        _studio_url,
        "https://www.google-analytics.com",
        "https://sentry.io",
    )
    CSP_FRAME_SRC = (
        "'self'",
        _lms_url,
        _mfe_url,
        _studio_url,
        "https://www.youtube.com",
        "https://player.vimeo.com",
    )
    CSP_MEDIA_SRC = ("'self'", "blob:", "https:")
    CSP_OBJECT_SRC = ("'none'",)
    CSP_BASE_URI = ("'self'",)
    CSP_FRAME_ANCESTORS = ("'self'",)

    # CSP violation report endpoint (optional; set to a Sentry CSP endpoint if available).
    _csp_report_uri = os.environ.get("CSP_REPORT_URI", "")
    if _csp_report_uri:
        CSP_REPORT_URI = _csp_report_uri

    # Rate limiting for authentication endpoints.
    # Open edX uses Django REST Framework throttling via openedx.core.lib.api.throttle.
    # These rates apply to anonymous and authenticated users respectively.
    # The built-in Open edX login/registration rate limiter is controlled via:
    #   - AUTHENTICATION_BACKENDS throttle settings
    #   - RateLimitMixin (openedx.core.djangoapps.util.ratelimit)
    # We configure DRF defaults here; per-view overrides live in edx-platform.
    REST_FRAMEWORK = dict(globals().get("REST_FRAMEWORK", {}))
    REST_FRAMEWORK.setdefault("DEFAULT_THROTTLE_CLASSES", [
        "openedx.core.lib.api.throttle.ScopedRateThrottle",
    ])
    REST_FRAMEWORK.setdefault("DEFAULT_THROTTLE_RATES", {})
    _throttle_rates = dict(REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"])
    # Auth endpoints: ~6 req/min burst for anon (≈30 per 5 min), 100/min for authenticated.
    _throttle_rates.setdefault("anon_burst",        os.environ.get("THROTTLE_ANON_BURST",        "6/min"))
    _throttle_rates.setdefault("user",              os.environ.get("THROTTLE_USER",              "100/min"))
    # Login-specific throttle (used by openedx.core.djangoapps.user_authn).
    _throttle_rates.setdefault("login_and_register", os.environ.get("THROTTLE_LOGIN_AND_REGISTER", "6/min"))
    # Password reset throttle.
    _throttle_rates.setdefault("password_reset",    os.environ.get("THROTTLE_PASSWORD_RESET",    "5/hour"))
    REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"] = _throttle_rates

    # Open edX specific login rate limit (separate from DRF; used by login view directly).
    # Limits: N failed login attempts per unit of time before lockout.
    FEATURES["ENABLE_ACCOUNT_ACTIVATION_EMAIL_LINK"] = True
    LOGIN_THROTTLE_ENABLED = os.environ.get("LOGIN_THROTTLE_ENABLED", "true").lower() not in ("false", "0", "no")
    MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED = int(os.environ.get("MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED", "10"))
    MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS = int(
        os.environ.get("MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS", "300")  # 5 minutes
    )
    # ── End Security Hardening ───────────────────────────────────────────────────
""").rstrip() + "\n"

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    if path.name == "Caddyfile":
        # Inject the security_headers snippet once, before the first site block.
        if "(security_headers)" not in updated:
            # Find the first site block (a line ending with ' {' that is not indented
            # and is not a global options block '{ ... }').
            lines = updated.splitlines(keepends=True)
            insert_at = None
            for i, line in enumerate(lines):
                stripped = line.strip()
                # Skip blank lines and comments
                if not stripped or stripped.startswith("#"):
                    continue
                # Skip the global options block `{ ... }`
                if stripped == "{":
                    # Skip until closing brace
                    depth = 1
                    i += 1
                    while i < len(lines) and depth > 0:
                        for ch in lines[i]:
                            if ch == "{":
                                depth += 1
                            elif ch == "}":
                                depth -= 1
                        i += 1
                    continue
                # First non-blank, non-comment, non-options line is our insertion point
                insert_at = i
                break
            if insert_at is not None:
                updated = "".join(lines[:insert_at]) + CADDY_SECURITY_SNIPPET + "".join(lines[insert_at:])

    if path.name == "production.py":
        # Append Django security settings once (guard on sentinel string).
        if "Security Hardening (T119)" not in updated:
            updated = updated.rstrip() + "\n" + DJANGO_SECURITY_SETTINGS

    if updated != original:
        path.write_text(updated)
PY
}
