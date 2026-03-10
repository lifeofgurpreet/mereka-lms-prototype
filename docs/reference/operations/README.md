# Operations Reference
_Audience: Operators and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Use this root for factual operator reference: inventories, matrices, contracts, setup reference, and environment facts. Start here when you need to answer “what is true?” about the current runtime surface. Do not use this root for step-by-step execution or policy decisions.

## Start Here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Understand the deployment contract or runtime lanes | [`CANONICAL_DEPLOY_CONTRACT.md`](CANONICAL_DEPLOY_CONTRACT.md) | [`../../ops/runbooks/README.md`](../../ops/runbooks/README.md) |
| Find hostnames, domains, or route ownership | [`OPENEDX_HOSTNAMES.md`](OPENEDX_HOSTNAMES.md) | [`DOMAIN_MATRIX.md`](DOMAIN_MATRIX.md) |
| Check auth, secrets, or operator access posture | [`AUTH_AND_PERMISSIONS.md`](AUTH_AND_PERMISSIONS.md) | [`../../policies/operations/README.md`](../../policies/operations/README.md) |
| Look up monitoring, dashboards, or parity reference | [`MONITORING.md`](MONITORING.md) | [`../../ops/monitoring/README.md`](../../ops/monitoring/README.md) |
| Find service-specific environment reference | [`CI_CD_SETUP.md`](CI_CD_SETUP.md) or [`ASPECTS_ANALYTICS_SETUP.md`](ASPECTS_ANALYTICS_SETUP.md) | The relevant runbook under [`../../ops/runbooks/`](../../ops/runbooks/README.md) |

## Core references

- Runtime and release:
  [`CANONICAL_DEPLOY_CONTRACT.md`](CANONICAL_DEPLOY_CONTRACT.md),
  [`DEPLOYMENT_LANES.md`](DEPLOYMENT_LANES.md),
  [`RELEASE_PROCESS.md`](RELEASE_PROCESS.md),
  [`RELEASE_BUNDLE.md`](RELEASE_BUNDLE.md),
  [`SLSA_PROVENANCE.md`](SLSA_PROVENANCE.md)
- Routing and tenancy:
  [`OPENEDX_HOSTNAMES.md`](OPENEDX_HOSTNAMES.md),
  [`DOMAIN_MATRIX.md`](DOMAIN_MATRIX.md),
  [`ROUTE_MATRIX.md`](ROUTE_MATRIX.md),
  [`USER_FACING_URLS.md`](USER_FACING_URLS.md),
  [`ENTERPRISE_MULTI_TENANCY_NAVIGATION.md`](ENTERPRISE_MULTI_TENANCY_NAVIGATION.md)
- Auth and secrets:
  [`AUTH_AND_PERMISSIONS.md`](AUTH_AND_PERMISSIONS.md),
  [`AUTH_INTEGRATION_CONTRACT.md`](AUTH_INTEGRATION_CONTRACT.md),
  [`SECRETS_SNAPSHOT.md`](SECRETS_SNAPSHOT.md),
  [`COMMIT_SIGNING.md`](COMMIT_SIGNING.md),
  [`SSO_CANARY.md`](SSO_CANARY.md)
- Observability:
  [`MONITORING.md`](MONITORING.md),
  [`ALERT_SEVERITY_MATRIX.md`](ALERT_SEVERITY_MATRIX.md),
  [`LOGGING_AND_SENTRY.md`](LOGGING_AND_SENTRY.md),
  [`OPERATOR_DASHBOARD_GUIDE.md`](OPERATOR_DASHBOARD_GUIDE.md)
- Service and environment specifics:
  [`ADMIN_CONSOLE_SETUP.md`](ADMIN_CONSOLE_SETUP.md),
  [`ASPECTS_ANALYTICS_SETUP.md`](ASPECTS_ANALYTICS_SETUP.md),
  [`CI_CD_SETUP.md`](CI_CD_SETUP.md),
  [`EMAIL_PIPELINE.md`](EMAIL_PIPELINE.md),
  [`LIBRARIES_GCS_SETUP.md`](LIBRARIES_GCS_SETUP.md)

## Do not use this directory for

- step-by-step procedures, which belong in `docs/ops/runbooks/**`
- active status reporting, which belongs in `docs/status/**`
- policy decisions, which belong in `docs/policies/**`
- raw proof bundles, which belong in `docs/evidence/**`

## How To Use This Root Well

1. Start with the smallest reference that answers the question you have right now.
2. If you need execution steps, leave this root and move to [`../../ops/runbooks/README.md`](../../ops/runbooks/README.md).
3. If you need the governing rule, leave this root and move to [`../../policies/README.md`](../../policies/README.md) or [`../../concepts/architecture/README.md`](../../concepts/architecture/README.md).
