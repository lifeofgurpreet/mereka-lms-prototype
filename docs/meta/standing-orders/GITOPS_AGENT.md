# GitOps Agent Standing Order

> You are the consumer of the LMS deployment package.
> You realize environments and clusters.
> You do not re-implement app behavior.

## Mission

Make GitOps a clean environment/cluster realization layer with explicit topology, explicit ownership, and release-proof enforcement.

## Implementation Order

### PR1 - Topology Truth
Normalize or create:
- `config/service-topology-catalog.yaml`
- `config/bootstrap-lane-topology.yaml`
- `config/cluster-topology-catalog.yaml`

Rules: every service classified as exactly one of: env / cluster / global / preview / externalized / tooling-only. No `enabled:false` for env-scoped services. Use `lifecycle_state`: live / planned / externalized. Current runtime cluster and target runtime cluster must both be explicit.

### PR2 - Shared Nonprod Platform Owner
Create:
- `clusters/nonprod/rke2/platform-shared/`
- `bootstrap/platform/application-nonprod.yaml`
- `clusters/nonprod/rke2/platform/appproject-platform-nonprod.yaml`

Move cluster-scoped operators here while dev and staging still share one cluster. There must be exactly one active owner on the shared cluster.

### PR3 - Pure Workload Lanes
Ensure: dev tree contains only dev workloads, staging tree contains only staging workloads, prod platform ownership is explicit and singular, namespace normalization, zero namespace exceptions remain.

### PR4 - Consume LMS Contract, Do Not Redefine LMS
GitOps may own only: env var injection, image pins, ingress/TLS/certificates, secret-store/provider wiring, resource sizing, Argo applications/projects/sync policy, promotion policy.

GitOps must not own: Django production.py variants, runtime Python logic, app behavior Caddyfiles, auth/runtime workaround logic.

Pin and consume: `deploy/k8s/VERSION`, `deploy/k8s/contract.json`.

### PR5 - Migration Truth on the GitOps Side
Prove that migration execution receives the same truth as runtime. Audit and fix: configMap/secret parity between runtime pods and migration jobs, stale or ambiguous mongodb service presence, duplicate ingress host ownership, provider-neutral secret store patching, contract-compliant override fields only.

No promotion may be considered good unless LMS release-gate proof exists.

### PR6 - Runtime Validation
Add or extend post-merge validation to emit machine-readable proof for: contract version consumed, topology consistency, namespace consistency, duplicate host absence, migration proof presence, runtime app health and drift signals.

## Forbidden
- Duplicate cluster-scoped operators on the current shared nonprod cluster
- New runtime Python in GitOps
- New full Caddyfiles in GitOps
- New namespace exceptions
- New positional critical patches
- Mutable prod image tags
