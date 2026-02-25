#!/usr/bin/env bash
# @covers AC-007
# @spec: observability-stack_spec.md
# Verify Caddy ingress forwards request correlation headers to upstream services.
#
# Usage:
#   ./scripts/qa/verify-correlation-header-propagation.sh [--strict]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

CADDYFILE="${CADDYFILE:-deploy/k8s/base/apps/caddy/Caddyfile}"
CORRELATION_EVIDENCE_LABEL="${VERIFY_CORRELATION_ENV_LABEL:-${OBSERVABILITY_ENV_LABEL:-unknown}}"
CORRELATION_EVIDENCE_PROFILE="${VERIFY_CORRELATION_DISPATCH_PROFILE:-${OBSERVABILITY_DISPATCH_PROFILE:-custom}}"
CORRELATION_EVIDENCE_CONTEXT="${VERIFY_CORRELATION_K8S_CONTEXT:-${OBSERVABILITY_K8S_CONTEXT:-default}}"
CORRELATION_EVIDENCE_PROJECT="${VERIFY_CORRELATION_GCP_PROJECT:-${GCP_PROJECT:-mereka-lms}}"
STRICT="${STRICT:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

EVIDENCE_IDENTITY="env=${CORRELATION_EVIDENCE_LABEL};profile=${CORRELATION_EVIDENCE_PROFILE};context=${CORRELATION_EVIDENCE_CONTEXT};project=${CORRELATION_EVIDENCE_PROJECT}"

cat <<EOF
- Correlation header propagation evidence
- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- caddyfile: ${CADDYFILE}
- evidence_identity: ${EVIDENCE_IDENTITY}
EOF

echo "Verify: Correlation header propagation"
echo "  caddyfile: $CADDYFILE"
echo ""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --help|-h)
      echo "Usage: $0 [--strict]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$CADDYFILE" ]]; then
  echo -e "${RED}FAIL${NC}: Caddyfile not found: $CADDYFILE"
  exit 1
fi

python3 - "$CADDYFILE" <<'PY'
import re
import sys

caddyfile = sys.argv[1]
required_headers = {"x-request-id", "traceparent"}
required = ["X-Request-ID", "traceparent"]

raw_lines = open(caddyfile, "r", encoding="utf-8").read().splitlines()

def strip_comment(line: str) -> str:
    return line.split("#", 1)[0].rstrip()

def braces_delta(text: str) -> int:
    return text.count("{") - text.count("}")

def has_required_headers(block_lines):
    present = set()
    for line in block_lines:
        m = re.search(r"^\s*header_up\s+([^\s{]+)", line, re.IGNORECASE)
        if m:
            present.add(m.group(1).lower())
    missing = [h for h in required if h.lower() not in present]
    return missing

def collect_block(lines, start_index):
    block = []
    depth = braces_delta(lines[start_index])
    block.append(lines[start_index])
    i = start_index
    # include lines until matching closing brace for block.
    while depth > 0 and i + 1 < len(lines):
        i += 1
        line = lines[i]
        depth += braces_delta(line)
        block.append(line)
        if depth <= 0:
            break
    return block, i

lines = [strip_comment(line) for line in raw_lines]
lines = [line for line in lines if line.strip()]

snippet_headers = []
bad_blocks = []
direct_blocks = []
snippet_found = False
i = 0

while i < len(lines):
    line = lines[i]
    if not snippet_found and re.match(r"^\(proxy\)\s*{", line):
        snippet_found = True
        block, end_idx = collect_block(lines, i)
        missing = has_required_headers(block)
        snippet_headers = missing
        i = end_idx + 1
        continue

    if re.match(r"^\s*reverse_proxy\b.*\{", line):
        block, end_idx = collect_block(lines, i)
        direct_blocks.append((i + 1, block))
        i = end_idx + 1
        continue

    i += 1

if not snippet_found:
    print("FAIL: Could not find (proxy) snippet definition")
    sys.exit(1)

if snippet_headers:
    for header in snippet_headers:
        print(f"FAIL: proxy snippet missing '{header}'")
    sys.exit(1)

if not direct_blocks:
    print("PASS: no direct reverse_proxy blocks found; proxy snippet present")
    sys.exit(0)

for line_no, block in direct_blocks:
    missing = has_required_headers(block)
    if missing:
        bad_blocks.append((line_no, missing))

if bad_blocks:
    print("FAIL: direct reverse_proxy blocks do not forward required headers")
    for line_no, missing in bad_blocks:
        print(f"  line {line_no}: missing {', '.join(missing)}")
    print(f"TOTAL_FAILS: {len(bad_blocks)}")
    sys.exit(1)

print("OK: Proxy snippet and direct reverse_proxy blocks forward required headers")
sys.exit(0)
PY

status=$?
if [[ "$status" -ne 0 ]]; then
  echo -e "${RED}FAILED${NC} correlation header propagation check failed"
  if [[ "$STRICT" -eq 1 ]]; then
    exit "$status"
  fi
  echo -e "${YELLOW}WARN${NC} run with --strict for hard fail"
  exit 0
fi

echo -e "${GREEN}PASS${NC} correlation headers are present for proxy snippet and direct reverse_proxy blocks"
echo ""
