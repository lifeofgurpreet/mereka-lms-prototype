#!/usr/bin/env bash
# @covers AC-BUILD-RL-001
# @covers AC-BAUTH-007, AC-BAUTH-009, AC-BAUTH-010
# @spec: build-authority-deterministic-builds_spec.md
#
# verify-red-line-contract.sh — machine-checkable red lines from RFC-BUILD-AUTHORITY-001
# Bead: mereka-lms-jj97.21
#
# Exit 0: all red lines respected
# Exit 1: one or more violations
# Exit 2: script error (missing required file, etc.)
#
# Usage:
#   ./scripts/qa/verify-red-line-contract.sh [--quiet]
#
# --quiet: suppress PASS lines, show only FAIL/WARN/summary

set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# ── output helpers ──────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

rl_pass() {
  local label="$1"
  PASS_COUNT=$((PASS_COUNT + 1))
  [[ "$QUIET" -eq 0 ]] && echo "[PASS] $label"
  return 0
}

rl_fail() {
  local label="$1"
  local hint="${2:-}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "[FAIL] $label"
  [[ -n "$hint" ]] && echo "       Remediation: $hint"
  return 0
}

rl_warn() {
  local label="$1"
  local hint="${2:-}"
  WARN_COUNT=$((WARN_COUNT + 1))
  echo "[WARN] $label"
  [[ -n "$hint" ]] && echo "       Note: $hint"
  return 0
}

# ── helper: grep wrapper (uses rg if available, falls back to grep) ─────────
rl_grep() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -q --fixed-strings -- "$pattern" "$file" 2>/dev/null
  else
    grep -qF -- "$pattern" "$file" 2>/dev/null
  fi
}

rl_grep_regex() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -q -- "$pattern" "$file" 2>/dev/null
  else
    grep -qE -- "$pattern" "$file" 2>/dev/null
  fi
}

# ── RL-1: No second observability island ────────────────────────────────────
# Soft heuristic: flag if CI scripts/configs in *this* repo reference a local
# prometheus.yml, grafana/datasource.yaml, or docker-compose.yml that is
# NOT pointing at the canonical VPS stack. We look for these filenames under
# .github/ and scripts/ only — the root docker-compose.yml used locally for
# infra is out of scope.
check_red_line_1() {
  local verdict=0
  local suspicious_files=()

  # Look for grafana datasource YAML definitions inside CI / scripts trees
  while IFS= read -r -d '' f; do
    suspicious_files+=("$f")
  done < <(find "$REPO_ROOT/.github" "$REPO_ROOT/scripts" \
    -type f \( -name "prometheus.yml" -o -name "datasource.yaml" -o -name "datasource.yml" \) \
    -print0 2>/dev/null || true)

  # Also look for docker-compose files under .github/ (not the root one)
  while IFS= read -r -d '' f; do
    suspicious_files+=("$f")
  done < <(find "$REPO_ROOT/.github" \
    -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \) \
    -print0 2>/dev/null || true)

  if [[ "${#suspicious_files[@]}" -eq 0 ]]; then
    rl_pass "RL-1: No second observability island (no local prometheus/grafana/docker-compose configs in CI tree)"
  else
    rl_warn "RL-1: Potential observability island files found in CI tree — review manually" \
      "Remove or confirm these point at the canonical VPS stack (~/infrastructure/observability): ${suspicious_files[*]}"
    verdict=1
  fi
  return $verdict
}

