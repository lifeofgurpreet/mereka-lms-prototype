#!/usr/bin/env bash
# One-Click Local Development Setup
# This script sets up everything needed for local development
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
MIN_DOCKER_MEMORY_BYTES="${MIN_DOCKER_MEMORY_BYTES:-12884901888}"
MIN_FREE_DISK_KB="${MIN_FREE_DISK_KB:-41943040}"
HTTP_ROUTE_ATTEMPTS="${HTTP_ROUTE_ATTEMPTS:-12}"
HTTP_ROUTE_SLEEP_SECONDS="${HTTP_ROUTE_SLEEP_SECONDS:-5}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

die() {
    echo -e "${RED}❌ $1${NC}" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_submodule_state() {
    local drift
    drift="$(git submodule status --recursive 2>/dev/null | rg '^[^ ]' || true)"
    if [[ -n "$drift" ]]; then
        printf '%s\n' "$drift" >&2
        die "Submodules are not at the repo-pinned state. Run 'git submodule update --init --recursive' and retry."
    fi
}

check_docker_resources() {
    local docker_memory_bytes docker_memory_gib free_disk_kb free_disk_gib
    docker_memory_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || true)"
    if [[ "$docker_memory_bytes" =~ ^[0-9]+$ ]] && (( docker_memory_bytes > 0 )); then
        docker_memory_gib=$(( docker_memory_bytes / 1024 / 1024 / 1024 ))
        if (( docker_memory_bytes < MIN_DOCKER_MEMORY_BYTES )); then
            if [[ "$(uname -s)" == "Darwin" ]]; then
                die "Docker Desktop reports ${docker_memory_gib} GiB RAM. Raise it to at least 12 GiB before the first image build."
            fi
            warn "Docker reports ${docker_memory_gib} GiB RAM. Open edX image builds are expected to need about 12 GiB."
        fi
    else
        warn "Unable to read Docker memory limits from 'docker info'."
    fi

    free_disk_kb="$(df -Pk "$REPO_ROOT" | awk 'NR==2 {print $4}')"
    if [[ "$free_disk_kb" =~ ^[0-9]+$ ]]; then
        free_disk_gib=$(( free_disk_kb / 1024 / 1024 ))
        if (( free_disk_kb < MIN_FREE_DISK_KB )); then
            warn "Only ${free_disk_gib} GiB free on the repo filesystem. First-run image builds are expected to need about 40 GiB."
        fi
    fi
}

wait_for_http_route() {
    local url="$1"
    local label="$2"
    local allowed_statuses="$3"
    local attempts="${4:-$HTTP_ROUTE_ATTEMPTS}"
    local sleep_seconds="${5:-$HTTP_ROUTE_SLEEP_SECONDS}"
    local attempt status

    for ((attempt = 1; attempt <= attempts; attempt++)); do
        status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$url" 2>/dev/null || true)"
        status="${status:-000}"
        if [[ " ${allowed_statuses} " == *" ${status} "* ]]; then
            echo -e "${GREEN}✅ ${label} accessible (HTTP ${status})${NC}"
            return 0
        fi
        sleep "$sleep_seconds"
    done

    echo -e "${RED}❌ ${label} not accessible after ${attempts} attempts (last HTTP ${status:-000})${NC}" >&2
    return 1
}

ensure_local_tutor_plugin_enabled() {
    local plugin="$1"
    local output

    if output="$(tutor plugins enable "$plugin" 2>&1)"; then
        [[ -n "$output" ]] && printf '%s\n' "$output"
        return 0
    fi

    printf '%s\n' "$output" >&2
    die "Failed to enable required local Tutor plugin: ${plugin}"
}

