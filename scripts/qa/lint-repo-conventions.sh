#!/usr/bin/env bash
# lint-repo-conventions.sh - Factory.ai lint categories for mereka-lms repo
#
# Implements 4 Factory.ai lint categories:
# 1. Glob-ability: File placement conventions
# 2. Grep-ability: Consistent naming patterns
# 3. Architectural boundaries: Prevent cross-contamination
# 4. Observability: Structured output patterns
#
# Fast (<15s), exit non-zero on errors.
#
# Usage:
#   ./scripts/qa/lint-repo-conventions.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Output functions
pass() {
  echo "[PASS] $*"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "[FAIL] $*"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo "[WARN] $*"
  WARN_COUNT=$((WARN_COUNT + 1))
}

################################################################################
# Category 1: Glob-ability (file placement conventions)
################################################################################

check_glob_ability() {
  echo "=== Category 1: Glob-ability (file placement) ==="

  # Check spec files: must end in _spec.md and live in specs/
  local spec_violations=0
  if [[ -d specs ]]; then
    while IFS= read -r -d '' file; do
      local basename
      basename="$(basename "$file")"
      local dirname
      dirname="$(dirname "$file")"

      # Skip exceptions
      if [[ "$basename" == "IMPLEMENTATION_ORDER.md" ]] || \
         [[ "$basename" == "INDEX.md" ]] || \
         [[ "$basename" == "_TEMPLATE.md" ]] || \
         [[ "$basename" == "README.md" ]]; then
        continue
      fi

      # Check if it's in specs/ root and doesn't end with _spec.md
      if [[ "$dirname" == "specs" ]] && [[ ! "$basename" =~ _spec\.md$ ]]; then
        fail "Glob-ability: Spec file must end in _spec.md: $file"
        spec_violations=$((spec_violations + 1))
      fi
    done < <(find specs -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)
  fi

  if [[ $spec_violations -eq 0 ]] && [[ -d specs ]]; then
    pass "Glob-ability: All spec files follow *_spec.md naming"
  fi

  # Check plan files: must end in _plan.md or _testplan.md and live in specs/plans/
  local plan_violations=0
  if [[ -d specs/plans ]]; then
    while IFS= read -r -d '' file; do
      local basename
      basename="$(basename "$file")"

      # Skip README
      if [[ "$basename" == "README.md" ]]; then
        continue
      fi

      if [[ ! "$basename" =~ _plan\.md$ ]] && [[ ! "$basename" =~ _testplan\.md$ ]]; then
        fail "Glob-ability: Plan file must end in _plan.md or _testplan.md: $file"
        plan_violations=$((plan_violations + 1))
      fi
    done < <(find specs/plans -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)
  fi

  if [[ $plan_violations -eq 0 ]] && [[ -d specs/plans ]]; then
    pass "Glob-ability: All plan files follow *_plan.md or *_testplan.md naming"
  fi

  # Check verify scripts: must start with verify- or end in -verify.sh and live in scripts/qa/
  local verify_violations=0
  if [[ -d scripts/qa ]]; then
    while IFS= read -r -d '' file; do
      local basename
      basename="$(basename "$file")"
      local dirname
      dirname="$(dirname "$file")"

      # Skip subdirectories
      if [[ "$dirname" != "scripts/qa" ]]; then
        continue
      fi

      # Check if filename suggests it's a verify script but doesn't follow convention
      if [[ "$basename" =~ verify ]] || [[ "$basename" =~ test ]] || [[ "$basename" =~ check ]] || [[ "$basename" =~ audit ]]; then
        if [[ ! "$basename" =~ ^verify- ]] && [[ ! "$basename" =~ -verify\.sh$ ]] && \
           [[ ! "$basename" =~ ^test- ]] && [[ ! "$basename" =~ ^check- ]] && \
           [[ ! "$basename" =~ ^audit- ]] && [[ ! "$basename" =~ ^run- ]] && \
           [[ ! "$basename" =~ ^lint- ]] && [[ ! "$basename" =~ ^scan- ]] && \
           [[ ! "$basename" =~ ^smoke- ]] && [[ ! "$basename" =~ ^generate- ]] && \
           [[ ! "$basename" =~ ^collect- ]] && [[ ! "$basename" =~ ^build- ]] && \
           [[ ! "$basename" =~ ^capture- ]] && [[ ! "$basename" =~ ^list- ]] && \
           [[ ! "$basename" =~ ^map- ]] && [[ ! "$basename" =~ ^microsite- ]] && \
           [[ ! "$basename" =~ ^public- ]] && [[ ! "$basename" =~ ^visual- ]] && \
           [[ ! "$basename" =~ ^fix- ]] && [[ ! "$basename" =~ ^course- ]] && \
           [[ ! "$basename" =~ ^analyze- ]] && [[ ! "$basename" =~ ^gate- ]] && \
           [[ ! "$basename" =~ ^load- ]] && [[ ! "$basename" =~ ^comprehensive- ]]; then
          # This is overly strict for existing codebase, just warn
          warn "Glob-ability: QA script doesn't follow standard naming: $file"
        fi
      fi
    done < <(find scripts/qa -maxdepth 1 -type f -name '*.sh' -print0 2>/dev/null)
  fi

  # Informational only - verify scripts are in scripts/qa/
  if [[ -d scripts/qa ]]; then
    pass "Glob-ability: Verification scripts live in scripts/qa/"
  fi

  # Check testmap files: must end in .testmap.yml and live in specs/testmaps/
  local testmap_violations=0
  if [[ -d specs/testmaps ]]; then
    while IFS= read -r -d '' file; do
      local basename
      basename="$(basename "$file")"

      if [[ ! "$basename" =~ \.testmap\.yml$ ]]; then
        fail "Glob-ability: Testmap file must end in .testmap.yml: $file"
        testmap_violations=$((testmap_violations + 1))
      fi
    done < <(find specs/testmaps -maxdepth 1 -type f -name '*.yml' -o -name '*.yaml' -print0 2>/dev/null)
  fi

  if [[ $testmap_violations -eq 0 ]] && [[ -d specs/testmaps ]]; then
    pass "Glob-ability: All testmap files follow *.testmap.yml naming"
  fi
}

