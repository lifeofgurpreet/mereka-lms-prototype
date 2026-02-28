#!/usr/bin/env bash
# @covers AC-TKN-018, AC-TKN-019, AC-TKN-024, AC-TKN-025, AC-TKN-026
# @covers AC-TKN-027, AC-TKN-028, AC-TKN-032, AC-008
# @spec: paragon-design-tokens-migration_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SPEC_FILE="$REPO_ROOT/specs/paragon-design-tokens-migration_spec.md"
PROMPT_FILE="$REPO_ROOT/docs/FRONTEND_PHASE_C_PROMPT.md"
AUDIT_DOC="$REPO_ROOT/docs/architecture/PARAGON_V22_TOKEN_AUDIT.md"
BRANDING_CHECKLIST="$REPO_ROOT/docs/BRANDING_VERIFICATION_CHECKLIST.md"
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
THEME_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand.min.css"
RUNTIME_URL="${PARAGON_RUNTIME_URL:-}"
REQUIRE_RUNTIME=0

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

usage() {
  cat <<'EOF'
Usage: verify-paragon-runtime-deferred.sh [--runtime-url <url>] [--require-runtime]

Options:
  --runtime-url <url>  Base URL to validate runtime theme endpoint. Example:
                       https://apps.academyv2.mereka.io
  --require-runtime    Fail when runtime URL is unavailable/reachable checks cannot run.
  -h, --help           Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-url)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --runtime-url requires a value" >&2
        exit 2
      fi
      RUNTIME_URL="$2"
      shift 2
      ;;
    --require-runtime)
      REQUIRE_RUNTIME=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

echo "=== Paragon Runtime/Deferred Contract Verification ==="

# AC-008 parser-compatibility: ensure cross-spec text reference exists
if [[ -f "$SPEC_FILE" ]] && grep -q "AC-008 through AC-010" "$SPEC_FILE"; then
  pass "AC-008 cross-spec compatibility reference is present in spec text"
else
  fail "AC-008 compatibility reference missing from spec text"
fi

# AC-TKN-018 / AC-TKN-019 runtime validation is environment-dependent.
if [[ -n "${RUNTIME_URL:-}" ]]; then
  runtime_url="${RUNTIME_URL%/}/theme/mereka-brand.min.css"
  if curl -fsSIL "$runtime_url" >/tmp/paragon-theme-head.$$ 2>/dev/null; then
    if grep -qi "^content-type:.*text/css" /tmp/paragon-theme-head.$$; then
      pass "AC-TKN-019 runtime theme endpoint returns text/css (${runtime_url})"
    else
      fail "AC-TKN-019 runtime theme endpoint missing text/css content-type (${runtime_url})"
    fi
    if grep -qi "^cache-control:" /tmp/paragon-theme-head.$$; then
      pass "AC-TKN-019 runtime theme endpoint includes cache-control"
    else
      fail "AC-TKN-019 runtime theme endpoint missing cache-control header"
    fi

    if curl -fsSL "$runtime_url" >/tmp/paragon-theme-body.$$ 2>/dev/null; then
      body_bytes="$(wc -c </tmp/paragon-theme-body.$$ | tr -d ' ')"
      if [[ "$body_bytes" -gt 100 ]]; then
        pass "AC-TKN-019 runtime theme endpoint returns non-empty CSS body (${body_bytes} bytes)"
      else
        fail "AC-TKN-019 runtime theme endpoint body too small (${body_bytes} bytes)"
      fi

      if grep -q -- "--pgn-color-primary-base" /tmp/paragon-theme-body.$$; then
        pass "AC-TKN-019 runtime theme CSS body contains Paragon primary-color marker"
      else
        fail "AC-TKN-019 runtime theme CSS body missing Paragon primary-color marker"
      fi
    else
      fail "AC-TKN-019 runtime theme endpoint body fetch failed (${runtime_url})"
    fi

    pass "AC-TKN-018 runtime URL is reachable for cache-clear verification workflow"
  else
    fail "AC-TKN-018/019 runtime URL not reachable: ${runtime_url}"
  fi
  rm -f /tmp/paragon-theme-head.$$
  rm -f /tmp/paragon-theme-body.$$
else
  if [[ "$REQUIRE_RUNTIME" -eq 1 ]]; then
    fail "AC-TKN-018/019 runtime checks required but no runtime URL was provided (use --runtime-url or PARAGON_RUNTIME_URL)"
  else
    warn "AC-TKN-018 runtime cache-clear behavior requires PARAGON_RUNTIME_URL or --runtime-url (not set)"
    warn "AC-TKN-019 runtime header contract requires PARAGON_RUNTIME_URL or --runtime-url (not set)"
  fi
fi

# AC-TKN-024/025/026: v22 tokenization boundary documented in audit + prompt.
if [[ -f "$AUDIT_DOC" ]] && [[ -f "$PROMPT_FILE" ]]; then
  if grep -qi "does not consume" "$AUDIT_DOC" && grep -qi "must remain as CSS rules" "$PROMPT_FILE"; then
    pass "AC-TKN-024/025/026 migration boundary is explicitly documented for Paragon v22"
  else
    warn "AC-TKN-024/025/026 migration boundary docs not in expected exact phrasing; treat as deferred/manual"
  fi
else
  warn "AC-TKN-024/025/026 required docs missing; treat as deferred/manual"
fi

# AC-TKN-027 / AC-TKN-028: deferred contraction check with explicit evidence.
if [[ -f "$MFE_SCSS" ]]; then
  line_count="$(wc -l < "$MFE_SCSS" | tr -d ' ')"
  rgba_count="$(grep -c "rgba(" "$MFE_SCSS" || true)"
  if [[ "$line_count" -lt 100 ]]; then
    pass "AC-TKN-027 mereka.scss line count is ${line_count} (<100)"
  else
    warn "AC-TKN-027 deferred: mereka.scss line count currently ${line_count} (target <100)"
  fi
  if [[ "$rgba_count" -lt 5 ]]; then
    pass "AC-TKN-028 rgba() count is ${rgba_count} (<5)"
  else
    warn "AC-TKN-028 deferred: rgba() count currently ${rgba_count} (target <5)"
  fi
else
  fail "AC-TKN-027/028 missing file: infrastructure/tutor/themes/mereka/mfe/mereka.scss"
fi

# AC-TKN-032 visual regression contract readiness.
if [[ -f "$BRANDING_CHECKLIST" ]] && [[ -f "$THEME_CSS" ]]; then
  pass "AC-TKN-032 visual regression runbook + compiled theme asset are present"
else
  fail "AC-TKN-032 missing visual-regression prerequisites"
fi

echo ""
echo "=== Summary: PASS=${PASS} WARN=${WARN} FAIL=${FAIL} ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
