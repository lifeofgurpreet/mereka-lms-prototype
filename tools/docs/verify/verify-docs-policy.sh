#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

RANGE_OVERRIDE=""
SUMMARY_JSON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --range)
      RANGE_OVERRIDE="${2:?missing value for --range}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON="${2:?missing value for --summary-json}"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF_HELP'
Usage: verify-docs-policy.sh [--range <git-diff-range>] [--summary-json <path>]

Options:
  --range <range>         explicit git diff range (example: origin/main...HEAD)
  --summary-json <path>   optional JSON summary output path
  --help                  show this message
EOF_HELP
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -n "$RANGE_OVERRIDE" ]]; then
  RANGE="$RANGE_OVERRIDE"
elif [[ -n "${DOCS_POLICY_RANGE:-}" ]]; then
  RANGE="$DOCS_POLICY_RANGE"
elif [[ -n "${GITHUB_EVENT_BEFORE:-}" && -n "${GITHUB_SHA:-}" && "$GITHUB_EVENT_BEFORE" != "0000000000000000000000000000000000000000" ]]; then
  RANGE="${GITHUB_EVENT_BEFORE}...${GITHUB_SHA}"
elif git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
  RANGE="HEAD~1...HEAD"
else
  RANGE="HEAD...HEAD"
fi

echo "Docs policy range: ${RANGE}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ALLOWLIST=("README.md" "CONTRIBUTING.md" "DOCS_REMEDIATION_PLAN_AND_TRACKER.md" "catalog.json")
TRANSITIONAL_PREFIXES=("docs/operations/" "docs/onboarding/" "docs/branding/" "docs/runbooks/" "docs/architecture/" "reports/2026/status/" "reports/2026/readiness/" "evidence/")
ARCHIVE_PREFIXES=("docs/archive/")

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
root_violation_paths=()
content_status="pass"
CONTENT_SUMMARY_JSON="$TMP_DIR/content-summary.json"
cat > "$CONTENT_SUMMARY_JSON" <<'EOF_CONTENT_SUMMARY'
{"status":"pass","files_checked":0,"errors":[]}
EOF_CONTENT_SUMMARY

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
      root_violation_paths+=("$candidate")
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
  if ! python3 - "$REPO_ROOT" "$CONTENT_SUMMARY_JSON" "${changed_md[@]}" <<'PY'
import re
import sys
import json
from pathlib import Path

repo = Path(sys.argv[1])
summary_path = Path(sys.argv[2])
files = [Path(p) for p in sys.argv[3:] if (repo / p).exists()]

link_re = re.compile(r"\[[^\]]+\]\(([^)]+)\)")

def has_frontmatter(text: str) -> bool:
    lines = text.splitlines()
    return len(lines) > 2 and lines[0].strip() == "---"

def check_canonical_metadata(path: Path, text: str) -> tuple[list[str], bool]:
    errors = []
    head = "\n".join(text.splitlines()[:30])
    canonical = bool(re.search(r"status:\s*\"?canonical\"?|Status:\s*canonical", head, flags=re.IGNORECASE))
    if not canonical:
        return errors, False

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
    return errors, True

def check_superseded_pointer(path: Path, text: str) -> list[str]:
    head = "\n".join(text.splitlines()[:20])
    superseded = bool(re.search(r"status:\s*\"?superseded\"?|Status:\s*superseded", head, flags=re.IGNORECASE))
    if superseded and not re.search(r"(?im)^\s*superseded_by:\s*.+$", text):
        return [f"{path}: superseded doc missing `superseded_by` pointer"]
    return []

def check_transitional_stub(path: Path, text: str) -> list[str]:
    transitional_prefixes = (
        "docs/operations/",
        "docs/onboarding/",
        "docs/branding/",
        "docs/runbooks/",
        "docs/architecture/",
        "reports/2026/status/",
        "reports/2026/readiness/",
        "evidence/",
    )
    rel = str(path)
    if not any(rel.startswith(prefix) for prefix in transitional_prefixes):
        return []
    head = "\n".join(text.splitlines()[:25])
    if not re.search(r"status:\s*\"?superseded\"?|Status:\s*superseded", head, flags=re.IGNORECASE):
        return [f"{path}: transitional doc must be stub-only and marked superseded"]
    if not re.search(r"(?im)^\s*superseded_by:\s*.+$", text):
        return [f"{path}: transitional doc missing `superseded_by` pointer"]
    return []

