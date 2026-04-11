#!/usr/bin/env bash
# Install a deterministic envsubst-compatible command for CI/release workflows.
set -euo pipefail

log() {
  printf '[install-envsubst] %s\n' "$*" >&2
}

resolve_install_dir() {
  local candidate
  for candidate in "${INSTALL_DIR:-}" "/usr/local/bin" "${HOME}/.local/bin" "${HOME}/bin"; do
    [[ -z "${candidate}" ]] && continue
    mkdir -p "${candidate}"
    if touch "${candidate}/.envsubst-write-test" 2>/dev/null; then
      rm -f "${candidate}/.envsubst-write-test"
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

current_envsubst_available() {
  if ! command -v envsubst >/dev/null 2>&1; then
    return 1
  fi

  printf '${ENVSTUB_CHECK}' | envsubst >/dev/null 2>&1
}

install_python_wrapper() {
  local install_dir="$1"
  cat > "${install_dir}/envsubst" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

python3 -c '
import os
import re
import sys

pattern = re.compile(r"\$(\w+)|\$\{([^}]+)\}")
data = sys.stdin.read()

def replace(match):
    key = match.group(1) or match.group(2) or ""
    return os.environ.get(key, "")

sys.stdout.write(pattern.sub(replace, data))
'
EOF
  chmod 0755 "${install_dir}/envsubst"
}

main() {
  local install_dir
  install_dir="$(resolve_install_dir)"
  if [[ -z "${install_dir}" ]]; then
    echo "Unable to find a writable install directory for envsubst." >&2
    exit 1
  fi

  if current_envsubst_available; then
    log "Reusing existing envsubst from PATH."
    exit 0
  fi

  install_python_wrapper "${install_dir}"
  echo "${install_dir}" >> "${GITHUB_PATH:-/dev/null}"
  log "Installed deterministic envsubst wrapper at ${install_dir}/envsubst."
}

main "$@"
