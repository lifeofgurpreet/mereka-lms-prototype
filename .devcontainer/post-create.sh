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
pip install -r requirements-tutor.txt --quiet
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
# 6. Tutor config save through the canonical front door
# ---------------------------------------------------------------------------
log "Running canonical Tutor config wrapper (sets local Docker service names and prepares build context)..."
# shellcheck source=/dev/null
source infrastructure/tutor/tutor-env.sh
./scripts/infra/tutor-config-save.sh \
  --set LMS_HOST=localhost \
  --set CMS_HOST=studio.localhost \
  --set MFE_HOST=apps.localhost \
  --set DISCOVERY_HOST=discovery.localhost \
  --set ECOMMERCE_HOST=ecommerce.localhost \
  --set XQUEUE_HOST=xqueue.localhost \
  --set RUN_MONGODB=true \
  --set RUN_MYSQL=true \
  --set RUN_REDIS=true \
  --set RUN_MEILISEARCH=true \
  --set RUN_SMTP=true \
  --set DOCKER_REGISTRY=mirror.gcr.io/ \
  --set DOCKER_IMAGE_OPENEDX=openedx:nightly \
  --set MFE_DOCKER_IMAGE=openedx-mfe:nightly \
  --set DOCKER_IMAGE_CADDY=mirror.gcr.io/library/caddy:2.7.4 \
  --set DOCKER_IMAGE_MEILISEARCH=mirror.gcr.io/getmeili/meilisearch:v1.8.4 \
  --set DOCKER_IMAGE_MONGODB=mirror.gcr.io/library/mongo:7.0.28 \
  --set DOCKER_IMAGE_MYSQL=mirror.gcr.io/library/mysql:8.4.0 \
  --set DOCKER_IMAGE_REDIS=mirror.gcr.io/library/redis:7.4.5 \
  --set DOCKER_IMAGE_SMTP=mirror.gcr.io/devture/exim-relay:4.96-r1-0 \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017 \
  --set MYSQL_PORT=3306 \
  --set MYSQL_ROOT_HOST=% \
  --set REDIS_PORT=6379
ok "Tutor config saved and build context prepared"

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
echo "         ./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast"
echo "         ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast"
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
