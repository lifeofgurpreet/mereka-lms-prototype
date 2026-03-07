#!/usr/bin/env bash
# Lane normalization library for Mereka LMS.
# Source this file; do not execute directly.
#
# Canonical lane names (matching GitOps): dev, staging, prod
# Legacy names used in some scripts: rke2-nonprod, nonprod, production, local
#
# Reference: config/lane-identity.yaml

# normalize_lane_to_canonical <input>
# Maps any legacy or variant lane name to the canonical GitOps name.
# Returns empty string and exit 1 for unknown inputs.
normalize_lane_to_canonical() {
  local input
  input="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
  case "$input" in
    dev|rke2-nonprod|nonprod)
      echo "dev" ;;
    staging|stage|stg)
      echo "staging" ;;
    prod|production)
      echo "prod" ;;
    local)
      echo "local" ;;
    *)
      echo "Unknown lane: $1" >&2
      return 1 ;;
  esac
}

# normalize_lane_to_overlay <canonical_lane>
# Maps a canonical lane name to the LMS overlay directory name.
normalize_lane_to_overlay() {
  case "$1" in
    dev)     echo "rke2-nonprod" ;;
    staging) echo "staging" ;;
    prod)    echo "production" ;;
    local)   echo "local" ;;
    *)
      echo "Unknown canonical lane: $1" >&2
      return 1 ;;
  esac
}

# normalize_lane_to_namespace <canonical_lane>
# Maps a canonical lane name to the Kubernetes namespace.
normalize_lane_to_namespace() {
  case "$1" in
    dev)     echo "mereka-lms-dev" ;;
    staging) echo "stg-mereka-lms" ;;
    prod)    echo "mereka-lms" ;;
    *)
      echo "Unknown canonical lane: $1" >&2
      return 1 ;;
  esac
}

# is_valid_target_environment <value>
# Returns 0 if the value is a valid target_environment for proof artifacts.
# Accepts both canonical and legacy names.
is_valid_target_environment() {
  case "$1" in
    dev|nonprod|staging|production|prod|rke2-nonprod) return 0 ;;
    *) return 1 ;;
  esac
}
