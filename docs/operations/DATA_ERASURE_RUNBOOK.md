# Data Erasure Runbook (Right to Erasure / Right to be Forgotten)

> **Regulations**: PDPA (Malaysia) — 30 days; GDPR (EU) — 30 days
> **Owner**: platform-engineering
> **Last Updated**: 2026-02-25
> **Contact**: privacy@mereka.io

## Timeline

| Milestone | SLA |
|-----------|-----|
| Acknowledge request | 3 business days |
| Verify identity | 5 business days |
| Execute all erasure steps | Within 30 days of verified request |
| Confirm completion | Within 30 days |

## Pre-Erasure

- [ ] Identity verified (government ID or login verification)
- [ ] No legal hold (active dispute, fraud investigation, court order)
- [ ] Note: financial records (orders) retain 7 years per Companies Act 2016 — PII fields anonymized only

Collect before starting:
```bash
USERNAME="<open_edx_username>"
EMAIL="<user_email>"
EMAIL_HASH=$(echo -n "$EMAIL" | sha256sum | cut -c1-16)
RETIRED_EMAIL="retired_${EMAIL_HASH}@retired.invalid"
```

---

## Step 1 — Open edX Retirement Pipeline

Handles: `auth_user` anonymization, `auth_userprofile` deletion, `social_auth_usersocialauth` deletion, forum author anonymization, session invalidation, certificate revocation. Full details: `docs/operations/GDPR_COMPLIANCE.md` §2.

```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms retirement_retire_learner --username "$USERNAME"

kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms perform_retirement --username "$USERNAME"

# Verify: expected state = COMPLETE
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms show_retirement_states --username "$USERNAME"
```

If pipeline fails mid-run: `python manage.py lms retire_user --username "$USERNAME" --force`

---

## Step 2 — Purchase Gateway (PostgreSQL)

```bash
PG_POD=$(kubectl get pod -n mereka-lms -l app=payments-gateway \
  -o jsonpath='{.items[0].metadata.name}')

# Anonymize orders (retain financial data — Companies Act 2016, 7 years)
kubectl exec -n mereka-lms "$PG_POD" -- python -c "
from app.database import get_session
from app.models.order import Order
from sqlalchemy import update
with get_session() as db:
    r = db.execute(update(Order).where(Order.buyer_email=='${EMAIL}').values(
        buyer_email='${RETIRED_EMAIL}', buyer_user_id=None, stripe_customer_id=None))
    db.commit(); print(f'{r.rowcount} order(s) anonymized')
"

# Anonymize entitlements
kubectl exec -n mereka-lms "$PG_POD" -- python -c "
from app.database import get_session
from app.models.entitlement import Entitlement
from sqlalchemy import update
with get_session() as db:
    r = db.execute(update(Entitlement).where(Entitlement.recipient_email=='${EMAIL}').values(
        recipient_email='${RETIRED_EMAIL}', claimed_by_user_id=None))
    db.commit(); print(f'{r.rowcount} entitlement(s) anonymized')
"
```

Note: `stripe_events.payload_json` may embed buyer email — manually review records for this user before the 90-day auto-deletion job runs.

---

## Step 3 — Stripe (External)

Record the `stripe_customer_id` from the orders table (before Step 2 clears it), then:

```bash
curl -X DELETE "https://api.stripe.com/v1/customers/<stripe_customer_id>" \
  -u "$STRIPE_SECRET_KEY:"
```

Or: Stripe Dashboard → Customers → search by email → Delete. Stripe retains charge records for tax purposes; only customer PII is removed.

---

## Step 4 — Meilisearch Forum Index

After Step 1 anonymizes MongoDB forum authors, re-index to propagate changes:

```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms reindex_forum
```

---

## Step 5 — HubSpot CRM

The Open edX retirement pipeline does NOT touch HubSpot. Delete manually:

```bash
# Get contact ID
curl -H "Authorization: Bearer $HUBSPOT_PAT" \
  "https://api.hubapi.com/contacts/v1/contact/email/$EMAIL/profile" | jq '.vid'

# Delete contact (permanent)
curl -X DELETE -H "Authorization: Bearer $HUBSPOT_PAT" \
  "https://api.hubapi.com/contacts/v1/contact/vid/<contact_vid>"
```

---

## Step 6 — GCS Files and Firestore

```bash
BUCKET="gs://mereka-lms-static"
gsutil rm "$BUCKET/profile-images/${USERNAME}*" 2>/dev/null || true
gsutil rm "$BUCKET/certificates/*${USERNAME}*" 2>/dev/null || true

# Delete HubSpot webhook dedup record
firebase firestore:delete --project mereka-lms /hubspot_registrations/"$EMAIL"
```

GCS backup snapshots rotate every 90 days automatically. Document the erasure date; backups older than that date age out within 90 days.

---

## Step 7 — Verify and Document

```bash
# Confirm user is retired in Open edX
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from django.contrib.auth import get_user_model
u = get_user_model().objects.filter(email__contains='${EMAIL}').first()
print('Found:', u)  # Should be None or retired_ prefixed
"

./scripts/qa/verify-pii-inventory.sh
```

Create an erasure log entry in `docs/operations/postmortems/` or a dedicated erasure register:
```
Date: YYYY-MM-DD
Username hash: sha256(<username>)[:16]
Steps completed: 1,2,3,4,5,6
Backup window expires: YYYY-MM-DD (+90 days)
Confirmed to requester: YYYY-MM-DD
```

---

## Known Gaps

| Gap | Risk | Remediation |
|-----|------|-------------|
| Firestore dedup records have no automated TTL | Low | Add Firestore TTL rule |
| `stripe_events.payload_json` may embed email | Medium | Manual review required in Step 2 |
| HubSpot deletion is manual (no scripted automation) | Medium | Add HubSpot API to a dedicated erasure script |
| GCP Cloud Logging retains Firebase logs with PII | Low | Reduce Firebase function log retention to 7 days |

---

## References

- PII inventory: `docs/operations/PII_DATA_INVENTORY.md`
- GDPR runbook: `docs/operations/GDPR_COMPLIANCE.md`
- Spec: `specs/data-privacy-gdpr-compliance_spec.md`
- Open edX retirement: https://docs.openedx.org/en/latest/developers/references/user_retirement/index.html
- PDPA Malaysia: https://www.pdp.gov.my/ | GDPR Art 17: https://gdpr-info.eu/art-17-gdpr/
