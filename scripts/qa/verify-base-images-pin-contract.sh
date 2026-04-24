#!/usr/bin/env bash
# @covers AC-IMG-001, AC-IMG-002, AC-IMG-003
# @spec: k8s-deployment_spec.md
# @runtime-dependencies: python3 (stdlib yaml module via pyyaml)
set -euo pipefail

# verify-base-images-pin-contract.sh
#
# Guards against the rq9k regression: a container image reference in
# deploy/k8s/base/** that is neither using the pin-required sentinel nor
# listed in the third-party allowlist, allowing an unpinned image to reach
# a prod rollout undetected until Kyverno denies it at admission time.
#
# Evaluation order per unique image reference:
#
#   1. "@sha256:" present → PASS (inline digest pin, always safe)
#
#   2. Tag is "pin-required":
#      (a) image name (without tag) is declared as a newName: in
#          deploy/k8s/base/kustomization.yaml images: block → PASS
#          (kustomize built-image rewrite declared)
#      (b) image name begins with "ghcr.io/biji-biji-initiative/" → PASS
#          (first-party built image; overlay supplies the real tag)
#      (c) else → FAIL (undeclared pin-required sentinel)
#
#   3. Tag is absent (untagged ref, e.g. docker.io/overhangio/openedx):
#      Must appear as a name: in the kustomization images: block — kustomize
#      will rewrite it to the newName:pin-required form at render time.
#      If not declared → FAIL (would ship tagless and unpinned to prod).
#
#   4. Tagged ref (has a real tag, not pin-required, no digest):
#      (a) image name (without tag) is declared as a name: in the kustomization
#          images: block → PASS (kustomize rewrites regardless of tag value)
#      (b) normalized image name is in the third-party allowlist → PASS
#          (allowlist entry carries the prod-overlay digest pin contract)
#      (c) else → FAIL
#
# Normalization (B3+B4):
#   - Strip tag using last-colon: name = ${ref%:*}  (handles registry:port/img:tag)
#   - Bare names (no slash) normalized to docker.io/library/<name> before allowlist
#     lookup; allowlist must use that canonical form.
#
# Usage:
#   ./scripts/qa/verify-base-images-pin-contract.sh           # human output
#   ./scripts/qa/verify-base-images-pin-contract.sh --json    # machine output
#   ./scripts/qa/verify-base-images-pin-contract.sh --help
#
# Exit codes:
#   0  all images satisfy the pin contract
#   1  one or more images violate the contract
#
# See also:
#   scripts/qa/fixtures/base-images-third-party-allowlist.txt
#   docs/reference/architecture/DEPLOYMENT_CONTRACT.md
#   bbi-infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml
#   bead: mereka-lms-rq9k

# ── setup ─────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_DIR="${REPO_ROOT}/deploy/k8s/base"
BASE_KUSTOMIZATION="${BASE_DIR}/kustomization.yaml"
ALLOWLIST_FILE="${REPO_ROOT}/scripts/qa/fixtures/base-images-third-party-allowlist.txt"

JSON_MODE=0

usage() {
  grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \?//'
  exit 0
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
fi
if [[ "${1:-}" == "--json" ]]; then
  JSON_MODE=1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
if [[ "$JSON_MODE" == "1" ]]; then
  RED='' GREEN='' NC=''
fi

PASS_COUNT=0
FAIL_COUNT=0
declare -a JSON_RESULTS=()

_pass() {
  local image="$1" reason="$2"
  PASS_COUNT=$((PASS_COUNT + 1))
  if [[ "$JSON_MODE" == "0" ]]; then
    echo -e "${GREEN}✓ PASS${NC}: ${image}  (${reason})"
  fi
  JSON_RESULTS+=("{\"image\":$(printf '%s' "\"$image\""),\"status\":\"PASS\",\"reason\":$(printf '%s' "\"$reason\"")}")
}

_fail() {
  local image="$1" reason="$2"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  if [[ "$JSON_MODE" == "0" ]]; then
    echo -e "${RED}✗ FAIL${NC}: ${image}  (${reason})"
  fi
  JSON_RESULTS+=("{\"image\":$(printf '%s' "\"$image\""),\"status\":\"FAIL\",\"reason\":$(printf '%s' "\"$reason\"")}")
}

