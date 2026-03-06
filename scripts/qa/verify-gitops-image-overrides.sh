#!/usr/bin/env bash
# @covers AC-014
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

APP_BASE="${APP_BASE:-$REPO_ROOT/deploy/k8s/base/kustomization.yaml}"
APP_PROD_OVERLAY="${APP_PROD_OVERLAY:-$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml}"
APP_STAGING_OVERLAY="${APP_STAGING_OVERLAY:-$REPO_ROOT/deploy/k8s/overlays/staging/kustomization.yaml}"
APP_MFE_CADDYFILE="${APP_MFE_CADDYFILE:-$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile}"
INFRA_PROD_OVERLAY="${INFRA_PROD_OVERLAY:-}"
CHECK_INFRA="${CHECK_INFRA:-auto}" # auto|1|0
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"

if [[ -z "$INFRA_PROD_OVERLAY" ]]; then
  for candidate in \
    "${WORKSPACE_ROOT}/infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml" \
    "${WORKSPACE_ROOT}/bbi-infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml"; do
    if [[ -f "$candidate" ]]; then
      INFRA_PROD_OVERLAY="$candidate"
      break
    fi
  done
fi

if [[ -z "$INFRA_PROD_OVERLAY" ]]; then
  INFRA_PROD_OVERLAY="${WORKSPACE_ROOT}/infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml"
fi

usage() {
  cat <<'EOF'
Usage: scripts/qa/verify-gitops-image-overrides.sh [--check-infra|--skip-infra] [--infra-file PATH]

Purpose:
  Enforce image override contract to avoid silent tag drift after Kustomize image transforms.

Checks:
  1) Base kustomization pins canonical docker.io names to Artifact Registry.
  2) Production overlay uses canonical names.
  3) Production overlay includes transformed-name override parity for openedx-mfe.
  4) Staging overlay uses canonical docker.io names (no bare openedx/openedx-mfe names).
  5) Optional infra overlay parity check in active GitOps checkout (when available).
  6) Optional tag/digest parity check between this repo's production overlay and infra production overlay.
  7) Optional vendored MFE Caddyfile parity check in infra checkout (when vendored base exists).

Options:
  --check-infra        Require and validate infra overlay file.
  --skip-infra         Skip infra overlay validation.
  --infra-file PATH    Override infra overlay file path.
                       (default auto-detect: infrastructure -> bbi-infrastructure)
  -h, --help           Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-infra)
      CHECK_INFRA="1"
      shift
      ;;
    --skip-infra)
      CHECK_INFRA="0"
      shift
      ;;
    --infra-file)
      INFRA_PROD_OVERLAY="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

python3 - "$APP_BASE" "$APP_PROD_OVERLAY" "$APP_STAGING_OVERLAY" "$APP_MFE_CADDYFILE" "$INFRA_PROD_OVERLAY" "$CHECK_INFRA" <<'PY'
import re
import sys
from pathlib import Path
import hashlib

APP_BASE = Path(sys.argv[1])
APP_PROD = Path(sys.argv[2])
APP_STAGING = Path(sys.argv[3])
APP_MFE_CADDYFILE = Path(sys.argv[4])
INFRA_PROD = Path(sys.argv[5])
CHECK_INFRA = sys.argv[6]

TARGET_OPENEDX = "ghcr.io/biji-biji-initiative/mereka-lms/openedx"
TARGET_MFE = "ghcr.io/biji-biji-initiative/mereka-lms/mfe"
SOURCE_OPENEDX = "docker.io/overhangio/openedx"
SOURCE_MFE = "docker.io/overhangio/openedx-mfe"


def parse_images(path: Path):
    if not path.exists():
        return None
    images = []
    current = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        m_name = re.match(r"^\s*-\s*name:\s*(\S+)\s*$", line)
        if m_name:
            if current:
                images.append(current)
            current = {"name": m_name.group(1), "newName": None, "newTag": None, "digest": None}
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
        m_digest = re.match(r"^\s*digest:\s*(\S+)\s*$", line)
        if m_digest:
            current["digest"] = m_digest.group(1)
            continue
    if current:
        images.append(current)
    return images