def check_canonical_links(path: Path, text: str, canonical: bool) -> list[str]:
    if not canonical:
        return []
    errors = []
    transitional_prefixes = (
        "docs/operations/",
        "docs/onboarding/",
        "docs/branding/",
        "docs/runbooks/",
        "docs/architecture/",
    )
    archive_prefixes = ("docs/archive/",)
    legacy_markers = ("legacy", "historical", "superseded", "archive", "compatibility")
    for line in text.splitlines():
        for raw in link_re.findall(line):
            link = raw.split("#", 1)[0].strip()
            if not link or link.startswith(("http://", "https://", "mailto:")):
                continue
            if link.startswith(transitional_prefixes) or link.startswith(archive_prefixes):
                lowered = line.lower()
                if not any(marker in lowered for marker in legacy_markers):
                    errors.append(f"{path}: canonical doc links to transitional/archive path without legacy marker -> {raw}")
    return errors

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
    metadata_errors, canonical = check_canonical_metadata(rel, text)
    all_errors += metadata_errors
    all_errors += check_superseded_pointer(rel, text)
    all_errors += check_transitional_stub(rel, text)
    all_errors += check_canonical_links(rel, text, canonical)
    all_errors += check_links(rel, text)

if all_errors:
    summary_path.write_text(
        json.dumps({"status": "fail", "files_checked": len(files), "errors": all_errors}, indent=2),
        encoding="utf-8",
    )
    print("DOCS_POLICY_ERRORS")
    for e in all_errors:
        print(f"- {e}")
    sys.exit(1)

summary_path.write_text(
    json.dumps({"status": "pass", "files_checked": len(files), "errors": []}, indent=2),
    encoding="utf-8",
)
print("DOCS_POLICY_OK")
PY
  then
    content_status="fail"
  fi
else
  echo "No changed markdown docs in scope."
fi

echo "Check 5/11: legacy architecture root retired"
legacy_arch_status="pass"
if ! python3 tools/docs/verify/verify_legacy_architecture_root.py --repo-root .; then
  legacy_arch_status="fail"
fi

echo "Check 6/11: legacy operations root retired"
legacy_ops_status="pass"
if ! python3 tools/docs/verify/verify_legacy_operations_root.py --repo-root .; then
  legacy_ops_status="fail"
fi

echo "Check 7/11: legacy CI/CD root retired"
legacy_ci_cd_status="pass"
if ! python3 tools/docs/verify/verify_legacy_ci_cd_root.py --repo-root .; then
  legacy_ci_cd_status="fail"
fi

echo "Check 8/11: legacy branding root retired"
legacy_branding_status="pass"
if ! python3 tools/docs/verify/verify_legacy_branding_root.py --repo-root .; then
  legacy_branding_status="fail"
fi

echo "Check 9/11: legacy runbooks root retired"
legacy_runbooks_status="pass"
if ! python3 tools/docs/verify/verify_legacy_runbooks_root.py --repo-root .; then
  legacy_runbooks_status="fail"
fi

echo "Check 10/11: legacy migrations root retired"
legacy_migrations_status="pass"
if ! python3 tools/docs/verify/verify_legacy_migrations_root.py --repo-root .; then
  legacy_migrations_status="fail"
fi

echo "Check 11/11: concepts architecture root is clean"
concepts_architecture_status="pass"
if ! python3 tools/docs/verify/verify_concepts_architecture_clean.py --repo-root .; then
  concepts_architecture_status="fail"
fi

