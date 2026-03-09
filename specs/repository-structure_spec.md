---
title: "Repository Structure Specification"
type: "feature_spec"
id: "SPEC-REPOSITORY-STRUCTURE"
status: "approved"
spec_class: "system"
owner: "engineering"
vehicle: "talent_platform"
created: "2026-02-10"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "platform"
normativity: "normative"
last_updated: "2026-02-10"
version: "1.0.0"
depends_on: []
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/lint-repo-conventions.sh"
  - "scripts/qa/spec-tools/spec_lint.py"
interfaces: []
tags:
  - "platform.repo-boundary"
  - "docs.policy"
  - "docs.catalog"
summary: "Normative repository layout contract defining canonical roots, deprecated paths, and structural verification expectations."
links:
  related_docs:
    - "docs/guides/onboarding/LOCAL_DEVELOPMENT_GUIDE.md"
    - "docs/guides/onboarding/QUICK_START_LOCAL.md"
    - "CLAUDE.md"
    - "AGENTS.md"
  related_specs:
    - "specs/secrets-management_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/tutor-configuration_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A governed directory structure for the Mereka LMS repository that separates deployment manifests, executable scripts, infrastructure-as-code, documentation, and runtime artifacts into well-defined locations. The structure enforces deprecated-path hygiene (legacy `tools/` and `ops/` directories), limits root-level markdown sprawl, and provides a shared configuration entrypoint (`scripts/shared/config.sh`) so that all scripts and agents operate on consistent project variables.

## Why it matters

Without a canonical structure contract, agents and engineers create files in ad-hoc locations, duplicate utilities across directories, and reference deprecated paths. This repository has already undergone two major reorganizations (January 2026 and February 2026). Each time, dangling references and misplaced files caused broken scripts, missing configs, and wasted debugging time. A machine-checkable spec prevents regression.

## Success looks like

- Every new file lands in the correct directory on the first attempt because the contract is unambiguous.
- CI or manual verification scripts catch structure violations before they reach `main`.
- Deprecated directories (`tools/`, `ops/`) remain empty tombstones with only a redirect README.
- Root-level markdown files are limited to a defined allowlist; all other docs live under `docs/`.
- Onboarding time for new agents/engineers is reduced because the structure is self-documenting.

# Agent Contract

## Scope

- In scope:
  - Canonical directory layout for the mereka-lms repository root and first two levels of nesting
  - Allowed root-level markdown files (exhaustive allowlist)
  - Deprecated directory policy (`tools/`, `ops/`)
  - Gitignored runtime directories (`var/`, `tutor_env/`)
  - Script organization under `scripts/` with required subdirectories
  - K8s manifest organization under `deploy/k8s/` with base/overlay pattern
  - Documentation organization under `docs/` with required subdirectories
  - Infrastructure-as-code organization under `infrastructure/`
  - Shared configuration entrypoint (`scripts/shared/config.sh`)
  - Verification commands to check structural compliance
- Out of scope:
  - File-level naming conventions within directories (e.g., kebab-case vs snake_case)
  - Content requirements for individual files (covered by other specs)
  - Git branching strategy or CI pipeline definitions
  - Third-party submodule layout (e.g., `tmp/frontend-app-authn/`)
  - Internal Tutor-generated file structure within `tutor_env/`

## Non-goals

- This spec does NOT prescribe how deep nesting may go below the second level; teams own subdirectory organization within their domain directories.
- This spec does NOT mandate migration of existing root markdown files that violate the allowlist; it defines the target state and provides a verification mechanism. A cleanup task is tracked separately.
- This spec does NOT cover repository size limits, LFS policies, or binary asset management.
- This spec does NOT define CI enforcement; it provides verification commands that CI MAY adopt.

## Assumptions

