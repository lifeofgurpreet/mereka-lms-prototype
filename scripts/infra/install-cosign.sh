#!/usr/bin/env bash
# Install a pinned cosign binary deterministically for CI/release workflows.
set -euo pipefail

COSIGN_VERSION="${COSIGN_VERSION:-v3.0.5}"
COSIGN_SHA256="${COSIGN_SHA256:-db15cc99e6e4837daabab023742aaddc3841ce57f193d11b7c3e06c8003642b2}"
COSIGN_URL="https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"
DOWNLOAD_TIMEOUT="${DOWNLOAD_TIMEOUT:-300}"

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

  timeout "${DOWNLOAD_TIMEOUT}" curl -fsSL --retry 3 --retry-delay 2 --retry-connrefused \
    -o "${tmp_bin}" \
    "${COSIGN_URL}"

  echo "${COSIGN_SHA256}  ${tmp_bin}" | sha256sum -c -

  install -m 0755 "${tmp_bin}" "${install_dir}/cosign"
  echo "${install_dir}" >> "${GITHUB_PATH:-/dev/null}"
  "${install_dir}/cosign" version
}

main "$@"