################################################################################
# Category 2: Grep-ability (consistent naming)
################################################################################

check_grep_ability() {
  echo ""
  echo "=== Category 2: Grep-ability (consistent naming) ==="

  # Check K8s manifests have app.kubernetes.io/name label
  local k8s_label_violations=0
  if [[ -d deploy/k8s ]]; then
    while IFS= read -r -d '' file; do
      # Skip kustomization.yaml files
      if [[ "$(basename "$file")" == "kustomization.yaml" ]]; then
        continue
      fi

      # Skip patch files (strategic merge patches don't need standalone labels)
      if [[ "$file" == *"/patches/"* ]]; then
        continue
      fi

      # Skip if file doesn't contain "kind:" (not a K8s manifest)
      if ! grep -q "^kind:" "$file" 2>/dev/null; then
        continue
      fi

      # Check for app.kubernetes.io/name label
      if ! grep -q "app.kubernetes.io/name:" "$file" 2>/dev/null; then
        fail "Grep-ability: K8s manifest missing app.kubernetes.io/name label: $file"
        k8s_label_violations=$((k8s_label_violations + 1))
      fi
    done < <(find deploy/k8s -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null)
  fi

  if [[ $k8s_label_violations -eq 0 ]] && [[ -d deploy/k8s ]]; then
    pass "Grep-ability: All K8s manifests have app.kubernetes.io/name label"
  fi

  # Check shell scripts have set -euo pipefail (only check scripts/, not all)
  local pipefail_missing=0
  if [[ -d scripts ]]; then
    while IFS= read -r -d '' file; do
      # Only check scripts in scripts/ directory (not tutor_env, etc.)
      if [[ ! "$file" =~ ^scripts/ ]]; then
        continue
      fi

      # Explicit per-file exception for scripts that must not set global strict mode.
      if grep -q "lint: allow-no-euo" "$file" 2>/dev/null; then
        continue
      fi

      if ! grep -q "set -euo pipefail" "$file" 2>/dev/null && \
         ! grep -q "set -eu" "$file" 2>/dev/null; then
        warn "Grep-ability: Shell script missing 'set -euo pipefail': $file"
        pipefail_missing=$((pipefail_missing + 1))
      fi
    done < <(find scripts -type f -name '*.sh' -print0 2>/dev/null || true)
  fi

  if [[ $pipefail_missing -eq 0 ]] && [[ -d scripts ]]; then
    pass "Grep-ability: All scripts/ shell scripts have set -euo pipefail"
  fi

  # Check shell scripts have proper shebang
  local shebang_violations=0
  while IFS= read -r -d '' file; do
    # Skip files in hidden dirs, var/, node_modules/, tutor_env/ (generated)
    if [[ "$file" =~ /\. ]] || [[ "$file" =~ /var/ ]] || [[ "$file" =~ /node_modules/ ]] || [[ "$file" =~ /tutor_env/ ]]; then
      continue
    fi

    local first_line
    first_line="$(head -n1 "$file")"

    if [[ ! "$first_line" =~ ^#!/usr/bin/env\ bash ]] && \
       [[ ! "$first_line" =~ ^#!/bin/bash ]] && \
       [[ ! "$first_line" =~ ^#!/bin/sh ]]; then
      fail "Grep-ability: Shell script missing proper shebang: $file"
      shebang_violations=$((shebang_violations + 1))
    fi
  done < <(find . -type f -name '*.sh' -print0 2>/dev/null | grep -zv '^\./\.' | grep -zv '/var/' | grep -zv '/node_modules/' | grep -zv '/tutor_env/' || true)

  if [[ $shebang_violations -eq 0 ]]; then
    pass "Grep-ability: All shell scripts have proper shebang"
  fi

  # Check workflow action refs are immutable SHAs (external uses: only)
  local workflow_ref_violations=0
  while IFS=: read -r file line ref; do
    [[ -n "$file" ]] || continue
    [[ "$ref" == ./* ]] && continue
    [[ "$ref" == docker://* ]] && continue

    if [[ "$ref" != *@* ]]; then
      fail "Grep-ability: Workflow uses ref missing @version: ${file}:${line} (${ref})"
      workflow_ref_violations=$((workflow_ref_violations + 1))
      continue
    fi

    local version
    version="${ref##*@}"
    if [[ ! "$version" =~ ^[0-9a-f]{40}$ ]]; then
      fail "Grep-ability: Workflow uses ref must be full 40-char SHA: ${file}:${line} (${ref})"
      workflow_ref_violations=$((workflow_ref_violations + 1))
    fi
  done < <(
    awk '
      match($0, /^[[:space:]]*uses:[[:space:]]*([^[:space:]#]+)/, m) {
        print FILENAME ":" NR ":" m[1]
      }
    ' .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null || true
  )

  if [[ $workflow_ref_violations -eq 0 ]]; then
    pass "Grep-ability: All external workflow uses refs are pinned to immutable SHAs"
  fi
}

################################################################################
# Category 3: Architectural boundaries
################################################################################

check_architectural_boundaries() {
  echo ""
  echo "=== Category 3: Architectural boundaries ==="

  # Check spec files don't reference deprecated directories (tools/, ops/)
  # Look for path references like "tools/something" or "ops/something" but NOT "service-tools/" or "privacy-tools/"
  local deprecated_refs=0
  if [[ -d specs ]]; then
    while IFS= read -r -d '' file; do
      # Look for standalone tools/ or ops/ paths (not part of service names)
      # Match: "tools/", "../tools/", "./tools/" but NOT "service-tools/", "privacy-tools/"
      local violations
      violations=$(grep -n -E '(^|[[:space:]]|`|/)(tools|ops)/[a-zA-Z0-9_-]+' "$file" 2>/dev/null | \
                  grep -v -E '(services/[a-zA-Z0-9_-]*-tools/|team-skills.*tools/)' | \
                  grep -v -i -E '(deprecated|moved to|migrated to|see scripts/)' || true)

      if [[ -n "$violations" ]]; then
        fail "Architectural boundaries: Spec references deprecated tools/ops/ directory: $file"
        echo "$violations" | head -3 | sed 's/^/    /'
        if [[ $(echo "$violations" | wc -l) -gt 3 ]]; then
          echo "    ... ($(echo "$violations" | wc -l) total violations)"
        fi
        deprecated_refs=$((deprecated_refs + 1))
      fi
    done < <(find specs -type f -name '*.md' -print0 2>/dev/null)
  fi

  if [[ $deprecated_refs -eq 0 ]] && [[ -d specs ]]; then
    pass "Architectural boundaries: No references to deprecated directories in specs"
  fi

  # Check for cloud IPs (10.x.x.x) in local config files
  local cloud_ip_violations=0
  local local_configs=(
    "infrastructure/tutor/config.yml.example"
    "docker-compose.yml"
    "docker-compose.override.yml"
  )

  for config in "${local_configs[@]}"; do
    if [[ ! -f "$config" ]]; then
      continue
    fi

    # Look for 10.x.x.x IP patterns
    if grep -q -E '\b10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b' "$config" 2>/dev/null; then
      fail "Architectural boundaries: Cloud IP (10.x.x.x) found in local config: $config"
      cloud_ip_violations=$((cloud_ip_violations + 1))
    fi
  done

  if [[ $cloud_ip_violations -eq 0 ]]; then
    pass "Architectural boundaries: No cloud IPs in local config files"
  fi

  # Check specs don't reference non-existent scripts (warn only for planned features)
  # Only fail if it's referenced in a *_spec.md file (not *_plan.md or *_testplan.md)
  local missing_script_refs=0
  local missing_script_warns=0
  local missing_script_warn_duplicates=0
  declare -A seen_missing_plan_refs=()
  if [[ -d specs ]]; then
    while IFS= read -r -d '' file; do
      local basename
      basename="$(basename "$file")"

      # Extract script paths mentioned in specs (scripts/...)
      while IFS= read -r script_path; do
        # Clean up the path (remove markdown syntax, quotes)
        script_path=$(echo "$script_path" | sed -E 's/.*`([^`]+)`.*/\1/' | sed -E 's/.*\[([^\]]+)\].*/\1/' | sed 's/"//g' | sed "s/'//g")

        # Skip if it's a pattern or example
        if [[ "$script_path" =~ \* ]] || [[ "$script_path" =~ \$ ]] || [[ "$script_path" =~ \{ ]]; then
          continue
        fi

        # Check if the script exists
        if [[ ! -f "$script_path" ]] && [[ ! -d "$script_path" ]]; then
          # Only warn for plan/testplan files (future work), fail for spec files
          if [[ "$basename" =~ _plan\.md$ ]] || [[ "$basename" =~ _testplan\.md$ ]]; then
            if [[ -z "${seen_missing_plan_refs[$script_path]+x}" ]]; then
              warn "Architectural boundaries: Plan references non-existent file (future work): $script_path"
              seen_missing_plan_refs[$script_path]=1
              missing_script_warns=$((missing_script_warns + 1))
            else
              missing_script_warn_duplicates=$((missing_script_warn_duplicates + 1))
            fi
          else
            fail "Architectural boundaries: Spec references non-existent file: $script_path (in $file)"
            missing_script_refs=$((missing_script_refs + 1))
          fi
        fi
      done < <(grep -oE 'scripts/[a-zA-Z0-9_/-]+\.sh' "$file" 2>/dev/null || true)
    done < <(find specs -type f -name '*.md' -print0 2>/dev/null)
  fi

  if [[ $missing_script_refs -eq 0 ]] && [[ -d specs ]]; then
    pass "Architectural boundaries: All spec-referenced scripts exist"
  fi
  if [[ $missing_script_warn_duplicates -gt 0 ]]; then
    pass "Architectural boundaries: Suppressed $missing_script_warn_duplicates duplicate future-work missing-file warnings"
  fi
}

################################################################################
# Category 4: Observability
################################################################################

check_observability() {
  echo ""
  echo "=== Category 4: Observability ==="

  # Check PrometheusRule files have consistent naming
  local prometheus_violations=0
  if [[ -d deploy/k8s ]]; then
    while IFS= read -r -d '' file; do
      local basename
      basename="$(basename "$file")"

      # Check if it's a PrometheusRule
      if ! grep -q "kind: PrometheusRule" "$file" 2>/dev/null; then
        continue
      fi

      # Should follow prometheusrule-*.yaml pattern.
      # Allow known historical exceptions to avoid noisy warnings until renamed.
      case "$file" in
        deploy/k8s/base/monitoring/slo-burn-rate-rules.yaml|\
        deploy/k8s/base/plugins/aspects/prometheusrule.yml|\
        deploy/k8s/base/apps/xqueue-graders/prometheusrule.yaml)
          continue
          ;;
      esac

      if [[ ! "$basename" =~ ^prometheusrule- ]]; then
        warn "Observability: PrometheusRule file doesn't follow prometheusrule-*.yaml naming: $file"
        prometheus_violations=$((prometheus_violations + 1))
      fi
    done < <(find deploy/k8s -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 2>/dev/null)
  fi

  if [[ $prometheus_violations -eq 0 ]] && [[ -d deploy/k8s ]]; then
    pass "Observability: All PrometheusRule files follow naming convention"
  fi

  # Check observability docs for unresolved lane/context placeholders
  local placeholder_violations=0
  local file_list
  if [[ -d docs/qa && -d docs/operations ]]; then
    file_list=$(find docs/qa docs/operations \
      -type f \
      -name '*.md' \
      \( -iname '*observability*' -o -iname '*OBSERVABILITY*' -o -iname '*parity*' -o -iname '*ONCALL*' \) \
      | sort -u)

    if [[ -n "$file_list" ]]; then
      while IFS= read -r doc; do
        local placeholder_hits
        placeholder_hits="$(rg -n -E '<[A-Za-z0-9._-]+-context>|<[A-Za-z0-9._-]+-project>|<dev-or-shared-project>|<lane-context>' "$doc" 2>/dev/null || true)"
        if [[ -n "$placeholder_hits" ]]; then
          echo "[FAIL] Observability docs still contain unresolved placeholders: $doc"
          echo "$placeholder_hits" | sed 's/^/  /'
          placeholder_violations=$((placeholder_violations + 1))
        fi
      done <<< "$file_list"
    fi
  fi

  if [[ $placeholder_violations -eq 0 ]]; then
    pass "Observability: No unresolved context/project placeholders in observability docs"
  fi

  # Check QA scripts produce structured output (informational only, don't spam warnings)
  # Just provide a summary
  local structured_count=0
  local total_qa_scripts=0
  if [[ -d scripts/qa ]]; then
    while IFS= read -r -d '' file; do
      local basename
      basename="$(basename "$file")"

      # Skip this script itself
      if [[ "$basename" == "lint-repo-conventions.sh" ]]; then
        continue
      fi

      # Skip subdirectories
      if [[ "$(dirname "$file")" != "scripts/qa" ]]; then
        continue
      fi

      total_qa_scripts=$((total_qa_scripts + 1))

      # Check if script produces structured output (PASS/FAIL/WARN patterns)
      if grep -q -E '\[(PASS|FAIL|WARN|OK|ERROR)\]' "$file" 2>/dev/null; then
        structured_count=$((structured_count + 1))
      fi
    done < <(find scripts/qa -maxdepth 1 -type f -name '*.sh' -print0 2>/dev/null)

    if [[ $total_qa_scripts -gt 0 ]]; then
      local pct=$((structured_count * 100 / total_qa_scripts))
      pass "Observability: $structured_count/$total_qa_scripts QA scripts ($pct%) use structured output"
    fi
  fi
}

################################################################################
# Main
################################################################################

main() {
  echo "Running Factory.ai repo convention checks for mereka-lms..."
  echo ""

  check_glob_ability
  check_grep_ability
  check_architectural_boundaries
  check_observability

  echo ""
  echo "========================================="
  echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed, $WARN_COUNT warnings"
  echo "========================================="

  if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"
