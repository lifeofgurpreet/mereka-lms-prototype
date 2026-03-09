---
spec: repository-structure_spec.md
tier: 0
status: draft
estimated_effort: M
last_updated: '2026-03-09'
---

# Implementation Plan: Repository Structure

**Source Spec**: `specs/repository-structure_spec.md`
**Tier**: 0 -- Foundations (blocks all other specs)
**Last Updated**: 2026-02-10

## Summary

This plan implements the repository structure specification by: (1) creating any missing required directories, (2) archiving root-level markdown files that violate the allowlist, (3)verifying deprecated directory hygiene, (4) building an automated verification script that checks all 12 acceptance criteria, and (5) optionally integrating the verification into CI as a GitHub Actions workflow.

The repository already has most of the required structure inplace. The primary work items are cleaning up ~12 extra root-level markdown files, ensuring the verification script is comprehensive and fast, and integrating verification into the development workflow.

## Current State Assessment

Existing violations detected against the spec:

| Violation | Details |
|-----------|---------|
| Root markdown allowlist | 12 extra files: `ALTERNATIVE_DOMAIN_FIX_SUMMARY.md`, `BILLING_SUMMARY.txt`, `COST_BREAKDOWN_VISUALIZATION.txt`, `DEPLOY_BRANDING_FIX.md`, `FIX_README.md`,`GKE_LOKI_SETUP_SUMMARY.md`, `LOGO_FIX_DEPLOYMENT_CHECKLIST.md`, `LOGO_FIX_SUMMARY.md`, `MFE_OAUTH_FIX_CHECKLIST.md`, `MFE_OAUTH_FIX_README.md`, `MFE_OAUTH_FIX_SUMMARY.md`, `MONITORING_DELIVERABLES.md`, `PROMETHEUS_INTEGRATION.md`, `STUDIO_BRANDING_FIX_VERIFIED.md` |
| Root `.txt` files | `BILLING_SUMMARY.txt`, `COST_BREAKDOWN_VISUALIZATION.txt` (not markdown, but still clutter) |
| Root test scripts | `test-mct-api.mjs`, `test-mct-direct.mjs`, `test-no-client-type.mjs`, `test-sof-api.mjs`, `test-sof-self.mjs`, `test-v3.mjs` (executable scripts at root) |
| Undocumented top-level dirs | `exports/`, `hubspot-webhook-mct/`, `patches/`, `tmp/` exist but are not in the spec's canonical layout |
| Root misc files | `nul`, `mereka-academy.code-workspace`, `test-*.mjs` |
| AC-006 (no hardcoded secrets) | Needs audit of `deploy/k8s/base/secrets/` YAML files |

Compliant areas (already passing):
- All 7 required top-level directories exist (`deploy/`, `scripts/`, `infrastructure/`, `docs/`, `specs/`, `services/`, `assets/`, `apps/`)
- All 6 required `scripts/` subdirectories exist (`shared/`,`infra/`, `migrations/`, `branding/`, `analytics/`, `qa/`)
- `scripts/shared/config.sh` exists and exports required variables
- `deploy/k8s/overlays/local/` and `production/` exist
- `deploy/k8s/base/secrets/`, `apps/`, `plugins/` exist
- All 6 required `docs/` subdirectories exist
- All 4 required `infrastructure/` subdirectories exist
- `var/` and `tutor_env/` are in `.gitignore`
- All `specs/*.md` files follow `*_spec.md` naming (except `IMPLEMENTATION_ORDER.md` which is a meta-doc)
- Deprecated `tools/` and `ops/` directories do not exist

## Prerequisites

- Repository must be on `main` branch or a feature branch
- No other reorganization PRs in flight (to avoid merge conflicts)
- `shellcheck` installed for linting the verification script(`apt install shellcheck`)

---

## Task Breakdown

### Build

1. **[S] Create verification script skeleton**

   Create `scripts/qa/verify-repo-structure.sh` with the framework from the spec's Verification section. Implement the `check()` helper function, timing mechanism (to verify <5s completion), and the PASS/FAIL output format. The script must be executable and pass shellcheck.

   - Files: `scripts/qa/verify-repo-structure.sh` (create)
   - Complexity: S
   - Dependencies: None
   - AC: AC-012

2. **[M] Implement all AC checks in the verification script**

   Add individual check functions for each of the 12 acceptance criteria: top-level directory existence (AC-001), root markdown allowlist (AC-002), scripts subdirectories (AC-003), config.sh variable exports (AC-004), k8s overlay directories (AC-005), no-hardcoded-secrets scan (AC-006), deprecated directory hygiene (AC-007), docs subdirectories (AC-008), infrastructure subdirectories (AC-009), gitignore patterns (AC-010), spec naming convention (AC-011), and the meta-check for execution time (AC-012). The AC-006 check requires parsing YAML files for `kind: Secret` with `data:` or `stringData:` fields that contain inline values (not references).

   - Files: `scripts/qa/verify-repo-structure.sh` (modify)
   - Complexity: M
   - Dependencies: Task 1
   - AC: AC-001 through AC-012

