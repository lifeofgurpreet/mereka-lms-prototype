# Wave 9 Prerequisite — App-Repo Shadow Overlay Reference Audit

**Date:** 2026-04-19
**Triggered by:** #1872 (m0u5.9 architect remediation) — recommendation to accelerate Wave 9 deletion
**Overlays in scope:** `deploy/k8s/overlays/rke2-nonprod/`, `deploy/k8s/overlays/production/`, `deploy/k8s/overlays/staging/`

## Phase 1 Verdict: CANNOT DELETE YET

All three overlay directories are confirmed DEPRECATED with Wave 9 deletion markers in their
`kustomization.yaml` headers. However, the overlays cannot be deleted atomically because 63 files
across `scripts/` and `.github/` hold functional (non-comment) path references to these directories.
Deleting without updating these callers would break CI gates, release scripts, and QA verifiers.

## Reference Count Summary

| Category | File count | Notes |
|---|---|---|
| `scripts/infra/` — release/deploy scripts | 6 | Read + write the files; deletion breaks live release path |
| `scripts/qa/` — verifiers and audits | 50+ | Read existence, parse YAML, assert structure |
| `scripts/governance/` — registry + entrypoints | 2 | Document the overlay paths as script outputs |
| `.github/CODEOWNERS` | 1 | Owns `/deploy/k8s/overlays/production/` |
| **Total non-doc files** | **63** | |

## High-Impact References (block deletion)

### `scripts/infra/release-openedx-gitops.sh`
```
APP_PROD_REL="deploy/k8s/overlays/production/kustomization.yaml"
APP_STAGING_REL="deploy/k8s/overlays/staging/kustomization.yaml"
```
Writes image tags into the app-repo overlay, commits, and pushes. This script is the
release-blocking `promote` entrypoint per `canonical-entrypoints.yaml`.

**Required fix:** Retarget writes to `bbi-infrastructure` repo overlay paths via cross-repo
dispatch (GitHub App dispatch already exists from WS4). The script already references
`INFRA_STAGING_REL="apps/mereka-lms/overlays/staging/kustomization.yaml"` for the
bbi-infrastructure path; the `APP_PROD_REL`/`APP_STAGING_REL` writes must be removed.

### `scripts/infra/bump-image-tags.sh`
```
OVERLAY_FILE="${REPO_ROOT}/deploy/k8s/overlays/production/kustomization.yaml"
```
Queries GCR and writes updated image tags directly into the production overlay.

**Required fix:** Deprecate or retarget to bbi-infrastructure; this script is a GKE relic
(queries GCR Artifact Registry, which is decommissioned).

### `scripts/infra/verify-release-preflight.sh`
Asserts `deploy/k8s/overlays/production/kustomization.yaml` and `deploy/k8s/overlays/staging/kustomization.yaml`
exist and are non-empty. Will hard-fail after deletion.

**Required fix:** Update assertions to check bbi-infrastructure paths (or remove checks,
since app-repo overlays are no longer authoritative).

### `scripts/infra/assemble-release-evidence.sh` and `sync-gitops-prod-image-tags.sh`
Read image tags from `deploy/k8s/overlays/production/kustomization.yaml` to build release
evidence artifacts. Both will produce empty/corrupt output after deletion.

**Required fix:** Switch source of truth to bbi-infrastructure overlay or to CI-emitted
`release_object` artifact (which already carries pinned digests from WS4 dispatch chain).

### `scripts/qa/verify-runtime-authority-map.sh`
Explicitly checks for existence, DEPRECATED marker, and image sentinel in all three overlays
at lines 73–251. This verifier is in the static CI inventory and runs on every PR.

**Required fix:** After deletion, update this verifier to skip existence checks for deleted
overlays OR convert the check to "confirm overlay is absent" (inversion guard).

### `scripts/qa/verify-staging-activation.sh`
Asserts `deploy/k8s/overlays/staging/` exists at line 103–107 (`fail_check` on absence).
Runs in CI. Will hard-fail after deletion.

**Required fix:** Remove or invert the existence assertion; replace with bbi-infrastructure
overlay existence probe (requires INFRA_REPO env to be available in CI).

### `scripts/qa/verify-release-dry-run-contract.sh`
Copies `deploy/k8s/overlays/production/kustomization.yaml` into a temp fixture at line 43.
Will fail with `cp: source not found` after deletion.

**Required fix:** Either carry a static fixture copy for the dry-run contract test, or
re-point to a bbi-infrastructure path.

### `scripts/governance/script-registry.yaml`
Documents `deploy/k8s/overlays/production/kustomization.yaml` as the output of
`release-openedx-gitops.sh` and `bump-image-tags.sh`. Registry is a governance surface —
stale output paths mislead future agents.

**Required fix:** Update `outputs:` fields after fixing the scripts themselves.

### `.github/CODEOWNERS`
```
/deploy/k8s/overlays/production/ @Biji-Biji-Initiative/infra
```
Benign after deletion (no-op CODEOWNERS rules for absent paths don't error), but should be
removed for hygiene.

## Prerequisite Work Before Wave 9 Can Execute

The following must happen in a prerequisite PR **before** the overlay directories are deleted:

1. **Retarget release scripts** (`release-openedx-gitops.sh`, `assemble-release-evidence.sh`,
   `sync-gitops-prod-image-tags.sh`) — remove writes to app-repo overlay; source image tags
   from `release_object` artifact or bbi-infrastructure overlay.
2. **Deprecate `bump-image-tags.sh`** — GCR-targeting GKE relic; mark deprecated or remove.
3. **Fix `verify-release-preflight.sh`** — update overlay existence assertions.
4. **Fix `verify-staging-activation.sh`** — invert or remove `deploy/k8s/overlays/staging` existence check.
5. **Fix `verify-release-dry-run-contract.sh`** — use static fixture instead of `cp` from live overlay.
6. **Fix `verify-runtime-authority-map.sh`** — convert existence checks to absence-assertions post-deletion.
7. **Update `script-registry.yaml` outputs** — after scripts are retargeted.
8. **Remove CODEOWNERS entry** — hygiene.

## Files Safe to Ignore (docs, history, comments)

References in `docs/` are historical narrative — safe to leave as-is or update opportunistically.
References in `scripts/qa/deprecated/` are already deprecated scripts — non-blocking.

## Recommendation

Open prerequisite PR (suggested title: `fix(scripts): retarget release + QA scripts from
app-repo shadow overlays to bbi-infrastructure (Wave 9 unblock)`) that addresses items 1–8
above. Once merged and CI green, the actual Wave 9 deletion PR can proceed as originally
scoped.
