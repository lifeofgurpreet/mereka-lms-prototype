#!/usr/bin/env bash
# @covers AC-020
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/release-openedx-gitops.sh"

echo "Checking release dry-run contract..."

if [[ ! -x "$RELEASE_SCRIPT" ]]; then
  echo "❌ Missing executable release script: ${RELEASE_SCRIPT#"$REPO_ROOT"/}"
  exit 1
fi

TMP_INFRA="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_INFRA"
}
trap cleanup EXIT

mkdir -p "$TMP_INFRA/apps/mereka-lms/base"
mkdir -p "$TMP_INFRA/apps/mereka-lms/overlays/prod"
mkdir -p "$TMP_INFRA/apps/mereka-lms/overlays/staging"

cat > "$TMP_INFRA/apps/mereka-lms/base/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - https://github.com/Biji-Biji-Initiative/mereka-lms.git//deploy/k8s/base?ref=deadbeef
YAML

cp "$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml" \
  "$TMP_INFRA/apps/mereka-lms/overlays/prod/kustomization.yaml"
cp "$REPO_ROOT/deploy/k8s/overlays/staging/kustomization.yaml" \
  "$TMP_INFRA/apps/mereka-lms/overlays/staging/kustomization.yaml"

# Fixture guard: release-openedx-gitops.sh expects infra overlay to include the
# already-transformed openedx image name entry as well.
python3 - "$TMP_INFRA/apps/mereka-lms/overlays/prod/kustomization.yaml" <<'PY'
import sys
from pathlib import Path

import yaml

path = Path(sys.argv[1])
doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
images = doc.setdefault("images", [])
required_name = "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx"

if not any((item or {}).get("name") == required_name for item in images):
    openedx_tag = next(
        ((item or {}).get("newTag") for item in images if (item or {}).get("name") == "docker.io/overhangio/openedx"),
        "fixture-openedx-tag",
    )
    images.append(
        {
            "name": required_name,
            "newName": required_name,
            "newTag": openedx_tag,
        }
    )
    path.write_text(yaml.safe_dump(doc, sort_keys=False), encoding="utf-8")
PY

git -C "$TMP_INFRA" init -q

APP_PROD_FILE="$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml"
INFRA_PROD_FILE="$TMP_INFRA/apps/mereka-lms/overlays/prod/kustomization.yaml"
APP_PROD_BEFORE="$(sha256sum "$APP_PROD_FILE" | awk '{print $1}')"
INFRA_PROD_BEFORE="$(sha256sum "$INFRA_PROD_FILE" | awk '{print $1}')"

"$RELEASE_SCRIPT" \
  --target-env production \
  --openedx-tag qa-contract-openedx \
  --mfe-tag qa-contract-mfe \
  --openedx-digest "sha256:1111111111111111111111111111111111111111111111111111111111111111" \
  --mfe-digest "sha256:2222222222222222222222222222222222222222222222222222222222222222" \
  --require-digests \
  --app-repo "$REPO_ROOT" \
  --infra-repo "$TMP_INFRA" \
  --skip-base-ref >/tmp/release-dry-run-contract.log

APP_PROD_AFTER="$(sha256sum "$APP_PROD_FILE" | awk '{print $1}')"
INFRA_PROD_AFTER="$(sha256sum "$INFRA_PROD_FILE" | awk '{print $1}')"

if [[ "$APP_PROD_BEFORE" != "$APP_PROD_AFTER" ]]; then
  echo "❌ Dry-run modified app production overlay unexpectedly"
  exit 1
fi

if [[ "$INFRA_PROD_BEFORE" != "$INFRA_PROD_AFTER" ]]; then
  echo "❌ Dry-run modified infra production overlay unexpectedly"
  exit 1
fi

if "$RELEASE_SCRIPT" \
  --target-env production \
  --openedx-tag qa-contract-openedx \
  --mfe-tag qa-contract-mfe \
  --require-digests \
  --app-repo "$REPO_ROOT" \
  --infra-repo "$TMP_INFRA" \
  --skip-base-ref >/tmp/release-require-digest-negative.log 2>&1; then
  echo "❌ --require-digests did not fail when digests were omitted"
  exit 1
fi

if ! rg -n -- '--require-digests requires both --openedx-digest and --mfe-digest' /tmp/release-require-digest-negative.log >/dev/null; then
  echo "❌ Missing expected error message when --require-digests is used without digests"
  exit 1
fi

echo "✅ Release dry-run contract passed."
