#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCAL_OVERLAY="${LOCAL_OVERLAY:-$REPO_ROOT/deploy/k8s/overlays/local/kustomization.yaml}"
PROD_OVERLAY="${PROD_OVERLAY:-$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml}"

echo "Checking dev(local) ↔ prod image tag parity..."

python3 - "$LOCAL_OVERLAY" "$PROD_OVERLAY" <<'PY'
import re
import sys
from pathlib import Path

local_path = Path(sys.argv[1])
prod_path = Path(sys.argv[2])

TARGET_OPENEDX = "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx"
TARGET_MFE = "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe"
SOURCE_OPENEDX = "docker.io/overhangio/openedx"
SOURCE_MFE = "docker.io/overhangio/openedx-mfe"


def parse_images(path: Path):
    if not path.exists():
        raise SystemExit(f"missing kustomization: {path}")
    images = []
    current = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        m_name = re.match(r"^\s*-\s*name:\s*(\S+)\s*$", line)
        if m_name:
            if current:
                images.append(current)
            current = {"name": m_name.group(1), "newName": None, "newTag": None}
            continue
        if current is None:
            continue
        m_new_name = re.match(r"^\s*newName:\s*(\S+)\s*$", line)
        if m_new_name:
            current["newName"] = m_new_name.group(1)
            continue
        m_new_tag = re.match(r"^\s*newTag:\s*(\S+)\s*$", line)
        if m_new_tag:
            current["newTag"] = m_new_tag.group(1)
            continue
    if current:
        images.append(current)
    return images


def first_match(images, *, name=None, new_name=None):
    for item in images:
        if name is not None and item.get("name") != name:
            continue
        if new_name is not None and item.get("newName") != new_name:
            continue
        return item
    return None


local_images = parse_images(local_path)
prod_images = parse_images(prod_path)
errors = []

local_openedx = first_match(local_images, new_name=TARGET_OPENEDX)
prod_openedx = first_match(prod_images, name=SOURCE_OPENEDX)
if not local_openedx:
    errors.append(f"{local_path}: missing openedx mapping to {TARGET_OPENEDX}")
if not prod_openedx:
    errors.append(f"{prod_path}: missing openedx source mapping {SOURCE_OPENEDX}")

local_mfe = first_match(local_images, name=SOURCE_MFE)
prod_mfe = first_match(prod_images, name=SOURCE_MFE)
if not local_mfe:
    errors.append(f"{local_path}: missing openedx-mfe source mapping {SOURCE_MFE}")
if not prod_mfe:
    errors.append(f"{prod_path}: missing openedx-mfe source mapping {SOURCE_MFE}")

if errors:
    for e in errors:
        print(f"✗ {e}")
    raise SystemExit(1)

if local_openedx.get("newTag") != prod_openedx.get("newTag"):
    errors.append(
        f"openedx tag drift: local '{local_openedx.get('newTag')}' != prod '{prod_openedx.get('newTag')}'"
    )

if local_mfe.get("newTag") != prod_mfe.get("newTag"):
    errors.append(
        f"openedx-mfe tag drift: local '{local_mfe.get('newTag')}' != prod '{prod_mfe.get('newTag')}'"
    )

if errors:
    for e in errors:
        print(f"✗ {e}")
    raise SystemExit(1)

print("✓ Dev/prod image tag parity passed")
print(f"  openedx tag: {prod_openedx.get('newTag')}")
print(f"  mfe tag:     {prod_mfe.get('newTag')}")
PY
