#!/usr/bin/env bash
# Dry-run checks for Kajabi + MCT migration pipelines
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

MCT_BASE_URL="${MCT_BASE_URL:-learn.skillourfuture.org}"
MCT_RESOURCES="${MCT_RESOURCES:-users,courses,enrollments}"

printf "== MCT dry run ==\n"
MCT_BASE_URL="$MCT_BASE_URL" node scripts/migrations/mct/mct-export.mjs --dry-run --resources "$MCT_RESOURCES"

printf "\n== Kajabi dry run ==\n"

manifest="scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv"
alt_manifest="var/migrations/kajabi/course_packages/course_packages_manifest.csv"

if [[ -f "$manifest" ]]; then
  manifest_path="$manifest"
elif [[ -f "$alt_manifest" ]]; then
  manifest_path="$alt_manifest"
else
  echo "! Kajabi manifest not found at:" >&2
  echo "  - $manifest" >&2
  echo "  - $alt_manifest" >&2
  echo "  Skipping Kajabi dry run until artifacts are available." >&2
  exit 0
fi

packages_root="$(dirname "$manifest_path")"

MANIFEST_PATH="$manifest_path" PACKAGES_ROOT="$packages_root" python3 - <<'PY'
import csv
import os
from pathlib import Path

manifest = Path(os.environ["MANIFEST_PATH"])
packages_root = Path(os.environ["PACKAGES_ROOT"])

rows = list(csv.DictReader(manifest.open(encoding="utf-8")))
missing = 0
for row in rows:
    rel = row.get("package_path")
    if not rel:
        continue
    tarball = packages_root / rel
    if not tarball.exists():
        missing += 1

print(f"✓ Manifest: {manifest}")
print(f"✓ Packages root: {packages_root}")
print(f"✓ Courses in manifest: {len(rows)}")
if missing:
    print(f"! Missing tarballs: {missing}")
else:
    print("✓ All tarballs present")
PY
