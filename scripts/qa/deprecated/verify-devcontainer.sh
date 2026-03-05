#!/usr/bin/env bash
# No @covers - devcontainer structural verification, not a spec AC
# Verify .devcontainer setup is structurally correct.
# Checks: files exist, JSON is valid, required tools and env vars are declared.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
SKIP=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $*"; SKIP=$((SKIP + 1)); }

echo "Verifying .devcontainer setup..."
echo ""

# ---------------------------------------------------------------------------
# 1. Required files exist
# ---------------------------------------------------------------------------
echo "1. Required files..."

if [ -f ".devcontainer/devcontainer.json" ]; then
  pass "devcontainer.json exists"
else
  fail "devcontainer.json missing"
fi

if [ -f ".devcontainer/Dockerfile" ]; then
  pass "Dockerfile exists"
else
  fail "Dockerfile missing"
fi

if [ -f ".devcontainer/post-create.sh" ]; then
  pass "post-create.sh exists"
else
  fail "post-create.sh missing"
fi

# ---------------------------------------------------------------------------
# 2. devcontainer.json is valid JSON
# ---------------------------------------------------------------------------
echo ""
echo "2. devcontainer.json validity..."

if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import json, sys; json.load(open('.devcontainer/devcontainer.json'))" 2>/dev/null; then
    pass "devcontainer.json is valid JSON"
  else
    fail "devcontainer.json is not valid JSON"
  fi
elif command -v jq >/dev/null 2>&1; then
  if jq . .devcontainer/devcontainer.json >/dev/null 2>&1; then
    pass "devcontainer.json is valid JSON"
  else
    fail "devcontainer.json is not valid JSON"
  fi
else
  skip "no JSON validator available (python3 or jq required)"
fi

# ---------------------------------------------------------------------------
# 3. post-create.sh is executable
# ---------------------------------------------------------------------------
echo ""
echo "3. post-create.sh permissions..."

if [ -x ".devcontainer/post-create.sh" ]; then
  pass "post-create.sh is executable"
else
  fail "post-create.sh is not executable (run: chmod +x .devcontainer/post-create.sh)"
fi

# ---------------------------------------------------------------------------
# 4. Dockerfile references required tools
# ---------------------------------------------------------------------------
echo ""
echo "4. Dockerfile tool declarations..."

for tool in python node shellcheck; do
  if grep -q "$tool" .devcontainer/Dockerfile 2>/dev/null; then
    pass "Dockerfile references: $tool"
  else
    fail "Dockerfile does not reference: $tool"
  fi
done

if grep -q "tutor" .devcontainer/Dockerfile 2>/dev/null; then
  pass "Dockerfile installs tutor"
else
  fail "Dockerfile does not install tutor"
fi

if grep -q "pre-commit" .devcontainer/Dockerfile 2>/dev/null; then
  pass "Dockerfile installs pre-commit"
else
  fail "Dockerfile does not install pre-commit"
fi

# ---------------------------------------------------------------------------
# 5. TUTOR_ROOT is declared in devcontainer.json
# ---------------------------------------------------------------------------
echo ""
echo "5. Environment variable declarations..."

if grep -q "TUTOR_ROOT" .devcontainer/devcontainer.json 2>/dev/null; then
  pass "TUTOR_ROOT declared in devcontainer.json"
else
  fail "TUTOR_ROOT not declared in devcontainer.json"
fi

# ---------------------------------------------------------------------------
# 6. postCreateCommand wires post-create.sh
# ---------------------------------------------------------------------------
echo ""
echo "6. postCreateCommand wiring..."

if grep -q "post-create.sh" .devcontainer/devcontainer.json 2>/dev/null; then
  pass "postCreateCommand references post-create.sh"
else
  fail "postCreateCommand does not reference post-create.sh"
fi

# ---------------------------------------------------------------------------
# 7. tutor_env mount declared
# ---------------------------------------------------------------------------
echo ""
echo "7. Persistent volume mount..."

if grep -q "tutor_env" .devcontainer/devcontainer.json 2>/dev/null; then
  pass "tutor_env mount declared in devcontainer.json"
else
  fail "tutor_env mount not declared in devcontainer.json"
fi

# ---------------------------------------------------------------------------
# 8. Required ports declared
# ---------------------------------------------------------------------------
echo ""
echo "8. Port forwarding..."

required_ports=(80 443 8000 8001 8002)
for port in "${required_ports[@]}"; do
  if grep -q "\"$port\"" .devcontainer/devcontainer.json 2>/dev/null || \
     grep -q "$port" .devcontainer/devcontainer.json 2>/dev/null; then
    pass "Port $port declared"
  else
    fail "Port $port not declared"
  fi
done

# ---------------------------------------------------------------------------
# 9. post-create.sh references apply-patches.sh and tutor config save
# ---------------------------------------------------------------------------
echo ""
echo "9. post-create.sh content..."

if grep -q "apply-patches.sh" .devcontainer/post-create.sh 2>/dev/null; then
  pass "post-create.sh calls apply-patches.sh"
else
  fail "post-create.sh does not call apply-patches.sh"
fi

if grep -q "tutor config save" .devcontainer/post-create.sh 2>/dev/null; then
  pass "post-create.sh calls tutor config save"
else
  fail "post-create.sh does not call tutor config save"
fi

if grep -q "submodule" .devcontainer/post-create.sh 2>/dev/null; then
  pass "post-create.sh initialises git submodules"
else
  fail "post-create.sh does not initialise git submodules"
fi

if grep -q "pre-commit install" .devcontainer/post-create.sh 2>/dev/null; then
  pass "post-create.sh installs pre-commit hooks"
else
  fail "post-create.sh does not install pre-commit hooks"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "----------------------------------------------------------------------"
printf "  PASS: %d  FAIL: %d  SKIP: %d\n" "$PASS" "$FAIL" "$SKIP"
echo "----------------------------------------------------------------------"

if [ "$FAIL" -eq 0 ]; then
  echo "PASS: devcontainer setup is valid."
  exit 0
else
  echo "FAIL: $FAIL check(s) failed. Fix issues above."
  exit 1
fi
