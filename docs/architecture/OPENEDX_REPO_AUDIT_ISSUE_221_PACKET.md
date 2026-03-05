# Issue #221 Implementation Packet - Purchase Gateway Outbox/Saga

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/221  
Parent: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214  
Status: audit-to-implementation handoff

## Goal

Guarantee payment-to-fulfillment resilience by replacing synchronous webhook fulfillment with a durable outbox/worker model.

## Confirmed Risks

- Webhook currently marks order paid then calls fulfillment synchronously in request path.
- On fulfillment failure, handler returns `500` and relies on Stripe redelivery.
- Config includes queue/retry knobs (`REDIS_URL`, `FULFILLMENT_MAX_RETRIES`, `ENABLE_RECONCILIATION_JOB`) but no durable outbox worker path is present.
- README architecture still mentions Redis queue, causing code-to-doc drift.

---

## PR Strategy (recommended 3 PRs)

1. `PR-221-A` data model + webhook transaction boundary
2. `PR-221-B` worker deployment + retry/backoff
3. `PR-221-C` reconciliation and observability

---

## PR-221-A (Outbox Data Model + Webhook Refactor)

### File Changes

1. New model and migration:
   - `services/purchase-gateway/app/models/fulfillment_job.py`
   - Alembic migration under `services/purchase-gateway/alembic/versions/`
2. Webhook handler refactor:
   - `services/purchase-gateway/app/routers/webhooks.py`
3. Config additions/clarifications:
   - `services/purchase-gateway/app/config.py`

### Transaction Contract

Inside one DB transaction:
1. persist stripe event processing state
2. mark order as paid
3. create one fulfillment job (idempotent dedupe key per order+line_item/event)
4. commit

Webhook returns success after commit.  
No LMS API call in webhook request path.

### Acceptance Criteria

- `AC-221-A1`: every paid order has durable fulfillment job record.
- `AC-221-A2`: duplicate webhook deliveries do not create duplicate jobs.
- `AC-221-A3`: webhook request time is decoupled from LMS latency.

### Verification Commands

```bash
pytest services/purchase-gateway/tests -k "webhook and idempot"
```

---

## PR-221-B (Worker + Retry Policy)

### File Changes

1. Worker entrypoint:
   - `services/purchase-gateway/app/workers/fulfillment_worker.py`
2. Queue abstraction:
   - Redis-backed or DB polling implementation (choose one explicitly).
3. K8s deployment:
   - `services/purchase-gateway/k8s/deployment-worker.yaml`
   - optional update to kustomization.

### Worker Contract

- fetch pending jobs
- call LMS fulfillment logic
- update job and order states
- bounded retry with exponential backoff
- move to terminal `dead_letter` after max retries.

### Acceptance Criteria

- `AC-221-B1`: worker fulfills jobs asynchronously and idempotently.
- `AC-221-B2`: failed jobs are retried with bounded policy.
- `AC-221-B3`: terminal failures are persisted with diagnostic reason.

### Verification Commands

```bash
pytest services/purchase-gateway/tests -k "fulfillment_worker or retry"
kubectl get deploy -n mereka-lms | rg payments-gateway
```

---

## PR-221-C (Reconciliation + Metrics)

### File Changes

1. Reconciliation task:
   - `services/purchase-gateway/app/workers/reconciliation.py`
2. Metrics/logging:
   - queue depth, retry count, dead-letter count, oldest pending age
3. Docs:
   - `services/purchase-gateway/README.md`
   - runbook under `docs/operations/` for fulfillment incidents.

### Acceptance Criteria

- `AC-221-C1`: periodic reconciliation requeues eligible stuck jobs.
- `AC-221-C2`: metrics exist for operational alerting.
- `AC-221-C3`: docs reflect implemented architecture (no queue illusion mismatch).

### Rollback Plan

1. Feature flag:
   - `ENABLE_ASYNC_FULFILLMENT` (new) toggles old synchronous fallback for emergency.
2. If worker fails broadly:
   - disable async flag and revert to synchronous path while keeping outbox records.
3. Maintain idempotency keys in both modes.

### Verification Commands

```bash
pytest services/purchase-gateway/tests
./scripts/qa/test-stripe-webhook-delivery.sh dev
```
