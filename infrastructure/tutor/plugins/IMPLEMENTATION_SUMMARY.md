# Tutor Plugin Implementation Summary

_Status: current as of 2026-04-22. Canonical operating docs remain
`infrastructure/tutor/plugins/README.md`,
`docs/reference/operations/TUTOR_CONFIG_CI.md`, and
`docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`._

## Current Shape

`infrastructure/tutor/plugins/mereka_lms.py` is a loader for the
`_mereka_lms/` package. The plugin owns behavior that Tutor hooks can express at
source-render time. The bounded post-render compatibility layer owns only the
classes documented in `infrastructure/tutor/patch-manifest.yml`.

Current plugin-owned areas:

| Area | Source owner |
|---|---|
| LMS settings, hosts, CSRF, sessions, enterprise, discussions | `_mereka_lms/lms_settings.py` |
| CMS settings | `_mereka_lms/cms_settings.py` |
| Shared asset settings | `_mereka_lms/asset_settings.py` |
| Open edX Dockerfile hooks | `_mereka_lms/openedx_dockerfile.py` |
| MFE Dockerfile hooks | `_mereka_lms/mfe_dockerfile.py` |
| MFE runtime/footer/slot config | `_mereka_lms/mfe_runtime.py` |
| Caddy edge config and SiteTheme init convergence | `_mereka_lms/infrastructure.py` |

Current non-plugin owners:

| Area | Owner |
|---|---|
| Local MySQL `MYSQL_ROOT_HOST: "%"` insertion | `infrastructure/tutor/patches/mysql-root-host.sh` |
| Tutor 21 MySQL native-password mode | upstream Tutor render, verified as `--mysql-native-password=ON` |
| Dependency image mirror normalization | `infrastructure/tutor/patches/dependency-image-mirrors.sh` |
| Build-optimizations residual render deltas | `infrastructure/tutor/patches/build-optimizations.sh` plus `build-optimizations.allowed-delta.yaml` |
| MFE npm install resilience | `infrastructure/tutor/patches/mfe-npm-install-resilience.sh` |
| MFE theme/brand filesystem sync | `brand-package.sh` and `sync-footer-assets.sh` |
| Retired Indigo/deprecated shell cleanup | manifest-listed migration guards |

## Boundary

Do not add hidden build semantics to the plugin or to `apply-patches.sh` without
updating:

1. `infrastructure/tutor/patch-manifest.yml`
2. `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`
3. the relevant verifier or fixture test
4. the retirement trigger for the temporary behavior

`apply-patches.sh` is not a second generator. It is a controlled compatibility
layer for file sync, migration guards, dependency acquisition normalization, and
bounded rendered-file exceptions.

## Local Verification

```bash
make tutor-verify
TUTOR_TEST_ASSUME_PATCHED_BASELINE=1 tests/tutor/run_all_tests.sh
./scripts/qa/verify-cold-start-onboarding-contract.sh
```

For CI parity and troubleshooting, see
`docs/reference/operations/TUTOR_CONFIG_CI.md`.

## Retired Claims

These are explicitly not current authority:

- `mysql-docker-compose` plugin hook ownership
- `--default-authentication-plugin=mysql_native_password` in the Tutor plugin
- `nginx-lms-config` plugin ownership
- direct operator use of `apply-patches.sh` as the clean-render entrypoint
- archiving `apply-patches.sh` before the manifest and inventory show no active
  temporary compatibility entries remain
