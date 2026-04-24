#!/usr/bin/env bash
# install-docker-compose.sh - install a pinned Docker Compose v2 CLI plugin.
set -euo pipefail

COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-v5.1.3}"
COMPOSE_UNAME_M="${DOCKER_COMPOSE_UNAME_M:-$(uname -m)}"
COMPOSE_INSTALL_ROOT="${DOCKER_CONFIG:-${HOME:?HOME is required}/.docker}"
COMPOSE_PLUGIN_DIR="${DOCKER_COMPOSE_PLUGIN_DIR:-$COMPOSE_INSTALL_ROOT/cli-plugins}"
COMPOSE_BASE_URL="${DOCKER_COMPOSE_BASE_URL:-https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}}"
FORCE_INSTALL="${DOCKER_COMPOSE_FORCE_INSTALL:-0}"

case "$FORCE_INSTALL" in
  0|1) ;;
  *)
    echo "DOCKER_COMPOSE_FORCE_INSTALL must be 0 or 1, got: $FORCE_INSTALL" >&2
    exit 2
    ;;
esac

if [[ "$FORCE_INSTALL" != "1" ]] && docker compose version >/dev/null 2>&1; then
  docker compose version
  exit 0
fi

case "$COMPOSE_UNAME_M" in
  x86_64|amd64) compose_arch="x86_64" ;;
  aarch64|arm64) compose_arch="aarch64" ;;
  *)
    echo "Unsupported Docker Compose install architecture: $COMPOSE_UNAME_M" >&2
    exit 1
    ;;
esac

asset="docker-compose-linux-${compose_arch}"
tmp_dir="$(mktemp -d -t docker-compose-install.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

curl -fsSLo "$tmp_dir/$asset" "$COMPOSE_BASE_URL/$asset"
curl -fsSLo "$tmp_dir/$asset.sha256" "$COMPOSE_BASE_URL/$asset.sha256"
(cd "$tmp_dir" && sha256sum -c "$asset.sha256")

mkdir -p "$COMPOSE_PLUGIN_DIR"
install -m 0755 "$tmp_dir/$asset" "$COMPOSE_PLUGIN_DIR/docker-compose"
docker compose version
