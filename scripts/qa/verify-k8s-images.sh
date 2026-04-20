#!/usr/bin/env bash
# @covers AC-025, AC-026
# @spec: k8s-deployment_spec.md
set -euo pipefail

# verify-k8s-images.sh - Verifies production image tags in K8s manifests
#
# Default (strict) mode: production images MUST use deterministic immutable tags
# (SHA-based or digest-pinned). Mutable tags like :mereka-brand or :latest are
# rejected in the production overlay unless RELAXED_MODE=1 is set.
#
# RELAXED_MODE=1: Allows mutable convenience tags in the production overlay.
#   Use only for temporary local testing. NEVER set in CI.
#   Document the reason when using: RELAXED_MODE=1 # reason: <explanation>
#
# Usage:
#   scripts/qa/verify-k8s-images.sh                      # Run all checks (strict)
#   scripts/qa/verify-k8s-images.sh --check no-latest    # Check for :latest tags
#   scripts/qa/verify-k8s-images.sh --check registry-path # Check registry paths
#   RELAXED_MODE=1 scripts/qa/verify-k8s-images.sh       # Relaxed (temporary only)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Allow env var overrides for testing; fall back to canonical paths
PROD_KUSTOMIZATION="${PROD_KUSTOMIZATION:-${REPO_ROOT}/deploy/k8s/overlays/production/kustomization.yaml}"
BASE_KUSTOMIZATION="${BASE_KUSTOMIZATION:-${REPO_ROOT}/deploy/k8s/base/kustomization.yaml}"
SCOPE_MODE="${VERIFY_K8S_IMAGES_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_K8S_IMAGES_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      .github/workflows/ci.yml|\
      deploy/k8s/*|\
      scripts/qa/verify-k8s-images.sh)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-k8s-images (scope skip: no k8s-image-policy-relevant changes)"
  exit 0
fi

# RELAXED_MODE=1 disables strict immutable-tag enforcement for the production overlay.
# This is a temporary escape hatch — never set in CI.
RELAXED_MODE="${RELAXED_MODE:-0}"
if [[ "$RELAXED_MODE" == "1" ]]; then
  echo "WARNING: RELAXED_MODE=1 is set — mutable tags will not be rejected."
  echo "         This mode is TEMPORARY and must NOT be used in CI."
  echo ""
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Check 1: No :latest tags in production
check_no_latest() {
  echo "Checking for :latest tags in production images..."

  if [[ ! -f "$PROD_KUSTOMIZATION" ]]; then
    # Wave 9 (ADR-025): production overlay relocated to bbi-infrastructure.
    # Boundary doc presence is the canonical statement of the move.
    if [[ -f "${REPO_ROOT}/docs/reference/architecture/DEPLOYMENT_CONTRACT.md" ]]; then
      pass "Production kustomization absent (Wave 9 shadow deletion — canonical boundary doc present); skipping :latest scan"
    else
      fail "File not found: $PROD_KUSTOMIZATION AND deployment-boundary doc missing — absence cannot be attributed to Wave 9"
    fi
    return
  fi

  # Extract image tags from production kustomization
  local in_images=false
  local latest_found=false
  local latest_images=()

  while IFS= read -r line; do
    # Detect images section
    if [[ "$line" =~ ^images: ]]; then
      in_images=true
      continue
    fi

    # Exit images section if we hit another top-level key
    if [[ "$in_images" == true && "$line" =~ ^[a-zA-Z] ]]; then
      in_images=false
    fi

    # Check for :latest tag
    if [[ "$in_images" == true && "$line" =~ newTag:[[:space:]]*(.+) ]]; then
      local tag="${BASH_REMATCH[1]}"
      if [[ "$tag" == "latest" ]]; then
        latest_found=true
        # Try to find the image name from previous lines
        local context
        context=$(grep -B 3 "newTag: $tag" "$PROD_KUSTOMIZATION" | grep "newName:" | tail -1 | sed -E 's/.*newName:\s+//' || echo "unknown")
        latest_images+=("$context")
      fi
    fi
  done < "$PROD_KUSTOMIZATION"

  if [[ "$latest_found" == true ]]; then
    fail "Found :latest tags in production images:"
    for img in "${latest_images[@]}"; do
      echo "    - $img"
    done
  else
    pass "No :latest tags found in production kustomization"
  fi
}

