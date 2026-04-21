# Tutor Configuration CI/CD Reference
_Audience: Operators and release owners • Owner: Platform Team • Last verified: 2026-04-21 • Status: canonical_

This document describes the current CI surfaces that validate Tutor render,
patch, and plugin contracts.

## Current Workflow Owners

### Main CI Tutor Lane

**Workflow:** `.github/workflows/ci.yml`
**Job:** `tutor-config-tests`

**Current behavior:**

- runs only when the change-scope selector marks Tutor authority as in scope
- on unrelated PRs, the lane is skipped and workflow-contract verifiers enforce
  CI-control-plane truth instead
- on Tutor-authority PRs, the job renders a clean Tutor environment through
  `./scripts/infra/tutor-config-save.sh`; the wrapper is the single front door
  for `tutor config save`, build-context preparation, and
  `./scripts/infra/verify-tutor-config.sh`
- after that governed render baseline, CI runs the Tutor verification shell
  tests, including:
  - `tests/tutor/test_tutor_apply.sh`
  - `tests/tutor/test_verify_patches.sh`
  - `tests/tutor/test_idempotency.sh`
  - `tests/tutor/test_edge_cases.sh`
  - `scripts/qa/check-config-example-yaml.py`

This is an important boundary:

- **operator and CI front door:** `./scripts/infra/tutor-config-save.sh`, with
  `./scripts/infra/prepare-tutor-build-context.sh --target ...` as the manual
  post-render refresh path
- **low-level helper contract:** `./infrastructure/tutor/apply-patches.sh`
  remains directly tested for re-run/idempotency behavior, but it is not the
  clean-render entrypoint in CI
- **render verifier authority:** `./scripts/infra/verify-tutor-config.sh` is the
  canonical rendered verifier; `./scripts/qa/verify-tutor-patches.sh` is a stable
  compatibility entrypoint that delegates to it

### Tutor Plugin / Render Contract

**Workflow:** `.github/workflows/tutor-plugin-test.yml`

**Current jobs:**

1. `lint-plugins`
   - compiles Tutor plugin sources
   - runs `ruff` and `black --check`
2. `verify-retired-legacy-shim`
   - verifies `mfe_oauth_fix.py` stays a metadata-only compatibility shim
   - rejects old `ENV_PATCHES` behavior or config-example re-enablement
3. `render-contract-preflight`
   - installs Tutor into an isolated CI venv
   - runs `./scripts/ci/preflight-check.sh`
   - validates rendered Dockerfile and plugin/render-contract assumptions

This workflow is the current plugin/render-contract owner. It is not the older
"plugin lifecycle plus PR comment" workflow described in superseded docs.

## Running Locally

### Verify Tutor Configuration Contract

```bash
# Quick check (Make target)
make tutor-verify

# Full verifier
./scripts/infra/verify-tutor-config.sh
```

### Recreate The Governed Operator Flow

```bash
./scripts/infra/tutor-config-save.sh

# Or, after a manual tutor config save:
./scripts/infra/prepare-tutor-build-context.sh --target all
```

### Recreate CI Helper-Level Baseline

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh
bash tests/tutor/test_tutor_apply.sh
bash tests/tutor/test_verify_patches.sh
```

### Test Tutor Plugin / Render Contract

```bash
# Source lint and compile checks
python3 -m compileall infrastructure/tutor/plugins
ruff check infrastructure/tutor/plugins/
black --check infrastructure/tutor/plugins/

# Render-contract preflight
python3 -m venv .ci-venv
source .ci-venv/bin/activate
pip install -U pip
pip install -r requirements-tutor.txt
TUTOR_VENV="$(pwd)/.ci-venv" ./scripts/ci/preflight-check.sh
```

## What CI Actually Proves

Current CI covers these contract classes:

- Tutor source -> render -> build-context -> verifier chain still works from a
  clean baseline through the canonical wrapper
- the Makefile and wrapper scripts are wired correctly
- patch verification tests still pass against the canonical rendered verifier
- `apply-patches.sh` remains re-runnable enough for the declared idempotency
  contract
- plugin sources lint and compile
- the retired standalone `mfe_oauth_fix` shim stays metadata-only
- rendered plugin and Dockerfile contract preflight still passes

## Failure Scenarios

### Tutor Config Lane Fails In `ci.yml`

**Symptom:** `Tutor Configuration Tests` fails in `.github/workflows/ci.yml`

**Fix:**
```bash
./scripts/infra/tutor-config-save.sh
bash tests/tutor/test_tutor_apply.sh
bash tests/tutor/test_verify_patches.sh
```

If the failure reproduces only after a helper-level rerun, isolate the helper
contract separately:

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./infrastructure/tutor/apply-patches.sh
```

