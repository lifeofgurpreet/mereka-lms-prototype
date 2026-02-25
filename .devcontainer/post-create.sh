#!/usr/bin/env bash
# post-create.sh — runs once after devcontainer is created.
# Idempotent: safe to re-run.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[post-create]${NC} $*"; }
ok()   { echo -e "${GREEN}[post-create] ok:${NC} $*"; }
warn() { echo -e "${YELLOW}[post-create] warn:${NC} $*"; }

# ---------------------------------------------------------------------------
# 1. Python virtual environment
# ---------------------------------------------------------------------------
log "Setting up Python virtual environment..."
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
  ok "Created .venv"
else
  ok ".venv already exists"
fi

# shellcheck source=/dev/null
source .venv/bin/activate
pip install --upgrade pip --quiet
pip install uv --quiet
ok "Python environment ready"

# ---------------------------------------------------------------------------
# 2. Git submodules
# ---------------------------------------------------------------------------
log "Initialising git submodules..."
git submodule update --init --recursive
ok "Submodules initialised"

# ---------------------------------------------------------------------------
# 3. Pre-commit hooks
# ---------------------------------------------------------------------------
log "Installing pre-commit hooks..."
if command -v pre-commit >/dev/null 2>&1; then
  pre-commit install
  ok "pre-commit hooks installed"
else
  warn "pre-commit not found, skipping hook install"
fi

# ---------------------------------------------------------------------------
# 4. Git hooks (Tutor config safety + secret scanning)
# ---------------------------------------------------------------------------
if [ -f ".gitconfig" ]; then
  git config --local include.path ../.gitconfig || true
  ok "git hooks configured"
fi

# ---------------------------------------------------------------------------
# 5. Tutor environment directory
# ---------------------------------------------------------------------------
log "Preparing tutor_env directory..."
mkdir -p tutor_env
ok "tutor_env directory ready (TUTOR_ROOT=${TUTOR_ROOT:-$REPO_ROOT/tutor_env})"

# Export TUTOR_ROOT so subsequent tutor calls in this script work correctly.
export TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"

# ---------------------------------------------------------------------------
# 6. Tutor config save + apply patches
# ---------------------------------------------------------------------------
log "Running tutor config save (sets local Docker service names)..."
tutor config save \
  --set LMS_HOST=localhost \
  --set CMS_HOST=studio.localhost \
  --set MFE_HOST=apps.localhost \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017 \
  --set MYSQL_PORT=3306 \
  --set REDIS_PORT=6379
ok "tutor config saved"

log "Applying Mereka patches..."
if [ -x "infrastructure/tutor/apply-patches.sh" ]; then
  ./infrastructure/tutor/apply-patches.sh
  ok "Patches applied"
else
  warn "apply-patches.sh not found or not executable, skipping"
fi

# ---------------------------------------------------------------------------
# 7. Seed demo course (opt-in)
# ---------------------------------------------------------------------------
if [ "${SEED_DEMO_COURSE:-false}" = "true" ]; then
  log "SEED_DEMO_COURSE=true — seeding demo course after services start..."
  # Services must already be running for this to work.
  if docker ps --filter "name=tutor_local-lms" --format "{{.Status}}" 2>/dev/null | grep -q "Up"; then
    tutor local do importdemocourse || warn "Demo course import failed, continuing"
    ok "Demo course seeded"
  else
    warn "Tutor services not running; skipping demo course seed."
    warn "Start services first with 'make tutor-start', then re-run:"
    warn "  tutor local do importdemocourse"
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "----------------------------------------------------------------------"
echo "  Devcontainer ready."
echo ""
echo "  Next steps:"
echo "    1. Build images (first time only, 30-45 min):"
echo "         tutor images build openedx"
echo "         tutor images build mfe"
echo "    2. Launch local platform:"
echo "         make tutor-start"
echo "         # or: tutor local launch -I --skip-build"
echo "    3. Access:"
echo "         LMS:    http://localhost"
echo "         Studio: http://studio.localhost"
echo "         MFE:    http://apps.localhost/authn/login"
echo ""
echo "  See docs/onboarding/DEVCONTAINER_GUIDE.md for full instructions."
echo "----------------------------------------------------------------------"
