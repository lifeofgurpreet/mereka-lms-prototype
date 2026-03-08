# Stripe Webhooks (Ecommerce)
_Audience: Platform Eng • Last updated: 2026-02-17_

> **DEPRECATED**: This document covers Stripe webhook integration for the legacy Oscar-based ecommerce service. The custom Purchase Gateway (`services/purchase-gateway/`) handles its own Stripe integration. See `specs/ecommerce-purchase-gateway_spec.md` for the migration plan and `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md` for the architectural decision. Retained for reference during the transition period.

Ecommerce uses Stripe webhooks to verify and finalize payment state changes.
Without webhooks, you can see inconsistent behavior at scale (orders stuck as
pending, delayed enrollments, or retries not being processed).

## Endpoint

Stripe should send events to:

- Prod (GKE): `https://ecommerce.academyv2.mereka.io/api/v2/webhooks/stripe/`
- Dev (kind): `https://ecommerce.academyv2.mereka.dev/api/v2/webhooks/stripe/`

This route is defined in the ecommerce service:
`/api/v2/webhooks/stripe/` (Django: `extensions/api/v2/urls.py`).

## Required Secret

Stripe signs webhook requests. Ecommerce verifies the signature using the
webhook signing secret (`whsec_...`) which must be injected as:

- Prod: `MEREKA_LMS_STRIPE_WEBHOOK_SECRET` (Infisical env `prod`, path `/k8s/mereka-lms`)
- Dev: `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_DEV` (Infisical env `dev`, path `/k8s/mereka-lms`)

K8s maps this to the container env var:
- `STRIPE_WEBHOOK_SECRET`

Note: our current scripts treat this as **optional** until webhooks are
configured, but for real checkout readiness you should require it.

## Stripe Dashboard Setup

1. Stripe Dashboard
2. Developers -> Webhooks -> Add endpoint
3. Set the endpoint URL (prod or dev)
4. Subscribe to events (minimum for current code paths):
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `payment_intent.requires_action`
5. Copy the webhook signing secret (`whsec_...`)
6. Save it into Infisical under the correct key (prod vs dev).

## Propagate Secret to GKE (Infisical -> GCP SM -> ExternalSecrets)

This repo uses External Secrets Operator (ESO) reading from GCP Secret Manager.
Use the sync helper to ensure the new secret exists in GCP SM:

```bash
INFISICAL_ENV=prod ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
INFISICAL_ENV=dev ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
```

Then restart ecommerce workloads so env vars are reloaded:

```bash
kubectl rollout restart deploy/ecommerce deploy/ecommerce-worker -n mereka-lms
kubectl --context kind-dev rollout restart deploy/ecommerce deploy/ecommerce-worker -n mereka-lms
```

## Verify

```bash
REQUIRE_STRIPE_WEBHOOK_SECRET=1 ./scripts/qa/verify-ecommerce-config.sh
REQUIRE_STRIPE_WEBHOOK_SECRET=1 K8S_CONTEXT=kind-dev ./scripts/qa/verify-ecommerce-config.sh
```

## Verify Webhook Delivery (Without Stripe CLI)

This sends a locally signed webhook payload (using the webhook secret already
injected into the running ecommerce pod) and expects HTTP 200.

```bash
./scripts/qa/test-stripe-webhook-delivery.sh prod
K8S_CONTEXT=kind-dev ./scripts/qa/test-stripe-webhook-delivery.sh dev
```

## Stripe CLI (Dev Testing)

Stripe CLI is installed on this VPS as `~/.local/bin/stripe`.

Note: this repo’s primary verification path does **not** require Stripe CLI login:
use `./scripts/qa/test-stripe-webhook-delivery.sh` which signs the payload using the
webhook secret already injected into the running ecommerce pod. Stripe CLI is optional
for interactive dev iteration.

1. Login (interactive):
```bash
stripe login
```

2. Forward webhook events to your dev endpoint:
```bash
stripe listen --forward-to https://ecommerce.academyv2.mereka.dev/api/v2/webhooks/stripe/
```

3. Trigger test events:
```bash
stripe trigger payment_intent.succeeded
stripe trigger payment_intent.payment_failed
stripe trigger payment_intent.requires_action
```

If your dev endpoint is not publicly reachable, port-forward or use a tunnel.
