# Live Synthetic Fixture State — mereka-lms-dev

> Generated: 2026-03-12T09:35:00Z
> Namespace: mereka-lms-dev
> Cluster: rke2-nonprod

## Synthetic Identities (all @synthetic.test)

| Username | Email | Staff | Super | Enterprise Link | User ID |
|----------|-------|-------|-------|-----------------|---------|
| lanea-platform-admin | lanea-platform-admin@synthetic.test | true | true | NONE (platform-only) | 94023 |
| lanea-enterprise-admin | lanea-enterprise-admin@synthetic.test | false | false | biji-biji (admin) | 94024 |
| lanea-enterprise-learner | lanea-enterprise-learner@synthetic.test | false | false | biji-biji (learner) | 94025 |
| lanea-unlinked-user | lanea-unlinked-user@synthetic.test | false | false | NONE (negative case) | 94031 |

## Enterprise Customer

| Field | Value |
|-------|-------|
| Slug | `biji-biji` |
| UUID | `7ad11569-d027-4e9d-a08f-e65c57e27c8b` |
| Name | Biji Biji Initiative |
| Contact Email | lanea-enterprise-admin@synthetic.test |
| Site | academyv2.mereka.dev |
| Active | true |

## Catalogs (Both Sides Populated)

### LMS Side (EnterpriseCustomerCatalog)
- `57e324c2-e0d1-4e65-91ea-818f636c91aa` — "Biji Biji Default Catalog" (matches enterprise-catalog)
- `4f627262-af96-4442-8827-e64ed5e26578` — "Biji Biji Initiative Default Catalog"
- `db51443c-e6d0-4d0a-bf1f-95db6b4f8d14` — "Biji Biji Initiative Default Catalog"

### Enterprise-Catalog Service Side
- `57e324c2-e0d1-4e65-91ea-818f636c91aa` — "Biji Biji Default Catalog"
  - enterprise_uuid: `7ad11569-d027-4e9d-a08f-e65c57e27c8b`
  - CatalogQuery id=1, content_filter: `{content_type: course}`

## Waffle State

| Type | Name | Active |
|------|------|--------|
| Flag | enterprise.learner_bff_enabled | true (everyone) |
| Switch | enterprise.enable_learner_portal.biji-biji | true |
| Switch | enterprise.enable_integrated_learner_portal_search.biji-biji | true |
| Switch | enterprise.enable_analytics_screen.biji-biji | true |
| Switch | enterprise.enable_audit_enrollment.biji-biji | false |
| Switch | enterprise.enable_portal_code_management.biji-biji | false |

## Negative Case

- `lanea-unlinked-user` exists with NO enterprise links
- Attempting learner portal access should return 403 or redirect

## Passwords

Passwords are stored in Infisical at `/k8s/mereka-lms/` in the active environment. To set all
passwords deterministically from env vars:

```bash
# Pull from Infisical, then:
LANEA_PLATFORM_ADMIN_PASSWORD=<pw> \
LANEA_ENTERPRISE_ADMIN_PASSWORD=<pw> \
LANEA_ENTERPRISE_LEARNER_PASSWORD=<pw> \
LANEA_UNLINKED_USER_PASSWORD=<pw> \
./scripts/tenants/apply-substrate-live.sh --env dev --set-passwords
```

Or set individually via Django management command:
```bash
kubectl exec -n mereka-lms-dev <lms-pod> -- python manage.py lms changepassword <username>
```

## One-Command Live Validation

```bash
./scripts/tenants/validate-substrate-live.sh
# or with JSON output:
./scripts/tenants/validate-substrate-live.sh --json
```

Checks: users, user profiles, enterprise customers, enterprise links, catalogs,
UUID drift, waffle flags, password usability, negative-case readiness.

## Idempotency

All fixture operations are idempotent (get_or_create). Re-running the
bootstrap tool produces 12/12 NOOP results. UUID drift detection now
catches silent mismatches on NOOP paths.

## Rollback

Synthetic objects are identified by `@synthetic.test` email domain.
Rollback targets only synthetic users and their enterprise links.
The EnterpriseCustomer `biji-biji` is shared with 4 real users and
must NOT be deleted during rollback.