# ── RL-2: No co-equal cache authorities ─────────────────────────────────────
# Fail if docker-bake.hcl heavy targets (openedx-proof, mfe-proof) declare
# BOTH type=gha AND type=registry in cache-from WITHOUT the gha entry being
# marked with a "# transitional" comment AND appearing under an L3 fallback ref.
#
# Current state (2026-04-16): the bake file has gha as primary and registry as
# fallback — which is the *pre-fix* state. We check if it violates the
# future rule: registry must be present; gha may exist only as transitional.
# Since the RFC mandates registry-primary, we flag if gha appears without
# the transitional comment in the same target block.
check_red_line_2() {
  local bake_file="$REPO_ROOT/docker-bake.hcl"
  local verdict=0

  if [[ ! -f "$bake_file" ]]; then
    rl_fail "RL-2: docker-bake.hcl not found" \
      "The bake file must exist at repo root: docker-bake.hcl"
    return 1
  fi

  # Extract cache-from blocks for the two heavy targets
  # We look for: target block containing both type=gha and type=registry in cache-from
  # and verify that if gha is present in cache-from, it has a "# transitional" comment nearby

  local openedx_block mfe_block
  openedx_block="$(awk '/^target "openedx-proof"/{found=1} found{print} /^}$/{if(found) exit}' "$bake_file")"
  mfe_block="$(awk '/^target "mfe-proof"/{found=1} found{print} /^}$/{if(found) exit}' "$bake_file")"

  local openedx_cache_from_block mfe_cache_from_block
  openedx_cache_from_block="$(awk '/cache-from/{found=1} found{print} /\]/{if(found) exit}' <<<"$openedx_block")"
  mfe_cache_from_block="$(awk '/cache-from/{found=1} found{print} /\]/{if(found) exit}' <<<"$mfe_block")"

  # Check openedx-proof
  local openedx_has_gha=0 openedx_has_registry=0 openedx_gha_transitional=0
  if grep -q 'type=gha' <<<"$openedx_cache_from_block"; then
    openedx_has_gha=1
  fi
  if grep -q 'type=registry' <<<"$openedx_cache_from_block"; then
    openedx_has_registry=1
  fi
  if grep -q '# transitional' <<<"$openedx_cache_from_block"; then
    openedx_gha_transitional=1
  fi

  # Check mfe-proof
  local mfe_has_gha=0 mfe_has_registry=0 mfe_gha_transitional=0
  if grep -q 'type=gha' <<<"$mfe_cache_from_block"; then
    mfe_has_gha=1
  fi
  if grep -q 'type=registry' <<<"$mfe_cache_from_block"; then
    mfe_has_registry=1
  fi
  if grep -q '# transitional' <<<"$mfe_cache_from_block"; then
    mfe_gha_transitional=1
  fi

  # Rule: registry must be present in cache-from
  if [[ "$openedx_has_registry" -eq 0 ]]; then
    rl_fail "RL-2: openedx-proof cache-from missing type=registry (registry must be primary authority)" \
      "Add type=registry,ref=ghcr.io/.../cache/openedx:main-amd64 as first entry in openedx-proof.cache-from"
    verdict=1
  fi
  if [[ "$mfe_has_registry" -eq 0 ]]; then
    rl_fail "RL-2: mfe-proof cache-from missing type=registry (registry must be primary authority)" \
      "Add type=registry,ref=ghcr.io/.../cache/mfe:main-amd64 as first entry in mfe-proof.cache-from"
    verdict=1
  fi

  # Rule: gha may coexist only if marked transitional
  if [[ "$openedx_has_gha" -eq 1 && "$openedx_gha_transitional" -eq 0 ]]; then
    rl_fail "RL-2: openedx-proof has type=gha in cache-from without a '# transitional' comment" \
      "Mark the gha cache-from entry with '# transitional' or remove it (registry is the sole authority)"
    verdict=1
  elif [[ "$openedx_has_gha" -eq 1 && "$openedx_gha_transitional" -eq 1 ]]; then
    rl_warn "RL-2: openedx-proof has type=gha marked as transitional — remove when registry authority is confirmed"
  fi

  if [[ "$mfe_has_gha" -eq 1 && "$mfe_gha_transitional" -eq 0 ]]; then
    rl_fail "RL-2: mfe-proof has type=gha in cache-from without a '# transitional' comment" \
      "Mark the gha cache-from entry with '# transitional' or remove it (registry is the sole authority)"
    verdict=1
  elif [[ "$mfe_has_gha" -eq 1 && "$mfe_gha_transitional" -eq 1 ]]; then
    rl_warn "RL-2: mfe-proof has type=gha marked as transitional — remove when registry authority is confirmed"
  fi

  # Summary pass if no hard failures
  if [[ "$verdict" -eq 0 ]]; then
    rl_pass "RL-2: Cache authority is correct (registry present; no unmarked gha co-authority)"
  fi

  return $verdict
}

