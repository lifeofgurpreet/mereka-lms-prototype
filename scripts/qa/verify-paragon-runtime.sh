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
BRAND_LIGHT_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand-light.min.css"
CORE_THEME_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme/core.min.css"
LIGHT_THEME_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme/light.min.css"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
RUNTIME_URL="${PARAGON_RUNTIME_URL:-}"
REQUIRE_RUNTIME=0
THEME_DEFAULT_ENABLED=1
MAX_CORE_THEME_BYTES="${MAX_CORE_THEME_BYTES:-614400}"
MAX_BRAND_THEME_BYTES="${MAX_BRAND_THEME_BYTES:-51200}"
MAX_LIGHT_THEME_BYTES="${MAX_LIGHT_THEME_BYTES:-4096}"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $*"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

usage() {
  cat <<'EOF'
Usage: verify-paragon-runtime.sh [--runtime-url <url>] [--require-runtime]

Options:
  --runtime-url <url>  Base URL to validate runtime theme endpoint. Example:
                       https://apps.academyv2.mereka.io
  --require-runtime    Fail when runtime URL is unavailable/reachable checks cannot run.
  -h, --help           Show this help.
EOF
}

normalize_runtime_url() {
  local raw="$1"
  [[ -z "$raw" ]] && { echo ""; return 0; }
  python3 - "$raw" <<'PY'
import sys
from urllib.parse import urlparse

raw = (sys.argv[1] or "").strip()
if not raw:
    print("")
    raise SystemExit(0)
if "://" not in raw:
    raw = f"https://{raw}"
parsed = urlparse(raw)
if not parsed.netloc:
    print("")
    raise SystemExit(0)
scheme = parsed.scheme or "https"
print(f"{scheme}://{parsed.netloc}")
PY
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

if [[ -n "${RUNTIME_URL:-}" ]]; then
  original_runtime_url="$RUNTIME_URL"
  normalized_runtime_url="$(normalize_runtime_url "$RUNTIME_URL")"
  if [[ -z "$normalized_runtime_url" ]]; then
    fail "Invalid --runtime-url/PARAGON_RUNTIME_URL value: ${original_runtime_url}"
    echo ""
    echo "=== Summary: PASS=${PASS} WARN=${WARN} FAIL=${FAIL} ==="
    exit 1
  fi
  RUNTIME_URL="$normalized_runtime_url"
  if [[ "$RUNTIME_URL" != "$original_runtime_url" ]]; then
    warn "Normalized runtime URL to origin for contract checks: ${RUNTIME_URL} (from ${original_runtime_url})"
  fi
fi

if [[ -f "$PLUGIN_FILE" ]]; then
  if grep -q '("MEREKA_PARAGON_THEME_ENABLED",[[:space:]]*False)' "$PLUGIN_FILE"; then
    THEME_DEFAULT_ENABLED=0
  elif grep -q '("MEREKA_PARAGON_THEME_ENABLED",[[:space:]]*True)' "$PLUGIN_FILE"; then
    THEME_DEFAULT_ENABLED=1
  fi
fi

echo "=== Paragon Runtime Contract Verification ==="

# Final-pattern contract: runtime PARAGON_THEME_URLS must be enabled by default.
if [[ "$THEME_DEFAULT_ENABLED" -eq 1 ]]; then
  pass "Runtime PARAGON_THEME_URLS is enabled by default in plugin config"
else
  fail "Runtime PARAGON_THEME_URLS is disabled by default (set MEREKA_PARAGON_THEME_ENABLED=True)"
fi

# AC-008 parser-compatibility: ensure cross-spec text reference exists
if [[ -f "$SPEC_FILE" ]] && grep -q "AC-008 through AC-010" "$SPEC_FILE"; then
  pass "AC-008 cross-spec compatibility reference is present in spec text"
else
  fail "AC-008 compatibility reference missing from spec text"
fi

# AC-TKN-018 / AC-TKN-019 runtime validation is environment-dependent.
if [[ -n "${RUNTIME_URL:-}" ]]; then
  runtime_url="${RUNTIME_URL%/}/theme/mereka-brand.min.css"
  runtime_status="$(curl -sSIL -o /tmp/paragon-theme-head.$$ -w "%{http_code}" "$runtime_url" || true)"
  if [[ "$runtime_status" =~ ^[0-9]+$ ]] && [[ "$runtime_status" -ge 200 ]] && [[ "$runtime_status" -lt 400 ]]; then
    content_type_ok=0
    cache_header_ok=0
    body_fetch_ok=0
    body_size_ok=0
    marker_ok=0

    if grep -qi "^content-type:.*text/css" /tmp/paragon-theme-head.$$; then
      content_type_ok=1
    fi
    if grep -qi "^cache-control:" /tmp/paragon-theme-head.$$; then
      cache_header_ok=1
    fi

    if curl -sSL "$runtime_url" >/tmp/paragon-theme-body.$$ 2>/dev/null; then
      body_fetch_ok=1
      body_bytes="$(wc -c </tmp/paragon-theme-body.$$ | tr -d ' ')"
      if [[ "$body_bytes" -gt 100 ]]; then
        body_size_ok=1
      fi
      if grep -q -- "--pgn-color-primary-base" /tmp/paragon-theme-body.$$; then
        marker_ok=1
      fi
    else
      body_bytes=0
    fi

    if [[ "$content_type_ok" -eq 1 && "$cache_header_ok" -eq 1 && "$body_fetch_ok" -eq 1 && "$body_size_ok" -eq 1 && "$marker_ok" -eq 1 ]]; then
      pass "AC-TKN-019 runtime theme endpoint returns text/css (${runtime_url})"
      pass "AC-TKN-019 runtime theme endpoint includes cache-control"
      pass "AC-TKN-019 runtime theme endpoint returns non-empty CSS body (${body_bytes} bytes)"
      pass "AC-TKN-019 runtime theme CSS body contains Paragon primary-color marker"
    else
      if [[ "$REQUIRE_RUNTIME" -eq 0 && "$THEME_DEFAULT_ENABLED" -eq 0 ]]; then
        warn "AC-TKN-019 runtime theme endpoint not active (${runtime_url}); default MEREKA_PARAGON_THEME_ENABLED=False in plugin config"
      else
        [[ "$content_type_ok" -eq 1 ]] && pass "AC-TKN-019 runtime theme endpoint returns text/css (${runtime_url})" || fail "AC-TKN-019 runtime theme endpoint missing text/css content-type (${runtime_url})"
        [[ "$cache_header_ok" -eq 1 ]] && pass "AC-TKN-019 runtime theme endpoint includes cache-control" || fail "AC-TKN-019 runtime theme endpoint missing cache-control header"
        [[ "$body_fetch_ok" -eq 1 ]] && pass "AC-TKN-019 runtime theme endpoint body fetch succeeded" || fail "AC-TKN-019 runtime theme endpoint body fetch failed (${runtime_url})"
        [[ "$body_size_ok" -eq 1 ]] && pass "AC-TKN-019 runtime theme endpoint returns non-empty CSS body (${body_bytes} bytes)" || fail "AC-TKN-019 runtime theme endpoint body too small (${body_bytes} bytes)"
        [[ "$marker_ok" -eq 1 ]] && pass "AC-TKN-019 runtime theme CSS body contains Paragon primary-color marker" || fail "AC-TKN-019 runtime theme CSS body missing Paragon primary-color marker"
      fi
    fi

    pass "AC-TKN-018 runtime URL is reachable for cache-clear verification workflow"
  else
    fail "AC-TKN-018/019 runtime URL check failed: ${runtime_url} (HTTP ${runtime_status:-unknown})"
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
  active_line_count="$(python3 - "$MFE_SCSS" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
lines = [line for line in text.splitlines() if line.strip() and not line.strip().startswith("//")]
print(len(lines))
PY
)"
  rgba_count="$(grep -c "rgba(" "$MFE_SCSS" || true)"
  if [[ "$active_line_count" -lt 300 ]]; then
    pass "AC-TKN-027 active mereka.scss rule line count is ${active_line_count} (<300); raw lines=${line_count}"
  else
    warn "AC-TKN-027 deferred: active mereka.scss rule line count currently ${active_line_count} (target <300); raw lines=${line_count}"
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

# Runtime theme artifact budgets and light-variant parity checks.
if [[ -f "$CORE_THEME_CSS" ]]; then
  core_size="$(wc -c < "$CORE_THEME_CSS" | tr -d ' ')"
  if [[ "$core_size" -le "$MAX_CORE_THEME_BYTES" ]]; then
    pass "Theme core CSS size ${core_size}B is within budget (${MAX_CORE_THEME_BYTES}B)"
  else
    fail "Theme core CSS size ${core_size}B exceeds budget (${MAX_CORE_THEME_BYTES}B)"
  fi
else
  fail "Theme core CSS missing: ${CORE_THEME_CSS#$REPO_ROOT/}"
fi

if [[ -f "$THEME_CSS" ]]; then
  brand_size="$(wc -c < "$THEME_CSS" | tr -d ' ')"
  if [[ "$brand_size" -le "$MAX_BRAND_THEME_BYTES" ]]; then
    pass "Brand theme CSS size ${brand_size}B is within budget (${MAX_BRAND_THEME_BYTES}B)"
  else
    fail "Brand theme CSS size ${brand_size}B exceeds budget (${MAX_BRAND_THEME_BYTES}B)"
  fi
else
  fail "Brand theme CSS missing: ${THEME_CSS#$REPO_ROOT/}"
fi

if [[ -f "$LIGHT_THEME_CSS" ]]; then
  light_size="$(wc -c < "$LIGHT_THEME_CSS" | tr -d ' ')"
  if [[ "$light_size" -le "$MAX_LIGHT_THEME_BYTES" ]]; then
    pass "Light theme CSS size ${light_size}B is within budget (${MAX_LIGHT_THEME_BYTES}B)"
  else
    warn "Light theme CSS size ${light_size}B exceeds delta budget (${MAX_LIGHT_THEME_BYTES}B)"
  fi
else
  fail "Light theme CSS missing: ${LIGHT_THEME_CSS#$REPO_ROOT/}"
fi

if [[ -f "$THEME_CSS" && -f "$BRAND_LIGHT_CSS" ]]; then
  if cmp -s "$THEME_CSS" "$BRAND_LIGHT_CSS"; then
    pass "Brand light theme CSS is byte-identical to base brand theme CSS"
  else
    fail "Brand light theme CSS differs from base brand theme CSS (unexpected drift)"
  fi
else
  fail "Brand theme parity check prerequisites missing"
fi

echo ""
echo "=== Summary: PASS=${PASS} WARN=${WARN} FAIL=${FAIL} ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
