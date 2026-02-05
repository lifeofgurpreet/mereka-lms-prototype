#!/usr/bin/env bash
# Validate Site + SiteConfiguration entries for academyv2 microsites.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
STRICT="${STRICT:-0}"
CONTEXT_ARGS=()
if [[ -n "${K8S_CONTEXT:-}" ]]; then
  CONTEXT_ARGS+=(--context "${K8S_CONTEXT}")
fi

DOMAINS=(
  "${LMS_DOMAIN}"
  "${BIJI_DOMAIN}"
  "${SKILLOURFUTURE_DOMAIN}"
)

export DOMAINS_CSV
DOMAINS_CSV=$(IFS=, ; echo "${DOMAINS[*]}")

kubectl "${CONTEXT_ARGS[@]}" exec -i -n "${NAMESPACE}" deploy/lms -- env DOMAINS="${DOMAINS_CSV}" STRICT="${STRICT}" python - <<'PY'
import os
import sys
import django

django.setup()

from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration

domains = [d.strip() for d in os.environ.get("DOMAINS", "").split(",") if d.strip()]
strict = os.environ.get("STRICT", "0") == "1"

missing = []
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

if missing and strict:
    sys.exit(1)
PY