# ── RL-3: No uncontrolled ARC vs fastlane comparison ────────────────────────
# Soft check on dashboard JSON / PromQL files: any panel/query comparing
# runner_class without filtering by benchmark_class is flagged.
# Until jj97.4 lands, dashboards don't exist yet — no-ops gracefully with WARN.
check_red_line_3() {
  local dashboard_dir="$HOME/projects/vps/infrastructure/grafana/dashboards/ci"
  local verdict=0

  if [[ ! -d "$dashboard_dir" ]]; then
    rl_warn "RL-3: CI dashboard dir not found (forward-looking check — OK before jj97.4)" \
      "Once grafana/dashboards/ci/ exists, verify all runner_class PromQL queries filter by benchmark_class"
    return 0
  fi

  # Look for PromQL expressions referencing runner_class without benchmark_class filter
  local suspicious_panels=()
  while IFS= read -r -d '' f; do
    # Look for JSON with runner_class in expr but not benchmark_class in same expr
    if python3 -c "
import json, sys
data = json.loads(open('$f').read())
panels = data.get('panels', [])
for panel in panels:
    targets = panel.get('targets', [])
    for target in targets:
        expr = target.get('expr', '')
        if 'runner_class' in expr and 'benchmark_class' not in expr:
            print(f'${f}: panel \"{panel.get(\"title\",\"(untitled)\")}\": expr references runner_class without benchmark_class filter')
" 2>/dev/null; then
      suspicious_panels+=("$f")
    fi
  done < <(find "$dashboard_dir" -name "*.json" -print0 2>/dev/null || true)

  if [[ "${#suspicious_panels[@]}" -eq 0 ]]; then
    rl_pass "RL-3: No uncontrolled ARC vs fastlane comparisons found in CI dashboards"
  else
    rl_warn "RL-3: Dashboard panel(s) compare runner_class without benchmark_class filter" \
      "Add benchmark_class filter to all runner_class PromQL queries: ${suspicious_panels[*]}"
    verdict=1
  fi
  return $verdict
}

# ── RL-4: No hand-labeled warm/cold ─────────────────────────────────────────
# Fail if any .github/workflows/*.yml or scripts/ file emits warm= / cold= /
# benchmark_class= as a literal label value in metric emission context.
# Exception: workflow_dispatch INPUT named benchmark_class is allowed.
check_red_line_4() {
  local verdict=0
  local violations=()

  # Patterns that indicate hard-coded label emission (not input definitions)
  # We search for: benchmark_class=warm, benchmark_class=cold, warm=true, cold=true
  # in non-comment lines of workflow and script files.
  # We skip lines that are input definitions (type: string, type: choice, options:, default:)

  check_file_for_hardcoded_labels() {
    local file="$1"
    local found=0
    while IFS= read -r line; do
      # Skip pure YAML comment lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      # Skip workflow input definition lines (description:, type:, default:, options:, inputs:)
      [[ "$line" =~ (description:|type:[[:space:]]*(string|choice|boolean)|default:|options:|^[[:space:]]*inputs:) ]] && continue
      # Flag emission patterns
      if grep -qE '(benchmark_class|warm|cold)[[:space:]]*=[[:space:]]*(warm|cold|"warm"|"cold"|true|false)[^_a-zA-Z]' <<<"$line"; then
        # Allow: benchmark_class is used as a condition variable (not a label value)
        # Disallow: it appears in metric emission context (step name "emit", "push", "metric", label)
        if grep -qiE '(metric|label|emit|push|prometheus|pushgateway)' <<<"$line"; then
          found=1
          echo "  In $file: $line"
        fi
      fi
    done < "$file"
    return $found
  }

  # Scan workflow files
  while IFS= read -r -d '' f; do
    local tmp_violations
    tmp_violations=$(check_file_for_hardcoded_labels "$f" 2>/dev/null || true)
    if [[ -n "$tmp_violations" ]]; then
      violations+=("$tmp_violations")
      verdict=1
    fi
  done < <(find "$REPO_ROOT/.github/workflows" \( -name "*.yml" -o -name "*.yaml" \) -print0 2>/dev/null || true)

  # Scan CI scripts
  while IFS= read -r -d '' f; do
    local tmp_violations
    tmp_violations=$(check_file_for_hardcoded_labels "$f" 2>/dev/null || true)
    if [[ -n "$tmp_violations" ]]; then
      violations+=("$tmp_violations")
      verdict=1
    fi
  done < <(find "$REPO_ROOT/scripts/ci" -name "*.sh" -print0 2>/dev/null || true)

  if [[ "$verdict" -eq 0 ]]; then
    rl_pass "RL-4: No hand-labeled warm/cold metric emission found"
  else
    rl_fail "RL-4: Found hard-coded warm/cold/benchmark_class label emission in workflows or scripts" \
      "Classification must be DERIVED in Prometheus recording rules, not emitted as a literal label"
    for v in "${violations[@]}"; do
      echo "$v"
    done
  fi
  return $verdict
}