disable_local_optional_tutor_plugin() {
    local plugin="$1"
    local output

    if output="$(tutor plugins disable "$plugin" 2>&1)"; then
        [[ -n "$output" ]] && printf '%s\n' "$output"
        echo -e "${YELLOW}⚠️  Optional local Tutor plugin disabled for canonical first-run: ${plugin}${NC}"
    fi
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        One-Click Local Development Setup                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Prerequisites Check
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"
if ! command -v docker &> /dev/null; then
    die "Docker not found. Please install Docker Desktop."
fi
if ! docker info &> /dev/null; then
    die "Docker not running. Please start Docker Desktop."
fi
if ! docker compose version &> /dev/null; then
    die "Docker Compose v2 is required. Install or update Docker Desktop / Docker Compose."
fi
if ! command -v python3 &> /dev/null; then
    die "Python 3 not found. Please install Python 3.12+."
fi
check_submodule_state
check_docker_resources
echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Step 2: Python Environment
echo -e "${BLUE}Step 2: Setting up Python environment...${NC}"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    echo -e "${GREEN}✅ Created virtual environment${NC}"
else
    echo -e "${YELLOW}⚠️  Virtual environment already exists${NC}"
fi

if [[ -f .venv/bin/activate ]]; then
    # shellcheck source=/dev/null
    source .venv/bin/activate
else
    echo -e "${RED}ERROR: .venv/bin/activate not found. Run 'python3 -m venv .venv' first.${NC}"
    exit 1
fi
pip install --upgrade pip --quiet
pip install -r requirements-tutor.txt --quiet
echo -e "${GREEN}✅ Python environment ready${NC}"
echo ""

# Step 3: Tutor Environment
echo -e "${BLUE}Step 3: Configuring Tutor environment...${NC}"
# shellcheck source=/dev/null
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$REPO_ROOT/tutor_env"

if [ ! -f "tutor_env/config.yml" ]; then
    echo -e "${YELLOW}⚠️  Config file not found, creating from example...${NC}"
    mkdir -p tutor_env
    cp infrastructure/tutor/config.example.yml tutor_env/config.yml
fi

echo -e "${BLUE}Converging canonical local Tutor plugin set...${NC}"
for plugin in mfe discovery forum notes xqueue; do
    ensure_local_tutor_plugin_enabled "$plugin"
done
for plugin in aspects ecommerce; do
    disable_local_optional_tutor_plugin "$plugin"
done

# Ensure local Docker services are configured
./scripts/infra/tutor-config-save.sh \
    --set LMS_HOST=localhost \
    --set CMS_HOST=studio.localhost \
    --set MFE_HOST=apps.localhost \
    --set DISCOVERY_HOST=discovery.localhost \
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
    --set OPENEDX_COMMON_VERSION=release/ulmo \
    --set OPENEDX_LMS_VERSION=release/ulmo \
    --set OPENEDX_CMS_VERSION=release/ulmo \
    --set MFE_COMMON_VERSION=release/ulmo.2 \
    --set MYSQL_HOST=mysql \
    --set MONGODB_HOST=mongodb \
    --set REDIS_HOST=redis \
    --set MONGODB_PORT=27017 \
    --set MYSQL_PORT=3306 \
    --set MYSQL_ROOT_HOST=% \
    --set REDIS_PORT=6379

echo -e "${GREEN}✅ Tutor configured${NC}"
echo ""

# Step 4: Build Images (if needed)
echo -e "${BLUE}Step 4: Checking Docker images...${NC}"
./scripts/infra/ensure-buildx-dependency-mirror.sh
source "$REPO_ROOT/scripts/infra/build-context-fingerprint.sh"
FORCE_LOCAL_IMAGE_BUILD="${FORCE_LOCAL_IMAGE_BUILD:-0}"

image_matches_context() {
    local image_ref="$1"
    local context_dir="$2"
    local expected_sha
    local actual_sha

    docker image inspect "$image_ref" >/dev/null 2>&1 || return 1
    expected_sha="$(mereka_build_context_fingerprint "$context_dir")"
    actual_sha="$(docker image inspect \
        --format '{{ index .Config.Labels "io.mereka.build-context-sha256" }}' \
        "$image_ref" 2>/dev/null || true)"

    [[ -n "$actual_sha" && "$actual_sha" == "$expected_sha" ]]
}

if [[ "$FORCE_LOCAL_IMAGE_BUILD" == "1" ]] || ! image_matches_context openedx:nightly tutor_env/env/build/openedx; then
    echo -e "${YELLOW}⚠️  OpenEdX image missing or stale. Building fast local image (this still takes time)...${NC}"
    ./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
else
    echo -e "${GREEN}✅ OpenEdX image matches current rendered build context${NC}"
fi

if [[ "$FORCE_LOCAL_IMAGE_BUILD" == "1" ]] || ! image_matches_context openedx-mfe:nightly tutor_env/env/plugins/mfe/build/mfe; then
    echo -e "${YELLOW}⚠️  MFE image missing or stale. Building fast local image (this still takes time)...${NC}"
    ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
else
    echo -e "${GREEN}✅ MFE image matches current rendered build context${NC}"
fi
echo ""

# Step 5: Initialize Tutor runtime
echo -e "${BLUE}Step 5: Converging initialized Tutor runtime...${NC}"
echo -e "${YELLOW}⚠️  Running Tutor launch/init with local images. This is idempotent and repairs partial data directories.${NC}"
tutor local launch -I --skip-build
echo -e "${GREEN}✅ Tutor launch/init converged${NC}"
echo ""

# Step 6: Start Services
echo -e "${BLUE}Step 6: Starting services...${NC}"
make tutor-start
sleep 10
echo -e "${GREEN}✅ Services started${NC}"
echo ""

# Step 7: Verify local bootstrap baseline
echo -e "${BLUE}Step 7: Verifying local bootstrap baseline...${NC}"
./scripts/infra/verify-local-bootstrap-readiness.sh
echo -e "${GREEN}✅ Local bootstrap baseline verified${NC}"
echo ""

# Step 8: Create Admin User
echo -e "${BLUE}Step 8: Setting up admin user...${NC}"
LOCAL_ADMIN_USERNAME="${LOCAL_ADMIN_USERNAME:-admin}"
LOCAL_ADMIN_EMAIL="${LOCAL_ADMIN_EMAIL:-admin@mereka.academy}"
LOCAL_ADMIN_CREDENTIALS_FILE="${LOCAL_ADMIN_CREDENTIALS_FILE:-tutor_env/local-admin-credentials.txt}"
if [[ -z "${LOCAL_ADMIN_PASSWORD:-}" ]]; then
    LOCAL_ADMIN_PASSWORD="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)"
    mkdir -p "$(dirname "$LOCAL_ADMIN_CREDENTIALS_FILE")"
    umask 077
    {
        printf 'username=%s\n' "$LOCAL_ADMIN_USERNAME"
        printf 'email=%s\n' "$LOCAL_ADMIN_EMAIL"
        printf 'password=%s\n' "$LOCAL_ADMIN_PASSWORD"
    } > "$LOCAL_ADMIN_CREDENTIALS_FILE"
    echo -e "${YELLOW}⚠️  Generated local admin password in $LOCAL_ADMIN_CREDENTIALS_FILE${NC}"
else
    mkdir -p "$(dirname "$LOCAL_ADMIN_CREDENTIALS_FILE")"
    umask 077
    {
        printf 'username=%s\n' "$LOCAL_ADMIN_USERNAME"
        printf 'email=%s\n' "$LOCAL_ADMIN_EMAIL"
        printf 'password=%s\n' "$LOCAL_ADMIN_PASSWORD"
    } > "$LOCAL_ADMIN_CREDENTIALS_FILE"
fi
ADMIN_SETUP_LOG="$(mktemp)"
if docker exec \
  -e LOCAL_ADMIN_USERNAME="$LOCAL_ADMIN_USERNAME" \
  -e LOCAL_ADMIN_EMAIL="$LOCAL_ADMIN_EMAIL" \
  -e LOCAL_ADMIN_PASSWORD="$LOCAL_ADMIN_PASSWORD" \
  tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "
import os
from django.contrib.auth import get_user_model
User = get_user_model()
username = os.environ['LOCAL_ADMIN_USERNAME']
email = os.environ['LOCAL_ADMIN_EMAIL']
password = os.environ['LOCAL_ADMIN_PASSWORD']
try:
    u = User.objects.get(username=username)
except User.DoesNotExist:
    u = User.objects.create_user(username, email, password)
u.email = email
u.set_password(password)
u.is_active = True
u.is_staff = True
u.is_superuser = True
u.save()
print('✅ Admin user ready')
" >"$ADMIN_SETUP_LOG" 2>&1; then
    grep -E "(Admin|✅)" "$ADMIN_SETUP_LOG" || cat "$ADMIN_SETUP_LOG"
else
    cat "$ADMIN_SETUP_LOG" >&2
    rm -f "$ADMIN_SETUP_LOG"
    exit 1
fi
rm -f "$ADMIN_SETUP_LOG"
echo ""

# Step 9: Verify Setup
echo -e "${BLUE}Step 9: Verifying setup...${NC}"
CONTAINERS=$(docker ps --filter "name=tutor_local" --format "{{.Names}}" | wc -l | tr -d ' ')
echo -e "${BLUE}ℹ️  tutor_local containers running: $CONTAINERS${NC}"

FINAL_FAILURES=0
wait_for_http_route http://localhost "LMS" "200 302" || FINAL_FAILURES=$((FINAL_FAILURES + 1))
wait_for_http_route http://studio.localhost "Studio" "200 302" || FINAL_FAILURES=$((FINAL_FAILURES + 1))
wait_for_http_route http://apps.localhost/authn/login "MFE authn" "200 302" || FINAL_FAILURES=$((FINAL_FAILURES + 1))
wait_for_http_route http://discovery.localhost "Discovery" "200 302" || FINAL_FAILURES=$((FINAL_FAILURES + 1))
echo ""

if (( FINAL_FAILURES > 0 )); then
    die "Local setup did not converge to a healthy runtime. Re-run ./scripts/infra/verify-local-bootstrap-readiness.sh and inspect the failed routes above."
fi

# Final Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Setup Complete!                                       ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  📍 Access URLs:"
echo "    • LMS: http://localhost"
echo "    • Studio: http://studio.localhost"
echo "    • MFE Login: http://apps.localhost/authn/login"
echo "    • Discovery: http://discovery.localhost"
echo "    • Admin: http://localhost/admin"
echo ""
echo "  🔐 Credentials:"
echo "    • Username: $LOCAL_ADMIN_USERNAME"
echo "    • Password file: $LOCAL_ADMIN_CREDENTIALS_FILE"
echo ""
echo "  🛠️  Next Steps:"
echo "    • Re-run the governed first-run wrapper: make local-first-run"
echo "    • Fast Open edX rebuild: ./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast"
echo "    • Fast MFE rebuild: ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast"
echo "    • Strict local Open edX proof rebuild: ./scripts/infra/build-openedx-image.sh --local-defaults --build-profile proof --cache-mode none"
echo "    • Strict local MFE proof rebuild: ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile proof --cache-mode none"
echo "      (CI proof class: build-benchmark.yml with benchmark_class=app-cache-cold)"
echo "    • Verify initialized stack: ./scripts/infra/verify-local-bootstrap-readiness.sh"
echo "    • Optional setup smoke: ./scripts/qa/verify-setup.sh"
echo "    • Read: docs/guides/onboarding/QUICK_START_LOCAL.md"
echo "    • Check: docs/status/readiness/README.md"
echo ""
echo "╚══════════════════════════════════════════════════════════════╝"
