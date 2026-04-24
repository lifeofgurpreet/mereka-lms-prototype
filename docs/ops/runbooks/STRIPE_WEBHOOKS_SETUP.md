# Stripe Webhooks Setup
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-04-10 • Status: active_

This is the current webhook setup guide for the Purchase Gateway payment lane.

For the stable system model, dual-stack transition boundary, and non-webhook
commerce ownership split, start with
[Purchase Gateway Overview](../../concepts/architecture/purchase-gateway-overview.md).

Use it to:

- register the right Stripe endpoint
- sync the current webhook signing secret through the governed bridge
- validate delivery to the gateway webhook handler
- distinguish current gateway setup from legacy Oscar continuity

Without webhooks, purchases can look successful in Stripe while staying stuck as
`pending` or never entering the fulfillment queue.

## Endpoint

Stripe should send events to:

- Prod: `https://academyv2.mereka.io/payments/webhooks/stripe/`
- Dev: `https://academyv2.mereka.dev/payments/webhooks/stripe/`

External Caddy routing strips `/payments` and forwards to the gateway's
internal `/webhooks/stripe/` route.

For current production behavior, treat the purchase-gateway endpoint as the
primary authority. Legacy Oscar endpoints are historical continuity only.

## Required Secret

Stripe signs webhook requests. The Purchase Gateway verifies the signature using
the webhook signing secret (`whsec_...`) which must be injected as:

- Prod: `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY`
- Dev: `MEREKA_LMS_STRIPE_WEBHOOK_SECRET_GATEWAY_DEV` when the dev lane uses
  distinct gateway secrets

K8s maps this to the container env var:
- `STRIPE_WEBHOOK_SECRET`

For a real purchase-ready lane, treat this secret as required.

## Stripe Dashboard Setup

1. Stripe Dashboard
2. Developers -> Webhooks -> Add endpoint
3. Set the endpoint URL (prod or dev)
4. Subscribe to the current gateway event set:
   - `checkout.session.completed`
   - `checkout.session.expired`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `charge.refunded`
   - `charge.refund.updated`
   - `charge.dispute.created`
   - `charge.dispute.closed`
   - subscription and invoice events if enterprise recurring billing is active
5. Copy the webhook signing secret (`whsec_...`)
6. Save it into Infisical under the correct gateway secret key.

## Propagate Secret Through the Governed Bridge

This repo uses External Secrets Operator (ESO) through the governed secrets bridge.
The current production implementation still resolves through
`gcp-secret-manager`. Use the sync helper to move the new secret through that
bridge:

```bash
INFISICAL_ENV=prod ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
INFISICAL_ENV=dev ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
```

Then restart the gateway workloads so env vars are reloaded:

```bash
kubectl rollout restart deploy/payments-gateway deploy/payments-worker -n mereka-lms
kubectl --context kind-dev rollout restart deploy/payments-gateway deploy/payments-worker -n mereka-lms
```

## Verify

```bash
./scripts/qa/verify-purchase-gateway-k8s.sh --online
./scripts/qa/verify-caddy-payments-route.sh
```

## Verify Webhook Delivery (Without Stripe CLI)

This sends a locally signed webhook payload (using the webhook secret already
injected into the running gateway pod) and expects HTTP 200.

```bash
./scripts/qa/test-stripe-webhook-delivery.sh prod
K8S_CONTEXT=kind-dev ./scripts/qa/test-stripe-webhook-delivery.sh dev
```

After the probe succeeds, confirm the order lane advances out of `pending`. A
`200` alone proves receipt, not full learner fulfillment.

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
stripe listen --forward-to https://academyv2.mereka.dev/payments/webhooks/stripe/
```

3. Trigger test events:
```bash
stripe trigger payment_intent.succeeded
stripe trigger payment_intent.payment_failed
stripe trigger payment_intent.requires_action
```

If your dev endpoint is not publicly reachable, port-forward or use a tunnel.

## Legacy Oscar continuity

Legacy Oscar webhook setup is no longer the primary authority for current
production purchases. Keep the old `ecommerce.*` endpoints only if the dual
stack transition still explicitly requires them. Do not route new operator work
through the Oscar endpoint by default.
