# Enterprise Operator Defaults

> This file declares the recommended defaults for enterprise bootstrap.
> The operator may override any default — consequences are documented below.

## Recommended Defaults

| Decision | Default | Alternative |
|----------|---------|-------------|
| **Slug** | `bijibiji` | `biji-biji` |
| **Variant** | `shared-mereka` | `partner-isolated` |

## Slug: `bijibiji` (recommended)

**Why**:
- Valid Python identifier (no quoting needed in `import`, `getattr`, Django ORM filters)
- Clean URL path segment (`/enterprise/bijibiji/` — no ambiguous hyphen parsing)
- Waffle switch names stay clean (`enterprise.enable_learner_portal.bijibiji`)
- Matches `infrastructure/tenants/tenant-contracts.yml` (canonical provisioning source)
- No collision with any existing slug in the platform

**If operator overrides to `biji-biji`**:
- Must update all 3 spec variants: `dev.enterprise-tenants.yaml`, `shared-mereka`, `partner-isolated`
- Must update `infrastructure/tenants/tenant-contracts.yml` to match
- Waffle switch names become `enterprise.enable_learner_portal.biji-biji` (hyphen in name — unusual but functional)
- `tenant-registry.yaml` already uses `biji-biji` (no change needed there)
- All 34 tests will fail until fixtures are updated (slug conflict test enforces `bijibiji`)

## Variant: `shared-mereka` (recommended)

**Why**:
- Partner orgs (BIJIBIJI, SKILLOURFUTURE) have **0 courses** of their own
- `partner-isolated` catalogs would be **empty** — portals render but show nothing
- `shared-mereka` gives partners access to 109 MEREKA courses immediately
- Learner portal is useful from day one instead of appearing broken
- Tightening to isolated later is a single org_filter edit per tenant

**If operator overrides to `partner-isolated`**:
- Partner learner portals show 0 courses until partners create their own
- Partner admin portals show empty catalog
- Enterprise analytics will show no data for partners
- Reversible: add `MEREKA` to partner org_filters later
- Must copy `dev.enterprise-tenants.partner-isolated.yaml` to `dev.enterprise-tenants.yaml`

## Apply Commands with Defaults

```bash
# Step 1: Copy recommended variant
cp config/enterprise-tenants/dev.enterprise-tenants.shared-mereka.yaml \
   config/enterprise-tenants/dev.enterprise-tenants.yaml

# Step 2: Dry run
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /tmp/bootstrap.py --env dev

# Step 3: Apply
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /tmp/bootstrap.py --env dev --apply

# Step 4: Validate
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /tmp/validate.py --json > var/proofs/enterprise-bootstrap-dev.json
```

## Override Checklist

If overriding either default:

- [ ] Update `dev.enterprise-tenants.yaml` to match chosen variant
- [ ] If slug changed: update all spec files, tenant-contracts.yml, test fixtures
- [ ] Run `python -m pytest tests/tenants/ -v` to verify specs are consistent
- [ ] Run dry-run before apply to confirm expected objects
- [ ] Document override reason in apply evidence template
