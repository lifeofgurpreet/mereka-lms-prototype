#!/usr/bin/env bash
# Shared helper for locating/grepping Mereka Tutor plugin contract sources.
#
# Why this exists:
# - Most QA gates historically grep only mereka_lms.py.
# - #109 introduces staged maintainability split where contract markers can move
#   into sibling modules (mereka_lms_*.py) without runtime behavior changes.
# - These helpers keep checks compatible during the staged transition.

set -euo pipefail

mereka_plugin_main_file() {
  local repo_root="${1:?repo_root required}"
  printf "%s\n" "$repo_root/infrastructure/tutor/plugins/mereka_lms.py"
}

mereka_plugin_contract_files() {
  local repo_root="${1:?repo_root required}"
  local plugins_dir="$repo_root/infrastructure/tutor/plugins"
  local main_file
  main_file="$(mereka_plugin_main_file "$repo_root")"

  if [[ -f "$main_file" ]]; then
    printf "%s\n" "$main_file" 2>/dev/null || true
  fi

  # Sibling modules (mereka_lms_*.py)
  if [[ -d "$plugins_dir" ]]; then
    while IFS= read -r -d '' file; do
      printf "%s\n" "$file" 2>/dev/null || true
    done < <(find "$plugins_dir" -maxdepth 1 -type f -name "mereka_lms_*.py" -print0 | sort -z)
  fi

  # Subpackage modules (_mereka_lms/*.py, _mereka_lms/*.js)
  if [[ -d "$plugins_dir/_mereka_lms" ]]; then
    while IFS= read -r -d '' file; do
      printf "%s\n" "$file" 2>/dev/null || true
    done < <(find "$plugins_dir/_mereka_lms" -type f \( -name "*.py" -o -name "*.js" \) -print0 | sort -z)
  fi
}

mereka_plugin_has_any() {
  local repo_root="${1:?repo_root required}"
  local file
  while IFS= read -r file; do
    [[ -f "$file" ]] && return 0
  done < <(mereka_plugin_contract_files "$repo_root")
  return 1
}

mereka_plugin_has_fixed() {
  local repo_root="${1:?repo_root required}"
  local needle="${2:?needle required}"
  local file
  while IFS= read -r file; do
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
      return 0
    fi
  done < <(mereka_plugin_contract_files "$repo_root")
  return 1
}

mereka_plugin_has_regex() {
  local repo_root="${1:?repo_root required}"
  local pattern="${2:?pattern required}"
  local file
  while IFS= read -r file; do
    if grep -qE -- "$pattern" "$file" 2>/dev/null; then
      return 0
    fi
  done < <(mereka_plugin_contract_files "$repo_root")
  return 1
}

mereka_plugin_count_regex() {
  local repo_root="${1:?repo_root required}"
  local pattern="${2:?pattern required}"
  local file
  local total=0
  local count=0

  while IFS= read -r file; do
    count=$(grep -cE -- "$pattern" "$file" 2>/dev/null || true)
    total=$((total + count))
  done < <(mereka_plugin_contract_files "$repo_root")

  printf "%s\n" "$total"
}