# ── RL-5: No PR cache writes ─────────────────────────────────────────────────
# Fail if build-tutor-images.yml (and any heavy-build workflow) sets cache-to=
# without a guard expression containing:
#   github.ref == 'refs/heads/main' AND github.event_name == 'push'
# We walk YAML for any unconditional cache-to and flag.
check_red_line_5() {
  local build_wf="$REPO_ROOT/.github/workflows/build-tutor-images.yml"
  local verdict=0

  if [[ ! -f "$build_wf" ]]; then
    rl_fail "RL-5: build-tutor-images.yml not found" \
      "Expected at: .github/workflows/build-tutor-images.yml"
    return 1
  fi

  # Strategy: parse YAML with Python to find any 'cache-to' key set in build
  # steps whose surrounding job does NOT have an 'if' condition referencing
  # both github.ref == 'refs/heads/main' AND github.event_name == 'push'.
  #
  # We use a text-scan approach: look for cache-to: mentions in the file,
  # then check whether the enclosing job block has the required guard.

  local py_result
  py_result=$(python3 - "$build_wf" <<'PY'
from __future__ import annotations
import re
import sys

try:
    import yaml
except ImportError:
    print("SKIP: PyYAML not available; skipping RL-5 YAML parse")
    sys.exit(0)

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    raw = f.read()

try:
    doc = yaml.safe_load(raw)
except yaml.YAMLError as e:
    print(f"ERROR: Could not parse {path}: {e}")
    sys.exit(2)

if not isinstance(doc, dict):
    print("SKIP: workflow YAML is not a mapping")
    sys.exit(0)

jobs = doc.get("jobs", {})
if not isinstance(jobs, dict):
    print("SKIP: no jobs found")
    sys.exit(0)

REQUIRED_REF = "refs/heads/main"
REQUIRED_EVENT = "push"

violations = []

for job_name, job in jobs.items():
    if not isinstance(job, dict):
        continue
    steps = job.get("steps", [])
    if not isinstance(steps, list):
        continue
    job_if = str(job.get("if", ""))

    for step in steps:
        if not isinstance(step, dict):
            continue
        # Look for cache-to in step 'with' or 'env' or 'run'
        has_cache_to = False

        # Check 'with' block for cache-to key
        with_block = step.get("with", {})
        if isinstance(with_block, dict):
            for key, val in with_block.items():
                if "cache-to" in str(key) and val:
                    has_cache_to = True

        # Check 'run' block for --cache-to or CACHE_TO patterns
        run_block = str(step.get("run", ""))
        if re.search(r"cache-to\s*=\s*['\"]?type=", run_block):
            has_cache_to = True

        # Check 'env' block for cache-to related vars being set
        env_block = step.get("env", {})
        if isinstance(env_block, dict):
            for key, val in env_block.items():
                if "CACHE_TO" in str(key).upper() and val and "type=" in str(val):
                    has_cache_to = True

        if not has_cache_to:
            continue

        step_if = str(step.get("if", ""))
        # Guard can be in if: condition OR in the env value expression itself
        # (e.g., CACHE_TO_X: ${{ github.ref == 'refs/heads/main' && ... || '' }})
        env_guard_str = ""
        if isinstance(env_block, dict):
            for key, val in env_block.items():
                if "CACHE_TO" in str(key).upper():
                    env_guard_str += " " + str(val)
        combined_guard = job_if + " " + step_if + " " + env_guard_str

        has_ref_guard = REQUIRED_REF in combined_guard
        has_event_guard = (
            REQUIRED_EVENT in combined_guard
            and "event_name" in combined_guard
        )

        if not (has_ref_guard and has_event_guard):
            step_name = step.get("name", "(unnamed step)")
            violations.append(
                f"  job={job_name!r} step={step_name!r}: cache-to set without "
                f"github.ref=='refs/heads/main' AND github.event_name=='push' guard"
            )

if violations:
    print("VIOLATIONS:")
    for v in violations:
        print(v)
    sys.exit(1)
else:
    print("OK")
    sys.exit(0)
PY
  )

  local py_exit=$?
  if [[ "$py_exit" -eq 0 ]]; then
    if [[ "$py_result" == "OK" ]]; then
      rl_pass "RL-5: No PR cache writes — all cache-to steps guarded by main-branch push condition"
    else
      # SKIP case from python
      rl_warn "RL-5: $py_result"
    fi
  elif [[ "$py_exit" -eq 2 ]]; then
    rl_warn "RL-5: Could not parse build-tutor-images.yml — manual review required" \
      "Verify all cache-to: settings are guarded by github.ref == 'refs/heads/main' AND github.event_name == 'push'"
  else
    rl_fail "RL-5: Cache writes not guarded for PR branches" \
      "Add 'if: github.ref == refs/heads/main && github.event_name == push' to any job/step that sets cache-to"
    echo "$py_result"
    verdict=1
  fi

  # Also check build-benchmark.yml if it exists (PR 5 deliverable)
  local benchmark_wf="$REPO_ROOT/.github/workflows/build-benchmark.yml"
  if [[ -f "$benchmark_wf" ]]; then
    if rl_grep_regex 'cache-to' "$benchmark_wf"; then
      # benchmark workflow is allowed to write cache under explicit benchmark_class conditions
      rl_warn "RL-5: build-benchmark.yml sets cache-to — verify it only writes under controlled benchmark conditions"
    fi
  fi

  return $verdict
}

