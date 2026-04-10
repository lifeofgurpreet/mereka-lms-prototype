#!/usr/bin/env bash
# Install a pinned trivy binary deterministically for CI scan workflows.
set -euo pipefail

TRIVY_VERSION="${TRIVY_VERSION:-v0.69.3}"
TRIVY_SHA256="${TRIVY_SHA256:-1816b632dfe529869c740c0913e36bd1629cb7688bd5634f4a858c1d57c88b75}"
TRIVY_TARBALL="trivy_${TRIVY_VERSION#v}_Linux-64bit.tar.gz"
TRIVY_GITHUB_REPO="${TRIVY_GITHUB_REPO:-aquasecurity/trivy}"
DOWNLOAD_TIMEOUT="${DOWNLOAD_TIMEOUT:-300}"
DOWNLOAD_ATTEMPT_TIMEOUT="${DOWNLOAD_ATTEMPT_TIMEOUT:-90}"
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-20}"
CURL_MAX_TIME="${CURL_MAX_TIME:-90}"
CURL_RETRIES="${CURL_RETRIES:-2}"

log() {
  printf '[install-trivy] %s\n' "$*" >&2
}

resolve_install_dir() {
  local candidate
  for candidate in "${INSTALL_DIR:-}" "/usr/local/bin" "${HOME}/.local/bin" "${HOME}/bin"; do
    [[ -z "${candidate}" ]] && continue
    mkdir -p "${candidate}"
    if touch "${candidate}/.trivy-write-test" 2>/dev/null; then
      rm -f "${candidate}/.trivy-write-test"
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

current_version_matches() {
  if ! command -v trivy >/dev/null 2>&1; then
    return 1
  fi

  local version_output=""
  version_output="$(trivy version 2>/dev/null || true)"
  grep -Fq "Version: ${TRIVY_VERSION#v}" <<<"${version_output}"
}

download_with_gh() {
  local output_path="$1"
  local gh_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

  if ! command -v gh >/dev/null 2>&1; then
    return 1
  fi

  if [[ -z "${gh_token}" ]]; then
    return 1
  fi

  log "Attempting authenticated GitHub release download for trivy ${TRIVY_VERSION}."
  GH_TOKEN="${gh_token}" timeout "${DOWNLOAD_TIMEOUT}" \
    gh release download "${TRIVY_VERSION}" \
      --repo "${TRIVY_GITHUB_REPO}" \
      --pattern "${TRIVY_TARBALL}" \
      --output "${output_path}" \
      --clobber
}

download_with_curl() {
  local output_path="$1"
  local url="https://github.com/${TRIVY_GITHUB_REPO}/releases/download/${TRIVY_VERSION}/${TRIVY_TARBALL}"
  local attempt

  for attempt in $(seq 1 "${CURL_RETRIES}"); do
    log "curl download attempt ${attempt}/${CURL_RETRIES} for ${url}"
    if timeout "${DOWNLOAD_ATTEMPT_TIMEOUT}" curl -fL \
      --retry 2 \
      --retry-delay 2 \
      --retry-connrefused \
      --connect-timeout "${CURL_CONNECT_TIMEOUT}" \
      --max-time "${CURL_MAX_TIME}" \
      -o "${output_path}" \
      "${url}"; then
      return 0
    fi
    log "curl download attempt ${attempt}/${CURL_RETRIES} failed."
  done

  return 1
}

main() {
  local install_dir
  install_dir="$(resolve_install_dir)"
  if [[ -z "${install_dir}" ]]; then
    echo "Unable to find a writable install directory for trivy." >&2
    exit 1
  fi

  if current_version_matches; then
    echo "trivy ${TRIVY_VERSION} already installed; reusing existing binary."
    exit 0
  fi

  local tmpdir=""
  local tarball_path=""
  trap 'rm -rf "${tmpdir:-}"' EXIT
  tmpdir="$(mktemp -d -t trivy-linux-amd64.XXXXXX)"
  tarball_path="${tmpdir}/${TRIVY_TARBALL}"

  if ! download_with_gh "${tarball_path}"; then
    log "GitHub release download unavailable or failed; falling back to curl."
    download_with_curl "${tarball_path}"
  fi

  echo "${TRIVY_SHA256}  ${tarball_path}" | sha256sum -c -
  tar -xzf "${tarball_path}" -C "${tmpdir}" trivy
  install -m 0755 "${tmpdir}/trivy" "${install_dir}/trivy"
  echo "${install_dir}" >> "${GITHUB_PATH:-/dev/null}"
  "${install_dir}/trivy" --version
}

main "$@"
