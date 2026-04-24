#!/usr/bin/env bash
# verify-pods-on-digest.sh
# -----------------------------------------------------------------------------
# Assert that all pods of a given selector in a namespace are running the
# expected container imageID (digest), not just that the Deployment spec
# claims it. Addresses the silent-sync-stuck class observed on 2026-04-18
# (bead infrastructure-nj48): Argo reports sync=Synced / health=Healthy while
# the live pods are still on a previous digest.
#
# Usage:
#   verify-pods-on-digest.sh --namespace <ns> --selector <label-selector> --digest <sha256:...>
#     [--context <kubectl-context>] [--container <name>]
#   verify-pods-on-digest.sh -n mereka-lms-dev -s app.kubernetes.io/name=cms-worker -d sha256:edc9cb33...
#   verify-pods-on-digest.sh --context rke2-prod -n mereka-lms \
#     -s app.kubernetes.io/name=lms --container lms -d sha256:b08fbb62...
#
# Exit codes:
#   0  All pods on expected digest
#   1  At least one pod on a different digest
#   2  Usage / environment error (e.g., no pods match selector, no digest arg)
# -----------------------------------------------------------------------------
# Closes: mereka-lms-lb4c.4 (S6.4 — gate promotion on pod imageID match)
# Hardened: mereka-lms-lb4c.8 (--context + per-container selection)
# -----------------------------------------------------------------------------
set -euo pipefail

NAMESPACE=""
SELECTOR=""
EXPECTED_DIGEST=""
CONTEXT=""
CONTAINER_NAME=""
VERBOSE=0

die() { echo "error: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="${2:-}"; shift 2 ;;
    -s|--selector)  SELECTOR="${2:-}"; shift 2 ;;
    -d|--digest)    EXPECTED_DIGEST="${2:-}"; shift 2 ;;
    -c|--context)   CONTEXT="${2:-}"; shift 2 ;;
    --container)    CONTAINER_NAME="${2:-}"; shift 2 ;;
    -v|--verbose)   VERBOSE=1; shift ;;
    -h|--help)
      sed -n '1,25p' "$0"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$NAMESPACE" ]]        || die "--namespace is required"
[[ -n "$SELECTOR" ]]         || die "--selector is required"
[[ -n "$EXPECTED_DIGEST" ]]  || die "--digest is required"

# Normalize digest form — accept both full 'sha256:XXX' and bare 'XXX'
case "$EXPECTED_DIGEST" in
  sha256:*) ;;
  [0-9a-f][0-9a-f]*) EXPECTED_DIGEST="sha256:${EXPECTED_DIGEST}" ;;
  *) die "--digest must be 'sha256:...' or a bare hex digest" ;;
esac

command -v kubectl >/dev/null 2>&1 || die "kubectl not found in PATH"
command -v jq      >/dev/null 2>&1 || die "jq not found in PATH"

# Build kubectl context flag if provided. All kubectl invocations must use it
# so runbook callers can point this at any cluster without mutating their
# ambient kube context (bead lb4c.8 gap #1).
KUBECTL_ARGS=()
if [[ -n "$CONTEXT" ]]; then
  KUBECTL_ARGS+=( "--context" "$CONTEXT" )
fi

# Fetch all matching pods and their container imageIDs. Use imageID (not image)
# because image is the tag the pod asked for; imageID is the resolved digest
# that actually got pulled.
pods_json="$(kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get pods -l "$SELECTOR" -o json 2>/dev/null || true)"
[[ -n "$pods_json" ]] || die "no response from kubectl for ns=$NAMESPACE selector=$SELECTOR${CONTEXT:+ context=$CONTEXT}"

pod_count="$(echo "$pods_json" | jq '.items | length')"
if [[ "$pod_count" -eq 0 ]]; then
  die "no pods matched ns=$NAMESPACE selector=$SELECTOR${CONTEXT:+ context=$CONTEXT}"
fi

# Extract (pod, container, imageID, phase, ready) rows. If --container was
# supplied, filter to that container name only; otherwise iterate across all
# container statuses so a sidecar on a different digest still gets caught
# (bead lb4c.8 gap #2). This replaces the prior containerStatuses[0] lookup,
# which silently mis-reported the moment a workload gained a sidecar or the
# container ordering changed.
if [[ -n "$CONTAINER_NAME" ]]; then
  jq_filter='
    .items[] as $pod |
    ($pod.status.containerStatuses // [])[]? |
    select(.name == $name) |
    [
      $pod.metadata.name,
      .name,
      (.imageID // "-"),
      ($pod.status.phase // "-"),
      (.ready | tostring)
    ] | @tsv
  '
  jq_args=( --arg name "$CONTAINER_NAME" )
else
  jq_filter='
    .items[] as $pod |
    ($pod.status.containerStatuses // [])[]? |
    [
      $pod.metadata.name,
      .name,
      (.imageID // "-"),
      ($pod.status.phase // "-"),
      (.ready | tostring)
    ] | @tsv
  '
  jq_args=()
fi

mismatches=0
total=0
while IFS=$'\t' read -r pod container image_id phase ready; do
  [[ -z "$pod" ]] && continue
  total=$((total+1))
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "pod=$pod container=$container phase=$phase ready=$ready imageID=$image_id"
  fi
  # Match expected digest as a substring of imageID (imageID usually looks
  # like 'ghcr.io/...@sha256:XXX'; we only care about the sha256 suffix).
  if [[ "$image_id" != *"$EXPECTED_DIGEST"* ]]; then
    echo "MISMATCH: pod=$pod container=$container imageID=$image_id (expected *${EXPECTED_DIGEST})" >&2
    mismatches=$((mismatches+1))
  fi
done < <(echo "$pods_json" | jq -r "${jq_args[@]}" "$jq_filter")

if [[ "$total" -eq 0 ]]; then
  if [[ -n "$CONTAINER_NAME" ]]; then
    die "no container named '$CONTAINER_NAME' found in any pod matching ns=$NAMESPACE selector=$SELECTOR"
  fi
  die "no container statuses found for pods matching ns=$NAMESPACE selector=$SELECTOR (pods not yet started?)"
fi

if [[ "$mismatches" -gt 0 ]]; then
  echo "FAIL: $mismatches of $total container(s) in ns=$NAMESPACE selector='$SELECTOR'${CONTAINER_NAME:+ container=$CONTAINER_NAME} are not on expected digest ${EXPECTED_DIGEST}" >&2
  echo "Hint: Argo may have reported sync=Synced while the rollout was silently stuck. Try:" >&2
  echo "  kubectl ${KUBECTL_ARGS[*]} -n argocd annotate application <app-name> argocd.argoproj.io/refresh=hard --overwrite" >&2
  echo "(See bead infrastructure-nj48 / docs/runbooks/ArgoAppSelfHealStuck.md)" >&2
  exit 1
fi

echo "PASS: all $total container(s) in ns=$NAMESPACE selector='$SELECTOR'${CONTAINER_NAME:+ container=$CONTAINER_NAME} are on expected digest ${EXPECTED_DIGEST}"
exit 0