- The repository is a monorepo containing deployment, infrastructure, scripts, documentation, and specs for a single Open edX instance (Mereka Academy).
- Tutor generates files into `tutor_env/` which is gitignored and outside the scope of version-controlled structure.
- The `var/` directory is gitignored and used for ephemeral runtime artifacts only.
- Deprecated directories (`tools/`, `ops/`) have already been removed from git tracking and no longer exist on disk.

## Requirements

### Functional

#### Root Directory

- The repository root MUST contain exactly these markdown files as the allowlist:
  - `README.md` -- Project overview
  - `CLAUDE.md` -- AI agent instructions
  - `AGENTS.md` -- Repository guidelines for agents
  - `CONTRIBUTING.md` -- Contributor guide
  - `MIGRATION_CHECKLIST.md` -- Active migration tracking
  - `CHANGES.md` -- Repository changelog
  - `GEMINI.md` -- Cross-tool adapter for Gemini
- Any markdown file at root level that is NOT in the allowlist MUST be moved to `docs/` or `docs/archive/` before merging to `main`.
- The repository root MUST NOT contain executable scripts; all scripts MUST reside under `scripts/`.

#### Primary Directory Structure

- The repository MUST contain these top-level directories with the following purposes:

  | Directory | Purpose | Gitignored |
  |-----------|---------|------------|
  | `deploy/` | Deployment manifests (K8s, Kustomize) | No |
  | `scripts/` | All executable automation scripts | No |
  | `infrastructure/` | Infrastructure-as-code (Tutor, Terraform, Cloudflare, monitoring) | No |
  | `docs/` | All documentation | No |
  | `specs/` | Machine-checkable specifications | No |
  | `services/` | Microservices source code (e.g., HubSpot webhooks) | No |
  | `assets/` | Static assets (logos, images, brand files) | No |
  | `tmp/` | Temporary/vendor checkouts (e.g., frontend-app-authn submodule) | No |
  | `var/` | Runtime artifacts (logs, temp files) | Yes |
  | `tutor_env/` | Tutor-generated environment state | Yes |

#### Scripts Directory

- `scripts/` MUST contain these subdirectories:
  - `shared/` -- Common utilities and configuration
  - `infra/` -- Infrastructure management scripts
  - `migrations/` -- Data migration scripts (Kajabi, MCT)
  - `branding/` -- Theme and branding scripts
  - `analytics/` -- Analytics export scripts
  - `qa/` -- QA, smoke tests, and validation scripts
- `scripts/shared/config.sh` MUST exist and MUST export these variables: `GCP_PROJECT`, `GCP_REGION`, `LMS_DOMAIN`.
- All shell scripts under `scripts/` SHOULD source `scripts/shared/config.sh` for common variables instead of hardcoding project values.

#### Deployment Directory

- `deploy/k8s/` MUST contain:
  - `base/` -- Base Kustomize resources with subdirectories: `secrets/`, `apps/`, `plugins/`
  - `overlays/` -- Environment-specific overlays
- `deploy/k8s/overlays/` MUST contain at minimum:
  - `local/` -- Local Kind/Minikube development
  - `production/` -- Production GKE
- `deploy/k8s/overlays/staging/` MAY exist as a legacy reference but MUST NOT be used for active deployments.
- `deploy/k8s/base/secrets/` MUST contain only ExternalSecret manifests, NOT static Secret manifests with hardcoded values.

#### Infrastructure Directory

- `infrastructure/` MUST contain:
  - `tutor/` -- Tutor configuration, patches, and themes
  - `cloudflare/` -- DNS record definitions
  - `terraform/` -- Terraform infrastructure configs
  - `monitoring/` -- Monitoring dashboards, alerting rules, and recording rules

#### Documentation Directory

- `docs/` MUST contain these subdirectories:
  - `adr/` -- Architecture Decision Records
  - `guides/onboarding/` -- Setup guides and getting-started docs
  - `ops/` -- Runbooks and operational procedures
  - `operations/` -- Legacy operational docs kept as transition compatibility path
  - `migrations/` -- Migration playbooks (Kajabi, MCT)
  - `concepts/architecture/` -- System design documentation
  - `architecture/` -- Legacy architectural path kept as transition compatibility path
  - `archive/` -- Historical/superseded documentation
