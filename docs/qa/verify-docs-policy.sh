#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

if [[ -n "${DOCS_POLICY_RANGE:-}" ]]; then
  RANGE="$DOCS_POLICY_RANGE"
elif [[ -n "${GITHUB_EVENT_BEFORE:-}" && -n "${GITHUB_SHA:-}" && "$GITHUB_EVENT_BEFORE" != "0000000000000000000000000000000000000000" ]]; then
  RANGE="${GITHUB_EVENT_BEFORE}...${GITHUB_SHA}"
elif git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
  RANGE="HEAD~1...HEAD"
else
  RANGE="HEAD...HEAD"
fi

echo "Docs policy range: ${RANGE}"

ALLOWLIST=("README.md" "CONTRIBUTING.md" "DOCS_REMEDIATION_PLAN_AND_TRACKER.md" "catalog.json")

is_allowlisted_root_file() {
  local name="$1"
  local a
  for a in "${ALLOWLIST[@]}"; do
    if [[ "$name" == "$a" ]]; then
      return 0
    fi
  done
  return 1
}

failures=0

echo "Check 1/4: root allowlist for newly added docs root files"
while IFS=$'\t' read -r status path1 path2; do
  [[ -z "${status:-}" ]] && continue
  candidate=""
  if [[ "$status" == A* ]]; then
    candidate="$path1"
  elif [[ "$status" == R* ]]; then
    candidate="$path2"
  fi

  [[ -z "$candidate" ]] && continue
  if [[ "$candidate" =~ ^docs/[^/]+$ ]]; then
    base="$(basename "$candidate")"
    if ! is_allowlisted_root_file "$base"; then
      echo "FAIL: non-allowlisted docs root addition: $candidate"
      failures=$((failures + 1))
    fi
  fi
done < <(git diff --name-status "$RANGE" -- docs/)

changed_md=()
while IFS= read -r f; do
  [[ -n "$f" ]] && changed_md+=("$f")
done < <(git diff --name-only "$RANGE" -- 'docs/**/*.md' 'docs/*.md')

echo "Changed markdown files in range: ${#changed_md[@]}"

echo "Check 2/4 + 3/4 + 4/4: canonical metadata, superseded pointers, broken links"
if [[ "${#changed_md[@]}" -gt 0 ]]; then
  python3 - "$REPO_ROOT" "${changed_md[@]}" <<'PY'
import re
import sys
from pathlib import Path

repo = Path(sys.argv[1])
files = [Path(p) for p in sys.argv[2:] if (repo / p).exists()]

link_re = re.compile(r"\[[^\]]+\]\(([^)]+)\)")

def has_frontmatter(text: str) -> bool:
    lines = text.splitlines()
    return len(lines) > 2 and lines[0].strip() == "---"

def check_canonical_metadata(path: Path, text: str) -> list[str]:
    errors = []
    head = "\n".join(text.splitlines()[:30])
    canonical = bool(re.search(r"status:\s*\"?canonical\"?|Status:\s*canonical", head, flags=re.IGNORECASE))
    if not canonical:
        return errors

    if has_frontmatter(text):
        fm = text.split("\n---", 1)[0] + "\n"
        if not re.search(r"(?im)^owner:\s*.+$", fm):
            errors.append(f"{path}: canonical frontmatter missing `owner`")
        if not re.search(r"(?im)^status:\s*\"?canonical\"?\s*$", fm):
            errors.append(f"{path}: canonical frontmatter missing `status: canonical`")
        if not re.search(r"(?im)^last_(updated|verified):\s*\"?\d{4}-\d{2}-\d{2}\"?\s*$", fm):
            errors.append(f"{path}: canonical frontmatter missing `last_updated` or `last_verified`")
    else:
        if "Audience:" not in head:
            errors.append(f"{path}: canonical subtitle metadata missing `Audience`")
        if "Owner:" not in head:
            errors.append(f"{path}: canonical subtitle metadata missing `Owner`")
        if "Last verified:" not in head and "Last updated:" not in head:
            errors.append(f"{path}: canonical subtitle metadata missing `Last verified/Last updated`")
        if not re.search(r"Status:\s*canonical", head):
            errors.append(f"{path}: canonical subtitle metadata missing `Status: canonical`")
    return errors

def check_superseded_pointer(path: Path, text: str) -> list[str]:
    head = "\n".join(text.splitlines()[:20])
    superseded = bool(re.search(r"status:\s*\"?superseded\"?|Status:\s*superseded", head, flags=re.IGNORECASE))
    if superseded and not re.search(r"(?im)^\s*superseded_by:\s*.+$", text):
        return [f"{path}: superseded doc missing `superseded_by` pointer"]
    return []

def check_links(path: Path, text: str) -> list[str]:
    errors = []
    base = (repo / path).parent
    for raw in link_re.findall(text):
        link = raw.split("#", 1)[0].strip()
        if not link or link.startswith(("http://", "https://", "mailto:")):
            continue
        if link.startswith("docs/"):
            target = repo / link
        else:
            target = (base / link).resolve()
        if not target.exists():
            errors.append(f"{path}: broken local link -> {raw}")
    return errors

all_errors = []
for rel in files:
    full = repo / rel
    text = full.read_text(encoding="utf-8", errors="ignore")
    all_errors += check_canonical_metadata(rel, text)
    all_errors += check_superseded_pointer(rel, text)
    all_errors += check_links(rel, text)

if all_errors:
    print("DOCS_POLICY_ERRORS")
    for e in all_errors:
        print(f"- {e}")
    sys.exit(1)

print("DOCS_POLICY_OK")
PY
else
  echo "No changed markdown docs in scope."
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Docs policy failed with ${failures} root allowlist violation(s)."
  exit 1
fi

echo "All docs policy checks passed."