# ── RL-6: No dashboard before data semantics ─────────────────────────────────
# Soft check: if grafana/dashboards/ci/ exists on VPS, verify CI_METRICS.md
# exists in this repo first. In CI we can only check CI_METRICS.md.
check_red_line_6() {
  local ci_metrics_doc="$REPO_ROOT/docs/ops/ci-cd/CI_METRICS.md"
  local dashboard_dir="$HOME/projects/vps/infrastructure/grafana/dashboards/ci"
  local verdict=0

  local ci_metrics_exists=0
  [[ -f "$ci_metrics_doc" ]] && ci_metrics_exists=1

  if [[ "$ci_metrics_exists" -eq 1 ]]; then
    rl_pass "RL-6: docs/ops/ci-cd/CI_METRICS.md exists — data semantics documented before dashboard"
  else
    # Check if dashboard already exists (local dev context only)
    if [[ -d "$dashboard_dir" ]] && compgen -G "$dashboard_dir/*.json" >/dev/null 2>&1; then
      rl_fail "RL-6: grafana/dashboards/ci/ exists but docs/ops/ci-cd/CI_METRICS.md is missing" \
        "Create CI_METRICS.md (owned by this sprint) before landing or enabling CI dashboards"
      verdict=1
    else
      rl_warn "RL-6: docs/ops/ci-cd/CI_METRICS.md not yet created (required before dashboard — jj97.15 deliverable)" \
        "Create docs/ops/ci-cd/CI_METRICS.md as part of bead jj97.15 (PR 1 Foundation)"
      verdict=0  # Forward-looking: warn, don't fail, until dashboard lands
    fi
  fi

  return $verdict
}

# ── main ──────────────────────────────────────────────────────────────────────
echo "=== Red-Line Contract Verification (RFC-BUILD-AUTHORITY-001) ==="
echo "    Bead: mereka-lms-jj97.21"
echo ""

check_red_line_1 || true
check_red_line_2 || true
check_red_line_3 || true
check_red_line_4 || true
check_red_line_5 || true
check_red_line_6 || true

echo ""
echo "=== Summary ==="
echo "Red-line contract: $PASS_COUNT/6 passed, $WARN_COUNT warning(s), $FAIL_COUNT failure(s)"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL — $FAIL_COUNT red line(s) violated"
  exit 1
fi

echo ""
echo "RESULT: PASS — all hard red lines respected"
exit 0
