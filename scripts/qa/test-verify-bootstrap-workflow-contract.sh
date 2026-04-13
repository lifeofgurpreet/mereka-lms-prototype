#!/usr/bin/env bash
# Seeded-defect self-test for verify-bootstrap-workflow-contract.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-bootstrap-workflow-contract.sh"

tmpdir="$(mktemp -d -t verify-bootstrap-workflow-contract.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows" "$tmpdir/scripts/infra"

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

write_pass_fixture() {
  cat >"$tmpdir/.github/workflows/bootstrap-local-readiness.yml" <<'EOF'
name: Bootstrap Local Readiness
on:
  workflow_dispatch:
permissions:
  contents: read
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
      - uses: actions/checkout@v4
      - run: ./scripts/infra/tutor-config-save.sh
      - run: |
          COMPOSE_ARGS=(
            -f "$TUTOR_ROOT/env/local/docker-compose.yml"
            -f "$TUTOR_ROOT/env/local/docker-compose.prod.yml"
          )
          docker compose "${COMPOSE_ARGS[@]}" config --images > expected-compose-images.txt
      - run: |
          while IFS= read -r image_ref; do
            timeout 20m docker pull "$image_ref"
            echo "$image_ref|sha256:abc" >> pulled-image-ids.txt
          done < expected-compose-images.txt
      - run: tutor local launch -I --skip-build
      - run: |
          docker inspect tutor_local-lms-1 --format '{{.Name}}|{{.Config.Image}}|{{.Image}}' > actual-running-images.txt
          echo PASS > bootstrap-image-provenance-check.txt
      - run: ./scripts/infra/verify-local-bootstrap-readiness.sh
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
text = text.replace('          docker compose "${COMPOSE_ARGS[@]}" config --images > expected-compose-images.txt\n', '', 1)
wf.write_text(text, encoding="utf-8")
PY
run_expect_fail "missing rendered compose image resolution is rejected"

echo "OK"