# Check 2: OpenEdX images use correct registry path and date-SHA format
check_registry_path() {
  echo "Checking OpenEdX image registry paths and tag format..."

  # Production overlay images must be immutable (digest-pinned or deterministic SHA tag).
  # Base kustomization may use mutable convenience tags (e.g. mereka-brand) — those are
  # expected and only checked for registry path correctness, not tag immutability.
  local prod_files=("$PROD_KUSTOMIZATION")
  local base_files=("$BASE_KUSTOMIZATION")
  # Registries to validate: GHCR only.
  local ghcr_registry="ghcr.io/biji-biji-initiative/mereka-lms/"
  # Strict immutable release tags: YYYYMMDD-<descriptor>-<sha> or <sha>-YYYYMMDDHHMMSS
  local tag_pattern='^[0-9]{8}-[a-z0-9-]+-[a-f0-9]{7,64}$'

  local all_valid=true
  local checked=0

  local report
  report="$(python3 - "$ghcr_registry" "$tag_pattern" "$RELAXED_MODE" "${prod_files[@]}" "---BASE---" "${base_files[@]}" <<'PY'
import re
import sys
from pathlib import Path

try:
    import yaml  # type: ignore
except Exception:
    print("ERROR\tPyYAML unavailable")
    sys.exit(2)

ghcr_registry = sys.argv[1]
tag_pattern = re.compile(sys.argv[2])
relaxed_mode = sys.argv[3] == "1"
args = sys.argv[4:]

# Split args into prod_files and base_files on the sentinel "---BASE---"
sentinel = "---BASE---"
try:
    sep_idx = args.index(sentinel)
    prod_files = args[:sep_idx]
    base_files = args[sep_idx + 1:]
except ValueError:
    prod_files = args
    base_files = []

semver_pattern = re.compile(r'^\d+\.\d+\.\d+(-[a-z0-9.]+)?$')
# Deterministic GHCR tags: hotfix/build descriptors with SHA suffix, or <sha>-<timestamp>.
# Bare mutable tags like "mereka-brand" are NOT deterministic and are rejected in strict mode.
ghcr_immutable_pattern = re.compile(r'^mereka-brand-[a-z0-9-]+-[a-f0-9]{6,}|[a-f0-9]{7,8}-\d{14}$')
# Mutable convenience tags only allowed in base or under RELAXED_MODE
ghcr_mutable_pattern = re.compile(r'^mereka-brand$')
# Sentinel tag that forces overlays to pin — valid only in base
sentinel_tag_pattern = re.compile(r'^pin-required$')
# Enterprise tags: nreum-clean-*, semver
enterprise_tag_pattern = re.compile(r'^(nreum-clean-\d{12}|\d+\.\d+\.\d+(-[a-z0-9.]+)?)$')

checked = 0

def check_file(path, strict_immutable):
    global checked
    p = Path(path)
    if not p.exists():
        print(f"WARN\tFile not found: {path} (skipping)")
        return
    payload = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    images = payload.get("images") or []
    for img in images:
        if not isinstance(img, dict):
            continue
        new_name = str(img.get("newName") or img.get("name") or "")
        tag = str(img.get("newTag") or "")
        digest = str(img.get("digest") or "")

        # Check GHCR images
        if new_name.startswith(ghcr_registry):
            checked += 1
            if digest:
                # Digest-pinned is always acceptable (strongest guarantee)
                print(f"PASS\t{new_name}:{tag}@{digest[:16]}... (digest pinned)")
            elif ghcr_immutable_pattern.match(tag) or tag_pattern.match(tag):
                print(f"PASS\t{new_name}:{tag} (deterministic immutable tag)")
            elif sentinel_tag_pattern.match(tag):
                if strict_immutable:
                    print(f"FAIL\t{new_name}:{tag} (sentinel tag in production overlay — overlay must pin to real image)")
                else:
                    print(f"PASS\t{new_name}:{tag} (sentinel tag — forces overlays to pin)")
            elif ghcr_mutable_pattern.match(tag):
                if strict_immutable and not relaxed_mode:
                    print(f"FAIL\t{new_name}:{tag} (mutable tag in production — use digest-pinned or SHA tag; set RELAXED_MODE=1 to bypass temporarily)")
                else:
                    print(f"PASS\t{new_name}:{tag} (mutable tag — acceptable in base/relaxed context)")
            else:
                print(f"FAIL\t{new_name}:{tag} (unrecognised tag format for GHCR image)")
        elif "docker.pkg.dev" in new_name:
            checked += 1
            print(f"FAIL\t{new_name}:{tag} (legacy GAR registry ref found; GHCR is required)")

for path in prod_files:
    check_file(path, strict_immutable=True)

for path in base_files:
    check_file(path, strict_immutable=False)

print(f"META\tchecked={checked}")
PY
)"

  while IFS=$'\t' read -r status message; do
    [[ -z "${status:-}" ]] && continue
    case "$status" in
      PASS)
        pass "$message"
        ;;
      FAIL)
        fail "$message"
        all_valid=false
        ;;
      WARN)
        warn "$message"
        ;;
      ERROR)
        fail "$message"
        all_valid=false
        ;;
      META)
        checked="${message#checked=}"
        ;;
    esac
  done <<< "$report"

  if [[ $checked -eq 0 ]]; then
    warn "No OpenEdX images found in kustomization files"
  elif [[ "$all_valid" == true ]]; then
    pass "All $checked OpenEdX images use correct registry and tag format"
  fi
}

# Main execution
main() {
  local check_type="all"

  # Parse arguments
  if [[ $# -gt 0 ]]; then
    if [[ "$1" == "--check" && $# -eq 2 ]]; then
      check_type="$2"
    else
      echo "Usage: $0 [--check no-latest|registry-path]"
      exit 1
    fi
  fi

  echo "=== K8s Image Tag Verification ==="
  echo "Production: $PROD_KUSTOMIZATION"
  echo "Base: $BASE_KUSTOMIZATION"
  echo

  # Run checks
  case "$check_type" in
    no-latest)
      check_no_latest
      ;;
    registry-path)
      check_registry_path
      ;;
    all)
      check_no_latest
      echo
      check_registry_path
      ;;
    *)
      echo "Unknown check type: $check_type"
      exit 1
      ;;
  esac

  # Summary
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS"
  echo -e "${RED}FAIL:${NC} $FAIL"

  if [[ $FAIL -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"
