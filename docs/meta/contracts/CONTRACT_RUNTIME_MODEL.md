# Wave 6 Contract Runtime Model

## Purpose

Wave 6 extends the Wave 5 change-intelligence runtime from repo-native knowledge into
cross-repo deployment intelligence.

The contract runtime answers a narrower but higher-value question:

- if truth changes in `mereka-lms`, what else must change in `bbi-infrastructure`
  or in release evidence for system truth to remain valid?

## Scope

Wave 6 is explicitly about repo contract truth, not live runtime reconciliation.

In scope:

- service ownership
- repo ownership
- deployment surfaces
- secret surfaces
- environment obligations
- release obligations
- reviewer groups for deployment-affecting changes
- generated reports that classify cross-repo impact for a diff

Out of scope:

- querying live clusters
- comparing desired state against live ArgoCD or Kubernetes state
- runtime health reconciliation
- cross-repo automated patching

## Runtime objects

### Service contract

A service contract defines the deployable unit and the edges that matter for
cross-repo change safety.

Required attributes:

- service identifier
- owning repo
- deployment repo
- deployment surfaces
- environment surfaces
- secret surfaces
- evidence obligations
- runbook surfaces
- reviewer groups
- cross-repo counterpart expectation

### Deployment surface

A deployment surface is any file or control plane that can change how a service is
realized in an environment.

Examples:

- GitOps overlays
- ArgoCD applications or appsets
- image promotion or pinning surfaces
- ingress, DNS, and edge routing surfaces
- secret wiring surfaces
- monitoring and alerting surfaces

### Release obligation

A release obligation is a required human or generated follow-up that must move with
deployment-affecting truth.

Examples:

- runbook update
- evidence refresh
- release note or promotion note
- infra counterpart PR
- reviewer signoff

### Cross-repo impact classification

Each change analyzed by Wave 6 must resolve to one of these outcomes:

- `infra_counterpart_required`
- `infra_counterpart_not_required`
- `manual_review_required`
- `unknown_mapping`

Unknown mappings are allowed only when declared by source-controlled schemas.

## Source-of-truth files

Wave 6 policy must live in source-controlled files, not only generated outputs.

Authoritative schema files:

- `docs/meta/contracts/CROSS_REPO_OWNERSHIP.yaml`
- `docs/meta/contracts/RELEASE_OBLIGATIONS.yaml`
- `docs/meta/contracts/ENVIRONMENT_SURFACES.yaml`

Future contract inventory and crosswalk files:

- `deploy/contracts/service-contracts/*.yaml`
- `deploy/contracts/infra-crosswalk.yaml`

Generated outputs are read models only and must be reproducible from source policy.

## Review model

Wave 6 review is layered:

1. Wave 5 decides what changed in this repo.
2. Wave 6 decides what must change with it across repos.
3. CI blocks deployment-affecting drift that lacks declared ownership, impact, or
   release obligations.

## Packet ordering

- Packet A: schema
- Packet B: service inventory
- Packet C: infra crosswalk
- Packet D: cross-repo impact engine
- Packet E: release obligations engine
- Packet F: contract gates
- Packet G: closeout and operating model
