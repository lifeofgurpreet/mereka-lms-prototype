#!/usr/bin/env bash
# Seeded-defect self-test for verify-bootstrap-workflow-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-bootstrap-workflow-contract.sh"

tmpdir="$(mktemp -d -t verify-bootstrap-workflow-contract.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows" "$tmpdir/scripts/ci" "$tmpdir/scripts/infra"

cat >"$tmpdir/scripts/infra/tutor-config-save.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "config save"
EOF

cat >"$tmpdir/scripts/infra/verify-local-bootstrap-readiness.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "bootstrap readiness"
EOF

chmod +x "$tmpdir/scripts/infra/tutor-config-save.sh" "$tmpdir/scripts/infra/verify-local-bootstrap-readiness.sh"

cat >"$tmpdir/scripts/ci/install-docker-compose.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
compose_arch="x86_64"
asset="docker-compose-linux-${compose_arch}"
curl -fsSLo "$asset" "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/${asset}"
curl -fsSLo "$asset.sha256" "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/${asset}.sha256"
sha256sum -c "$asset.sha256"
docker compose version
EOF

chmod +x "$tmpdir/scripts/ci/install-docker-compose.sh"

write_pass_fixture() {
  cat >"$tmpdir/.github/workflows/bootstrap-local-readiness.yml" <<'EOF'
name: Bootstrap Local Readiness
on:
  workflow_dispatch:
permissions:
  contents: read
env:
  DOCKER_COMPOSE_VERSION: v5.1.3
concurrency:
  group: bootstrap-local-readiness
  cancel-in-progress: false
jobs:
  select-bootstrap-lane:
    runs-on: ubuntu-latest
    steps:
      - uses: Biji-Biji-Initiative/bbi-infrastructure/.github/actions/select-runner-lane@main
        with:
          fallback_label: mereka-k8s-heavy-builders
  bootstrap-readiness:
    needs: [select-bootstrap-lane]
    runs-on: ${{ needs.select-bootstrap-lane.outputs.runner_label }}
    steps:
      - name: Pre-clean persistent Tutor workspace
        run: |
          set -euo pipefail
          cleanup_workspace_paths() {
            local path target
            local existing=()
            for path in "$@"; do
              case "$path" in
                tutor_env|var/bootstrap-readiness|var/ci|.buildx-cache) ;;
                *) echo "Refusing to cleanup unexpected workspace path: $path" >&2; exit 64 ;;
              esac
              target="$GITHUB_WORKSPACE/$path"
              [[ -e "$target" ]] && existing+=("$path")
            done
            [[ "${#existing[@]}" -eq 0 ]] && return 0
            if command -v docker >/dev/null 2>&1 && timeout 30s docker info >/dev/null 2>&1; then
              if timeout 2m docker run --rm \
                --network none \
                -v "$GITHUB_WORKSPACE:/workspace" \
                mirror.gcr.io/library/alpine:3.20 \
                sh -eu -c '
                  for rel in "$@"; do
                    case "$rel" in
                      tutor_env|var/bootstrap-readiness|var/ci|.buildx-cache) ;;
                      *) echo "Refusing to cleanup unexpected workspace path: $rel" >&2; exit 64 ;;
                    esac
                    rm -rf "/workspace/$rel"
                  done
                ' sh "${existing[@]}"; then
                return 0
              fi
              echo "Docker-owned cleanup failed; falling back to sudo/user cleanup." >&2
            fi
            for path in "${existing[@]}"; do
              target="$GITHUB_WORKSPACE/$path"
              [[ -e "$target" ]] || continue
              if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
                sudo rm -rf --one-file-system "$target"
              else
                rm -rf --one-file-system "$target"
              fi
            done
          }
          cleanup_workspace_paths tutor_env var/bootstrap-readiness var/ci .buildx-cache
      - uses: actions/checkout@v4
      - name: Ensure Docker Compose CLI
        run: ./scripts/ci/install-docker-compose.sh
      - run: |
          ./scripts/infra/tutor-config-save.sh \
            --set DOCKER_REGISTRY=mirror.gcr.io/ \
            --set DOCKER_IMAGE_CADDY=mirror.gcr.io/library/caddy:2.7.4 \
            --set DOCKER_IMAGE_MEILISEARCH=mirror.gcr.io/getmeili/meilisearch:v1.8.4 \
            --set DOCKER_IMAGE_MONGODB=mirror.gcr.io/library/mongo:7.0.28 \
            --set DOCKER_IMAGE_MYSQL=mirror.gcr.io/library/mysql:8.4.0 \
            --set DOCKER_IMAGE_REDIS=mirror.gcr.io/library/redis:7.4.5 \
            --set DOCKER_IMAGE_SMTP=mirror.gcr.io/devture/exim-relay:4.96-r1-0
      - run: |
          COMPOSE_ARGS=(
            -f "$TUTOR_ROOT/env/local/docker-compose.yml"
            -f "$TUTOR_ROOT/env/local/docker-compose.prod.yml"
          )
          compose() {
            if docker compose version >/dev/null 2>&1; then
              docker compose "$@"
            elif command -v docker-compose >/dev/null 2>&1; then
              docker-compose "$@"
            else
              echo "Neither docker compose nor docker-compose is available on this runner" >&2
              return 127
            fi
          }
          compose "${COMPOSE_ARGS[@]}" config --images > expected-compose-images.txt
      - run: |
          pull_with_retry() {
            local image_ref="$1"
            local attempt
            for attempt in 1 2 3; do
              if timeout 20m docker pull "$image_ref"; then
                return 0
              fi
              if [[ "$attempt" -eq 3 ]]; then
                echo "docker pull failed after ${attempt} attempts for ${image_ref}" >&2
                return 1
              fi
              sleep $((attempt * 20))
            done
          }
          while IFS= read -r image_ref; do
            pull_with_retry "$image_ref"
            echo "$image_ref|sha256:abc" >> pulled-image-ids.txt
          done < expected-compose-images.txt
      - run: tutor local launch -I --skip-build
      - run: |
          docker inspect tutor_local-lms-1 --format '{{.Name}}|{{.Config.Image}}|{{.Image}}' > actual-running-images.txt
          echo PASS > bootstrap-image-provenance-check.txt
      - run: ./scripts/infra/verify-local-bootstrap-readiness.sh
      - if: ${{ always() }}
        run: |
          python3 - <<'PY'
          import re
          from pathlib import Path
          secret_key = re.compile(r"(PASSWORD|SECRET|TOKEN|PRIVATE_KEY|API_KEY|MASTER_KEY|RSA_PRIVATE_KEY)", re.I)
          lines = []
          skip_block = False
          for line in Path("config.yml").read_text(encoding="utf-8").splitlines():
              if skip_block and line.startswith((" ", "-")):
                  continue
              if skip_block and line.strip() == "":
                  continue
              if skip_block:
                  skip_block = False
              key = line.split(":", 1)[0].strip() if ":" in line else ""
              if key and secret_key.search(key):
                  lines.append(f"{key}: <redacted>")
                  skip_block = True
              else:
                  lines.append(line)
          Path("config.redacted.yml").write_text("\n".join(lines) + "\n", encoding="utf-8")
          PY
      - if: ${{ always() }}
        uses: actions/upload-artifact@v4
      - if: ${{ always() }}
        run: tutor local down -v
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-bootstrap-workflow-contract.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-bootstrap-workflow-contract.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-bootstrap-workflow-contract.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixture
run_expect_pass "bootstrap workflow provenance contract passes"

