# Tenancy Epic Deployment Runbook

**Epic**: `mereka-lms-1gcr`
**Spec**: `specs/multi-tenancy-architecture_spec.md`
**Status**: Canonical operator runbook

## Overview

This runbook is the deployment front door for the multi-tenant architecture.
It is intentionally narrower than the historical version:

- image rollout happens through the governed release and GitOps flow
- Django `Site` and `SiteConfiguration` state reconciles from the multisite
  registry
- enterprise linkage reconciles through its own bounded script
- IdP setup is a separate bounded step, not part of the core tenancy rollout

This runbook does **not** allow:

- local `tutor images build openedx` as the production release path
- direct `kubectl set image` rollout
- `provision-all-tenants.sh` or `provision-tenant.sh` as the deployment
  front door for live `SiteConfiguration` state
- Django admin or ad hoc shell edits as a recovery path

## Prerequisites

- [ ] Tenant source of truth is merged on `main`
  - `infrastructure/tutor/multisite-sites.yml`
  - tenant registry / brand assets / runtime config changes
- [ ] Required repo checks are green
- [ ] You have access to:
  - GitHub Actions for `mereka-lms`
  - the GitOps promotion path
  - `kubectl` for the target cluster
  - `velero` for prod-like applies
- [ ] The release owner has the target image tags or the completed
  `build-tutor-images.yml` run that produced them

## Step 1: Verify Source-of-Truth Inputs

Before any rollout, prove the repo still describes one coherent tenancy model.

```bash
bash scripts/qa/verify-tenant-contract-alignment.sh
bash scripts/qa/verify-tenant-dns-inventory.sh
bash scripts/qa/verify-multisite-apply-guardrails.sh
bash scripts/qa/verify-tenant-enterprise-mutation-guardrails.sh
```

Expected result:

- all commands exit `0`
- no script recommends Django admin or direct `SiteConfiguration` mutation

## Step 2: Produce the Release Artifact

Use the governed image build workflow. Do not build or tag production images by
hand on an operator laptop.

Manual workflow:

- `.github/workflows/build-tutor-images.yml`

Required inputs:

- `target_environment=production`
- `update_gitops=false`
- `image_tag=<release-tag>`
- `build_openedx=true` when backend / Tutor / Django runtime changed
- `build_mfe=true` when MFE / branding / footer / learner shell changed

Keep the release bundle and provenance from that run. They are the proof that
the app artifact exists before GitOps promotion.

## Step 3: Roll Out Through GitOps

Use the canonical release path from the
[`RELEASE_CHECKLIST.md`](../../ops/runbooks/RELEASE_CHECKLIST.md) runbook.

The normal production front door is:

```bash
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}" \
  --apply --commit --push --verify-runtime
```

Do not replace this with direct `kubectl` image mutation.

## Step 4: Reconcile Django Site and SiteConfiguration State

After the new image is promoted, reconcile the tenant runtime state from the
multisite registry.

```bash
CONFIRM_APPLY_MULTISITE_CONFIG=APPLY_MULTISITE_CONFIG \
ALLOW_PROD_APPLY=1 \
./scripts/infra/apply-multisite-config.sh --env prod --apply
```

What this step owns:

- Django `Site` rows
- `SiteConfiguration` rows
- learner-facing MFE URL completeness
- domain-to-site alignment from `multisite-sites.yml`

What this step does **not** own:

- enterprise customer to tenant linkage
- IdP configuration

## Step 5: Reconcile Enterprise Mapping

If the rollout includes new tenants or tenant-domain changes, reconcile the
enterprise mapping explicitly after multisite apply.

```bash
CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING=SYNC_TENANT_ENTERPRISE_MAPPING \
ALLOW_PROD_APPLY=1 \
./scripts/tenants/sync-tenant-enterprise-mapping.sh \
  --env prod \
  --canonical-domains \
  --apply
```

This is the canonical owner for:

- `EnterpriseCustomer` to `SiteConfiguration` linkage
- canonical tenant slug to domain mapping

## Step 6: Configure IdP Only If the Change Requires It

IdP setup is not part of the base deployment path. Run it only when the change
actually affects SAML or OIDC configuration.

Example:

```bash
CONFIRM_CONFIGURE_TENANT_IDP=CONFIGURE_TENANT_IDP \
ALLOW_PROD_APPLY=1 \
./scripts/tenants/configure-tenant-idp.sh \
  --tenant-slug skillourfuture \
  --idp-type saml \
  --metadata-url https://idp.example.com/metadata \
  --apply
```

## Step 7: Post-Deployment Verification

Validate the live system, not just repo intent.

### Rollout and Runtime Health

```bash
kubectl -n argocd get application mereka-lms-local
kubectl -n mereka-lms rollout status deployment/lms
kubectl -n mereka-lms rollout status deployment/cms
kubectl -n mereka-lms rollout status deployment/mfe
```

### Tenancy Verification

```bash
bash scripts/qa/verify-tenant-isolation.sh
bash scripts/qa/verify-tenant-contract-alignment.sh
bash scripts/qa/verify-enterprise-runtime-app-wiring.sh
```

### Domain and MFE Contract Checks

```bash
curl -I https://academyv2.mereka.io/courses
curl -I https://academy.biji-biji.com/courses
curl -I https://skillourfuture.academy.mereka.io/courses

curl -fsS https://academyv2.mereka.io/api/mfe_config/v1 | jq .
```

Success looks like:

- all expected domains respond
- learner-facing MFE URLs are present in `/api/mfe_config/v1`
- enterprise/runtime verification exits `0`
- no unexplained `5xx` spikes or rollout failures

## Troubleshooting

### GitOps rollout failed

Use the rollback path in the
[`RELEASE_CHECKLIST.md`](../../ops/runbooks/RELEASE_CHECKLIST.md) runbook.
Do **not** recover with `kubectl set image`.

### Site or SiteConfiguration drift

Re-run the canonical multisite reconciliation:

```bash
CONFIRM_APPLY_MULTISITE_CONFIG=APPLY_MULTISITE_CONFIG \
ALLOW_PROD_APPLY=1 \
./scripts/infra/apply-multisite-config.sh --env prod --apply
```

Do **not** recover with `provision-all-tenants.sh`, Django admin, or direct SQL.

### Enterprise mapping drift

Re-run the enterprise mapping reconciliation:

```bash
CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING=SYNC_TENANT_ENTERPRISE_MAPPING \
ALLOW_PROD_APPLY=1 \
./scripts/tenants/sync-tenant-enterprise-mapping.sh \
  --env prod \
  --canonical-domains \
  --apply
```

### IdP drift

Use `configure-tenant-idp.sh` for the affected tenant. Do not patch live DB
state by hand.

## Success Criteria

Deployment is complete only when:

1. The promoted image is live through GitOps.
2. `apply-multisite-config.sh` has reconciled the target environment.
3. `sync-tenant-enterprise-mapping.sh` has reconciled enterprise linkage when
   needed.
4. Runtime verification passes on live domains.
5. No recovery step required a side door or manual DB mutation.

## Related

- Epic bead: `mereka-lms-1gcr`
- Spec: `specs/multi-tenancy-architecture_spec.md`
- Release runbook:
  [`RELEASE_CHECKLIST.md`](../../ops/runbooks/RELEASE_CHECKLIST.md)
- Canonical Site / SiteConfiguration apply:
  `scripts/infra/apply-multisite-config.sh`
- Canonical enterprise mapping sync:
  `scripts/tenants/sync-tenant-enterprise-mapping.sh`
- IdP setup:
  `scripts/tenants/configure-tenant-idp.sh`
