# Purchase Gateway Fulfillment Recovery

This runbook covers recovery for paid-but-unfulfilled orders after Stripe webhook acknowledgement.

## Architecture Contract

- Stripe webhook handling MUST ack independently from LMS fulfillment.
- Fulfillment execution MUST be driven by durable rows in `fulfillment_jobs`.
- Retries MUST use exponential backoff and transition to `dead_letter` after max attempts.

## Quick Triage

1. Inspect failing jobs:

```sql
SELECT
  id,
  order_id,
  status,
  attempts,
  max_attempts,
  next_attempt_at,
  last_error,
  updated_at
FROM fulfillment_jobs
WHERE status IN ('failed', 'dead_letter')
ORDER BY updated_at DESC
LIMIT 100;
```

2. Inspect paid orders with no success state:

```sql
SELECT
  o.id AS order_id,
  o.status AS order_status,
  j.status AS job_status,
  j.attempts,
  j.last_error
FROM orders o
LEFT JOIN fulfillment_jobs j ON j.order_id = o.id
WHERE o.status IN ('paid', 'fulfilling', 'partially_fulfilled', 'fulfillment_failed')
ORDER BY o.updated_at DESC
LIMIT 200;
```

## Manual Replay Procedure

Use only after validating downstream LMS/API health.

```sql
UPDATE fulfillment_jobs
SET
  status = 'pending',
  attempts = 0,
  next_attempt_at = NOW(),
  completed_at = NULL,
  last_error = NULL,
  triggered_by = 'runbook.manual_requeue'
WHERE order_id = '<ORDER_UUID>';
```

For orders that never received a job row:

```sql
INSERT INTO fulfillment_jobs (
  id,
  tenant_id,
  order_id,
  status,
  attempts,
  max_attempts,
  next_attempt_at,
  triggered_by
)
SELECT
  gen_random_uuid(),
  o.tenant_id,
  o.id,
  'pending',
  0,
  10,
  NOW(),
  'runbook.manual_enqueue'
FROM orders o
WHERE o.id = '<ORDER_UUID>'
  AND NOT EXISTS (
    SELECT 1 FROM fulfillment_jobs j WHERE j.order_id = o.id
  );
```

## Reconciliation Procedure

Enable automatic reconciliation loop and restart the service:

```bash
kubectl -n mereka-lms set env deploy/payments-gateway ENABLE_RECONCILIATION_JOB=true
kubectl -n mereka-lms rollout restart deploy/payments-gateway
```

The worker will enqueue missing jobs for orders in:

- `paid`
- `fulfilling`
- `partially_fulfilled`
- `fulfillment_failed`

## Rollback

If outbox worker behavior regresses:

1. Set `ENABLE_GATEWAY_FULFILLMENT=false` to stop fulfillment attempts.
2. Keep webhook ingestion active (payments remain recorded as `paid`).
3. Revert to previous gateway image and redeploy.
4. Replay pending jobs once corrected version is restored.