TMP_WF="$tmpdir/.github/workflows/bootstrap-local-readiness.yml" python3 - <<'PY'
from pathlib import Path
import os

wf = Path(os.environ["TMP_WF"])
text = wf.read_text(encoding="utf-8")
text = text.replace('        run: ./scripts/ci/install-docker-compose.sh\n', '        run: docker compose version\n', 1)
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "missing Docker Compose CLI bootstrap is rejected"

write_pass_fixture
TMP_WF="$tmpdir/.github/workflows/bootstrap-local-readiness.yml" python3 - <<'PY'
from pathlib import Path
import os

wf = Path(os.environ["TMP_WF"])
text = wf.read_text(encoding="utf-8")
text = text.replace('            --set DOCKER_IMAGE_MONGODB=mirror.gcr.io/library/mongo:7.0.28 \\\n', '', 1)
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "missing public image mirror contract is rejected"

write_pass_fixture
TMP_WF="$tmpdir/.github/workflows/bootstrap-local-readiness.yml" python3 - <<'PY'
from pathlib import Path
import os

wf = Path(os.environ["TMP_WF"])
text = wf.read_text(encoding="utf-8")
text = text.replace('              if skip_block and line.strip() == "":\n                  continue\n', '', 1)
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "missing multi-line config redaction is rejected"

write_pass_fixture
TMP_WF="$tmpdir/.github/workflows/bootstrap-local-readiness.yml" python3 - <<'PY'
from pathlib import Path
import os

wf = Path(os.environ["TMP_WF"])
text = wf.read_text(encoding="utf-8")
text = text.replace('          compose "${COMPOSE_ARGS[@]}" config --images > expected-compose-images.txt\n', '', 1)
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "missing rendered compose image resolution is rejected"

write_pass_fixture
TMP_WF="$tmpdir/.github/workflows/bootstrap-local-readiness.yml" python3 - <<'PY'
from pathlib import Path
import os

wf = Path(os.environ["TMP_WF"])
text = wf.read_text(encoding="utf-8")
text = text.replace('            pull_with_retry "$image_ref"\n', '            timeout 20m docker pull "$image_ref"\n', 1)
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "missing bootstrap image pull retry is rejected"

write_pass_fixture
TMP_WF="$tmpdir/.github/workflows/bootstrap-local-readiness.yml" python3 - <<'PY'
from pathlib import Path
import os

wf = Path(os.environ["TMP_WF"])
text = wf.read_text(encoding="utf-8")
start = text.index('      - name: Pre-clean persistent Tutor workspace\n')
end = text.index('      - uses: actions/checkout@v4\n', start)
text = text[:start] + text[end:]
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "missing pre-checkout persistent Tutor workspace cleanup is rejected"

write_pass_fixture
TMP_WF="$tmpdir/.github/workflows/bootstrap-local-readiness.yml" python3 - <<'PY'
from pathlib import Path
import os

wf = Path(os.environ["TMP_WF"])
text = wf.read_text(encoding="utf-8")
text = text.replace(" && timeout 30s docker info >/dev/null 2>&1", "", 1)
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "missing Docker-root cleanup fallback is rejected"

write_pass_fixture
TMP_WF="$tmpdir/.github/workflows/bootstrap-local-readiness.yml" python3 - <<'PY'
from pathlib import Path
import os

wf = Path(os.environ["TMP_WF"])
text = wf.read_text(encoding="utf-8")
text = text.replace("                --network none \\\n", "", 1)
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "networked cleanup helper is rejected"

write_pass_fixture
TMP_WF="$tmpdir/.github/workflows/bootstrap-local-readiness.yml" python3 - <<'PY'
from pathlib import Path
import os

wf = Path(os.environ["TMP_WF"])
text = wf.read_text(encoding="utf-8")
text = text.replace(" && sudo -n true >/dev/null 2>&1", "", 1)
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "interactive sudo-only cleanup is rejected"

echo "OK"
