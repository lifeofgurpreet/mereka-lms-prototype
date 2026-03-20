#!/usr/bin/env bash
# verify-script-registry-completeness.sh
# Enforces Charter non-negotiable #6:
#   "No new release-critical script without registry entry."
#
# Checks:
#   1. Every script in scripts/release/ is registered in script-registry.yaml
#   2. Every scripts/infra/canonical-*.sh and scripts/infra/release-*.sh is registered
#   3. Every release-blocking scripts/qa/* and scripts/ci/* script is in the
#      static execution authority (script-registry.yaml ci_static_inventory)
#   4. ci_runtime_inventory is inventory/manual truth only; it must not satisfy
#      release-blocking coverage
#   5. No script may appear in both the static and runtime authorities
#
# Usage:
#   bash scripts/qa/verify-script-registry-completeness.sh
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGISTRY="${REPO_ROOT}/scripts/governance/script-registry.yaml"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
TMPDIR="$(mktemp -d -t verify-script-registry-completeness.XXXXXX)"
trap 'rm -rf "${TMPDIR}"' EXIT

pass() { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

echo "=== Script Registry Completeness Check ==="
echo ""

if [[ ! -f "${REGISTRY}" ]]; then
  fail "script registry missing: ${REGISTRY}"
  echo ""
  echo "=== Summary ==="
  echo "  PASS: ${PASS}"
  echo "  FAIL: ${FAIL}"
  echo ""
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 is required to parse ${REGISTRY}"
  echo ""
  echo "=== Summary ==="
  echo "  PASS: ${PASS}"
  echo "  FAIL: ${FAIL}"
  echo ""
  exit 1
fi

if ! python3 - "${REGISTRY}" "${TMPDIR}" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML is required to parse script-registry.yaml") from exc

registry_path = Path(sys.argv[1])
tmpdir = Path(sys.argv[2])

payload = yaml.safe_load(registry_path.read_text(encoding="utf-8"))
if not isinstance(payload, dict):
    raise SystemExit("script-registry.yaml must load as a mapping")

scripts = payload.get("scripts")
if not isinstance(scripts, list):
    raise SystemExit("script-registry.yaml missing scripts list")

registered_paths: list[str] = []
blocking_verification: list[str] = []
for index, entry in enumerate(scripts, start=1):
    if not isinstance(entry, dict):
        raise SystemExit(f"scripts[{index}] must be a mapping")
    path = entry.get("path")
    if not isinstance(path, str) or not path.strip():
        raise SystemExit(f"scripts[{index}] missing path")
    registered_paths.append(path)
    if (
        entry.get("criticality") == "release-blocking"
        and (path.startswith("scripts/qa/") or path.startswith("scripts/ci/"))
    ):
        blocking_verification.append(path)

inventory = payload.get("ci_static_inventory")
if not isinstance(inventory, dict):
    raise SystemExit("script-registry.yaml missing ci_static_inventory mapping")
entries = inventory.get("entries")
if not isinstance(entries, list):
    raise SystemExit("ci_static_inventory.entries must be a list")

ci_static_paths: list[str] = []
for index, entry in enumerate(entries, start=1):
    if not isinstance(entry, dict):
        raise SystemExit(f"ci_static_inventory.entries[{index}] must be a mapping")
    script = entry.get("script")
    if not isinstance(script, str) or not script.strip():
        raise SystemExit(f"ci_static_inventory.entries[{index}] missing script")
    ci_static_paths.append(script)

runtime_inventory = payload.get("ci_runtime_inventory")
if not isinstance(runtime_inventory, dict):
    raise SystemExit("script-registry.yaml missing ci_runtime_inventory mapping")
runtime_entries = runtime_inventory.get("entries")
if not isinstance(runtime_entries, list):
    raise SystemExit("ci_runtime_inventory.entries must be a list")

ci_runtime_paths: list[str] = []
for index, entry in enumerate(runtime_entries, start=1):
    if not isinstance(entry, dict):
        raise SystemExit(f"ci_runtime_inventory.entries[{index}] must be a mapping")
    script = entry.get("script")
    if not isinstance(script, str) or not script.strip():
        raise SystemExit(f"ci_runtime_inventory.entries[{index}] missing script")
    ci_runtime_paths.append(script)

(tmpdir / "registered-paths.txt").write_text(
    "".join(f"{item}\n" for item in sorted(set(registered_paths))),
    encoding="utf-8",
)
(tmpdir / "blocking-verification.txt").write_text(
    "".join(f"{item}\n" for item in sorted(set(blocking_verification))),
    encoding="utf-8",
)
(tmpdir / "ci-static-paths.txt").write_text(
    "".join(f"{item}\n" for item in sorted(set(ci_static_paths))),
    encoding="utf-8",
)
(tmpdir / "ci-runtime-paths.txt").write_text(
    "".join(f"{item}\n" for item in sorted(set(ci_runtime_paths))),
    encoding="utf-8",
)
PY
then
  fail "unable to parse ${REGISTRY}"
  echo ""
  echo "=== Summary ==="
  echo "  PASS: ${PASS}"
  echo "  FAIL: ${FAIL}"
  echo ""
  exit 1
fi

declare -A REGISTERED_SET
while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  REGISTERED_SET["${p}"]=1
done < "${TMPDIR}/registered-paths.txt"

declare -A BLOCKING_VERIFICATION_SET
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  BLOCKING_VERIFICATION_SET["${path}"]=1
done < "${TMPDIR}/blocking-verification.txt"

declare -A CI_STATIC_SET
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  CI_STATIC_SET["${path}"]=1
done < "${TMPDIR}/ci-static-paths.txt"

declare -A CI_RUNTIME_SET
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  CI_RUNTIME_SET["${path}"]=1
done < "${TMPDIR}/ci-runtime-paths.txt"

# ── Check 1: scripts/release/* must be registered ────────────────────────────
echo "--- 1. scripts/release/ — all scripts registered ---"
if [[ -d "${REPO_ROOT}/scripts/release" ]]; then
  found=0
  while IFS= read -r abs_script; do
    rel="${abs_script#"${REPO_ROOT}/"}"
    found=$((found + 1))
    if [[ -n "${REGISTERED_SET["${rel}"]:-}" ]]; then
      pass "${rel}"
    else
      fail "${rel} — not in script-registry.yaml (Charter #6 violation)"
    fi
  done < <(find "${REPO_ROOT}/scripts/release" -maxdepth 1 -name '*.sh' -type f | sort)
  [[ "$found" -eq 0 ]] && info "No scripts found in scripts/release/"
else
  info "scripts/release/ does not exist — skipping"
fi

# ── Check 2: scripts/infra/canonical-*.sh and release-*.sh must be registered ─
echo ""
echo "--- 2. scripts/infra/{canonical,release}-*.sh — all registered ---"
found=0
while IFS= read -r abs_script; do
  rel="${abs_script#"${REPO_ROOT}/"}"
  found=$((found + 1))
  if [[ -n "${REGISTERED_SET["${rel}"]:-}" ]]; then
    pass "${rel}"
  else
    fail "${rel} — not in script-registry.yaml (Charter #6 violation)"
  fi
done < <(find "${REPO_ROOT}/scripts/infra" -maxdepth 1 \
  \( -name 'canonical-*.sh' -o -name 'release-*.sh' \) -type f | sort)
[[ "$found" -eq 0 ]] && info "No canonical-* or release-* scripts found in scripts/infra/"

# ── Check 3: static authority and runtime authority must not overlap ─────────
echo ""
echo "--- 3. static authority vs runtime authority — no overlap ---"
overlap_found=0
for path in $(printf '%s\n' "${!CI_STATIC_SET[@]}" | sort); do
  if [[ -n "${CI_RUNTIME_SET["${path}"]:-}" ]]; then
    fail "${path} — listed in both script-registry.yaml ci_static_inventory and ci_runtime_inventory"
    overlap_found=1
  fi
done
if [[ "${overlap_found}" -eq 0 ]]; then
  pass "static authority and runtime authority do not overlap"
fi

# ── Check 4: release-blocking qa/ci scripts must be statically enforced ──────
echo ""
echo "--- 4. release-blocking scripts/qa/ and scripts/ci/ — static execution coverage ---"
if [[ "${#BLOCKING_VERIFICATION_SET[@]}" -eq 0 ]]; then
  info "No release-blocking scripts/qa/ or scripts/ci/ entries found in registry"
else
  for path in $(echo "${!BLOCKING_VERIFICATION_SET[@]}" | tr ' ' '\n' | sort); do
    if [[ -n "${CI_STATIC_SET["${path}"]:-}" ]]; then
      pass "${path} — static authority via script-registry.yaml ci_static_inventory"
    elif [[ -n "${CI_RUNTIME_SET["${path}"]:-}" ]]; then
      fail "${path} — listed only in script-registry.yaml ci_runtime_inventory; runtime inventory is manual/runtime coverage, not release-blocking enforcement"
    else
      fail "${path} — criticality: release-blocking but absent from script-registry.yaml ci_static_inventory"
    fi
  done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL — ${FAIL} violation(s). Release-blocking qa/ci scripts must be in ci_static_inventory; use ci_runtime_inventory only for manual/runtime inventory paths.${NC}"
  exit 1
fi

echo -e "${GREEN}RESULT: PASS${NC}"
