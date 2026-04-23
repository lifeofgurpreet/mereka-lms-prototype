#!/usr/bin/env bash
# Install a pinned Syft binary deterministically for CI SBOM workflows.
set -euo pipefail

SYFT_VERSION="${SYFT_VERSION:-v1.42.1}"
SYFT_INSTALL_SHA="${SYFT_INSTALL_SHA:-01d0d15aff461f1bc54d1716feb4824341918c4f37e1b6a5a0c0caee2251be67}"
SYFT_INSTALL_URL="${SYFT_INSTALL_URL:-https://raw.githubusercontent.com/anchore/syft/${SYFT_VERSION}/install.sh}"
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-20}"
CURL_MAX_TIME="${CURL_MAX_TIME:-90}"
CURL_RETRIES="${CURL_RETRIES:-2}"

log() {
  printf '[install-syft] %s\n' "$*" >&2
}

resolve_install_dir() {
  local candidate
  for candidate in "${INSTALL_DIR:-}" "/usr/local/bin" "${HOME}/.local/bin" "${HOME}/bin"; do
    [[ -z "${candidate}" ]] && continue
    mkdir -p "${candidate}"
    if touch "${candidate}/.syft-write-test" 2>/dev/null; then
      rm -f "${candidate}/.syft-write-test"
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

current_version_matches() {
  if ! command -v syft >/dev/null 2>&1; then
    return 1
  fi

  local version_output=""
  version_output="$(syft version 2>/dev/null || true)"
  grep -Fq "Version: ${SYFT_VERSION#v}" <<<"${version_output}"
}

main() {
  local install_dir
  install_dir="$(resolve_install_dir)"
  if [[ -z "${install_dir}" ]]; then
    echo "Unable to find a writable install directory for syft." >&2
    exit 1
  fi

  if current_version_matches; then
    echo "syft ${SYFT_VERSION} already installed; reusing existing binary."
    exit 0
  fi

  local tmpdir=""
  trap 'rm -rf "${tmpdir:-}"' EXIT
  tmpdir="$(mktemp -d -t syft-install.XXXXXX)"
  local installer_path="${tmpdir}/syft-install.sh"

  log "Downloading Syft installer ${SYFT_VERSION}."
  curl -sSfL \
    --retry "${CURL_RETRIES}" \
    --retry-delay 2 \
    --retry-connrefused \
    --connect-timeout "${CURL_CONNECT_TIMEOUT}" \
    --max-time "${CURL_MAX_TIME}" \
    -o "${installer_path}" \
    "${SYFT_INSTALL_URL}"

  echo "${SYFT_INSTALL_SHA}  ${installer_path}" | sha256sum -c -

  log "Installing Syft ${SYFT_VERSION} into ${install_dir}."
  DOWNLOAD_TAG_INSTALL_SCRIPT=false sh "${installer_path}" -b "${install_dir}" "${SYFT_VERSION}"

  if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "${install_dir}" >> "${GITHUB_PATH}"
  fi

  "${install_dir}/syft" version
}

main "$@"
