#!/usr/bin/env bash
# Patch: CSRF trusted origins for extra domains.
# Adds biji-biji.com and skillourfuture origins to CSRF_TRUSTED_ORIGINS.

apply_csrf_origins_patch() {
  local targets=(
    "$LMS_SETTINGS_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/apps/openedx/settings/lms/production.py"
  )

  python - "${targets[@]}" <<'PY'
from pathlib import Path
import sys

targets = sys.argv[1:]

extra_csrf_origins = [
    "https://academy.biji-biji.com",
    "https://apps.academy.biji-biji.com",
    "https://skillourfuture.academy.mereka.io",
]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    original = path.read_text()
    updated = original

    anchor = 'CSRF_TRUSTED_ORIGINS.append("apps.academyv2.mereka.io")'
    if anchor not in updated:
        if updated != original:
            path.write_text(updated)
        continue
    inserts = ""
    for origin in extra_csrf_origins:
        if origin not in updated:
            inserts += f'\nCSRF_TRUSTED_ORIGINS.append("{origin}")'
    if not inserts:
        continue
    index = updated.index(anchor) + len(anchor)
    updated = updated[:index] + inserts + updated[index:]

    if updated != original:
        path.write_text(updated)
PY
}
