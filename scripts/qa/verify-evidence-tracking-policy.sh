#!/usr/bin/env bash
# verify-evidence-tracking-policy.sh
#
# Guardrail:
#  1) prevent new binary/log/json evidence artifacts from entering git under
#     curated evidence directories
#       (docs/evidence/operations, docs/evidence/observability,
#        docs/archive/evidence/observability), and
#  2) prevent newly introduced unredacted sensitive markers in changed
#     markdown evidence files.
# Existing historical files remain untouched.
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT"

BASE_REF="${EVIDENCE_POLICY_BASE_REF:-origin/main}"
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  BASE_REF="HEAD~1"
fi

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "WARN: unable to resolve base ref; skipping evidence tracking policy check."
  exit 0
fi

MERGE_BASE="$(git merge-base HEAD "$BASE_REF")"
MAX_MD_BYTES="${EVIDENCE_POLICY_MAX_MD_BYTES:-200000}"

violations=0
checks=0

fail() {
  echo "  FAIL: $*" >&2
  violations=$((violations + 1))
}

pass() {
  checks=$((checks + 1))
}

scan_sensitive_markers() {
  local path="$1"
  local findings=0
  local added_lines_file
  local sensitive_out
  added_lines_file="$(mktemp)"
  sensitive_out="$(mktemp)"
  trap 'rm -f "$added_lines_file" "$sensitive_out"' RETURN

  # Only scan newly introduced lines (not historical content already in file).
  git diff --unified=0 "$MERGE_BASE"...HEAD -- "$path" \
    | sed -e '/^+++/d' -e '/^@@/d' -e '/^---/d' -e '/^diff --git/d' -e '/^index /d' \
    | sed -n 's/^+//p' >"$added_lines_file"

  if [[ ! -s "$added_lines_file" ]]; then
    pass
    return
  fi

  # Live cookie headers/tokens should never be committed in markdown evidence.
  if rg -n -i --pcre2 'set-cookie:\s*[^<\n]*(sessionid|csrftoken|edx-jwt-cookie-header-payload)\s*=' "$added_lines_file" >"$sensitive_out" 2>/dev/null; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      fail "$path introduces unredacted Set-Cookie evidence marker: $line"
      findings=$((findings + 1))
    done <"$sensitive_out"
  fi

  : >"$sensitive_out"
  if rg -n -i --pcre2 '\b(sessionid|csrftoken)=([A-Za-z0-9._%+-]{16,})' "$added_lines_file" >"$sensitive_out" 2>/dev/null; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      fail "$path introduces unredacted session/csrf token marker: $line"
      findings=$((findings + 1))
    done <"$sensitive_out"
  fi

  : >"$sensitive_out"
  if rg -n -i --pcre2 'authorization:\s*bearer\s+[A-Za-z0-9._-]{20,}' "$added_lines_file" >"$sensitive_out" 2>/dev/null; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      fail "$path introduces unredacted bearer token marker: $line"
      findings=$((findings + 1))
    done <"$sensitive_out"
  fi

  : >"$sensitive_out"
  if rg -n -i --pcre2 'data:image/[a-z0-9.+-]+;base64,' "$added_lines_file" >"$sensitive_out" 2>/dev/null; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      fail "$path introduces inline base64 image payload (store binary evidence in CI artifacts/object storage): $line"
      findings=$((findings + 1))
    done <"$sensitive_out"
  fi

  if [[ "$findings" -eq 0 ]]; then
    pass
  fi
}

check_new_markdown_size() {
  local path="$1"
  local size_bytes
  size_bytes="$(wc -c <"$path" | tr -d ' ')"
  if [[ "$size_bytes" -gt "$MAX_MD_BYTES" ]]; then
    fail "$path is ${size_bytes} bytes (max ${MAX_MD_BYTES}); move raw payloads to CI artifacts/object storage and keep markdown summaries lean"
  else
    pass
  fi
}

echo "=== Evidence Tracking Policy Verification ==="
echo "Base ref   : $BASE_REF"
echo "Merge base : $MERGE_BASE"
echo ""

while IFS= read -r path; do
  [[ -z "$path" ]] && continue

  case "$path" in
    docs/evidence/operations/*|docs/evidence/observability/*|docs/archive/evidence/observability/*)
      if [[ "$path" == *.md ]]; then
        if [[ -f "$path" ]]; then
          check_new_markdown_size "$path"
        else
          pass
        fi
      else
        fail "$path introduces non-markdown evidence artifact in docs evidence directories"
      fi
      ;;
    *)
      pass
      ;;
  esac
done < <(git diff --name-only --diff-filter=A "$MERGE_BASE"...HEAD)

# Changed markdown evidence files must not introduce sensitive markers.
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  [[ -f "$path" ]] || continue

  if [[ "$path" =~ ^docs/evidence/operations/.+\.md$ || "$path" =~ ^docs/evidence/observability/.+\.md$ || "$path" =~ ^docs/archive/evidence/observability/.+\.md$ ]]; then
    scan_sensitive_markers "$path"
  fi
done < <(git diff --name-only --diff-filter=AM "$MERGE_BASE"...HEAD -- docs/evidence/operations docs/evidence/observability docs/archive/evidence/observability)

echo "=== Summary ==="
echo "Checks     : $checks"
echo "Violations : $violations"
echo ""

if [[ "$violations" -gt 0 ]]; then
  cat >&2 <<'EOM'
FAIL — evidence tracking policy violations found.
Use CI artifacts/object storage for raw evidence payloads, and keep only
human-readable markdown summaries plus links in docs/archive/evidence.
Redact cookie/session/bearer markers before committing markdown evidence.
EOM
  exit 1
fi

echo "PASS — evidence tracking policy checks passed."
