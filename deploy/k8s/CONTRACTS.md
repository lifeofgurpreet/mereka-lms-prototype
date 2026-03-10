# Deployment Contract -- Mereka LMS

> Machine-readable version: [`contract.json`](contract.json) | ADR: [ADR-027](../../docs/adr/rfc/027-deployment-contract-ownership-lanes.md)

## Contract Version

See [`VERSION`](VERSION). Follows semver:
- **PATCH**: New secret key in existing ExternalSecret, new PrometheusRule
- **MINOR**: New Deployment/Service, new ExternalSecret, new ConfigMap
- **MAJOR**: Deployment renamed/removed, secret structure changed, namespace changed

## What This Repo Guarantees

### Base Kustomization

`deploy/k8s/base/` is a complete, buildable Kustomize application. Running
`kubectl kustomize deploy/k8s/base/` produces all resources. It requires an
overlay to provide environment-specific configuration.

### Workloads (27 Deployments)

| Name | Ports | HPA | Health Probe |
|------|-------|-----|-------------|
| caddy | 80, 443, 2019 | no | -- |
| cms | 8000 | yes | /heartbeat:8000 |
| cms-worker | -- | yes | -- |
| credentials | 8000 | no | /health/:8000 |
| discovery | 8000 | no | /health/:8000 |
| elasticsearch | 9200 | no | -- |
| enterprise-access | 18270 | yes | /health/:18270 |
| enterprise-access-worker | -- | no | -- |
| enterprise-admin-portal | 8002 | no | /:8002 |
| enterprise-catalog | 8160 | yes | /health/:8160 |
| enterprise-catalog-worker | -- | no | -- |
| enterprise-learner-portal | 8002 | no | /:8002 |
| enterprise-subsidy | 18280 | yes | /health/:18280 |
| license-manager | 18170 | yes | /health/:18170 |
| lms | 8000 | yes | /heartbeat:8000 |
| lms-worker | -- | yes | -- |
| meilisearch | 7700 | no | /health:7700 |
| mfe | 8002 | no | -- |
| mux-delivery-monitor | 8000 | no | /healthz:8000 |
| mysql | 3306 | no | -- |
| notes | 8000 | no | /heartbeat:8000 |
| payments-gateway | 8080 | yes | /health/:8080 |
| postgresql-payments | 5432 | no | -- |
| preview-redirect | 80 | no | -- |
| redis | 6379 | no | -- |
| smtp | 8025 | no | -- |
| xqueue | 8000 | no | /status/:8000 (disabled) |

### Required Secrets (7 ExternalSecrets, 77 keys)

| ExternalSecret | Keys | Description |
|---------------|------|-------------|
| openedx-secrets | 43 | Platform secrets (JWT, OAuth, Stripe, Sentry, MUX, email) |
| database-secrets | 6 | MySQL passwords |
| enterprise-secrets | 12 | Enterprise service secrets + MySQL passwords |
| enterprise-sso-secrets | 4 | SAML/OIDC/SCIM credentials |
| aspects-secrets | 4 | ClickHouse + Superset credentials |
| payments-gateway-secrets | 6 | Purchase gateway DB + Stripe + OAuth |
| ses-smtp-credentials | 2 | SES relay credentials |

The base assumes a ClusterSecretStore named `gcp-secret-manager`. Overlays
that use a different backend (e.g., Infisical) must patch all ExternalSecrets.

### Required ConfigMaps (13)

All generated via `configMapGenerator` in the base kustomization. Overlays may
override individual files using `behavior: merge` or `behavior: replace`.

### Images

The base uses `pin-required` sentinel tags for openedx and MFE images. Non-local overlays **MUST** pin to immutable `tag+digest` references.

### GitOps Boundary

The contract defines exactly what the GitOps consumer repo may override.
See `contract.json` fields `allowedGitOpsOverrides` and `forbiddenGitOpsMutations`.

**Allowed**: namespace, image pins, ingress hosts, TLS, secret store refs,
env var injection (specific vars listed), resource sizing, replica counts,
ArgoCD config, storage class.

**Forbidden**: Python settings logic, hardcoded configmap hashes, full Caddyfile
overrides, mutable image tags, cluster-scoped resources in app overlay,
positional array patches, app middleware sequencing.

## What the GitOps Repo Must Provide

### Per-Environment Overlay

Each environment overlay must:
1. Reference `deploy/k8s/base` as the base layer (remote or local)
2. Set `namespace: mereka-lms`
3. Pin all images to immutable tags with digests
4. Provide Ingress resources for externally-accessible services
5. Patch the ClusterSecretStore if not using `gcp-secret-manager`
6. Set replica counts appropriate for the environment
7. Configure storage classes for PVCs

### Required Ingress Hosts (Production)

- LMS: `academyv2.mereka.io`, `academy.biji-biji.com`
- Studio: `studio.academyv2.mereka.io`
- MFE: `apps.academyv2.mereka.io`
- Enterprise Admin: `admin.academyv2.mereka.io`
- Enterprise Learner: `learner.academyv2.mereka.io`
- Credentials: `credentials.academyv2.mereka.io`
- Notes: `notes.academyv2.mereka.io`

## Local Development

`deploy/k8s/overlays/local/` is the reference implementation of a consumer
overlay. It demonstrates all required patches for a Kind cluster.

## Migration Status

| Overlay | Owner | Status |
|---------|-------|--------|
| `overlays/local/` | This repo | Permanent |
| `overlays/rke2-nonprod/` | GitOps repo | Pending migration |
| `overlays/staging/` | GitOps repo | Pending migration |
| `overlays/production/` | GitOps repo | Pending migration |
| `base/arc/` | GitOps repo | Pending migration |
