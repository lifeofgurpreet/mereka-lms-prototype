# Patch Idempotency Testing

## Problem

`infrastructure/tutor/apply-patches.sh` modifies Tutor-generated template files. If a patch function is not idempotent, running `apply-patches.sh` twice produces different output -- duplicate `INSTALLED_APPS` entries, doubled middleware, extra env vars, etc.

## Solution

`scripts/qa/verify-patch-idempotency.sh` verifies idempotency two ways:

1. **Checksum comparison**: Runs `apply-patches.sh` twice and verifies all patched files produce identical SHA-256 checksums.
2. **Duplicate marker detection**: Scans patched files for sentinels (e.g. `INSTALLED_APPS.append('mfe_oauth_fix')`) and verifies each appears at most once.

## Usage

```bash
# Full test (requires Tutor environment)
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/qa/verify-patch-idempotency.sh --tutor

# Offline mode (checks existing files for duplicate markers only)
./scripts/qa/verify-patch-idempotency.sh --offline

# Dry-run (lists what would be checked)
./scripts/qa/verify-patch-idempotency.sh --dry-run
```

## CI

The `verify-patch-idempotency.yml` workflow runs on PRs that touch `infrastructure/tutor/**`. It installs Tutor, generates a clean config, and runs the full idempotency test.

## Adding New Patches

When adding a new patch to `apply-patches.sh`:

1. Ensure the patch function checks whether it has already been applied before modifying text (e.g. `if "marker" in text: return text`).
2. Add a corresponding entry to the `DUPLICATE_CHECKS` array in `verify-patch-idempotency.sh`.
3. Run `./scripts/qa/verify-patch-idempotency.sh --tutor` locally before pushing.
