#!/usr/bin/env bash
# @covers AC-002
# @spec: auth-sso-enterprise_spec.md
# Verify multisite cookie-domain middleware ordering guardrails for OIDC.
#
# Why this matters:
# - During /auth/login/oidc/, Django stores OAuth state in the session cookie.
# - If cookie-domain rewriting runs too early in response order, the cookie can
#   stay host-only and callback validation fails with "Session value state missing".
#
# This script is repo-local and CI-safe (no kubectl required).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

python3 - "$REPO_ROOT" <<'PY'
from pathlib import Path
import sys

repo = Path(sys.argv[1])
checks = [
    (
        repo / "deploy/k8s/base/apps/openedx/settings/lms/production.py",
        "lms.envs.tutor.mereka_multisite.MerekaCookieDomainMiddleware",
    ),
    (
        repo / "deploy/k8s/base/apps/openedx/settings/cms/production.py",
        "cms.envs.tutor.mereka_multisite.MerekaCookieDomainMiddleware",
    ),
]

# The actual code may use either the exact two-variable form or the more general
# loop-and-min pattern. Accept both: require the session middleware constant and
# at least one of the known reordering patterns.
required_constants = [
    '_session_middleware = "django.contrib.sessions.middleware.SessionMiddleware"',
]
# Accept any of these reordering patterns (exact match or general form)
reordering_patterns = [
    # General form (loop over targets, use min)
    ("if _cookie_idx > _earliest:", "MIDDLEWARE.insert(_earliest, MIDDLEWARE.pop(_cookie_idx))"),
    # Exact two-variable form
    ("if cookie_index > session_index:", "MIDDLEWARE.insert(session_index, MIDDLEWARE.pop(cookie_index))"),
]

failed = False
for path, cookie_middleware in checks:
    text = path.read_text(encoding="utf-8")
    file_failed = False
    if cookie_middleware not in text:
        print(f"FAIL {path}: missing cookie middleware reference {cookie_middleware}")
        failed = True
        file_failed = True
        continue
    for fragment in required_constants:
        if fragment not in text:
            print(f"FAIL {path}: missing hardening constant: {fragment}")
            failed = True
            file_failed = True
    # Check that at least one reordering pattern is present
    has_reordering = False
    for pattern_set in reordering_patterns:
        if all(p in text for p in pattern_set):
            has_reordering = True
            break
    if not has_reordering:
        print(f"FAIL {path}: no recognized middleware reordering pattern found")
        failed = True
        file_failed = True
    if not file_failed:
        print(f"OK   {path}: cookie middleware hardening fragments present")

if failed:
    sys.exit(1)
PY
