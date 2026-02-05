#!/usr/bin/env bash
# Validate ecommerce OAuth + site configuration (non-secret checks).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
STRICT="${STRICT:-0}"
CONTEXT_ARGS=()
if [[ -n "${K8S_CONTEXT:-}" ]]; then
  CONTEXT_ARGS+=(--context "${K8S_CONTEXT}")
fi

failures=0

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

run_lms_checks() {
  log "Checking LMS OAuth2 apps + scopes..."
  kubectl "${CONTEXT_ARGS[@]}" exec -i -n "${NAMESPACE}" deploy/lms -- env STRICT="${STRICT}" python - <<'PY'
import os
import sys
import django

django.setup()

from oauth2_provider.models import Application
from openedx.core.djangoapps.oauth_dispatch.models import ApplicationAccess

strict = os.environ.get("STRICT", "0") == "1"
missing = []

apps = {
    "ecommerce": Application.objects.filter(client_id="ecommerce").first(),
    "ecommerce-sso": Application.objects.filter(client_id="ecommerce-sso").first(),
}

for key, app in apps.items():
    if not app:
        print(f"{key}: MISSING")
        missing.append(key)
        continue
    print(f"{key}: grant={app.authorization_grant_type} redirects={app.redirect_uris}")
    access = ApplicationAccess.objects.filter(application=app).first()
    scopes = access.scopes if access else None
    print(f"{key}: scopes={scopes}")
    if not scopes or "user_id" not in scopes:
        missing.append(f"{key}_scopes")

if missing and strict:
    sys.exit(1)
PY
}

run_ecommerce_checks() {
  log "Checking ecommerce SiteConfiguration + Partner..."
  kubectl "${CONTEXT_ARGS[@]}" exec -i -n "${NAMESPACE}" deploy/ecommerce -- python - <<'PY'
import django
django.setup()

from django.contrib.sites.models import Site
from ecommerce.core.models import SiteConfiguration
from oscar.core.loading import get_model
from ecommerce.extensions.payment.models import PaypalProcessorConfiguration

Partner = get_model("partner", "Partner")

sites = {s.domain: s for s in Site.objects.all()}
for domain in ["ecommerce.academyv2.mereka.io", "ecommerce.academyv2.mereka.dev", "ecommerce.localhost"]:
    site = sites.get(domain)
    if not site:
        print(f"{domain}: SITE_MISSING")
        continue
    cfg = SiteConfiguration.objects.filter(site=site).first()
    if not cfg:
        print(f"{domain}: CONFIG_MISSING")
        continue
    print(f"{domain}: lms_url_root={cfg.lms_url_root} payment_processors={cfg.payment_processors}")

print("Partners:", [(p.code, p.short_code) for p in Partner.objects.all()])
print("Paypal configs:", [(p.name, p.enabled) for p in PaypalProcessorConfiguration.objects.all()])
PY
}

run_lms_checks || failures=$((failures + 1))
run_ecommerce_checks || failures=$((failures + 1))

if [[ "${STRICT}" == "1" && "${failures}" -gt 0 ]]; then
  log "Ecommerce config checks failed."
  exit 1
fi

log "Ecommerce config checks completed."