3. **[M] Archive non-allowlist root markdown files**

   Move all root-level markdown files not in the allowlist to`docs/archive/`. This includes: `ALTERNATIVE_DOMAIN_FIX_SUMMARY.md`, `DEPLOY_BRANDING_FIX.md`, `FIX_README.md`, `GKE_LOKI_SETUP_SUMMARY.md`, `LOGO_FIX_DEPLOYMENT_CHECKLIST.md`, `LOGO_FIX_SUMMARY.md`, `MFE_OAUTH_FIX_CHECKLIST.md`, `MFE_OAUTH_FIX_README.md`, `MFE_OAUTH_FIX_SUMMARY.md`, `MONITORING_DELIVERABLES.md`, `PROMETHEUS_INTEGRATION.md`, `STUDIO_BRANDING_FIX_VERIFIED.md`. Also move the `.txt` files (`BILLING_SUMMARY.txt`, `COST_BREAKDOWN_VISUALIZATION.txt`) to `docs/archive/`. Use `git mv` to preserve history.

   - Files: Root `*.md` and `*.txt` files -> `docs/archive/`(move ~14 files)
   - Complexity: M
   - Dependencies: None
   - AC: AC-002

4. **[S] Relocate root-level test scripts**

   Move `test-mct-api.mjs`, `test-mct-direct.mjs`, `test-no-client-type.mjs`, `test-sof-api.mjs`, `test-sof-self.mjs`, `test-v3.mjs` from repository root to `scripts/qa/` or `scripts/migrations/` (depending on their purpose -- they appear to beMCT/SOF API test harnesses). Update any references to thesescripts in documentation or other scripts.

   - Files: Root `test-*.mjs` -> `scripts/migrations/` or `scripts/qa/` (move 6 files)
   - Complexity: S
   - Dependencies: None
   - AC: AC-002 (root cleanliness, supports the "no executable scripts at root" requirement)

5. **[S] Clean up miscellaneous root files**

   Address the `nul` empty file at root (delete it). Decide on `mereka-academy.code-workspace` (IDE config, should be gitignored or left as-is since it is not a markdown file and doesnot violate any spec requirement). Add `exports/` to `.gitignore` if not already fully covered. Ensure `patches/` and `tmp/` are either moved under `infrastructure/` or gitignored per the Open Questions in the spec.

   - Files: Root `nul` (delete), `.gitignore` (modify), `patches/` (evaluate), `tmp/` (evaluate)
   - Complexity: S
   - Dependencies: None
   - AC: Supports general root hygiene

6. **[S] Audit deploy/k8s/base/secrets/ for hardcoded secrets**

   Scan all YAML files in `deploy/k8s/base/secrets/` to verify none contain `kind: Secret` resources with literal `data:`or `stringData:` values. Only ExternalSecret manifests shouldexist there. Document any findings and fix violations by converting to ExternalSecret references.

   - Files: `deploy/k8s/base/secrets/*.yaml` (audit/modify)
   - Complexity: S
   - Dependencies: None
   - AC: AC-006

### Test

7. **[M] Write test cases for the verification script**

   Create a test harness (`scripts/qa/test-verify-repo-structure.sh`) that exercises the verification script against known-good and known-bad directory states. The test creates a temporary directory tree, runs the verification script, and checks exit codes and output. Test cases include: all-passing tree, missing required directory, extra root markdown, deprecateddirectory with files, missing config.sh, hardcoded secret ink8s manifest, non-conforming spec filename.

   - Files: `scripts/qa/test-verify-repo-structure.sh` (create)
   - Complexity: M
   - Dependencies: Task 2
   - AC: AC-012

8. **[S] Manual verification: run against current main**

   Execute `scripts/qa/verify-repo-structure.sh` against thecurrent `main` branch after all cleanup tasks are done. Confirm zero violations and under-5-second completion. Document results.

   - Files: None (execution + screenshot/log capture)
   - Complexity: S
   - Dependencies: Tasks 2, 3, 4, 5, 6
   - AC: AC-012

### Observability

9. **[S] Add structured output to verification script**

   Ensure the verification script outputs machine-parseable results. Each check line follows the format `[PASS|FAIL] <check-description>`. Add a summary JSON line at the end: `{"violations_total": N, "root_markdown_count": N, "deprecated_dir_files": N}` that can be scraped by CI for metrics emission. This supports the observability requirements in the spec.

   - Files: `scripts/qa/verify-repo-structure.sh` (modify)
   - Complexity: S
   - Dependencies: Task 2
   - AC: Observability requirements (metrics section of spec)

### Docs

10. **[S] Update CLAUDE.md repository structure section**

    Verify that the "Repository Structure" section in `CLAUDE.md` matches the canonical layout from the spec. Add any missing directories (e.g., `apps/`) and remove references to deprecated directories. Ensure the directory tree in the doc matches reality after cleanup.

    - Files: `CLAUDE.md` (modify)
    - Complexity: S
    - Dependencies: Tasks 3, 4, 5
    - AC: Supports NFR-Discoverability

