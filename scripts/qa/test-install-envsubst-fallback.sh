#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
ORIGINAL_PATH="${PATH}"

FAKE_BIN="${TMP_DIR}/fake-bin"
INSTALL_DIR="${TMP_DIR}/install-bin"
mkdir -p "${FAKE_BIN}" "${INSTALL_DIR}"

cat > "${FAKE_BIN}/envsubst" <<'EOF'
#!/usr/bin/env bash
exit 127
EOF
chmod 0755 "${FAKE_BIN}/envsubst"

export INSTALL_DIR
export GITHUB_PATH="${TMP_DIR}/github_path"
export PATH="${FAKE_BIN}:${ORIGINAL_PATH}"

"${ROOT_DIR}/scripts/infra/install-envsubst.sh" >"${TMP_DIR}/stdout.log"

[[ -x "${INSTALL_DIR}/envsubst" ]]
grep -q "${INSTALL_DIR}" "${GITHUB_PATH}"

rendered="$(
  FOO="world" BAR="again" PATH="${INSTALL_DIR}:${PATH}" \
    bash -lc 'printf "hello ${FOO} ${BAR} $MISSING" | envsubst'
)"

[[ "${rendered}" == "hello world again " ]]

echo "install-envsubst fallback wrapper works"