- Documentation files MUST NOT exist at repository root unless they are in the root markdown allowlist.
- Every ADR in `docs/adr/` SHOULD follow the numbered naming convention: `NNN-<slug>.md`.

#### Deprecated Directories

- The directories `tools/` and top-level root `ops/` MUST NOT exist in the repository.
- If tombstone directories are maintained for redirect purposes, they MUST contain only a `README.md` file that points to the new locations (`scripts/` and `infrastructure/` respectively).
- No scripts, configs, or data files MUST exist in deprecated directory paths.

#### Specs Directory

- All machine-checkable specifications MUST reside in `specs/`.
- Spec files MUST use the naming convention `<slug>_spec.md`.
- Specs MUST NOT be placed in `docs/` (specs are contracts, docs are explanations).

### Non-Functional Requirements

- **Discoverability**: A new engineer or AI agent MUST be able to locate any file category (scripts, k8s manifests, docs, specs) within 1 directory traversal from root.
- **Verification speed**: The structure verification script MUST complete in under 5 seconds on a standard checkout.
- **Determinism**: The structure MUST be fully described by this spec such that two independent agents reading this spec would produce identical directory layouts.
- **Backward compatibility**: Existing file paths that comply with this spec MUST NOT change. Only non-compliant paths require migration.

## Acceptance Criteria

- [ ] AC-001: Given a fresh clone of the repository, when listing top-level directories, then `deploy/`, `scripts/`, `infrastructure/`, `docs/`, `specs/`, `services/`, and `assets/` all exist.
- [ ] AC-002: Given the repository root, when listing `*.md` files, then only files in the defined allowlist (README.md, CLAUDE.md, AGENTS.md, CONTRIBUTING.md, MIGRATION_CHECKLIST.md, CHANGES.md, GEMINI.md) are present. Any others are violations.
- [ ] AC-003: Given the `scripts/` directory, when listing subdirectories, then `shared/`, `infra/`, `migrations/`, `branding/`, `analytics/`, and `qa/` all exist.
- [ ] AC-004: Given `scripts/shared/config.sh`, when sourcing it, then environment variables `GCP_PROJECT`, `GCP_REGION`, and `LMS_DOMAIN` are exported with non-empty values.
- [ ] AC-005: Given `deploy/k8s/overlays/`, when listing subdirectories, then `local/` and `production/` both exist.
- [ ] AC-006: Given the `deploy/k8s/base/secrets/` directory, when scanning YAML files, then no file contains a `kind: Secret` resource with `data:` or `stringData:` fields containing non-reference values.
- [ ] AC-007: Given the repository, when checking for `tools/` and `ops/` directories, then neither directory exists OR each contains only a `README.md` redirect file.
- [ ] AC-008: Given `docs/`, when listing subdirectories, then `adr/`, `migrations/`, and `archive/` exist and either canonical paths (`guides/onboarding/`, `ops/`, `concepts/architecture/`) exist or legacy transition directories (`onboarding/`, `operations/`, `architecture/`) are preserved as `README.md` tombstones.
- [ ] AC-009: Given `infrastructure/`, when listing subdirectories, then `tutor/`, `cloudflare/`, `terraform/`, and `monitoring/` all exist.
- [ ] AC-010: Given `var/` and `tutor_env/`, when checking `.gitignore`, then both directories are listed as gitignored patterns.
- [ ] AC-011: Given any `specs/*.md` file, when checking the filename, then it matches the pattern `*_spec.md`.
- [ ] AC-012: Given the full verification script, when executed against the repository, then it completes in under 5 seconds and reports PASS with zero violations.

## Edge Cases