Use the wrapper path for clean-render/operator guidance. Use the raw helper path
only when reproducing apply/idempotency behavior after a rendered baseline
already exists.

### Plugin / Render Contract Fails

**Symptom:** `.github/workflows/tutor-plugin-test.yml` fails

**Fix:**

```bash
python3 -m compileall infrastructure/tutor/plugins
ruff check infrastructure/tutor/plugins/
black --check infrastructure/tutor/plugins/
TUTOR_VENV="$(pwd)/.ci-venv" ./scripts/ci/preflight-check.sh
```

### Multi-Site Domain Or Hostname Drift

**Symptom:** Tutor verification fails on host or Caddy contract checks

**Fix:**
Review the actual source owners first:

- `infrastructure/tutor/patches/caddyfile`
- `infrastructure/tutor/plugins/mereka_lms.py`
- `infrastructure/tutor/config.example.yml`
- `scripts/infra/verify-tutor-config.sh`
- `scripts/qa/verify-tutor-patches.sh`

## Integration with CI Pipeline

The current split is:

1. `.github/workflows/ci.yml` owns the main Tutor configuration contract lane.
2. `.github/workflows/tutor-plugin-test.yml` owns plugin/render-contract
   preflight.
3. Docs-only or workflow-only diffs may skip the full Tutor render lane and are
   instead enforced by workflow contract verifiers.

## Monitoring

- **GitHub Actions** - View workflow runs at: https://github.com/Biji-Biji-Initiative/mereka-lms/actions
- **PR Comments** - Failed verifications post detailed comments on PRs
- **Workflow Badges** - Status badges in README.md show workflow health

## Related Documentation

- **Spec:** `specs/tutor-configuration_spec.md` - Full requirements
- **Spec:** `specs/multi-site-domains_spec.md` - Multi-site domain requirements
- **Script:** `scripts/infra/tutor-config-save.sh` - Governed operator front door
- **Script:** `scripts/infra/prepare-tutor-build-context.sh` - Manual post-render refresh path
- **Script:** `infrastructure/tutor/apply-patches.sh` - Low-level CI/helper patch application script
- **Script:** `scripts/infra/verify-tutor-config.sh` - Verification script
- **Workflow:** `.github/workflows/ci.yml` - Main Tutor configuration lane
- **Workflow:** `.github/workflows/tutor-plugin-test.yml` - Tutor plugin / render-contract lane

## Troubleshooting

### Workflow Fails But Local Verification Passes

**Cause:** CI starts from a cleaner rendered baseline than most local flows, but
it should still use the same wrapper/verifier path as local development.

**Fix:** Ensure `infrastructure/tutor/config.example.yml` is up to date

### Patch Idempotency Test Fails

**Cause:** `apply-patches.sh` changed its re-apply behavior against the rendered
baseline.

**Fix:** Reproduce with `bash tests/tutor/test_idempotency.sh` and correct the
helper-level patch contract. This is a CI/helper contract, not a reason to
change the operator front door back to raw helper execution.

### Render-Contract Preflight Fails

**Cause:** Plugin mirror, rendered Dockerfile contract, or helper ownership
split drifted.

**Fix:** Inspect:

- `scripts/ci/preflight-check.sh`
- `infrastructure/tutor/plugins/`
- `infrastructure/tutor/custom-apps/`
- rendered snapshot expectations in the current MFE/Tutor owner docs

## Future Improvements

- keep reducing direct helper tests to fixture-level proofs where possible, but
  do not reintroduce a second clean-render lane
- expand render-contract preflight coverage only when source truth adds a new
  durable contract