# ── load allowlist ────────────────────────────────────────────────────────────

if [[ ! -f "$ALLOWLIST_FILE" ]]; then
  echo -e "${RED}ERROR${NC}: allowlist not found: $ALLOWLIST_FILE" >&2
  exit 1
fi

declare -A ALLOWLIST
while IFS= read -r line; do
  line="${line%%#*}"
  line="${line//[[:space:]]/}"
  [[ -z "$line" ]] && continue
  ALLOWLIST["$line"]=1
done < "$ALLOWLIST_FILE"

# ── validate prereqs ──────────────────────────────────────────────────────────

if [[ ! -f "$BASE_KUSTOMIZATION" ]]; then
  echo -e "${RED}ERROR${NC}: base kustomization not found: $BASE_KUSTOMIZATION" >&2
  exit 1
fi

if ! python3 -c "import yaml" 2>/dev/null; then
  echo -e "${RED}ERROR${NC}: python3 pyyaml not available (pip install pyyaml)" >&2
  exit 1
fi

# ── parse base/kustomization.yaml images: block ───────────────────────────────
#
# KUST_NAMES    — `name:` values: upstream image names kustomize intercepts.
#                 Any manifest ref whose base name matches is rewritten at
#                 render time — it never ships to the cluster as-is.
# KUST_NEWNAMES — `newName:` values: the post-rewrite target names. Manifests
#                 that directly carry these names with :pin-required are the
#                 canonical built-image pattern (e.g. ghcr.io/.../openedx).

_kust_json="$(python3 - "${BASE_KUSTOMIZATION}" <<'PYEOF'
import yaml, json, sys
with open(sys.argv[1]) as f:
    doc = yaml.safe_load(f)
images = doc.get('images', [])
result = {'names': [], 'newnames': []}
for img in images:
    if 'name' in img:
        result['names'].append(img['name'])
    if 'newName' in img:
        result['newnames'].append(img['newName'])
print(json.dumps(result))
PYEOF
)"

declare -A KUST_NAMES KUST_NEWNAMES
while IFS= read -r n; do
  [[ -z "$n" ]] && continue
  KUST_NAMES["$n"]=1
done < <(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); [print(x) for x in d['names']]" <<<"$_kust_json")
while IFS= read -r n; do
  [[ -z "$n" ]] && continue
  KUST_NEWNAMES["$n"]=1
done < <(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); [print(x) for x in d['newnames']]" <<<"$_kust_json")

# ── normalize_name: strip tag, canonicalize bare names (B3+B4) ───────────────
#
# B3: use ${ref%:*} (last colon) so registry:port/img:tag → registry:port/img
# B4: no-slash names normalized to docker.io/library/<name>

normalize_name() {
  local ref="$1"
  local name
  # strip tag at last colon (B3); if no colon, ref is already tagless
  if [[ "$ref" == *":"* ]]; then
    name="${ref%:*}"
  else
    name="$ref"
  fi
  # normalize bare name: no slash → docker.io/library/<name> (B4)
  if [[ "$name" != *"/"* ]]; then
    name="docker.io/library/${name}"
  fi
  printf '%s' "$name"
}

# ── enumerate image references in base/** ────────────────────────────────────

declare -A SEEN_IMAGES

while IFS= read -r yaml_file; do
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"  # ltrim
    if [[ "$line" =~ ^image:[[:space:]]*(.*) ]]; then
      ref="${BASH_REMATCH[1]}"
      ref="${ref%%#*}"
      ref="${ref//[[:space:]]/}"
      [[ -z "$ref" ]] && continue
      SEEN_IMAGES["$ref"]=1
    fi
  done < <(grep -E '^\s+image:' "$yaml_file" 2>/dev/null || true)
done < <(find "$BASE_DIR" -name "*.yaml" -o -name "*.yml" | grep -v "kustomization.yaml")

# ── evaluate each image ref ──────────────────────────────────────────────────

if [[ "$JSON_MODE" == "0" ]]; then
  echo "=== verify-base-images-pin-contract ==="
  echo "Checking ${#SEEN_IMAGES[@]} unique image reference(s) in deploy/k8s/base/**"
  echo
fi

