# Enterprise Tenant Variants

> Two bootstrap variants for operator decision.
> Choose one, then apply via `bootstrap-enterprise-tenants.py`.

## Slug Decision: `bijibiji` (resolved)

Both variants use `bijibiji` (no hyphens). Rationale:
- Valid Python identifier
- URL-safe without encoding
- Matches `tenant-contracts.yml` (which already uses `bijibiji`)
- Avoids ambiguity with `biji-biji` in tenant-registry (registry uses `biji-biji` for the `registry_slug` display name only)
- `EnterpriseCustomer.slug` should be `bijibiji`

**Action required**: Update `tenant-registry.yaml` line 37 from `slug: biji-biji` to `slug: bijibiji` after this PR merges. Or keep `registry_slug: biji-biji` for display and use `slug: bijibiji` for the enterprise customer.

## Variant A: Shared MEREKA (Recommended)

**File**: `config/enterprise-tenants/dev.enterprise-tenants.shared-mereka.yaml`

Partner tenants see MEREKA courses in addition to their own org's courses.

| Tenant | Org filter | Courses visible | Catalog empty? |
|--------|-----------|----------------|---------------|
| mereka | `[MEREKA]` | 109 | No |
| bijibiji | `[BIJIBIJI, MEREKA]` | 109 (all MEREKA + 0 BIJIBIJI) | No |
| skillourfuture | `[SKILLOURFUTURE, MEREKA]` | 109 (all MEREKA + 0 SOF) | No |

**Pros**:
- Portals have content immediately
- No need to create partner-specific courses before enterprise features work
- Partners can still create org-specific courses later (they appear automatically)
- Matches the likely business intent (partners are distribution channels for MEREKA content)

**Cons**:
- Less isolation — partner learners see the same courses as Mereka learners
- If a partner should NOT see certain MEREKA courses, there's no per-course exclusion (only org-level)
- Partner analytics include MEREKA course data

## Variant B: Partner Isolated

**File**: `config/enterprise-tenants/dev.enterprise-tenants.partner-isolated.yaml`

Partner tenants see ONLY their own org's courses.

| Tenant | Org filter | Courses visible | Catalog empty? |
|--------|-----------|----------------|---------------|
| mereka | `[MEREKA]` | 109 | No |
| bijibiji | `[BIJIBIJI]` | 0 | **Yes** |
| skillourfuture | `[SKILLOURFUTURE]` | 0 | **Yes** |

**Pros**:
- Clean isolation — each tenant sees only its own content
- Partner analytics are pure (only their courses)
- Clear content ownership

**Cons**:
- **Partner portals are empty until courses are created under BIJIBIJI / SKILLOURFUTURE orgs**
- Enterprise features cannot be meaningfully tested for partners until content exists
- Additional work required to populate partner course catalogs

## Recommendation

**Use Variant A (Shared MEREKA)** for the initial bootstrap. Rationale:

1. The immediate goal is to make enterprise portals show meaningful content
2. All 109 courses are currently org MEREKA — without sharing, partner portals are empty
3. Isolation can be tightened later by removing MEREKA from partner org_filters
4. This is a catalog-level decision, not a database schema change — reversible in minutes

## How to switch between variants

```bash
# Use shared-mereka variant
cp config/enterprise-tenants/dev.enterprise-tenants.shared-mereka.yaml \
   config/enterprise-tenants/dev.enterprise-tenants.yaml

# Or use partner-isolated variant
cp config/enterprise-tenants/dev.enterprise-tenants.partner-isolated.yaml \
   config/enterprise-tenants/dev.enterprise-tenants.yaml

# Then run bootstrap
python scripts/tenants/bootstrap-enterprise-tenants.py --env dev --apply
```

## Catalog query structure

Both variants use the same `CatalogQuery` format consumed by `enterprise-catalog`:

```json
{
  "content_type": "course",
  "aggregation_key": ["courserun:*"],
  "organizations.key": ["MEREKA"]
}
```

The `organizations.key` field controls which orgs' courses appear in the catalog.
The enterprise-catalog service evaluates this filter against the Discovery service's
course index.
