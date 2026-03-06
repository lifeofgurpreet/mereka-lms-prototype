#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012
# @spec: repository-structure_spec.md
# Verify repository structure against specs/repository-structure_spec.md.
#
# This is intentionally fast, deterministic, and safe:
# - No network calls
# - No destructive operations
# - Supports REPO_ROOT_OVERRIDE for isolated tests
#
# Usage:
#   ./scripts/qa/verify-repo-structure.sh
#
# Env:
#   REPO_ROOT_OVERRIDE=/path/to/repo_like_tree   (optional)
#   ALLOW_EXTRA_ROOT_MD=1                        (optional; do not fail on root markdown allowlist)
set -euo pipefail

REPO_ROOT_OVERRIDE="${REPO_ROOT_OVERRIDE:-}"
ALLOW_EXTRA_ROOT_MD="${ALLOW_EXTRA_ROOT_MD:-0}"

REPO_ROOT=""
if [[ -n "$REPO_ROOT_OVERRIDE" ]]; then
  REPO_ROOT="$REPO_ROOT_OVERRIDE"
elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  REPO_ROOT="$(git rev-parse --show-toplevel)"
else
  echo "[FAIL] Unable to determine repo root (set REPO_ROOT_OVERRIDE=...)" >&2
  exit 2
fi

cd "$REPO_ROOT"

failures=0

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

exists_dir() {
  local path="$1"
  [[ -d "$path" ]]
}

exists_file() {
  local path="$1"
  [[ -f "$path" ]]
}

check_dir() {
  local path="$1"
  if exists_dir "$path"; then
    pass "Directory exists: $path/"
  else
    fail "Directory missing: $path/"
  fi
}

check_file() {
  local path="$1"
  if exists_file "$path"; then
    pass "File exists: $path"
  else
    fail "File missing: $path"
  fi
}

check_deprecated_dir() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    pass "Deprecated directory absent: $path/"
    return 0
  fi
  if [[ ! -d "$path" ]]; then
    fail "Deprecated path exists but is not a directory: $path"
    return 0
  fi
  local count
  count="$(find "$path" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ "$count" -eq 1 && -f "$path/README.md" ]]; then
    pass "Deprecated directory tombstone ok: $path/README.md"
  else
    fail "Deprecated directory must be absent or contain only README.md: $path/"
  fi
}

check_gitignore_has() {
  local pattern_re="$1"
  if [[ ! -f ".gitignore" ]]; then
    fail ".gitignore missing"
    return 0
  fi
  if rg -n --fixed-strings -- "$pattern_re" .gitignore >/dev/null 2>&1; then
    pass ".gitignore contains pattern: $pattern_re"
  else
    if grep -q "$pattern_re" .gitignore 2>/dev/null; then
      pass ".gitignore contains pattern: $pattern_re"
    else
      fail ".gitignore missing pattern: $pattern_re"
    fi
  fi
}

echo "Repo root: $REPO_ROOT"

# AC-001: Required top-level directories exist.
for d in deploy scripts infrastructure docs specs services assets; do
  check_dir "$d"
done

# AC-002: Root markdown allowlist.
allowed_root_md=(
  "README.md"
  "CLAUDE.md"
  "AGENTS.md"
  "CONTRIBUTING.md"
  "MIGRATION_CHECKLIST.md"
  "LOCAL_SETUP_COMPLETE.md"
  "DEPR.md"
  "SECURITY.md"
  "TRACKER.md"
)
shopt -s nullglob
root_mds=( *.md )
shopt -u nullglob
for f in "${root_mds[@]:-}"; do
  ok=0
  for a in "${allowed_root_md[@]}"; do
    if [[ "$f" == "$a" ]]; then
      ok=1
      break
    fi
  done
  if [[ "$ok" -eq 1 ]]; then
    continue
  fi
  if [[ "$ALLOW_EXTRA_ROOT_MD" -eq 1 ]]; then
    echo "[WARN] Root markdown not in allowlist (ignored): $f"
  else
    fail "Root markdown not in allowlist: $f"
  fi
done
if [[ "${#root_mds[@]}" -gt 0 ]]; then
  pass "Root markdown scanned: ${#root_mds[@]} file(s)"
fi

# AC-003: scripts/ required subdirectories.
for d in shared infra migrations branding analytics qa; do
  check_dir "scripts/$d"