def find_by_name(images, name):
    return [image for image in images if image["name"] == name]


def ensure_mapping(images, name, expected_new_name, context, errors):
    matches = find_by_name(images, name)
    if not matches:
        errors.append(f"{context}: missing image override for '{name}'")
        return None
    mapping = matches[0]
    if mapping["newName"] != expected_new_name:
        errors.append(
            f"{context}: '{name}' newName mismatch (got '{mapping['newName']}', expected '{expected_new_name}')"
        )
    return mapping


errors = []
notes = []

for required in (APP_BASE, APP_PROD, APP_STAGING, APP_MFE_CADDYFILE):
    if not required.exists():
        errors.append(f"missing required file: {required}")

if errors:
    for error in errors:
        print(f"✗ {error}")
    sys.exit(1)

base_images = parse_images(APP_BASE)
prod_images = parse_images(APP_PROD)
staging_images = parse_images(APP_STAGING)

ensure_mapping(base_images, SOURCE_OPENEDX, TARGET_OPENEDX, str(APP_BASE), errors)
ensure_mapping(base_images, SOURCE_MFE, TARGET_MFE, str(APP_BASE), errors)

prod_openedx = ensure_mapping(prod_images, SOURCE_OPENEDX, TARGET_OPENEDX, str(APP_PROD), errors)
prod_mfe_source = ensure_mapping(prod_images, SOURCE_MFE, TARGET_MFE, str(APP_PROD), errors)
prod_mfe_transformed = ensure_mapping(prod_images, TARGET_MFE, TARGET_MFE, str(APP_PROD), errors)

if prod_mfe_source and prod_mfe_transformed:
    if not prod_mfe_source["newTag"] or not prod_mfe_transformed["newTag"]:
        errors.append(f"{APP_PROD}: missing newTag for openedx-mfe dual-name overrides")
    elif prod_mfe_source["newTag"] != prod_mfe_transformed["newTag"]:
        errors.append(
            f"{APP_PROD}: openedx-mfe tag mismatch between canonical and transformed entries "
            f"('{prod_mfe_source['newTag']}' vs '{prod_mfe_transformed['newTag']}')"
        )
    if (prod_mfe_source["digest"] or prod_mfe_transformed["digest"]) and (
        prod_mfe_source["digest"] != prod_mfe_transformed["digest"]
    ):
        errors.append(
            f"{APP_PROD}: openedx-mfe digest mismatch between canonical and transformed entries "
            f"('{prod_mfe_source['digest']}' vs '{prod_mfe_transformed['digest']}')"
        )

for bare_name in ("openedx", "openedx-mfe"):
    if find_by_name(prod_images, bare_name):
        errors.append(f"{APP_PROD}: bare image name '{bare_name}' is not allowed; use canonical docker.io name")
    if find_by_name(staging_images, bare_name):
        errors.append(f"{APP_STAGING}: bare image name '{bare_name}' is not allowed; use canonical docker.io name")

ensure_mapping(staging_images, SOURCE_OPENEDX, TARGET_OPENEDX, str(APP_STAGING), errors)
ensure_mapping(staging_images, SOURCE_MFE, TARGET_MFE, str(APP_STAGING), errors)

check_infra = CHECK_INFRA
if check_infra == "auto":
    check_infra = "1" if INFRA_PROD.exists() else "0"

