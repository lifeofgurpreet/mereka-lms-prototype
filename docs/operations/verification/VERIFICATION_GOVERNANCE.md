# Verification Suite Governance

## Canonical Entry Points

1. `./scripts/qa/run-release-verification-gates.sh`
2. `./scripts/qa/run-operations-gates.sh --env <prod|dev|both>`
3. `./scripts/qa/run-multisite-governance-gates.sh --env <prod|dev|both>`

These are the only approved top-level gate entry points.

## Catalog Source of Truth

- Machine-readable: `docs/operations/verification/verification_catalog.json`
- Human summary: `docs/operations/verification/VERIFICATION_CATALOG.md`
- Deprecated archive: `docs/operations/verification/deprecated_verify_scripts.json`
- Generator: `python3 scripts/qa/generate-verification-catalog.py`
- CI gate: `./scripts/qa/verify-verification-catalog.sh`
- CI hygiene gate: `./scripts/qa/verify-deprecated-verification-hygiene.sh`

## Tier Policy

- `release_blocking`: MUST be bound to CI (`ci_static` or direct workflow use).
- `periodic_runtime`: SHOULD run from scheduled/runtime workflows or post-deploy runbooks.
- `exploratory_manual`: on-demand diagnostics only; not release-blocking.

## Deprecation Lifecycle

For scripts marked `deprecated_candidate` in the catalog:

1. Confirm no active workflow or runbook dependency.
2. Replace with one of the canonical entry points where possible.
3. Move decommissioned logic into docs/evidence or a consolidated gate.
4. Remove script from active references and regenerate the catalog.
5. Move retired scripts to `scripts/qa/deprecated/` and register them in `deprecated_verify_scripts.json`.

## Environment Dependency Boundary

To minimize “works on my machine” failures:

- `release_blocking` checks must remain repo-local (no implicit live-cluster dependency).
- Runtime-only checks must declare required tools/context (`kubectl`, `gcloud`, credentials, environment) in script help/comments.
- CI static lane must execute only deterministic scripts listed in `.github/ci-scripts-static.txt`.