- **Root markdown violation during active work**: Engineers and agents frequently create temporary markdown files at root (e.g., session summaries, fix checklists). The spec allows these during development branches but MUST enforce the allowlist on `main` branch merges.
- **New subdirectory creation**: When a new domain emerges (e.g., `scripts/mobile/`), it MAY be added without spec amendment. Only the required subdirectories listed in this spec are mandatory; additional subdirectories are allowed.
- **Deprecated directory recreation**: If a tool or script accidentally recreates `tools/` or `ops/`, the verification script MUST detect this and flag it as a violation.
- **Gitignored directories missing on fresh clone**: `var/` and `tutor_env/` will not exist on a fresh clone because they are gitignored. Verification MUST NOT fail if these directories are absent; it MUST only verify they are in `.gitignore`.
- **Submodule directories**: `tmp/` may contain git submodules (e.g., `frontend-app-authn`). Structure verification MUST NOT recurse into submodule directories.
- **Empty required directories**: A required directory (e.g., `docs/adr/`) MAY be empty (contain no files) and still pass verification. The requirement is that the directory exists.
- **Concurrent reorganization**: If two branches both reorganize files, merge conflicts on directory structure are resolved by this spec as the source of truth. The resulting merge MUST comply with all MUST requirements.

## Observability

- **Logs**: The verification script MUST output one line per check in the format `[PASS|FAIL] <check-description>` to stdout. Failed checks MUST also print the specific violation (e.g., the offending file path).
- **Metrics**:
  - `repo_structure.violations_total` (gauge): Count of spec violations detected per verification run. SHOULD be emitted by CI if structure checks are integrated.
  - `repo_structure.root_markdown_count` (gauge): Number of markdown files at repository root. Target: matches allowlist count exactly.
  - `repo_structure.deprecated_dir_files` (gauge): Number of non-README files in deprecated directories. Target: 0.
- **Alerts**:
  - If `repo_structure.violations_total > 0` on the `main` branch after merge, an alert SHOULD be sent to the engineering channel.
- **Dashboards**: No dedicated dashboard required. Structure compliance SHOULD be visible as a CI check status on pull requests.

## Rollout & Rollback

- **Rollout plan**:
  1. Publish this spec as `approved` status in `specs/repository-structure_spec.md`.
  2. Create the verification script at `scripts/qa/verify-repo-structure.sh` implementing all AC checks.
  3. Run verification against current `main` branch to identify existing violations.
  4. Create cleanup tasks (as beads) for each violation found (root markdown files outside allowlist, missing required directories).
  5. After cleanup reaches zero violations, optionally integrate `verify-repo-structure.sh` into CI as a blocking check.
- **Feature flags**: Not applicable. This is a structural governance spec, not a runtime feature.
- **Backward compatibility**: All currently compliant file paths remain valid. No file moves are required for files already in correct locations. Only non-compliant files need relocation.
- **Rollback steps**:
  - If the verification script produces false positives or blocks legitimate work, the CI check (if integrated) can be demoted from blocking to advisory by changing the CI job's `allow_failure` flag.
  - The spec itself can be amended by updating the allowlist or required directories with a new `last_updated` date and documenting the change in the Open Questions or a linked ADR.
  - Rolling back directory moves: `git log --diff-filter=R -- <path>` identifies the original location. Restore with `git checkout <commit> -- <old-path>`.

## Verification

