# Wave 14 Team Handbook Source Map

This page locks the Wave 14 handbook shape before handbook prose or generated references are added.

## Scope

- Human handbook pages live under `docs/guides/platform/`.
- Generated reference pages live under `docs/reference/platform/`.
- Canonical machine-readable outputs live under `generated/platform/`.
- Generators and verifiers live under `tools/docs/`.
- The canonical docs front door remains [docs/README.md](../../README.md); Packet F will add discoverability links there instead of creating a competing entrypoint.

## Canonical input policy

- Prefer machine-readable registries, contracts, and generated packs over handwritten summaries.
- Use existing canonical docs for platform-specific guidance.
- Use official Open edX and Tutor docs as deep links for generic product behavior.
- Do not use transitional or archive roots as primary read-first surfaces.
- Do not restate volatile URL, lane, service identity, or topology facts in handbook prose when a generated reference can carry them.

## Source resolution notes

The Wave 14 brief named some historical Wave 10-era files that are not present on the current `main` checkout. Wave 14 uses the live canonical inputs available on the Wave 13 lineage instead of recreating those historical names.

| Handbook surface | Artifact mode | Canonical internal sources | Generated sources | Official external references | Owner | Review cadence |
| --- | --- | --- | --- | --- | --- | --- |
| `docs/guides/platform/PLATFORM_START_HERE.md` | Human-authored | `docs/README.md`, `docs/guides/README.md`, `docs/guides/INDEX_BY_AUDIENCE.md`, `docs/ops/quickref/README.md` | `generated/platform/domain-access-reference.json`, `generated/platform/team-topology-reference.json`, `generated/knowledge/read-first-packs.json` | Open edX docs portal, Tutor docs portal | Platform Team | each handbook packet and each platform topology change |
| `docs/guides/platform/OPENEDX_FOR_TEAM_MEMBERS.md` | Human-authored | `docs/guides/admin/MULTI_SITE_GUIDE.md`, `docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md`, `docs/reference/operations/ENTERPRISE_MULTI_TENANCY_NAVIGATION.md`, `docs/reference/operations/DOMAIN_MATRIX.md` | `generated/platform/team-topology-reference.json`, `generated/platform/domain-access-reference.json` | Open edX architecture and sites docs, Tutor configuration overview | Platform Team | each handbook packet and each tenant model change |
| `docs/guides/platform/COURSE_AUTHORING_QUICKSTART.md` | Human-authored | `docs/guides/admin/ADMIN_LOGIN_GUIDE.md`, `docs/reference/operations/USER_FACING_URLS.md`, `docs/guides/admin/MULTI_SITE_GUIDE.md` | `generated/platform/domain-access-reference.json` | Open edX Studio course-creation docs, Open edX course authoring quick start | Platform Team | each handbook packet and before course-authoring workflow changes ship |
| `docs/guides/platform/OPENEDX_SETTINGS_MATRIX.md` | Human-authored | `docs/guides/admin/MULTI_SITE_GUIDE.md`, `docs/guides/admin/K8S_OPERATIONS_GUIDE.md`, `docs/guides/admin/SECRETS_MANAGEMENT_GUIDE.md`, `docs/ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md` | `generated/platform/team-topology-reference.json` | Open edX site configuration docs, Tutor config and plugin docs | Platform Team | each handbook packet and whenever ownership boundaries move |
| `docs/guides/platform/MULTI_TENANCY_EXPLAINED.md` | Human-authored | `docs/guides/admin/MULTI_SITE_GUIDE.md`, `docs/reference/operations/DOMAIN_MATRIX.md`, `docs/reference/operations/MULTITENANT_BRAND_PLATFORM.md`, `docs/reference/operations/ENTERPRISE_MULTI_TENANCY_NAVIGATION.md` | `generated/platform/team-topology-reference.json`, `generated/platform/domain-access-reference.json` | Open edX sites and theming docs | Platform Team | each handbook packet and each tenant/domain topology change |
| `docs/guides/platform/SUPPORT_AND_ESCALATION.md` | Human-authored | `docs/ops/quickref/README.md`, `docs/ops/runbooks/README.md`, `docs/reference/operations/DOMAIN_MATRIX.md`, `docs/guides/INDEX_BY_AUDIENCE.md` | `generated/platform/domain-access-reference.json`, `generated/platform/team-topology-reference.json` | Open edX support-facing docs only as targeted links when relevant | Platform Team | each handbook packet and after major support routing changes |
| `docs/guides/platform/SOURCE_MAP.md` | Human-authored | this file, `docs/README.md`, `docs/guides/standards/DOCS_SPECS_CONTRACT.md` | `generated/skills/read-first.json`, `generated/knowledge/read-first-packs.json` | none required | Platform Team | every packet in this wave |
| `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md` | Generated markdown projection | `bbi-infrastructure/config/domain-registry.yaml`, `docs/reference/operations/DOMAIN_MATRIX.md`, `docs/reference/operations/USER_FACING_URLS.md` | `generated/platform/domain-access-reference.json` | none required in generated output | Platform Team | regenerated on every relevant source change |
| `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md` | Generated markdown projection | `bbi-infrastructure/config/bootstrap-lane-topology.yaml`, `bbi-infrastructure/config/domain-registry.yaml`, `platform-control-plane/contracts/service-identity-contract.yaml`, `platform-control-plane/contracts/release-contracts.yaml`, `docs/guides/admin/MULTI_SITE_GUIDE.md` | `generated/platform/team-topology-reference.json` | none required in generated output | Platform Team | regenerated on every relevant source change |
| `generated/platform/domain-access-reference.json` | Canonical generated machine output | `bbi-infrastructure/config/domain-registry.yaml`, `docs/reference/operations/DOMAIN_MATRIX.md`, `docs/reference/operations/USER_FACING_URLS.md` | none | none | Platform Team | regenerated on every relevant source change |
| `generated/platform/team-topology-reference.json` | Canonical generated machine output | `bbi-infrastructure/config/bootstrap-lane-topology.yaml`, `bbi-infrastructure/config/domain-registry.yaml`, `platform-control-plane/contracts/service-identity-contract.yaml`, `platform-control-plane/contracts/release-contracts.yaml`, `docs/guides/admin/MULTI_SITE_GUIDE.md` | none | none | Platform Team | regenerated on every relevant source change |

