#!/usr/bin/env bash
# Patch: MongoDB Atlas SRV support.
# Installs pymongo[srv] (dnspython) for Atlas SRV connection strings.
# This is applied as part of the openedx Dockerfile patch in build-optimizations.sh
# but kept as a separate logical unit for clarity.

apply_mongodb_atlas_patch() {
  local targets=(
    "$OPENEDX_TEMPLATE"
    "$REPO_ROOT/tutor_env/env/build/openedx/Dockerfile"
  )

  python - "${targets[@]}" <<'PY'
from pathlib import Path
import sys

targets = sys.argv[1:]

for target in targets:
    path = Path(target)
    if not path.exists():
        continue
    if path.name != "Dockerfile":
        continue
    original = path.read_text()
    updated = original

    # Install pymongo SRV extras for MongoDB Atlas (requires dnspython)
    base_req_marker = "bash -o pipefail -c 'for attempt in 1 2 3; do pip install -r /openedx/edx-platform/requirements/edx/base.txt && exit 0; echo \"pip install attempt ${attempt} failed; retrying in 10s\" >&2; sleep 10; done; exit 1'"
    if base_req_marker in updated and "pymongo[srv]" not in updated and "dnspython" not in updated:
        pymongo_marker = "RUN pip install django-prometheus==2.3.1"
        pymongo_install = """RUN pip install django-prometheus==2.3.1\n\n# Install pymongo SRV extras for MongoDB Atlas
RUN pip install "pymongo[srv]" """
        if pymongo_marker in updated:
            updated = updated.replace(pymongo_marker, pymongo_install)
        else:
            updated = updated.replace(
                base_req_marker,
                base_req_marker + """\n\n# Install pymongo SRV extras for MongoDB Atlas
RUN pip install "pymongo[srv]" """,
            )

    if updated != original:
        path.write_text(updated)
PY
}