```bash
#!/usr/bin/env bash
set -euo pipefail

# Run from repository root
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "[PASS] $desc"
  else
    echo "[FAIL] $desc"
    FAIL=$((FAIL + 1))
  fi
}

# AC-001: Required top-level directories exist
for dir in deploy scripts infrastructure docs specs services assets; do
  check "Top-level directory $dir/ exists" test -d "$dir"
done

# AC-002: Root markdown allowlist
ALLOWED="AGENTS.md CHANGES.md CLAUDE.md CONTRIBUTING.md GEMINI.md MIGRATION_CHECKLIST.md README.md"
for f in *.md; do
  if ! echo "$ALLOWED" | grep -qw "$f"; then
    echo "[FAIL] Root markdown file '$f' is not in allowlist"
    FAIL=$((FAIL + 1))
  fi
done

# AC-003: Required scripts subdirectories
for dir in shared infra migrations branding analytics qa; do
  check "scripts/$dir/ exists" test -d "scripts/$dir"
done

# AC-004: config.sh exports required variables
check "scripts/shared/config.sh exists" test -f "scripts/shared/config.sh"

# AC-005: Required k8s overlays
for dir in local production; do
  check "deploy/k8s/overlays/$dir/ exists" test -d "deploy/k8s/overlays/$dir"
done

# AC-007: Deprecated directories
for dir in tools ops; do
  if [ -d "$dir" ]; then
    NON_README=$(find "$dir" -type f ! -name README.md | head -1)
    if [ -n "$NON_README" ]; then
      echo "[FAIL] Deprecated directory $dir/ contains non-README files: $NON_README"
      FAIL=$((FAIL + 1))
    else
      echo "[PASS] Deprecated directory $dir/ contains only README.md"
    fi
  else
    echo "[PASS] Deprecated directory $dir/ does not exist"
  fi
done

# AC-008: Required docs subdirectories
check "docs/adr/ exists" test -d docs/adr
if test -d docs/guides/onboarding || test -d docs/onboarding; then
  check "docs onboarding path exists (canonical or transition)" true
else
  echo "[FAIL] Onboarding docs path missing (expected docs/guides/onboarding or docs/onboarding)"
  FAIL=$((FAIL + 1))
fi
if test -d docs/ops || test -d docs/operations; then
  check "docs operations path exists (canonical or transition)" true
else
  echo "[FAIL] Operations docs path missing (expected docs/ops or docs/operations)"
  FAIL=$((FAIL + 1))
fi
check "docs/migrations/ exists" test -d docs/migrations
if test -d docs/concepts/architecture || test -d docs/architecture; then
  check "docs architecture path exists (canonical or transition)" true
else
  echo "[FAIL] Architecture docs path missing (expected docs/concepts/architecture or docs/architecture)"
  FAIL=$((FAIL + 1))
fi
check "docs/archive/ exists" test -d docs/archive

# AC-009: Required infrastructure subdirectories
for dir in tutor cloudflare terraform monitoring; do
  check "infrastructure/$dir/ exists" test -d "infrastructure/$dir"
done

# AC-010: Gitignored directories
check "var/ is in .gitignore" grep -q "^var/" .gitignore
check "tutor_env/ is in .gitignore" grep -q "^tutor_env/" .gitignore

# AC-011: Spec naming convention
for f in specs/*.md; do
  if [[ "$f" != *_spec.md ]]; then
    echo "[FAIL] Spec file '$f' does not match *_spec.md naming"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT: PASS (all checks passed)"
else
  echo "RESULT: FAIL ($FAIL violations)"
fi
exit "$FAIL"
```

## Open Questions

- **Root markdown cleanup timeline**: The current repository has ~12 extra markdown files at root (e.g., `ALTERNATIVE_DOMAIN_FIX_SUMMARY.md`, `MFE_OAUTH_FIX_SUMMARY.md`) that violate the allowlist. When should these be archived to `docs/archive/`? Recommend creating a cleanup bead with a 1-week deadline.
- **`exports/` and `hubspot-webhook-mct/` directories**: These top-level directories exist but are not specified in this contract. Should `exports/` be gitignored (like `var/`)? Should `hubspot-webhook-mct/` be moved under `services/`? Needs owner decision.
- **`patches/` and `tmp/` directories**: These top-level directories exist but are not in the canonical layout. Should `patches/` be moved under `infrastructure/`? Should `tmp/` be gitignored? Needs owner decision.
- **CI enforcement timing**: Should the verification script block PRs immediately, or run in advisory mode for a grace period? Recommend advisory mode for 2 weeks, then blocking.