status="pass"
if [[ "$failures" -gt 0 ]] || [[ "$content_status" = "fail" ]] || [[ "$legacy_arch_status" = "fail" ]] || [[ "$legacy_ops_status" = "fail" ]] || [[ "$legacy_ci_cd_status" = "fail" ]] || [[ "$legacy_branding_status" = "fail" ]] || [[ "$legacy_runbooks_status" = "fail" ]] || [[ "$legacy_migrations_status" = "fail" ]] || [[ "$concepts_architecture_status" = "fail" ]]; then
  status="fail"
fi

if [[ -n "$SUMMARY_JSON" ]]; then
  python3 - "$SUMMARY_JSON" "$RANGE" "$failures" "$content_status" "${#changed_md[@]}" "$CONTENT_SUMMARY_JSON" "$legacy_arch_status" "$legacy_ops_status" "$legacy_ci_cd_status" "$legacy_branding_status" "$legacy_runbooks_status" "$legacy_migrations_status" "$concepts_architecture_status" <<'PY'
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
range_value = sys.argv[2]
root_allowlist_violations = int(sys.argv[3])
content_status = sys.argv[4]
changed_markdown_files = int(sys.argv[5])
content_summary_path = Path(sys.argv[6])
legacy_arch_status = sys.argv[7]
legacy_ops_status = sys.argv[8]
legacy_ci_cd_status = sys.argv[9]
legacy_branding_status = sys.argv[10]
legacy_runbooks_status = sys.argv[11]
legacy_migrations_status = sys.argv[12]
concepts_architecture_status = sys.argv[13]

content_summary = {"status": "pass", "files_checked": 0, "errors": []}
if content_summary_path.exists():
    content_summary = json.loads(content_summary_path.read_text(encoding="utf-8"))

overall_status = "pass"
if root_allowlist_violations > 0 or content_status != "pass" or legacy_arch_status != "pass" or legacy_ops_status != "pass" or legacy_ci_cd_status != "pass" or legacy_branding_status != "pass" or legacy_runbooks_status != "pass" or legacy_migrations_status != "pass" or concepts_architecture_status != "pass":
    overall_status = "fail"

payload = {
    "status": overall_status,
    "range": range_value,
    "root_allowlist_violations": root_allowlist_violations,
    "changed_markdown_files": changed_markdown_files,
    "content_status": content_summary.get("status", content_status),
    "content_files_checked": content_summary.get("files_checked", 0),
    "content_errors": content_summary.get("errors", []),
    "legacy_architecture_root": legacy_arch_status,
    "legacy_operations_root": legacy_ops_status,
    "legacy_ci_cd_root": legacy_ci_cd_status,
    "legacy_branding_root": legacy_branding_status,
    "legacy_runbooks_root": legacy_runbooks_status,
    "legacy_migrations_root": legacy_migrations_status,
    "concepts_architecture_root": concepts_architecture_status,
}
out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
PY
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Docs policy failed with ${failures} root allowlist violation(s)."
fi
if [[ "$content_status" = "fail" ]]; then
  echo "Docs policy failed due to canonical metadata/superseded/link errors."
fi
if [[ "$legacy_arch_status" = "fail" ]]; then
  echo "Docs policy failed because docs/architecture is still acting like a living root."
fi
if [[ "$legacy_ops_status" = "fail" ]]; then
  echo "Docs policy failed because docs/operations is still acting like a living root."
fi
if [[ "$legacy_ci_cd_status" = "fail" ]]; then
  echo "Docs policy failed because docs/ci-cd is still acting like a living root."
fi
if [[ "$legacy_branding_status" = "fail" ]]; then
  echo "Docs policy failed because docs/branding is still acting like a living root."
fi
if [[ "$legacy_runbooks_status" = "fail" ]]; then
  echo "Docs policy failed because docs/runbooks is still acting like a living root."
fi
if [[ "$legacy_migrations_status" = "fail" ]]; then
  echo "Docs policy failed because docs/migrations is still acting like a living root."
fi
if [[ "$concepts_architecture_status" = "fail" ]]; then
  echo "Docs policy failed because docs/concepts/architecture still contains redirect clutter."
fi
if [[ "$status" = "fail" ]]; then
  exit 1
fi

echo "All docs policy checks passed."
