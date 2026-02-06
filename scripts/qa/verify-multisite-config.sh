#!/usr/bin/env bash
# Validate Site + SiteConfiguration entries for academyv2 microsites.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

ENVIRONMENT="${1:-prod}"
shift || true
if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Usage: $0 [prod|dev] [--context CONTEXT] [--namespace NS]" >&2
  exit 1
fi

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
STRICT="${STRICT:-0}"
CTX_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      CTX_OVERRIDE="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Default contexts per environment (avoid accidentally checking dev values in prod DB).
DEFAULT_PROD_CTX="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
DEFAULT_DEV_CTX="kind-dev"
K8S_CONTEXT_EFFECTIVE="${CTX_OVERRIDE:-}"
if [[ -z "$K8S_CONTEXT_EFFECTIVE" ]]; then
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    K8S_CONTEXT_EFFECTIVE="${K8S_CONTEXT:-$DEFAULT_PROD_CTX}"
  else
    K8S_CONTEXT_EFFECTIVE="$DEFAULT_DEV_CTX"
  fi
fi

CONTEXT_ARGS=()
if [[ -n "${K8S_CONTEXT_EFFECTIVE:-}" ]]; then
  CONTEXT_ARGS+=(--context "${K8S_CONTEXT_EFFECTIVE}")
fi

if [[ "$ENVIRONMENT" == "prod" ]]; then
  DOMAINS=(
    "${LMS_DOMAIN}"
    "${BIJI_DOMAIN}"
    "${SKILLOURFUTURE_DOMAIN}"
  )
else
  DOMAINS=(
    "${DEV_LMS_DOMAIN}"
  )
fi

export DOMAINS_CSV
DOMAINS_CSV=$(IFS=, ; echo "${DOMAINS[*]}")

EXPECTED_JSON=$(
  python3 - <<PY
import json, os

lms = os.environ.get("LMS_DOMAIN", "academyv2.mereka.io")
studio = os.environ.get("STUDIO_DOMAIN", f"studio.{lms}")
biji = os.environ.get("BIJI_DOMAIN", "academy.biji-biji.com")
biji_studio = os.environ.get("BIJI_STUDIO_DOMAIN", "studio.academy.biji-biji.com")
skill = os.environ.get("SKILLOURFUTURE_DOMAIN", "skillourfuture.academy.mereka.io")
dev = os.environ.get("DEV_LMS_DOMAIN", "academyv2.mereka.dev")

expected = {
  lms: {"LMS_ROOT_URL": f"https://{lms}", "CMS_ROOT_URL": f"https://{studio}"},
  biji: {"LMS_ROOT_URL": f"https://{biji}", "CMS_ROOT_URL": f"https://{biji_studio}"},
  # Skillourfuture currently shares the main Studio domain (no dedicated studio.* DNS).
  skill: {"LMS_ROOT_URL": f"https://{skill}", "CMS_ROOT_URL": f"https://{studio}"},
  dev: {"LMS_ROOT_URL": f"https://{dev}", "CMS_ROOT_URL": f"https://studio.{dev}"},
}

print(json.dumps(expected, sort_keys=True))
PY
)

kubectl "${CONTEXT_ARGS[@]}" exec -i -n "${NAMESPACE}" deploy/lms -- env DOMAINS="${DOMAINS_CSV}" STRICT="${STRICT}" EXPECTED_JSON="${EXPECTED_JSON}" python - <<'PY'
import os
import sys
import json
import django

django.setup()

from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration

domains = [d.strip() for d in os.environ.get("DOMAINS", "").split(",") if d.strip()]
strict = os.environ.get("STRICT", "0") == "1"
expected = json.loads(os.environ.get("EXPECTED_JSON", "{}") or "{}")

missing = []
bad = []
for domain in domains:
    site = Site.objects.filter(domain=domain).first()
    if not site:
        print(f"{domain}: SITE_MISSING")
        missing.append(domain)
        continue
    cfg = SiteConfiguration.objects.filter(site=site).first()
    if not cfg:
        print(f"{domain}: CONFIG_MISSING")
        missing.append(domain)
        continue
    values = cfg.site_values or {}
    theme = values.get("THEME_NAME", "unset")
    lms_root = values.get("LMS_ROOT_URL") or "unset"
    cms_root = values.get("CMS_ROOT_URL") or "unset"
    print(f"{domain}: theme={theme} lms_root={lms_root} cms_root={cms_root}")

    exp = expected.get(domain) or {}
    exp_lms = exp.get("LMS_ROOT_URL")
    exp_cms = exp.get("CMS_ROOT_URL")
    if exp_lms and lms_root != exp_lms:
        bad.append(f"{domain}: LMS_ROOT_URL expected={exp_lms} got={lms_root}")
    if exp_cms and cms_root != exp_cms:
        bad.append(f"{domain}: CMS_ROOT_URL expected={exp_cms} got={cms_root}")

if bad:
    for line in bad:
        print(f"{line} :: MISMATCH")

if missing and strict:
    sys.exit(1)
if bad and strict:
    sys.exit(1)
PY
