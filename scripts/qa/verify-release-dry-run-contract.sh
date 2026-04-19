#!/usr/bin/env bash
# @covers AC-020
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/release-openedx-gitops.sh"
VERIFY_OVERRIDES="$REPO_ROOT/scripts/qa/verify-gitops-image-overrides.sh"

source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"
require_command rg || exit 0

echo "Checking release dry-run contract..."

if [[ ! -x "$RELEASE_SCRIPT" ]]; then
  echo "❌ Missing executable release script: ${RELEASE_SCRIPT#"$REPO_ROOT"/}"
  exit 1
fi

if [[ ! -x "$VERIFY_OVERRIDES" ]]; then
  echo "❌ Missing executable image override verifier: ${VERIFY_OVERRIDES#"$REPO_ROOT"/}"
  exit 1
fi

# Wave 9 prep (bead mereka-lms-2xwo item 5): this contract test uses the
# app-repo DEPRECATED production overlay as a seed fixture for the infra
# overlay. Once Wave 9 deletion (bead mereka-lms-m0u5.9) retires the
# app-repo overlay, there is no source to copy from — and the contract
# itself is moot because the shadow-vs-infra dual-repo relationship no
# longer exists. Skip the test gracefully in that case.
APP_PROD_SOURCE="$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml"
if [[ ! -f "$APP_PROD_SOURCE" ]]; then
  echo "⏭  SKIP: app-repo production overlay absent (Wave 9 deletion complete)"
  echo "   The shadow-vs-bbi-infra contract is moot — bbi-infra is authoritative."
  echo "   Source:    ${APP_PROD_SOURCE#"$REPO_ROOT"/}"
  echo "   Authority: bbi-infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml"
  exit 0
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
# Staging overlay was removed from the app repo. Create a minimal fixture
# so that the release script's staging code path can still be exercised.
cat > "$TMP_INFRA/apps/mereka-lms/overlays/staging/kustomization.yaml" <<'YAML'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: mereka-lms
resources:
  - ../../base
images:
  - name: docker.io/overhangio/openedx
    newName: ghcr.io/biji-biji-initiative/mereka-lms/openedx
    newTag: fixture-tag
  - name: docker.io/overhangio/openedx-mfe
    newName: ghcr.io/biji-biji-initiative/mereka-lms/mfe
    newTag: fixture-tag
YAML

# Match the current GitOps prod overlay truth: prod pins the realized GHCR names
# directly. Do not reuse the deprecated app-repo production reference shape here.
python3 - "$TMP_INFRA/apps/mereka-lms/overlays/prod/kustomization.yaml" <<'PY'
import sys
from pathlib import Path

import yaml

path = Path(sys.argv[1])
doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
images = doc.setdefault("images", [])
normalized = []
for item in images:
    if not isinstance(item, dict):
        continue
    name = item.get("name")
    if name == "docker.io/overhangio/openedx":
        item = dict(item)
        item["name"] = "ghcr.io/biji-biji-initiative/mereka-lms/openedx"
        item.pop("newName", None)
        normalized.append(item)
        continue
    if name == "docker.io/overhangio/openedx-mfe":
        item = dict(item)
        item["name"] = "ghcr.io/biji-biji-initiative/mereka-lms/mfe"
        item.pop("newName", None)
        normalized.append(item)
        continue
    if name == "ghcr.io/biji-biji-initiative/mereka-lms/mfe":
        # The app repo carries an extra transformed-name parity entry for MFE; the
        # infra prod overlay does not.
        continue
    normalized.append(item)
images = normalized
doc["images"] = images
path.write_text(yaml.safe_dump(doc, sort_keys=False), encoding="utf-8")
PY

git -C "$TMP_INFRA" init -q

APP_PROD_FILE="$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml"
INFRA_PROD_FILE="$TMP_INFRA/apps/mereka-lms/overlays/prod/kustomization.yaml"
APP_PROD_BEFORE="$(sha256sum "$APP_PROD_FILE" | awk '{print $1}')"
INFRA_PROD_BEFORE="$(sha256sum "$INFRA_PROD_FILE" | awk '{print $1}')"

# B-012: Production --require-digests now requires --release-object-json.
# Generate a mock release object for the dry-run contract test.
MOCK_RELEASE_OBJECT="$TMP_INFRA/mock-release-object.json"
MOCK_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
MOCK_TS="$(date -u +%Y%m%dT%H%M%SZ)"
python3 - "$MOCK_RELEASE_OBJECT" "$MOCK_SHA" "$MOCK_TS" <<'PYEOF'
import json, sys
path, sha, ts = sys.argv[1], sys.argv[2], sys.argv[3]
json.dump({
    "schema_version": "release-object/v1",
    "release_id": f"ro-rb-qa00000-{ts}",
    "app_commit_sha": sha,
    "build": {
        "release_bundle_id": f"rb-qa00000-{ts}",
    },
    "build_origin_environment": "production",
    "promotion": {
        "status": "build-only",
        "gitops_repository": None,
        "gitops_commit_sha": None,
    },
    "promotion_target_environment": None,
    "images": {
        "openedx": {"digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111"},
        "mfe": {"digest": "sha256:2222222222222222222222222222222222222222222222222222222222222222"},
    },
}, open(path, "w"), indent=2)
PYEOF

"$RELEASE_SCRIPT" \
  --target-env production \
  --openedx-tag qa-contract-openedx \
  --mfe-tag qa-contract-mfe \
  --openedx-digest "sha256:1111111111111111111111111111111111111111111111111111111111111111" \
  --mfe-digest "sha256:2222222222222222222222222222222222222222222222222222222222222222" \
  --require-digests \
  --release-object-json "$MOCK_RELEASE_OBJECT" \
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

"$VERIFY_OVERRIDES" --check-infra --infra-file "$INFRA_PROD_FILE" >/tmp/release-verify-overrides.log

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

if ! rg -n -- '--require-digests requires digests for every targeted image\.|--require-digests requires both --openedx-digest and --mfe-digest\.|requires --release-object-json' /tmp/release-require-digest-negative.log >/dev/null; then
  echo "❌ Missing expected error message when --require-digests is used without digests or release-object"
  exit 1
fi

if "$RELEASE_SCRIPT" \
  --target-env production \
  --openedx-tag qa-contract-openedx \
  --mfe-tag qa-contract-mfe \
  --openedx-digest "sha256:1111111111111111111111111111111111111111111111111111111111111111" \
  --require-digests \
  --app-repo "$REPO_ROOT" \
  --infra-repo "$TMP_INFRA" \
  --skip-base-ref >/tmp/release-openedx-only-require-digest-negative.log 2>&1; then
  echo "❌ partial --require-digests did not fail when one digest was omitted"
  exit 1
fi

if ! rg -n -- '--require-digests requires digests for every targeted image\.|--require-digests requires both --openedx-digest and --mfe-digest\.|requires --release-object-json' /tmp/release-openedx-only-require-digest-negative.log >/dev/null; then
  echo "❌ Missing expected error message for partial --require-digests or missing release-object"
  exit 1
fi

echo "✅ Release dry-run contract passed."
