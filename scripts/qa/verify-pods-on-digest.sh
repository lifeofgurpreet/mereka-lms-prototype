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
#   verify-pods-on-digest.sh -n mereka-lms-dev -s app.kubernetes.io/name=cms-worker -d sha256:edc9cb33...
#
# Exit codes:
#   0  All pods on expected digest
#   1  At least one pod on a different digest
#   2  Usage / environment error (e.g., no pods match selector, no digest arg)
# -----------------------------------------------------------------------------
# Closes: mereka-lms-lb4c.4 (S6.4 — gate promotion on pod imageID match)
# -----------------------------------------------------------------------------
set -euo pipefail

NAMESPACE=""
SELECTOR=""
EXPECTED_DIGEST=""
VERBOSE=0

die() { echo "error: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="${2:-}"; shift 2 ;;
    -s|--selector)  SELECTOR="${2:-}"; shift 2 ;;
    -d|--digest)    EXPECTED_DIGEST="${2:-}"; shift 2 ;;
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

# Fetch all matching pods and their container imageIDs. Use imageID (not image)
# because image is the tag the pod asked for; imageID is the resolved digest
# that actually got pulled.
pods_json="$(kubectl -n "$NAMESPACE" get pods -l "$SELECTOR" -o json 2>/dev/null || true)"
[[ -n "$pods_json" ]] || die "no response from kubectl for ns=$NAMESPACE selector=$SELECTOR"

pod_count="$(echo "$pods_json" | jq '.items | length')"
if [[ "$pod_count" -eq 0 ]]; then
  die "no pods matched ns=$NAMESPACE selector=$SELECTOR"
fi

# Extract (pod, imageID) pairs for non-init containers.
mismatches=0
total=0
while IFS=$'\t' read -r pod image_id phase ready; do
  total=$((total+1))
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "pod=$pod phase=$phase ready=$ready imageID=$image_id"
  fi
  # Match expected digest as a substring of imageID (imageID usually looks
  # like 'ghcr.io/...@sha256:XXX'; we only care about the sha256 suffix).
  if [[ "$image_id" != *"$EXPECTED_DIGEST"* ]]; then
    echo "MISMATCH: pod=$pod imageID=$image_id (expected *${EXPECTED_DIGEST})" >&2
    mismatches=$((mismatches+1))
  fi
done < <(echo "$pods_json" | jq -r '
  .items[] |
  [
    .metadata.name,
    (.status.containerStatuses[0].imageID // "-"),
    (.status.phase // "-"),
    ([.status.containerStatuses[]?.ready] | all | tostring)
  ] | @tsv
')

if [[ "$mismatches" -gt 0 ]]; then
  echo "FAIL: $mismatches of $total pod(s) in ns=$NAMESPACE selector='$SELECTOR' are not on expected digest ${EXPECTED_DIGEST}" >&2
  echo "Hint: Argo may have reported sync=Synced while the rollout was silently stuck. Try:" >&2
  echo "  kubectl -n argocd annotate application <app-name> argocd.argoproj.io/refresh=hard --overwrite" >&2
  echo "(See bead infrastructure-nj48 / docs/runbooks/ArgoAppSelfHealStuck.md)" >&2
  exit 1
fi

echo "PASS: all $total pod(s) in ns=$NAMESPACE selector='$SELECTOR' are on expected digest ${EXPECTED_DIGEST}"
exit 0
