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
  # Use manage.py so settings/env are consistent with the running LMS.
  kubectl "${CONTEXT_ARGS[@]}" exec -i -n "${NAMESPACE}" deploy/lms -- env STRICT="${STRICT}" \
    python /openedx/edx-platform/manage.py lms shell -c '
import os
import sys

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
'
}

run_ecommerce_checks() {
  log "Checking ecommerce SiteConfiguration + Partner..."
  kubectl "${CONTEXT_ARGS[@]}" exec -i -n "${NAMESPACE}" deploy/ecommerce -- env REQUIRE_STRIPE_WEBHOOK_SECRET="${REQUIRE_STRIPE_WEBHOOK_SECRET:-0}" python - <<'PY'
import django
django.setup()

import os
import importlib
import sys
from django.contrib.sites.models import Site
from ecommerce.core.models import SiteConfiguration
from oscar.core.loading import get_model
from ecommerce.extensions.payment.models import PaypalProcessorConfiguration
from django.conf import settings

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

# Stripe env sanity (do not print values).
def present(k: str) -> bool:
    v = (os.environ.get(k) or "").strip()
    return bool(v and not v.startswith("REPLACE_") and v != "REPLACE_ME")

def stripe_key_type(value: str) -> str:
    v = (value or "").strip()
    if not v or v.startswith("REPLACE_") or v == "REPLACE_ME":
        return "missing"
    # Stripe webhook signing secrets don't encode test/live in the prefix.
    # They are always shaped like "whsec_...".
    if v.startswith("whsec_"):
        return "set"
    if v.startswith(("sk_live_", "pk_live_", "whsec_live_")):
        return "live"
    if v.startswith(("sk_test_", "pk_test_")):
        return "test"
    return "unknown"

require_webhook = (os.environ.get("REQUIRE_STRIPE_WEBHOOK_SECRET") or "0") == "1"
webhook_present = present("STRIPE_WEBHOOK_SECRET")
if require_webhook and not webhook_present:
    print("ERROR: STRIPE_WEBHOOK_SECRET missing but required (set REQUIRE_STRIPE_WEBHOOK_SECRET=0 to skip).")
    sys.exit(1)

print(
    "Stripe env present:",
    {
        "STRIPE_SECRET_KEY": present("STRIPE_SECRET_KEY"),
        "STRIPE_PUBLISHABLE_KEY": present("STRIPE_PUBLISHABLE_KEY"),
        # Webhook is optional until webhooks are configured.
        "STRIPE_WEBHOOK_SECRET": webhook_present,
    },
)
print(
    "Stripe key types:",
    {
        "STRIPE_SECRET_KEY": stripe_key_type(os.environ.get("STRIPE_SECRET_KEY", "")),
        "STRIPE_PUBLISHABLE_KEY": stripe_key_type(os.environ.get("STRIPE_PUBLISHABLE_KEY", "")),
        "STRIPE_WEBHOOK_SECRET": stripe_key_type(os.environ.get("STRIPE_WEBHOOK_SECRET", "")),
    },
)

# Stripe settings sanity: verify our Tutor settings loaded Stripe values into
# PAYMENT_PROCESSOR_CONFIG and the Stripe processor module imports cleanly.
cfg = (getattr(settings, "PAYMENT_PROCESSOR_CONFIG", {}) or {}).get("openedx") or {}
stripe = cfg.get("stripe") or {}

stripe_secret = stripe.get("secret_key") or ""
stripe_pub = stripe.get("publishable_key") or ""
stripe_webhook = stripe.get("webhook_endpoint_secret") or ""

try:
    importlib.import_module("ecommerce.extensions.payment.processors.stripe")
    stripe_module_ok = True
except Exception:
    stripe_module_ok = False

print(
    "Stripe settings:",
    {
        "stripe_present": bool(stripe),
        # Don't print any portion of the keys (even prefixes) to keep logs safe.
        "secret_set": bool(stripe_secret and not str(stripe_secret).startswith("REPLACE_")),
        "publishable_set": bool(stripe_pub and not str(stripe_pub).startswith("REPLACE_")),
        "webhook_set": bool((stripe_webhook or "").strip()) and not str(stripe_webhook).startswith("REPLACE_"),
        "secret_type": stripe_key_type(stripe_secret),
        "publishable_type": stripe_key_type(stripe_pub),
        "webhook_type": stripe_key_type(stripe_webhook),
        "processor_import_ok": stripe_module_ok,
    },
)
PY
}

run_lms_checks || failures=$((failures + 1))
run_ecommerce_checks || failures=$((failures + 1))

if [[ "${STRICT}" == "1" && "${failures}" -gt 0 ]]; then
  log "Ecommerce config checks failed."
  exit 1
fi

log "Ecommerce config checks completed."
