#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/fake-bin"
INSTALL_DIR="${TMP_DIR}/install-bin"
HOME_DIR="${TMP_DIR}/home"
FAKE_INSTALLER="${TMP_DIR}/fake-syft-install.sh"
mkdir -p "${FAKE_BIN}" "${INSTALL_DIR}" "${HOME_DIR}"

cat >"${FAKE_INSTALLER}" <<'EOF'
#!/usr/bin/env sh
set -eu

install_dir=""
while getopts "b:" arg; do
  case "$arg" in
    b) install_dir="$OPTARG" ;;
  esac
done
shift $((OPTIND - 1))
tag="${1:-}"

test "${DOWNLOAD_TAG_INSTALL_SCRIPT:-}" = "false"
test "${tag}" = "${SYFT_VERSION_EXPECTED}"
test -n "${install_dir}"

mkdir -p "${install_dir}"
cat >"${install_dir}/syft" <<EOS
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "version" ]]; then
  printf 'Application: syft\nVersion: ${SYFT_VERSION_EXPECTED#v}\n'
  exit 0
fi
printf 'fake syft\n'
EOS
chmod 0755 "${install_dir}/syft"
printf '%s\n' "${tag}" >"${install_dir}/installed-version.txt"
EOF
chmod 0755 "${FAKE_INSTALLER}"

cat >"${FAKE_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
test -n "${output}"
cp "${FAKE_INSTALLER}" "${output}"
EOF
chmod 0755 "${FAKE_BIN}/curl"

export HOME="${HOME_DIR}"
export INSTALL_DIR
export FAKE_INSTALLER
export PATH="${FAKE_BIN}:/usr/bin:/bin"
export GITHUB_PATH="${TMP_DIR}/github_path"
export SYFT_VERSION="v9.9.9"
export SYFT_VERSION_EXPECTED="${SYFT_VERSION}"
export SYFT_INSTALL_SHA
SYFT_INSTALL_SHA="$(sha256sum "${FAKE_INSTALLER}" | awk '{print $1}')"

"${ROOT_DIR}/scripts/infra/install-syft.sh" >"${TMP_DIR}/stdout.log"

[[ -x "${INSTALL_DIR}/syft" ]]
grep -q "${INSTALL_DIR}" "${GITHUB_PATH}"
grep -qx "${SYFT_VERSION}" "${INSTALL_DIR}/installed-version.txt"
grep -q "Version: ${SYFT_VERSION#v}" "${TMP_DIR}/stdout.log"

echo "install-syft helper pins and passes the requested release tag"
