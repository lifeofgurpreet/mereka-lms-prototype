# Issue #217 Implementation Packet - Multi-Brand Asset SoT Sync/Drift

Issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/217  
Parent: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214  
Status: audit-to-implementation handoff

## Goal

Guarantee deterministic brand asset synchronization across all in-repo brand packages and Tutor theme consumers from one canonical source.

## Confirmed Risks

- `scripts/branding/sync-brand-assets.sh` currently drives `brand-mereka` sync flow.
- `infrastructure/tutor/brand-biji-biji` and `infrastructure/tutor/brand-skillourfuture` exist but are not first-class in canonical sync script.
- `sync-brand-assets.sh` includes workstation-specific optional source path to external repo (`/home/gurpreet/...`), reducing portability.

## Canonical Source

- In-repo SoT: `assets/branding/`
- Per-brand deltas (if any): brand manifests in repo, not ad-hoc local paths.

---

## PR Strategy (recommended 2 PRs)

1. `PR-217-A` multi-brand sync pipeline generalization
2. `PR-217-B` drift enforcement + CI integration

---

## PR-217-A (Multi-Brand Sync Generalization)

### File Changes

1. Add manifest:
   - `assets/branding/brand-packages.manifest.yml`
2. Add new orchestrator:
   - `scripts/branding/sync-brand-packages.sh`
3. Keep compatibility wrapper:
   - `scripts/branding/sync-brand-package.sh` (calls orchestrator for `brand-mereka`)
4. Update existing sync entrypoint:
   - `scripts/branding/sync-brand-assets.sh`

### Manifest Contract

For each brand package:
- package path
- font policy (shared vs brand-specific)
- logo/icon mappings
- optional overrides.

Example keys:
- `name`
- `package_dir`
- `source_asset_profile`
- `required_files`.

### Acceptance Criteria

- `AC-217-A1`: one command syncs `brand-mereka`, `brand-biji-biji`, `brand-skillourfuture`.
- `AC-217-A2`: sync behavior is deterministic and idempotent.
- `AC-217-A3`: no hard dependency on local absolute paths for default operation.

### Verification Commands

```bash
./scripts/branding/sync-brand-assets.sh
./scripts/branding/sync-brand-packages.sh --check
find infrastructure/tutor/brand-* -maxdepth 2 -type f | sort
```

---

## PR-217-B (Drift Gate + CI)

### File Changes

1. Add drift verifier:
   - `scripts/qa/verify-brand-packages-drift.sh`
2. Wire to CI:
   - `.github/workflows/ci.yml`
3. Document contract:
   - `docs/guides/branding/BRAND_ASSET_SYNC_CONTRACT.md`

### Drift Verifier Contract

- Compute hashes for canonical assets and synced copies.
- Fail on missing required files or content mismatch.
- Emit actionable mapping:
  - `source -> destination -> mismatch reason`.

### Acceptance Criteria

- `AC-217-B1`: CI fails when any brand package drifts from canonical asset rules.
- `AC-217-B2`: docs specify how to add a new brand package without breaking gates.

### Verification Commands

```bash
bash -n scripts/qa/verify-brand-packages-drift.sh
./scripts/qa/verify-brand-packages-drift.sh
```

---

## Rollback Plan

1. If strict drift gate blocks unrelated PRs:
   - temporary warn mode via `STRICT_BRAND_PACKAGE_DRIFT=0` in CI.
2. Keep compatibility wrapper script in place for one release cycle.
3. Do not rollback to manual per-package ad-hoc copying.

## Implementation Notes

- Keep token provenance flow separate from package sync logic.
- Ensure `brand-package.sh` Tutor patch remains aligned with selected package(s) used in build context.
