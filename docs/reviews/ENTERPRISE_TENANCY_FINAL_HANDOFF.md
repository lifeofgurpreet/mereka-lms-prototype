# Enterprise Tenancy — Final Handoff

> Lane D is complete. This document is the single handoff artifact.

## What Is Merged

| PR | Content | Date |
|----|---------|------|
| #863 | Tenant/domain authority matrix, admin surfaces, data audit (6 docs) | 2026-03-11 |
| #864 | Bootstrap spec, tooling, tests, variants (13 files) | 2026-03-11 |
| #865 | Salvage branch ledger, config rollout debt (2 docs) | 2026-03-11 |
| #867 | Decision packet, dry-run previews, execution packet, hardened tests (7 files) | 2026-03-11 |
| #868 | Ruff lint fix for bootstrap tooling (2 files) | 2026-03-11 |
| #869 | Evidence templates, operator defaults, execution manifest, CI validation, this handoff | 2026-03-11 |

**Total artifacts**: 35+ files across docs, config, scripts, tests, fixtures.

## What Is Waiting on Runtime

Enterprise MFE portals must render in the browser before bootstrap apply is meaningful.

**Blocker**: PR #859 (`fix/enterprise-mfe-build-config`) — owned by Lane A.

**Gated actions**:
- `bootstrap-enterprise-tenants.py --apply`
- Portal content verification
- Evidence template completion
- Screenshot capture

## What Operator Must Decide

| Decision | Recommended | Alternative | Doc |
|----------|-------------|-------------|-----|
| Slug | `bijibiji` | `biji-biji` | `ENTERPRISE_OPERATOR_DEFAULTS.md` |
| Variant | `shared-mereka` | `partner-isolated` | `ENTERPRISE_OPERATOR_DEFAULTS.md` |

Both decisions are fully documented with consequences in `ENTERPRISE_OPERATOR_DECISION_PACKET.md`.

## What Exact Commands Run Next

Once runtime is green AND operator decisions are made:

```bash
# 1. Copy chosen variant (default: shared-mereka)
cp config/enterprise-tenants/dev.enterprise-tenants.shared-mereka.yaml \
   config/enterprise-tenants/dev.enterprise-tenants.yaml

# 2. Copy files to LMS pod
LMS_POD=$(kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms \
  -o jsonpath='{.items[0].metadata.name}')
kubectl cp config/enterprise-tenants/dev.enterprise-tenants.yaml \
  mereka-lms-dev/${LMS_POD}:/tmp/spec.yaml
kubectl cp scripts/tenants/bootstrap-enterprise-tenants.py \
  mereka-lms-dev/${LMS_POD}:/tmp/bootstrap.py
kubectl cp scripts/tenants/validate-enterprise-tenants.py \
  mereka-lms-dev/${LMS_POD}:/tmp/validate.py

# 3. Dry run (review output first)
kubectl exec -n mereka-lms-dev deploy/lms -- python /tmp/bootstrap.py --env dev

# 4. Apply
kubectl exec -n mereka-lms-dev deploy/lms -- python /tmp/bootstrap.py --env dev --apply

# 5. Validate
kubectl exec -n mereka-lms-dev deploy/lms -- python /tmp/validate.py --json \
  > var/proofs/enterprise-bootstrap-dev.json

# 6. Fill evidence template
# docs/reviews/ENTERPRISE_BOOTSTRAP_EVIDENCE_TEMPLATE.md
# Save to: var/proofs/enterprise-bootstrap-evidence-dev.md
```

## Artifact Map

| Category | Files |
|----------|-------|
| Architecture docs | `TENANT_DOMAIN_SURFACE_AUTHORITY.md`, `TENANT_DOMAIN_AUTHORITY_MATRIX.md`, `TENANT_MODEL_RECOMMENDATION.md`, `ADMIN_SURFACES_AND_ENTRYPOINTS.md`, `ENTERPRISE_TENANT_VARIANTS.md`, `SALVAGE_BRANCH_LEDGER.md`, `STABLE_CONFIG_ROLLOUT_DEBT.md` |
| Operations docs | `ENTERPRISE_DATA_AUDIT.md`, `ENTERPRISE_DATA_MODEL_AUDIT.md`, `ENTERPRISE_BOOTSTRAP_APPLY_RUNBOOK.md` |
| Review docs | `ENTERPRISE_TENANCY_REVIEW_SUMMARY.md`, `ENTERPRISE_OPERATOR_DECISION_PACKET.md`, `ENTERPRISE_OPERATOR_DEFAULTS.md`, `ENTERPRISE_TENANCY_FINAL_HANDOFF.md` |
| Dry-run previews | `ENTERPRISE_BOOTSTRAP_DRYRUN_SHARED_MEREKA.md`, `ENTERPRISE_BOOTSTRAP_DRYRUN_PARTNER_ISOLATED.md` |
| Evidence templates | `ENTERPRISE_BOOTSTRAP_EVIDENCE_TEMPLATE.md`, `ENTERPRISE_BOOTSTRAP_ROLLBACK_EVIDENCE_TEMPLATE.md` |
| Execution packet | `POST_RUNTIME_ENTERPRISE_BOOTSTRAP_EXECUTION.md` |
| Execution manifest | `config/enterprise-tenants/dev.execution-plan.json` |
| Bootstrap specs | `dev.enterprise-tenants.yaml`, `dev.enterprise-tenants.shared-mereka.yaml`, `dev.enterprise-tenants.partner-isolated.yaml` |
| Tooling | `scripts/tenants/bootstrap-enterprise-tenants.py`, `scripts/tenants/validate-enterprise-tenants.py` |
| Tests | `tests/tenants/test_bootstrap_spec.py` (34 tests) |
| Fixtures | 7 files in `tests/tenants/fixtures/` |
| CI validation | `scripts/qa/verify-tenant-specs.sh` |

## Lane D Status

**READY_FOR_APPLY_AFTER_RUNTIME**

No further Lane D work is needed until runtime lands.
