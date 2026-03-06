#!/usr/bin/env bash
# Standalone gate: no private key material committed under deploy/k8s/
#
# Detects:
#   - PEM private key blocks (BEGIN ... PRIVATE KEY)
#   - JWK private fields ("d":, "p":, "q": in JSON numeric context)
#   - SAML private key XML elements
#
# Does NOT flag:
#   - os.environ.get() references
#   - Empty value placeholders
#   - Comment lines
#
# Usage:
#   scripts/qa/no_private_key_material.sh [SCOPE_DIR]
#   Default SCOPE_DIR: deploy/k8s/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_DIR="${1:-${REPO_ROOT}/deploy/k8s}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

hits=0

scan() {
  local label="$1"
  local pattern="$2"
  local results
  set +e
  results=$(rg -n \
    --glob '!.git/**' \
    --glob '!*.md' \
    -- "$pattern" "$SCOPE_DIR" 2>/dev/null)
  local rc=$?
  set -e
  if [[ $rc -ne 0 && $rc -ne 1 ]]; then
    echo "rg error (rc=$rc) scanning $label" >&2
    exit "$rc"
  fi
  if [[ -n "$results" ]]; then
    echo -e "${RED}[FAIL]${NC} Private key material found ($label):"
    while IFS= read -r line; do
      # Skip lines that are only env-var references or comments
      if [[ "$line" =~ os\.environ\.get|getenv|\$\{[A-Z_]+\}|#[[:space:]] ]]; then
        continue
      fi
      echo "  $line"
      hits=$((hits + 1))
    done <<< "$results"
  fi
}

scan "PEM private key" "-----BEGIN[[:space:]]+(RSA|EC|OPENSSH|DSA|PGP|PRIVATE)[[:space:]]+PRIVATE[[:space:]]+KEY-----"
scan "JWK private fields" '"(d|p|q|dp|dq|qi)"[[:space:]]*:[[:space:]]*"[A-Za-z0-9_-]{10,}"'
scan "SAML private key XML" '<(ds:)?X509PrivateKey|<PrivateKey>'

if [[ $hits -gt 0 ]]; then
  echo ""
  echo -e "${RED}FAIL${NC}: $hits private key finding(s) in $SCOPE_DIR"
  exit 1
fi

echo -e "${GREEN}PASS${NC}: No private key material found in $SCOPE_DIR"
