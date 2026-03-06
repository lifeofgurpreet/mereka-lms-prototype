# Purchase Gateway Runbook
_Audience: Platform Eng + Operations • Owner: Engineering Lead • Last updated: 2026-02-10_

This runbook covers operational procedures for the Purchase Gateway (Stripe integration).

> **Status**: Purchase Gateway is **not yet implemented** (Tier 2). This runbook documents target-state procedures.
> **Spec**: `specs/ecommerce-purchase-gateway_spec.md`
> **Testmap**: `specs/testmaps/ecommerce-purchase-gateway_spec.testmap.yml`

## Prerequisites

- Access to Stripe dashboard (`https://dashboard.stripe.com`)
- Kubernetes access to `mereka-lms` namespace
- Database read access (PostgreSQL for gateway, MySQL for LMS)
- Infisical access for Stripe API keys

---

## Processing a Manual Refund

### Procedure
1. Verify refund request is legitimate:
   - Check order ID and payment intent ID
   - Confirm no existing refund for this order
2. Initiate refund via Stripe dashboard:
   - Navigate to **Payments** → search for payment intent ID
   - Click **Refund** and enter amount
   - Add reason (e.g., "Customer request", "Course not delivered")
3. Verify webhook triggers enrollment revocation:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=payments-gateway --tail=50 | grep refund
   ```
4. Check LMS enrollment status:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
     python manage.py lms get_enrollment --username <username> --course-id <course-id>
   ```
5. Verify enrollment is revoked (status: `unenrolled`)
6. Send refund confirmation email to customer

### Acceptance
- Refund processes in Stripe within 5-10 business days
- Enrollment is revoked within 5 minutes of webhook receipt
- Customer receives confirmation email
- Refund is logged in gateway database and audit trail

---

## Troubleshooting Failed Webhook Delivery

### Symptoms
- Payment succeeds in Stripe but enrollment not created
- Webhook endpoint shows 4xx/5xx errors in Stripe dashboard

### Diagnosis
1. Check Stripe webhook logs:
   - Navigate to **Developers** → **Webhooks** → select endpoint
   - Review recent delivery attempts and error responses
2. Check gateway logs:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=payments-gateway --tail=100 | grep webhook
   ```
3. Identify common errors:
   - **401 Unauthorized**: Signature verification failed (check webhook secret)
   - **500 Internal Server Error**: Database connection or LMS API failure
   - **504 Gateway Timeout**: Fulfillment took >30 seconds

### Resolution
- **Signature verification failure**:
  ```bash
  # Verify webhook secret in ExternalSecret
  kubectl get secret payments-gateway-secrets -n mereka-lms -o jsonpath='{.data.STRIPE_WEBHOOK_SECRET}' | base64 -d
  ```
- **Database connection failure**:
  ```bash
  # Check PostgreSQL connectivity
  kubectl exec -n mereka-lms -l app.kubernetes.io/name=payments-gateway -- \
    psql $DATABASE_URL -c "SELECT 1;"
  ```
- **LMS API failure**:
  ```bash
  # Test LMS enrollment API
  kubectl exec -n mereka-lms -l app.kubernetes.io/name=lms -- \
    curl -X POST http://localhost:8000/api/enrollment/v1/enrollment \
      -H "Authorization: Bearer $SERVICE_TOKEN" \
      -d '{"user":"test","course_id":"course-v1:Test+101+2024"}'
  ```

### Acceptance
- Webhook endpoint returns 200 OK within 2 seconds
- Failed webhooks are retried by Stripe (up to 3 days)
- Gateway logs show successful fulfillment
- Dead letter queue captures unrecoverable failures

---

## Manual Order Fulfillment

### Procedure (use when order is stuck in `paid`/`fulfillment_failed`/`partially_fulfilled`)
1. Identify candidate orders:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=payments-gateway -- \
     psql "$DATABASE_URL" -c "
     SELECT id, stripe_payment_intent_id, buyer_email, status, fulfilled_at
     FROM orders
     WHERE status IN ('paid', 'fulfillment_failed', 'partially_fulfilled')
     ORDER BY created_at DESC
     LIMIT 20;
     "
   ```