for ref in $(printf '%s\n' "${!SEEN_IMAGES[@]}" | sort); do

  # 1. Inline digest — always OK
  if [[ "$ref" == *"@sha256:"* ]]; then
    _pass "$ref" "inline digest pin"
    continue
  fi

  # Extract tag: text after the LAST colon (B3 fix)
  tag=""
  if [[ "$ref" == *":"* ]]; then
    tag="${ref##*:}"
  fi

  # 2. pin-required sentinel
  if [[ "$tag" == "pin-required" ]]; then
    name_no_tag="${ref%:*}"
    # 2a. declared as newName in kustomization images: block
    if [[ -n "${KUST_NEWNAMES[$name_no_tag]:-}" ]]; then
      _pass "$ref" "pin-required sentinel (declared newName in base/kustomization.yaml)"
      continue
    fi
    # 2b. first-party built image (ghcr.io/biji-biji-initiative/ namespace)
    if [[ "$name_no_tag" == "ghcr.io/biji-biji-initiative/"* ]]; then
      _pass "$ref" "pin-required sentinel (first-party ghcr.io/biji-biji-initiative/ image)"
      continue
    fi
    # 2c. undeclared — FAIL
    _fail "$ref" "tag is pin-required but '${name_no_tag}' is not declared in base/kustomization.yaml images: block and is not a first-party ghcr.io/biji-biji-initiative/ image"
    continue
  fi

  # 3. Untagged ref — must be declared as name: in kustomization images: block
  if [[ -z "$tag" ]]; then
    if [[ -n "${KUST_NAMES[$ref]:-}" ]]; then
      _pass "$ref" "untagged ref rewritten by base/kustomization.yaml images: block (name: ${ref})"
      continue
    fi
    _fail "$ref" "untagged image ref '${ref}' is not declared in base/kustomization.yaml images: block; it would ship tagless and unpinned to prod"
    continue
  fi

  # 4. Tagged ref (real tag, not pin-required, no digest)
  name_no_tag="${ref%:*}"

  # 4a. kustomize intercepts it via name: match (rewrites regardless of tag)
  if [[ -n "${KUST_NAMES[$name_no_tag]:-}" ]]; then
    _pass "$ref" "rewritten by base/kustomization.yaml images: block (name: ${name_no_tag})"
    continue
  fi

  # 4b. third-party allowlist (normalize bare name first — B4)
  normalized="$(normalize_name "$ref")"
  if [[ -n "${ALLOWLIST[$normalized]:-}" ]]; then
    _pass "$ref" "third-party allowlist (${normalized})"
    continue
  fi

  # Nothing matched — FAIL
  _fail "$ref" "not pin-required, not digest-pinned, not kustomize-rewritten, not in third-party allowlist; add '${normalized}' to scripts/qa/fixtures/base-images-third-party-allowlist.txt or use pin-required sentinel"
done

# ── report ───────────────────────────────────────────────────────────────────

if [[ "$JSON_MODE" == "1" ]]; then
  printf '{\n  "pass": %d,\n  "fail": %d,\n  "results": [\n' "$PASS_COUNT" "$FAIL_COUNT"
  for i in "${!JSON_RESULTS[@]}"; do
    if [[ $i -lt $(( ${#JSON_RESULTS[@]} - 1 )) ]]; then
      printf '    %s,\n' "${JSON_RESULTS[$i]}"
    else
      printf '    %s\n' "${JSON_RESULTS[$i]}"
    fi
  done
  printf '  ]\n}\n'
fi

if [[ "$JSON_MODE" == "0" ]]; then
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} ${PASS_COUNT}"
  echo -e "${RED}FAIL:${NC} ${FAIL_COUNT}"
  echo
fi

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  if [[ "$JSON_MODE" == "0" ]]; then
    echo -e "${RED}RESULT: FAIL${NC} — ${FAIL_COUNT} image(s) violate the pin contract."
    echo "  Fix: add to scripts/qa/fixtures/base-images-third-party-allowlist.txt"
    echo "       (with a corresponding digest pin in bbi-infrastructure prod overlay)"
    echo "       OR change the image tag to pin-required."
    echo "       OR declare the image in deploy/k8s/base/kustomization.yaml images: block."
  fi
  exit 1
fi

if [[ "$JSON_MODE" == "0" ]]; then
  echo -e "${GREEN}RESULT: PASS${NC} — all ${PASS_COUNT} image reference(s) satisfy the pin contract."
fi
exit 0