done

# AC-004: scripts/shared/config.sh exists + exports GCP_PROJECT/GCP_REGION/LMS_DOMAIN.
check_file "scripts/shared/config.sh"
if [[ -f "scripts/shared/config.sh" ]]; then
  # shellcheck disable=SC1091
  GCP_PROJECT="" GCP_REGION="" LMS_DOMAIN="" bash -c 'set -euo pipefail; source scripts/shared/config.sh; : "${GCP_PROJECT:?}"; : "${GCP_REGION:?}"; : "${LMS_DOMAIN:?}"' \
    >/dev/null 2>&1 \
    && pass "scripts/shared/config.sh exports GCP_PROJECT/GCP_REGION/LMS_DOMAIN" \
    || fail "scripts/shared/config.sh missing exports (GCP_PROJECT/GCP_REGION/LMS_DOMAIN)"
fi

# AC-005: deploy/k8s overlays local + production exist.
check_dir "deploy/k8s/overlays"
check_dir "deploy/k8s/overlays/local"
check_dir "deploy/k8s/overlays/production"

# AC-006: deploy/k8s/base/secrets: no committed secret values in Secret data/stringData.
check_dir "deploy/k8s/base/secrets"
if [[ -d "deploy/k8s/base/secrets" ]]; then
  python3 - <<'PY' || failures=$((failures + 1))
import sys
from pathlib import Path

import yaml

root = Path("deploy/k8s/base/secrets")
bad = []
for p in sorted(root.rglob("*.y*ml")):
    try:
        docs = list(yaml.safe_load_all(p.read_text(encoding="utf-8")))
    except Exception:
        continue
    for d in docs:
        if not isinstance(d, dict):
            continue
        if d.get("kind") != "Secret":
            continue
        for field in ("data", "stringData"):
            payload = d.get(field)
            if not isinstance(payload, dict):
                continue
            for k, v in payload.items():
                if v is None:
                    continue
                # Allow empty placeholders and reference-like values only.
                if isinstance(v, str) and (v.strip() == "" or "${" in v or v.strip().startswith("<")):
                    continue
                bad.append((str(p), k))

if bad:
    for p, k in bad[:50]:
        print(f"[FAIL] Committed secret-like value in {p}: {k}", file=sys.stderr)
    sys.exit(1)
print("[PASS] No committed Secret data/stringData values under deploy/k8s/base/secrets")
PY
fi

# AC-007: Deprecated dirs absent or tombstones.
check_deprecated_dir "tools"
check_deprecated_dir "ops"

# AC-008: docs required subdirectories.
for d in adr onboarding operations migrations architecture archive; do
  check_dir "docs/$d"
done

# AC-009: infrastructure required subdirectories.
for d in tutor cloudflare terraform monitoring; do
  check_dir "infrastructure/$d"
done

# AC-010: .gitignore baseline runtime + statefile patterns.
for pattern in \
  "var/" \
  "tutor_env/" \
  ".coverage.*" \
  ".hypothesis/" \
  "*.pid" \
  "*.sock" \
  "*.sqlite3" \
  "*.db" \
  "*.sqlite3-wal" \
  "*.db-wal"; do
  check_gitignore_has "$pattern"
done

# AC-011: specs root markdown files match *_spec.md (allow explicit exceptions).
spec_exceptions=(
  "IMPLEMENTATION_ORDER.md"
  "_TEMPLATE.md"
  "INDEX.md"
)
if [[ -d "specs" ]]; then
  while IFS= read -r -d '' p; do
    base="$(basename "$p")"
    if [[ "$base" == *_spec.md ]]; then
      continue
    fi
    ok=0
    for e in "${spec_exceptions[@]}"; do
      if [[ "$base" == "$e" ]]; then
        ok=1
        break
      fi
    done
    if [[ "$ok" -eq 1 ]]; then
      continue
    fi
    fail "Non-spec markdown in specs/ root: specs/$base (expected *_spec.md or exception)"
  done < <(find specs -maxdepth 1 -type f -name '*.md' -print0)
  pass "Spec naming: all specs/*.md files follow *_spec.md convention"
fi

if [[ "$failures" -eq 0 ]]; then
  echo "OK"
  exit 0
fi
echo "FAIL ($failures violation(s))" >&2
exit 1