if check_infra == "1":
    if not INFRA_PROD.exists():
        errors.append(f"infra check requested but file missing: {INFRA_PROD}")
    else:
        infra_images = parse_images(INFRA_PROD)
        infra_openedx = ensure_mapping(infra_images, SOURCE_OPENEDX, TARGET_OPENEDX, str(INFRA_PROD), errors)
        infra_mfe_source = ensure_mapping(infra_images, SOURCE_MFE, TARGET_MFE, str(INFRA_PROD), errors)
        infra_mfe_transformed = ensure_mapping(infra_images, TARGET_MFE, TARGET_MFE, str(INFRA_PROD), errors)
        if infra_mfe_source and infra_mfe_transformed:
            if infra_mfe_source["newTag"] != infra_mfe_transformed["newTag"]:
                errors.append(
                    f"{INFRA_PROD}: openedx-mfe tag mismatch between canonical and transformed entries "
                    f"('{infra_mfe_source['newTag']}' vs '{infra_mfe_transformed['newTag']}')"
                )
            if (infra_mfe_source["digest"] or infra_mfe_transformed["digest"]) and (
                infra_mfe_source["digest"] != infra_mfe_transformed["digest"]
            ):
                errors.append(
                    f"{INFRA_PROD}: openedx-mfe digest mismatch between canonical and transformed entries "
                    f"('{infra_mfe_source['digest']}' vs '{infra_mfe_transformed['digest']}')"
                )
        if prod_openedx and infra_openedx and prod_openedx["newTag"] and infra_openedx["newTag"]:
            if prod_openedx["newTag"] != infra_openedx["newTag"]:
                errors.append(
                    f"prod openedx tag drift: app overlay '{prod_openedx['newTag']}' "
                    f"!= infra overlay '{infra_openedx['newTag']}'"
                )
        if prod_openedx and infra_openedx and (prod_openedx["digest"] or infra_openedx["digest"]):
            if prod_openedx["digest"] != infra_openedx["digest"]:
                errors.append(
                    f"prod openedx digest drift: app overlay '{prod_openedx['digest']}' "
                    f"!= infra overlay '{infra_openedx['digest']}'"
                )
        if prod_mfe_source and infra_mfe_source and prod_mfe_source["newTag"] and infra_mfe_source["newTag"]:
            if prod_mfe_source["newTag"] != infra_mfe_source["newTag"]:
                errors.append(
                    f"prod openedx-mfe tag drift: app overlay '{prod_mfe_source['newTag']}' "
                    f"!= infra overlay '{infra_mfe_source['newTag']}'"
                )
        if prod_mfe_source and infra_mfe_source and (prod_mfe_source["digest"] or infra_mfe_source["digest"]):
            if prod_mfe_source["digest"] != infra_mfe_source["digest"]:
                errors.append(
                    f"prod openedx-mfe digest drift: app overlay '{prod_mfe_source['digest']}' "
                    f"!= infra overlay '{infra_mfe_source['digest']}'"
                )

        # If infra uses vendored base resources, enforce MFE Caddyfile parity so
        # runtime route contract doesn't drift from app repo source.
        infra_base_dir = INFRA_PROD.parents[2] / "base"
        infra_vendored_caddy = infra_base_dir / "deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
        if infra_vendored_caddy.exists():
            app_hash = hashlib.sha256(APP_MFE_CADDYFILE.read_bytes()).hexdigest()
            infra_hash = hashlib.sha256(infra_vendored_caddy.read_bytes()).hexdigest()
            if app_hash != infra_hash:
                errors.append(
                    "vendored MFE Caddyfile drift: "
                    f"{infra_vendored_caddy} differs from {APP_MFE_CADDYFILE}; "
                    "sync infra vendored base before release"
                )
        else:
            notes.append(f"vendored MFE Caddyfile not found under infra base: {infra_vendored_caddy}")
else:
    notes.append("infra overlay check skipped")

if errors:
    for error in errors:
        print(f"✗ {error}")
    for note in notes:
        print(f"- {note}")
    sys.exit(1)

print("✓ GitOps image override contract checks passed")
print(f"  base: {APP_BASE}")
print(f"  prod overlay: {APP_PROD}")
print(f"  staging overlay: {APP_STAGING}")
if check_infra == "1":
    print(f"  infra overlay: {INFRA_PROD}")
else:
    print("  infra overlay: skipped")
PY