2. Requeue fulfillment via admin endpoint (this resets retry attempts safely):
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=payments-gateway -- \
     curl -X POST "http://localhost:8080/api/v1/admin/orders/<order-id>/retry-fulfillment/" \
       -H "X-API-Key: $ADMIN_API_KEY"
   ```
3. Confirm a pending job exists:
   ```bash
   kubectl exec -n mereka-lms -l app.kubernetes.io/name=payments-gateway -- \
     psql "$DATABASE_URL" -c "
     SELECT order_id, status, attempts, max_attempts, next_attempt_at, last_error
     FROM fulfillment_jobs
     WHERE order_id = '<order-id>';
     "
   ```
4. Verify fulfillment result:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=payments-gateway --tail=200 | \
     grep "fulfillment.job_succeeded\|fulfillment.job_execution_error"
   ```

### Acceptance
- `fulfillment_jobs` row transitions to `pending` and worker picks it up
- Order transitions to `fulfilled` (or remains non-terminal with updated `last_error`)
- Enrollment appears in LMS with `is_active: true` when fulfillment succeeds
- Manual retry is logged as `triggered_by=admin.retry_fulfillment`

---

## Handling Stripe Disputes (Chargebacks)

### Procedure
1. Receive dispute notification via email or Stripe dashboard
2. Review dispute details:
   - Dispute reason (fraudulent, product not received, duplicate charge)
   - Evidence deadline (typically 7-14 days)
3. Gather evidence:
   - Enrollment confirmation email (timestamp)
   - Course access logs showing student activity
   - Certificate of completion (if applicable)
4. Submit evidence via Stripe dashboard:
   - Navigate to **Disputes** → select dispute
   - Upload supporting documents
   - Add written response
5. Monitor dispute resolution:
   - Stripe reviews evidence and makes decision
   - Outcome: won (funds retained) or lost (funds returned to customer)
6. If dispute lost, revoke enrollment (if appropriate)

### Acceptance
- Evidence submitted within deadline (avoid auto-loss)
- All relevant documentation is included
- Dispute outcome is logged in gateway database
- Enrollment status matches dispute outcome

---

## Monitoring Purchase Gateway Health

### Metrics to Watch
```bash
# Checkout success rate (should be >95%)
kubectl exec -n mereka-lms -l app.kubernetes.io/name=prometheus -- \
  promtool query instant 'rate(purchase_gateway_checkout_success_total[5m]) / rate(purchase_gateway_checkout_attempts_total[5m])'

# Fulfillment latency (p95 should be <10s)
kubectl exec -n mereka-lms -l app.kubernetes.io/name=prometheus -- \
  promtool query instant 'histogram_quantile(0.95, purchase_gateway_fulfillment_duration_seconds_bucket)'

# Webhook error rate (should be <1%)
kubectl exec -n mereka-lms -l app.kubernetes.io/name=prometheus -- \
  promtool query instant 'rate(purchase_gateway_webhook_errors_total[5m])'
```

### Alerts to Configure
- **Critical**: Checkout success rate drops below 90% for 15 minutes
- **Warning**: Fulfillment latency p95 exceeds 30 seconds for 10 minutes
- **Warning**: Webhook error rate exceeds 5% for 5 minutes
- **Critical**: Database connection pool exhausted for 2 minutes

### Acceptance
- Grafana dashboard shows all key metrics
- Alerts fire within 5 minutes of threshold breach
- On-call engineer receives PagerDuty notification
- Runbook link is included in alert message

---

## Migrating from Legacy Ecommerce Service

### Procedure (one-time migration)
1. **Dual-run phase** (2 weeks):
   - Both legacy and new gateway accept orders
   - Feature flag routes 10% of traffic to new gateway
2. **Verification**:
   - Compare order counts between legacy and new gateway
   - Verify fulfillment success rates are equivalent
3. **Ramp-up**:
   - Increase feature flag to 50%, then 100%
   - Monitor for errors at each step
4. **Decommission legacy**:
   - Set legacy ecommerce to read-only mode
   - Redirect all buy buttons to new gateway
   - After 30 days, delete legacy ecommerce pods and database

### Acceptance
- Zero revenue loss during migration
- All orders fulfilled correctly via new gateway
- Legacy ecommerce fully decommissioned
- Historical order data migrated or archived

---

## Related Documentation
- **Spec**: `specs/ecommerce-purchase-gateway_spec.md`
- **Architecture**: `docs/architecture/purchase-gateway-overview.md`
- **Stripe Webhooks Setup**: `docs/operations/STRIPE_WEBHOOKS_SETUP.md`
- **General Troubleshooting**: `docs/operations/TROUBLESHOOTING.md`
