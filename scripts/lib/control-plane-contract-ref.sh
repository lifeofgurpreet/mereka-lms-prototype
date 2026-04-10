#!/usr/bin/env bash
# Control-plane contract ref resolution library for Mereka LMS release tooling.
# Source this file; do not execute directly.

resolve_control_plane_contract_ref() {
  if [[ -n "${CONTRACT_REF:-}" ]]; then
    echo "${CONTRACT_REF}"
    return 0
  fi

  if [[ -n "${PLATFORM_CONTROL_PLANE_REF:-}" ]]; then
    echo "${PLATFORM_CONTROL_PLANE_REF}"
    return 0
  fi

  local repo_root="${REPO_ROOT:-$(pwd)}"
  local -a roots=()

  if [[ -n "${PLATFORM_CONTROL_PLANE_ROOT:-}" ]]; then
    roots+=("${PLATFORM_CONTROL_PLANE_ROOT}")
  fi
  if [[ -n "${WAVE10_PCP_ROOT:-}" ]]; then
    roots+=("${WAVE10_PCP_ROOT}")
  fi

  roots+=(
    "${repo_root}/../platform-control-plane"
    "${repo_root}/../../platform-control-plane"
    "${HOME}/projects/k8s/platform-control-plane"
    "${HOME}/projects/platform-control-plane"
  )

  local root sha
  for root in "${roots[@]}"; do
    [[ -n "${root}" && -d "${root}" ]] || continue
    [[ -f "${root}/contracts/release-contracts.yaml" ]] || continue
    sha="$(git -C "${root}" rev-parse HEAD 2>/dev/null || true)"
    if [[ "${sha}" =~ ^[0-9a-f]{40}$ ]]; then
      echo "Biji-Biji-Initiative/platform-control-plane@${sha}"
      return 0
    fi
  done

  echo "Biji-Biji-Initiative/platform-control-plane@194e6001c924902e8bf3dafefdc37fc842c56653"
}
