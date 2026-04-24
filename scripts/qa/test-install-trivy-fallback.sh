#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/fake-bin"
INSTALL_DIR="${TMP_DIR}/install-bin"
HOME_DIR="${TMP_DIR}/home"
mkdir -p "${FAKE_BIN}" "${INSTALL_DIR}" "${HOME_DIR}/.docker"
echo '{}' > "${HOME_DIR}/.docker/config.json"

cat > "${FAKE_BIN}/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod 0755 "${FAKE_BIN}/gh"

cat > "${FAKE_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod 0755 "${FAKE_BIN}/curl"

cat > "${FAKE_BIN}/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${TRIVY_DOCKER_LOG}"
if [[ "$*" == *"--version"* ]] || [[ "$*" == *" version" ]]; then
  printf 'Version: 0.69.3\n'
fi
exit 0
EOF
chmod 0755 "${FAKE_BIN}/docker"

export HOME="${HOME_DIR}"
export INSTALL_DIR
export TRIVY_DOCKER_LOG="${TMP_DIR}/docker.log"
export PATH="${FAKE_BIN}:${PATH}"
export GITHUB_PATH="${TMP_DIR}/github_path"

"${ROOT_DIR}/scripts/infra/install-trivy.sh" >"${TMP_DIR}/stdout.log"

[[ -x "${INSTALL_DIR}/trivy" ]]
grep -q "${INSTALL_DIR}" "${GITHUB_PATH}"
grep -q "ghcr.io/aquasecurity/trivy:0.69.3 --version" "${TRIVY_DOCKER_LOG}"
grep -q -- "-v /var/run/docker.sock:/var/run/docker.sock" "${TRIVY_DOCKER_LOG}"

echo "install-trivy fallback wrapper works"
