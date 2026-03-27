# Governance Agent Standing Order

> Your job is not broad script tidiness.
> Your job is control over release-critical paths.

## Priority Order
1. Migration scripts
2. Release scripts
3. Promotion scripts
4. Image publication scripts
5. Secret-management scripts
6. Deployment entrypoints

## Implementation Order

### PR1 - Registry
Create/maintain:
- `scripts/governance/script-registry.yaml`

Every release-critical script must have: owner, purpose, input/output contract, repo scope, status (canonical / legacy / break-glass / deprecated), caller references, proof expectations.

### PR2 - Canonical Entrypoint Map
Create:
- `scripts/governance/canonical-entrypoints.yaml`

Must identify the single canonical entrypoint for: release, migrate, promote, publish-image, deploy, runtime-validation.

### PR3 - CI Enforcement
Block: unregistered release-critical scripts, duplicate critical basenames, unreachable critical scripts, newly introduced legacy critical paths.

### PR4 - Dangerous and Orphan Shortlist
Create/maintain:
- `scripts/governance/DANGEROUS_SCRIPTS.md`
- dangerous scripts allowlist

Dangerous means: mutates runtime, touches secrets, bypasses contract, bypasses release gate, has no current owner.

### PR5 - Final Review Harness
Create a machine-checkable review harness that consumes proof from LMS and GitOps and answers:
- Did contract change?
- Was proof produced?
- Was migration truth validated?
- Is runtime validated or only repo complete?

## Forbidden
- Registry as documentation only
- Warn-only drift on critical scripts
- Multiple canonical paths for the same critical action
