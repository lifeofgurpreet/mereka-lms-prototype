#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

BUNDLE_PATH="${1:-${REPO_ROOT}/var/ci/release-bundle.json}"
if [[ $# -gt 0 ]]; then
  shift
fi

DEFAULT_PLATFORM_ROOTS=(
  "$REPO_ROOT/../platform-control-plane"
  "$REPO_ROOT/../../platform-control-plane"
  "$HOME/projects/k8s/platform-control-plane"
  "$HOME/projects/platform-control-plane"
)

PLATFORM_ROOT="${PLATFORM_CONTROL_PLANE_ROOT:-${WAVE10_PCP_ROOT:-}}"
platform_root_explicit=0
[[ -n "${PLATFORM_CONTROL_PLANE_ROOT:-}" || -n "${WAVE10_PCP_ROOT:-}" ]] && platform_root_explicit=1

if [[ -z "$PLATFORM_ROOT" ]]; then
  for candidate in "${DEFAULT_PLATFORM_ROOTS[@]}"; do
    if [[ -f "$candidate/contracts/release-contracts.yaml" ]]; then
      PLATFORM_ROOT="$candidate"
      break
    fi
  done
fi

if [[ ! -f "$BUNDLE_PATH" ]]; then
  echo "FAIL: release bundle not found at $BUNDLE_PATH" >&2
  exit 1
fi

if [[ ! -f "$PLATFORM_ROOT/contracts/release-contracts.yaml" ]]; then
  if [[ "$platform_root_explicit" -eq 1 ]]; then
    echo "FAIL: platform-control-plane root missing contracts/release-contracts.yaml: $PLATFORM_ROOT" >&2
    exit 1
  fi
  echo "SKIP: platform-control-plane repo not available at $PLATFORM_ROOT"
  exit 0
fi

tmpfile="$(mktemp -t release-bundle-pcp-projection.XXXXXX.json)"
trap 'rm -f "$tmpfile"' EXIT

python3 scripts/release/render_control_plane_release_bundle_projection.py \
  --release-bundle-json "$BUNDLE_PATH" \
  --platform-control-plane-root "$PLATFORM_ROOT" \
  --output "$tmpfile" >/dev/null

python3 - "$BUNDLE_PATH" "$tmpfile" <<'PY'
import json
import sys
from pathlib import Path

bundle = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
projection = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

errors: list[str] = []

if projection.get("schema_version") != "control-plane-release-bundle-projection/v1":
    errors.append("projection schema_version must equal control-plane-release-bundle-projection/v1")
if projection.get("projection_status") != "partial":
    errors.append("projection_status must equal partial")

canonical = projection.get("canonical_projection") or {}
if canonical.get("bundle_id") != bundle.get("bundle_id"):
    errors.append("canonical_projection.bundle_id must match source bundle_id")
if canonical.get("lane") != bundle.get("service_id"):
    errors.append("canonical_projection.lane must match source service_id")
if canonical.get("service_id") != bundle.get("service_id"):
    errors.append("canonical_projection.service_id must match source service_id")
if canonical.get("source_revision") != f"git:{bundle.get('commit_sha')}":
    errors.append("canonical_projection.source_revision must wrap bundle commit_sha as git:<sha>")
if not canonical.get("runtime_profile"):
    errors.append("canonical_projection.runtime_profile must be populated from PCP release contracts")
if not canonical.get("source_provenance_class"):
    errors.append("canonical_projection.source_provenance_class must be populated from PCP release contracts")

artifacts = canonical.get("artifacts")
if not isinstance(artifacts, list) or len(artifacts) != 2:
    errors.append("canonical_projection.artifacts must contain openedx and mfe entries")
else:
    seen = {item.get("name"): item for item in artifacts if isinstance(item, dict)}
    for name in ("openedx", "mfe"):
        item = seen.get(name)
        image = ((bundle.get("images") or {}).get(name) or {})
        if not item:
            errors.append(f"canonical_projection.artifacts missing {name}")
            continue
        if item.get("image") != image.get("name"):
            errors.append(f"{name} artifact image mismatch")
        if item.get("digest") != image.get("digest"):
            errors.append(f"{name} artifact digest mismatch")

resolution = projection.get("required_field_resolution") or {}
unresolved = resolution.get("unresolved") or []
unresolved_fields = sorted(
    item.get("field") for item in unresolved if isinstance(item, dict) and item.get("field")
)
if unresolved_fields != ["config_digest", "evidence_pack_ref", "rollback_target"]:
    errors.append(
        "unresolved required PCP fields must be exactly "
        "['config_digest', 'evidence_pack_ref', 'rollback_target']"
    )

resolved = resolution.get("resolved") or []
for field in (
    "bundle_id",
    "lane",
    "service_id",
    "runtime_profile",
    "source_provenance_class",
    "created_at",
    "source_revision",
    "artifacts",
):
    if field not in resolved:
        errors.append(f"required PCP field should be resolved in projection: {field}")

notes = projection.get("notes") or []
if not any("delivery_lane is intentionally omitted" in str(note) for note in notes):
    errors.append("projection notes must explain why delivery_lane is omitted")

if errors:
    print("FAIL: control-plane release bundle projection validation errors:", file=sys.stderr)
    for error in errors:
        print(f" - {error}", file=sys.stderr)
    sys.exit(1)

print("PASS: control-plane release bundle projection is truthful and bounded")
print(f"Bundle ID: {canonical.get('bundle_id')}")
PY
