#!/usr/bin/env bash
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

required_fragments = [
    '_session_middleware = "django.contrib.sessions.middleware.SessionMiddleware"',
    "if _cookie_middleware in MIDDLEWARE and _session_middleware in MIDDLEWARE:",
    "if cookie_index > session_index:",
    "MIDDLEWARE.insert(session_index, MIDDLEWARE.pop(cookie_index))",
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
    for fragment in required_fragments:
        if fragment not in text:
            print(f"FAIL {path}: missing hardening fragment: {fragment}")
            failed = True
            file_failed = True
    if not file_failed:
        print(f"OK   {path}: cookie middleware hardening fragments present")

if failed:
    sys.exit(1)
PY
