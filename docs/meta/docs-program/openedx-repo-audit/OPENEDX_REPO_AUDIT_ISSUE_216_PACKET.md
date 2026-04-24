# Issue #216 Implementation Packet - IaC Control-Plane Unification

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/216  
Parent: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214  
Status: audit-to-implementation handoff

## Goal

Eliminate conflicting deployment control paths by enforcing one canonical release flow for Open edX workloads.

## Confirmed Risks

- `scripts/export-k8s-manifests.sh` rewrites `deploy/k8s/base` from Tutor-generated `tutor_env/env/**`.
- `scripts/infra/deploy-aspects-k8s.sh` still executes `tutor k8s init` and applies from `tutor_env/env/k8s`.
- Legacy override scripts exist (`setup-k8s-overrides.sh`, `verify-k8s-overrides.sh`) while canonical flow is GitOps-based.
- Docs already define canonical flow (`docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`) but conflicting scripts remain executable.

## Target Control Plane

1. Render/build with Tutor as needed.
2. Managed manifests in `deploy/k8s/**` are source of truth.
3. Update image tags + pinned base ref via `scripts/infra/release-openedx-gitops.sh`.
4. ArgoCD reconciles from GitOps repo.

No direct production path through `tutor k8s init/apply`.

---

## PR Strategy (recommended 2 PRs)

1. `PR-216-A` deprecation fencing and workflow guardrails
2. `PR-216-B` docs and boundary contract consolidation

---

## PR-216-A (Deprecation Fencing + Guardrails)

### File Changes

1. Deprecation guard updates:
   - `scripts/export-k8s-manifests.sh`
   - `scripts/infra/deploy-aspects-k8s.sh`
   - `scripts/infra/setup-k8s-overrides.sh`
   - `scripts/infra/verify-k8s-overrides.sh`
2. CI guard script:
   - `scripts/qa/verify-no-legacy-tutor-k8s-paths.sh`
3. CI workflow wiring:
   - `.github/workflows/ci.yml`

### Script Guard Contract

Each deprecated script should:
- print clear deprecation message
- point to canonical replacement (`release-openedx-gitops.sh` / canonical release flow)
- exit non-zero by default
- allow explicit temporary bypass with env var:
  - `ALLOW_LEGACY_TUTOR_K8S=1`

### CI Guard Contract

`verify-no-legacy-tutor-k8s-paths.sh` should fail if:
- release workflows invoke deprecated scripts
- release workflows invoke `tutor k8s init` or `tutor k8s apply` directly
- docs labeled as active runbooks recommend deprecated path

### Acceptance Criteria

- `AC-216-A1`: deprecated scripts cannot be used accidentally in default mode.
- `AC-216-A2`: CI fails if workflows reference legacy Tutor K8s deployment path.
- `AC-216-A3`: bypass is explicit and auditable (`ALLOW_LEGACY_TUTOR_K8S=1`).

### Verification Commands

```bash
bash -n scripts/qa/verify-no-legacy-tutor-k8s-paths.sh
./scripts/qa/verify-no-legacy-tutor-k8s-paths.sh
rg -n "tutor k8s init|tutor k8s apply|export-k8s-manifests|setup-k8s-overrides|deploy-aspects-k8s" .github/workflows scripts docs
```

---

## PR-216-B (Boundary Contract Consolidation)

### File Changes

1. Add boundary contract doc:
   - `docs/policies/operations/REPO_BOUNDARIES.md`
2. Update active runbooks/docs:
   - `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
   - `scripts/infra/README.md`
   - any active docs under `docs/operations/` that still recommend deprecated flow

### Required Content

Document authoritative ownership:
- `infrastructure/terraform/**`: cloud infrastructure only
- `deploy/k8s/**`: app manifest source
- GitOps repo overlays: live environment realization
- Tutor rendering: build-time input, not runtime apply channel

### Acceptance Criteria

- `AC-216-B1`: docs have no conflicting active deploy path definitions.
- `AC-216-B2`: one canonical command chain is referenced by all active deploy runbooks.
- `AC-216-B3`: legacy scripts are marked historical/exception-only.

### Verification Commands

```bash
rg -n "canonical-release|release-openedx-gitops" docs/operations scripts/infra/README.md
rg -n "tutor k8s init|tutor k8s apply" docs/operations scripts/infra/README.md
```

---

## Rollback Plan

1. If critical release blocked:
   - run deprecated script with `ALLOW_LEGACY_TUTOR_K8S=1` for emergency only.
2. Record emergency use in issue `#216` and create follow-up to remove bypass dependency.
3. Keep guard script in CI even during emergency mode to prevent silent regression.

## Implementation Notes

- Do not delete legacy scripts in first pass; fence and document first.
- Avoid mixing this with manifest content refactors in same PR.
- Keep all production rollout behavior anchored on GitOps convergence checks.
