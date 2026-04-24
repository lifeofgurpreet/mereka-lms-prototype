#!/usr/bin/env bash
# Verify parity lane dispatch/context/project contract for parity matrix runs.
#
# Usage:
#   ./scripts/qa/verify-observability-parity-lane-contract.sh \
#     --env-label dev --dispatch-profile nonprod \
#     --k8s-context rke2-nonprod --gcp-project mereka-lms

set -euo pipefail

ENV_LABEL=""
DISPATCH_PROFILE=""
K8S_CONTEXT=""
GCP_PROJECT=""
OUT_JSON=""
OUT_MD=""

usage() {
  cat <<'USAGE'
Usage: ./scripts/qa/verify-observability-parity-lane-contract.sh \
  --env-label <dev|nonprod|prod|custom> \
  --dispatch-profile <nonprod|prod|custom> \
  --k8s-context <context> \
  --gcp-project <project> \
  [--out-json <path>] \
  [--out-md <path>]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-label)
      ENV_LABEL="${2:-}"
      shift 2
      ;;
    --dispatch-profile)
      DISPATCH_PROFILE="${2:-}"
      shift 2
      ;;
    --k8s-context)
      K8S_CONTEXT="${2:-}"
      shift 2
      ;;
    --gcp-project)
      GCP_PROJECT="${2:-}"
      shift 2
      ;;
    --out-json)
      OUT_JSON="${2:-}"
      shift 2
      ;;
    --out-md)
      OUT_MD="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ENV_LABEL" || -z "$DISPATCH_PROFILE" || -z "$K8S_CONTEXT" || -z "$GCP_PROJECT" ]]; then
  usage >&2
  exit 1
fi

failures=0

contract_note=""
case "$ENV_LABEL" in
  dev|nonprod)
    contract_note="dev/nonprod lane must use dispatch_profile=nonprod"
    ;;
  prod)
    contract_note="prod lane must use dispatch_profile=prod"
    ;;
  custom)
    contract_note="custom lane allows explicit profile"
    ;;
  *)
    echo "Unsupported env label: $ENV_LABEL" >&2
    exit 1
    ;;
esac

echo "==> Parity lane contract check"
echo "- env_label: $ENV_LABEL"
echo "- dispatch_profile: $DISPATCH_PROFILE"
echo "- k8s_context: $K8S_CONTEXT"
echo "- gcp_project: $GCP_PROJECT"
echo "- contract: $contract_note"

if [[ "$ENV_LABEL" == "dev" || "$ENV_LABEL" == "nonprod" ]]; then
  if [[ "$DISPATCH_PROFILE" != "nonprod" ]]; then
    echo "FAIL: $ENV_LABEL lane requires dispatch_profile=nonprod" >&2
    failures=$((failures + 1))
  else
    echo "OK: dispatch_profile is nonprod"
  fi
fi

if [[ "$ENV_LABEL" == "prod" ]]; then
  if [[ "$DISPATCH_PROFILE" != "prod" ]]; then
    echo "FAIL: prod lane requires dispatch_profile=prod" >&2
    failures=$((failures + 1))
  else
    echo "OK: dispatch_profile is prod"
  fi
fi

if [[ "$K8S_CONTEXT" == "default" || -z "$K8S_CONTEXT" ]]; then
  echo "FAIL: parity lane context must be explicit, got '$K8S_CONTEXT'" >&2
  failures=$((failures + 1))
else
  echo "OK: explicit k8s context"
fi

if [[ -z "$GCP_PROJECT" ]]; then
  echo "FAIL: gcp project required for parity lane" >&2
  failures=$((failures + 1))
else
  echo "OK: gcp project provided"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Lane contract validation failed with ${failures} error(s)" >&2
  exit 1
fi

echo "Lane contract validation passed"

if [[ -n "$OUT_JSON" ]]; then
  mkdir -p "$(dirname "$OUT_JSON")"
  cat > "$OUT_JSON" <<JSON
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lane": "${ENV_LABEL}",
  "dispatch_profile": "${DISPATCH_PROFILE}",
  "k8s_context": "${K8S_CONTEXT}",
  "gcp_project": "${GCP_PROJECT}",
  "contract": "${contract_note}"
}
JSON
fi

if [[ -n "$OUT_MD" ]]; then
  mkdir -p "$(dirname "$OUT_MD")"
  {
    echo "# Observability Parity Lane Contract"
    echo ""
    echo "- lane: ${ENV_LABEL}"
    echo "- dispatch_profile: ${DISPATCH_PROFILE}"
    echo "- k8s_context: ${K8S_CONTEXT}"
    echo "- gcp_project: ${GCP_PROJECT}"
    echo "- contract: ${contract_note}"
  } > "$OUT_MD"
fi
