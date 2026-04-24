#!/usr/bin/env bash
# @covers AC-MTA-014
# @spec: multi-tenancy-architecture_spec.md
# verify-siteconfig-authority.sh — lock direct SiteConfiguration writers to a reviewed set.
#
# Why:
# - SiteConfiguration and MFE_CONFIG are runtime authority surfaces.
# - New side-door mutators can silently overwrite canonical tenant config.
# - This guard fails CI when repo-owned runtime writers expand without review.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ALLOWLIST_FILE="${ALLOWLIST_FILE_OVERRIDE:-${REPO_ROOT}/scripts/qa/fixtures/siteconfig-authority-allowlist.txt}"

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  echo "FAIL: SiteConfiguration authority allowlist missing: $ALLOWLIST_FILE" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CURRENT_FILE="${TMP_DIR}/current.txt"

python3 - <<'PY' "$REPO_ROOT" >"$CURRENT_FILE"
from __future__ import annotations

import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])

patterns = [
    re.compile(r"\bSiteConfiguration\.objects\.(?:update_or_create|get_or_create|create)\("),
    re.compile(r"INSERT INTO site_configuration_siteconfiguration"),
    re.compile(r"UPDATE site_configuration_siteconfiguration"),
    re.compile(r"\b(?:site_config|cfg|sc)\.site_values\s*="),
    re.compile(r"""\[(?:"|')MFE_CONFIG(?:"|')\]\.update\("""),
    re.compile(r"""\b(?:site_values|values|rendered_values|mfe_site_values)\[(?:"|')MFE_CONFIG(?:"|')\]\s*="""),
]

candidates: set[str] = set()
excluded_paths = {
    "scripts/qa/verify-siteconfig-authority.sh",
    "scripts/qa/test-verify-siteconfig-authority.sh",
}

for root_name in ("scripts", "infrastructure"):
    root = repo_root / root_name
    if not root.exists():
        continue
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        relative_path = path.relative_to(repo_root).as_posix()
        if relative_path in excluded_paths:
            continue
        if any(pattern.search(text) for pattern in patterns):
            candidates.add(relative_path)

for candidate in sorted(candidates):
    print(candidate)
PY

mapfile -t current_candidates < "$CURRENT_FILE"
mapfile -t allowlisted_candidates < <(
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$ALLOWLIST_FILE"
)

unexpected=()
for path in "${current_candidates[@]}"; do
  if ! (printf '%s\n' "${allowlisted_candidates[@]}" || true) | grep -Fxq "$path"; then
    unexpected+=("$path")
  fi
done

stale=()
for path in "${allowlisted_candidates[@]}"; do
  if ! (printf '%s\n' "${current_candidates[@]}" || true) | grep -Fxq "$path"; then
    stale+=("$path")
  fi
done

if [[ "${#unexpected[@]}" -gt 0 ]]; then
  echo "FAIL: unreviewed SiteConfiguration/MFE_CONFIG writer candidates detected."
  echo "These paths directly mutate runtime SiteConfiguration state and must be"
  echo "explicitly reviewed before they become part of the accepted authority set."
  printf '  %s\n' "${unexpected[@]}"
  exit 1
fi

if [[ "${#stale[@]}" -gt 0 ]]; then
  echo "WARN: stale SiteConfiguration authority allowlist entries detected:"
  printf '  %s\n' "${stale[@]}"
fi

echo "PASS: SiteConfiguration/MFE_CONFIG writer authority matches reviewed allowlist."