## Generated versus handwritten split

### Handwritten

- `PLATFORM_START_HERE.md`
- `OPENEDX_FOR_TEAM_MEMBERS.md`
- `COURSE_AUTHORING_QUICKSTART.md`
- `OPENEDX_SETTINGS_MATRIX.md`
- `MULTI_TENANCY_EXPLAINED.md`
- `SUPPORT_AND_ESCALATION.md`
- `SOURCE_MAP.md`

### Generated

- `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`
- `docs/reference/platform/TEAM_TOPOLOGY_REFERENCE.md`
- `generated/platform/domain-access-reference.json`
- `generated/platform/team-topology-reference.json`

## Read-first order for Wave 14 implementation

1. `docs/README.md`
2. `docs/guides/README.md`
3. `bbi-infrastructure/config/domain-registry.yaml`
4. `bbi-infrastructure/config/bootstrap-lane-topology.yaml`
5. `platform-control-plane/contracts/service-identity-contract.yaml`
6. `platform-control-plane/contracts/release-contracts.yaml`
7. `docs/reference/operations/DOMAIN_MATRIX.md`
8. `docs/reference/operations/USER_FACING_URLS.md`
9. `docs/guides/admin/MULTI_SITE_GUIDE.md`

## Guardrails for later packets

- Human handbook pages must link to generated references for volatile facts instead of copying them.
- Generated markdown must carry a generated banner and must be reproducible from its JSON source.
- If a claimed source does not exist locally when a generator needs it, fail the generator instead of guessing.
- Packet F may update existing docs front doors for discoverability, but the handbook must stay inside the canonical docs portal instead of becoming a new standalone portal.
