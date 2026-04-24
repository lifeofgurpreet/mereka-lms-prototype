#!/usr/bin/env bash
# Install a pinned cosign binary deterministically for CI/release workflows.
set -euo pipefail

COSIGN_VERSION="${COSIGN_VERSION:-v3.0.5}"
COSIGN_SHA256="${COSIGN_SHA256:-db15cc99e6e4837daabab023742aaddc3841ce57f193d11b7c3e06c8003642b2}"
COSIGN_URL="https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"
COSIGN_GITHUB_REPO="${COSIGN_GITHUB_REPO:-sigstore/cosign}"
DOWNLOAD_TIMEOUT="${DOWNLOAD_TIMEOUT:-300}"
DOWNLOAD_ATTEMPT_TIMEOUT="${DOWNLOAD_ATTEMPT_TIMEOUT:-90}"
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-20}"
CURL_MAX_TIME="${CURL_MAX_TIME:-90}"
CURL_RETRIES="${CURL_RETRIES:-2}"

log() {
  printf '[install-cosign] %s\n' "$*" >&2
}

resolve_install_dir() {
  local candidate
  for candidate in "${INSTALL_DIR:-}" "/usr/local/bin" "${HOME}/.local/bin" "${HOME}/bin"; do
    [[ -z "${candidate}" ]] && continue
    mkdir -p "${candidate}"
    if touch "${candidate}/.cosign-write-test" 2>/dev/null; then
      rm -f "${candidate}/.cosign-write-test"
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

current_version_matches() {
  if ! command -v cosign >/dev/null 2>&1; then
    return 1
  fi

  local version_output=""
  version_output="$(cosign version 2>/dev/null || true)"
  grep -Fq "GitVersion:    ${COSIGN_VERSION}" <<<"${version_output}"
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

  log "Attempting authenticated GitHub release download for cosign ${COSIGN_VERSION}."
  GH_TOKEN="${gh_token}" timeout "${DOWNLOAD_TIMEOUT}" \
    gh release download "${COSIGN_VERSION}" \
      --repo "${COSIGN_GITHUB_REPO}" \
      --pattern "cosign-linux-amd64" \
      --output "${output_path}" \
      --clobber
}

download_with_curl() {
  local output_path="$1"
  local attempt

  for attempt in $(seq 1 "${CURL_RETRIES}"); do
    log "curl download attempt ${attempt}/${CURL_RETRIES} for ${COSIGN_URL}"
    if timeout "${DOWNLOAD_ATTEMPT_TIMEOUT}" curl -fL \
      --retry 2 \
      --retry-delay 2 \
      --retry-connrefused \
      --connect-timeout "${CURL_CONNECT_TIMEOUT}" \
      --max-time "${CURL_MAX_TIME}" \
      -o "${output_path}" \
      "${COSIGN_URL}"; then
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
    echo "Unable to find a writable install directory for cosign." >&2
    exit 1
  fi

  if current_version_matches; then
    echo "cosign ${COSIGN_VERSION} already installed; reusing existing binary."
    exit 0
  fi

  local tmp_bin=""
  trap 'rm -f "${tmp_bin:-}"' EXIT
  tmp_bin="$(mktemp -t cosign-linux-amd64.XXXXXX)"

  if ! download_with_gh "${tmp_bin}"; then
    log "GitHub release download unavailable or failed; falling back to curl."
    download_with_curl "${tmp_bin}"
  fi

  echo "${COSIGN_SHA256}  ${tmp_bin}" | sha256sum -c -

  install -m 0755 "${tmp_bin}" "${install_dir}/cosign"
  echo "${install_dir}" >> "${GITHUB_PATH:-/dev/null}"
  "${install_dir}/cosign" version
}

main "$@"
