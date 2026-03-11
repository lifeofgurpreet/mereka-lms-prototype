# Enterprise Operator Decision Packet

> Two decisions must be made before enterprise bootstrap can be applied.
> Both are reversible. Both affect only dev environment initially.

## Decision 1: Tenant Slug — `bijibiji` vs `biji-biji`

### Options

| Slug | Source | Format |
|------|--------|--------|
| `bijibiji` | `infrastructure/tenants/tenant-contracts.yml` | No hyphens, valid Python identifier, URL-safe |
| `biji-biji` | `deploy/k8s/tenancy/tenant-registry.yaml` | Hyphenated, matches brand spelling |

### Recommendation: `bijibiji`

### Consequences

| Factor | `bijibiji` | `biji-biji` |
|--------|-----------|-------------|
| Python identifier | Valid (`import bijibiji`) | Invalid (needs quoting) |
| URL path segment | Clean (`/enterprise/bijibiji/`) | Ambiguous parsing in some tools |
| Waffle switch suffix | `enterprise.enable_learner_portal.bijibiji` | `enterprise.enable_learner_portal.biji-biji` (hyphen in switch name) |
| Existing contract | Matches `tenant-contracts.yml` | Matches `tenant-registry.yaml` |
| Slug uniqueness | No collision risk | No collision risk |
| Open edX convention | Lowercase alphanumeric preferred | Hyphens technically valid |
| Reversibility | Rename requires: new EC + migrate catalogs/users | Same effort |

**Bottom line**: `bijibiji` avoids edge-case bugs in switch names and Python tooling. The tenant-contracts file already uses it. The tenant-registry can be updated to match.

---

## Decision 2: Partner Course Visibility — `shared-mereka` vs `partner-isolated`

### Options

| Variant | What partners see | Spec file |
|---------|-------------------|-----------|
| `shared-mereka` | Own org courses + MEREKA courses | `dev.enterprise-tenants.shared-mereka.yaml` |
| `partner-isolated` | Only own org courses | `dev.enterprise-tenants.partner-isolated.yaml` |

### Recommendation: `shared-mereka`

### Consequences

| Factor | `shared-mereka` | `partner-isolated` |
|--------|-----------------|---------------------|
| Biji-Biji catalog content | 109 courses (MEREKA) + 0 (BIJIBIJI) = 109 | 0 courses (BIJIBIJI has none) |
| Skill Our Future catalog content | 109 courses (MEREKA) + 0 (SOF) = 109 | 0 courses (SOF has none) |
| Learner portal usefulness | Immediately useful | Empty until partner creates courses |
| Data isolation | Weaker (cross-org visibility) | Strongest |
| Reversibility | Remove MEREKA from org_filter later | Add MEREKA to org_filter later |
| Business risk | Partner admins see all MEREKA content in admin portal | Partner portals show nothing — looks broken |

**Bottom line**: Both partner orgs (BIJIBIJI, SKILLOURFUTURE) have zero courses. Isolated catalogs would be empty, making portals appear broken. Share MEREKA courses now; tighten isolation when partners create their own content.

---

## Applying the Chosen Variant

After both decisions are made AND the runtime blocker (`fix/enterprise-mfe-build-config`) is resolved:

```bash
# Step 1: Copy chosen variant to active spec
# If shared-mereka (recommended):
cp config/enterprise-tenants/dev.enterprise-tenants.shared-mereka.yaml \
   config/enterprise-tenants/dev.enterprise-tenants.yaml

# If partner-isolated:
# cp config/enterprise-tenants/dev.enterprise-tenants.partner-isolated.yaml \
#    config/enterprise-tenants/dev.enterprise-tenants.yaml

# Step 2: Dry run (from LMS pod)
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /openedx/scripts/tenants/bootstrap-enterprise-tenants.py --env dev

# Step 3: Apply (only after reviewing dry-run output)
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /openedx/scripts/tenants/bootstrap-enterprise-tenants.py --env dev --apply

# Step 4: Validate
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /openedx/scripts/tenants/validate-enterprise-tenants.py

# Step 5: Verify portals render
curl -sI https://admin.academyv2.mereka.dev/ | head -5
curl -sI https://learner.academyv2.mereka.dev/ | head -5
```

See `docs/reviews/POST_RUNTIME_ENTERPRISE_BOOTSTRAP_EXECUTION.md` for the complete execution packet.

---

## Decision Record

| Field | Value |
|-------|-------|
| Decision owner | Platform operator |
| Deadline | Before first enterprise portal demo |
| Reversibility | Both decisions fully reversible in dev |
| Blast radius | Dev environment only |
| Dependencies | Runtime blocker must be resolved first |