11. **[S] Update AGENTS.md with structure governance**

    Add a section to `AGENTS.md` explaining that all new files must comply with the repository structure spec and that `scripts/qa/verify-repo-structure.sh` should be run before committing structural changes. Reference the spec for the canonical directory layout.

    - Files: `AGENTS.md` (modify)
    - Complexity: S
    - Dependencies: Task 2
    - AC: Supports NFR-Discoverability

### Rollout

12. **[S] Create GitHub Actions CI workflow (advisory mode)**

    Create `.github/workflows/verify-repo-structure.yml` thatruns the verification script on every PR targeting `main`. Start in advisory mode (`continue-on-error: true`) for a 2-week grace period, then switch to blocking. The workflow shouldrun only when files outside `tutor_env/` and `var/` change.

    - Files: `.github/workflows/verify-repo-structure.yml` (create)
    - Complexity: S
    - Dependencies: Task 2
    - AC: Rollout plan step 5 in spec, supports AC-012

13. **[S] Create cleanup beads for remaining Open Questions**

    Create beads (issue tickets) for the unresolved Open Questions from the spec: (a) decide whether `exports/` should befully gitignored, (b) decide whether `hubspot-webhook-mct/` should move under `services/`, (c) decide whether `patches/` should move under `infrastructure/`, (d) decide whether `tmp/`should be gitignored. These are owner decisions that shouldnot block the main implementation.

    - Files: `.beads/` (create via `br create`)
    - Complexity: S
    - Dependencies: None
    - AC: Supports Open Questions resolution

---

## Dependency Graph

```
Task 1 (skeleton) ─────────────> Task 2 (all checks) ──┬──> Task 7 (test harness)
                                                        ├──>Task 8 (manual verification)
                                                        ├──>Task 9 (observability output)
                                                        ├──>Task 11 (AGENTS.md update)
                                                        └──>Task 12 (CI workflow)

Task 3 (archive markdown) ─────> Task 8 (manual verification)
Task 4 (relocate scripts) ─────> Task 8 (manual verification)
Task 5 (clean misc) ───────────> Task 8 (manual verification)
Task 6 (audit secrets) ────────> Task 8 (manual verification)

Task 3, 4, 5 ──────────────────> Task 10 (update CLAUDE.md)

Task 13 (beads) ────────────────> (no downstream deps, can run anytime)
```

## Milestone Checkpoints

### Milestone 1: Verification Script Complete (Tasks 1, 2, 9)
- **Verifiable state**: `scripts/qa/verify-repo-structure.sh`exists, is executable, implements all 12 AC checks, and completes in under 5 seconds.
- **Check**: `bash scripts/qa/verify-repo-structure.sh` runsand produces structured output. Some checks may FAIL againstcurrent state -- that is expected before cleanup.

### Milestone 2: Repository Cleanup Complete (Tasks 3, 4, 5,6)
- **Verifiable state**: All root-level markdown files complywith the allowlist. No executable scripts at root. No hardcoded secrets in `deploy/k8s/base/secrets/`.
- **Check**: `bash scripts/qa/verify-repo-structure.sh` produces zero FAIL lines.

### Milestone 3: Full Pass (Task 8)
- **Verifiable state**: Verification script reports `RESULT:PASS (all checks passed)` in under 5 seconds.
- **Check**: `time bash scripts/qa/verify-repo-structure.sh`shows 0 violations and <5s wall time.

### Milestone 4: CI Integration (Task 12)
- **Verifiable state**: GitHub Actions workflow exists and runs on PR.
- **Check**: Open a test PR and confirm the `verify-repo-structure` check appears (advisory mode, green regardless of result).

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Root markdown cleanup breaks documentation links | Medium |Medium | Search all markdown files and scripts for references to moved files using `grep -r "FILENAME"` before moving. Update any links found. |
| AC-006 secret scan false positives | Low | Low | The scan checks for `kind: Secret` + `data:`/`stringData:` with inlinevalues. ExternalSecret manifests use `kind: ExternalSecret` and will not match. Test against actual files before finalizing. |
| Verification script too slow on large checkouts | Low | Low| The spec requires <5s. Current checks are all `test -d`, `grep`, and file listing -- well under 1 second combined. Addtiming assertion to the script itself. |
| `IMPLEMENTATION_ORDER.md` in specs/ violates AC-011 | Medium | Low | This is a meta-document, not a spec. Either: (a) rename to a `_spec.md` suffix (inappropriate since it is not aspec), (b) move it out of `specs/`, or (c) exclude files matching a documented exception list in the verification script.Recommend option (c): the verification script should list known exceptions. |
| Concurrent PRs create new root markdown files | Medium | Low | CI check (Task 12) catches this on PR. Advisory mode forweeks gives teams time to adjust workflow. |
| Open Questions about `exports/`, `patches/`, `tmp/`, `hubspot-webhook-mct/` remain unresolved | High | Low | These directories are not in the spec's required layout and their presence does not cause FAIL results (the spec only checks for required directories, not forbidden ones beyond `tools/` and `ops/`). Beads (Task 13) track resolution. |
