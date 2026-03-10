---
title: "CI/CD Pipeline Specification"
type: "feature_spec"
id: "SPEC-CICD-PIPELINE"
status: "approved"
spec_class: "system"
owner: "engineering"
vehicle: "talent_platform"
created: "2026-02-12"
last_reviewed: "2026-02-12"
review_due: "2026-06-12"
version: "1.0.0"
domain: "platform"
normativity: "normative"
implementation_note: "GitOps image tag sync improvements ongoing - see docs/ops/runbooks/GITOPS_WORKFLOW.md"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/k8s-deployment_spec.md"
  - "specs/secrets-management_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/run-spec-integrity-gates.sh"
  - ".github/workflows/ci.yml"
interfaces:
  - ".github/workflows/ci.yml"
  - "deploy/k8s/"
tags:
  - "build.gitops-promotion"
  - "build.image.registry"
  - "platform.control-plane"
summary: "Defines the CI/CD contract for building, validating, and promoting platform artifacts through the canonical GitOps release flow."
links:
  related_docs:
    - "docs/reference/operations/CI_CD_SETUP.md"
    - "docs/ops/runbooks/K8S_DEPLOYMENT_RUNBOOK.md"
    - "docs/ops/runbooks/GITOPS_WORKFLOW.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
  related_specs:
    - "specs/k8s-deployment_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/repository-structure_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# CI/CD Pipeline Specification

# Human Summary

## What we're building

A comprehensive, formally specified CI/CD pipeline for the Mereka Academy Open edX platform. The pipeline covers the complete development lifecycle from code commit to production deployment across three workflow tiers: (1) commit-time quality gates that run on every PR and push to main, (2) image build and artifact management for Open edX platform components (openedx, MFE, iOS), and (3) environment promotion with GitOps-driven deployment to production GKE. The pipeline consolidates and standardizes the 11 existing GitHub Actions workflows into a cohesive, auditable system with clear contracts for each stage.

## Why it matters

The platform currently has workflows that evolved organically -- CI, image builds, policy checks, observability audits, health checks, and release evidence gathering exist as independent workflow files without a unifying specification. This leads to ambiguity about which gates are required vs optional, inconsistent error handling across workflows, and no formal contract for what constitutes a releasable artifact. A formal CI/CD spec prevents deployment incidents caused by skipped gates, enables onboarding of new engineers who need to understand the release process, and provides compliance evidence for the Mereka Academy learning platform used by real learners.

## Success looks like

- Every merge to main passes all required quality gates (lint, validate-k8s, security-scan, spec-lint, branding-preflight) with zero manual intervention.
- Image builds produce immutable, digest-pinned artifacts that are traceable from source commit to production pod.
- Production deployments are always preceded by policy checks and release evidence bundles.
- Mean time from merge-to-main to production deployment is under 60 minutes for standard releases.
- Rollback to a prior known-good release completes within 10 minutes.
- All CI/CD workflow failures produce actionable notifications with clear remediation steps.

---

# Agent Contract

## Scope

- In scope:
  - GitHub Actions workflow standardization and execution contracts
  - Docker image build pipeline for openedx, MFE, and iOS app components
  - Multi-stage quality gates (linting, K8s validation, security scanning, spec linting, branding)
  - Automated security scanning (TruffleHog, Hadolint, pre-commit secret detection)
  - Code quality gates and formatting enforcement (ruff, yamllint, shellcheck, kubeconform)
  - GitOps deployment automation with environment promotion (local Kind, production GKE)
  - Automated rollback mechanisms and safety checks
  - Branch protection rules and merge gate policies
  - Artifact management and container registry operations (GCP Artifact Registry)
  - Infrastructure-as-code validation (Kustomize, Terraform, ExternalSecrets)
  - Scheduled operational audits (observability, alert routing, DR evidence, health checks)
  - Release evidence generation and compliance artifact bundling
  - Notification and alerting for build/deployment status
  - Cost optimization for CI/CD resource usage
  - iOS app build pipeline (TestFlight via Fastlane/Match)
- Out of scope:
  - Internal implementation of individual QA scripts (those are tested by their own contracts)
  - Tutor plugin development or Open edX core code changes
  - GKE cluster provisioning (covered by `specs/k8s-deployment_spec.md`)
  - Secret creation or rotation procedures (covered by `specs/secrets-management_spec.md`)
  - Observability stack deployment (covered by `specs/observability-stack_spec.md`)
  - MongoDB Atlas cluster management
  - End-user feature development

## Non-goals

- The pipeline will NOT support blue/green or canary deployment strategies in this iteration. Rollout is rolling update via GitOps.
- The pipeline will NOT include a dedicated staging environment. The operating model is local/dev (Kind on VPS) to production (GKE). Staging is gated behind `ENABLE_STAGING_ENV=true` for future use.
- The pipeline will NOT run Open edX application-level integration tests (Django test suite). Open edX's test suite is upstream-maintained and impractical to run in CI for a deployment repo.
- The pipeline will NOT manage Terraform apply in CI. Terraform plan may be validated; apply remains a manual operator action.
- The pipeline will NOT build custom Open edX plugins or XBlocks as separate artifacts.
- The pipeline will NOT implement DAST (Dynamic Application Security Testing) or container runtime security scanning.

## Cross-Spec Integration Criteria

### K8s Deployment Integration (Tier 2 → Tier 3)
- [ ] AC-INT-001: Given K8s manifests pass `validate-k8s.sh`, when CI builds and pushes images to Artifact Registry, then production Kustomize overlay references the new image tags and `kubectl apply` succeeds without resource validation errors.
- [ ] AC-INT-002: Given K8s Deployments require specific ExternalSecrets, when CI deployment workflow runs, then it verifies ExternalSecrets reach `SecretSynced` before declaring deployment success.

### Secrets Management Integration (Tier 1 → Tier 3)
- [ ] AC-INT-003: Given `secrets-management_spec.md` defines required secret keys, when CI runs secret validation (`infisical-validate-mereka-lms.sh`), then it fails the build if any required `MEREKA_LMS_*` key is missing or contains placeholder values in the target environment.

### Branding System Integration (Tier 3 → Tier 3)
- [ ] AC-INT-004: Given branding assets are synced via `apply-patches.sh`, when CI builds openedx image, then `branding-preflight.sh` passes and verifies Mereka logo presence and Google Fonts absence in compiled artifacts.

## Assumptions

- GitHub Actions is the sole CI/CD platform. No Jenkins, CircleCI, or other systems.
- GCP Artifact Registry at `ghcr.io/biji-biji-initiative/mereka-lms` is the container image registry.
- The GitOps target repository is `Biji-Biji-Initiative/bbi-infrastructure`, accessed via `GITOPS_PAT` secret.
- Production runs on GKE Autopilot in `asia-southeast1-c` (project `bbi-k8`).
- Dev/local runs on Kind cluster on the VPS (`194.233.84.55`).
- All secrets are managed via Infisical -> GCP Secret Manager -> ExternalSecrets (per `specs/secrets-management_spec.md`).
- GitHub-hosted runners provide 2-core, 7GB RAM machines. OpenEdX image builds may require 12GB+ (handled by Docker memory config or may need self-hosted runners).
- Tutor 21.0.0 (Ulmo) is the deployment toolchain.

## Requirements

### Functional

#### Workflow Inventory and Standardization

- The pipeline MUST maintain the following workflow files in `.github/workflows/`:

| Workflow File | Trigger | Category | Required for Merge |
|---------------|---------|----------|-------------------|
| `ci.yml` | PR + push to main | Quality Gates | Yes |
| `build-tutor-images.yml` | Push to main (path filter) + manual | Build | No |
| `build-ios-app.yml` | Push to main (path filter) + manual | Build | No |
| `policy-checks.yml` | Manual | Release Gate | No (manual pre-release) |
| `release-evidence.yml` | Manual | Compliance | No (manual pre-release) |
| `operations-gates-runtime.yml` | Every 6h schedule + manual | Operations | No |
| `observability-audit.yml` | Daily schedule + manual | Operations | No |
| `public-health-check.yml` | Every 30 min schedule + manual | Operations | No |
| `alert-routing-audit.yml` | Daily schedule + manual | Operations | No |
| `dr-evidence-bundle.yml` | Monthly schedule + manual | Compliance | No |
| `cloud-sql-backup.yml` | Tri-daily schedule (gated) | Operations | No |
| `authenticated-sso-canary.yml` | Every 6h schedule + manual | Operations | No |
| `tutor-config-verify.yml` | PR + push (path filter) + manual | Quality Gates | No |
| `tutor-plugin-test.yml` | PR + push (path filter) + manual | Quality Gates | No |

- Every workflow MUST use `actions/checkout@v4` as the first step.
- Every workflow MUST pin action versions to major tags (e.g., `@v4`, `@v2`) or SHA for third-party actions.
- Every workflow MUST NOT use `actions/checkout` with `persist-credentials: true` unless git push is required.

#### Quality Gates (ci.yml -- Required for Merge)

- The CI workflow MUST run on every pull request targeting `main` and on every push to `main`.
- The CI workflow MUST include the following jobs, all of which MUST pass for a PR to be mergeable:

| Job | Purpose | Tool |
|-----|---------|------|
| `spec-lint` | Validate spec structure and quality | `spec_lint.py`, `spec_verify.py` |
| `generated-docs` | Ensure generated docs are current | `update-openedx-hostnames-doc.sh` + `git diff --exit-code` |
| `branding-preflight` | Source-only branding gate | `run-branding-gates.sh prod` (offline) |
| `monitoring-guardrails` | Script syntax + observability audit + release contract checks | Multiple `verify-*.sh` scripts |
| `atlas-modulestore-guardrails` | Atlas modulestore path contract | `verify-atlas-modulestore-path.sh` |
| `gitops-image-contract` | Image override contract (repo-local) | `verify-gitops-image-overrides.sh` |
| `prod-tag-guard` | No mutable `:latest` tags in production overlays | `verify-no-latest-prod-tags.sh` |
| `lint` | Python (ruff), YAML (yamllint), Shell (shellcheck) | ruff, yamllint, action-shellcheck |
| `validate-k8s` | Kubernetes manifest validation | kubeconform (strict, ignore-missing-schemas) |
| `validate-tutor-config` | Tutor YAML syntax + patch script syntax | Python yaml.safe_load + bash -n |
| `validate-infisical` | Infisical secret presence (prod + dev) | infisical-validate-mereka-lms.sh (conditional) |
| `security-scan` | Secret detection + Dockerfile linting | TruffleHog (verified only) + Hadolint |

- The CI workflow MUST fail fast: if any required job fails, the PR MUST NOT be mergeable.
- The `validate-infisical` job SHOULD run only when `INFISICAL_TOKEN` and `INFISICAL_PROJECT_ID` secrets are configured (`if` condition).
- The `monitoring-guardrails` job MUST upload a `monitoring-offline-plan` artifact on success.
- The `security-scan` job MUST use TruffleHog with `--only-verified` flag to reduce false positives.
- The `lint` job MUST lint Python files in `scripts/` and `services/`, YAML files in `infrastructure/` and `deploy/`, and shell scripts in `scripts/`.
- The `validate-k8s` job MUST use kubeconform with `--strict` mode.

#### Docker Image Build Pipeline (build-tutor-images.yml)

- The build workflow MUST trigger on push to `main` when files change in `infrastructure/tutor/**`, `assets/branding/**`, or `.github/workflows/build-tutor-images.yml`.
- The build workflow MUST support `workflow_dispatch` with the following inputs: `build_openedx` (boolean), `build_mfe` (boolean), `update_gitops` (boolean), `target_environment` (choice: select-environment/production/staging), `image_tag` (string, optional).
- The build workflow MUST run a `lint` job before build jobs. Build jobs MUST depend on lint passing (`needs: lint`).
- The build workflow MUST install Tutor 21.0.0 for all build jobs.
- The build workflow MUST run `./infrastructure/tutor/apply-patches.sh` after `tutor config save` in every build job.
- The build workflow MUST authenticate to GCP Artifact Registry using `google-github-actions/auth@v2` with `GCP_SA_KEY`.
- The build workflow MUST tag images with both the full git SHA (or custom `image_tag`) and the 8-character short SHA.
- The build workflow MUST NOT publish mutable `:latest` tags to Artifact Registry.
- The build workflow MUST resolve and expose image digests as job outputs after push.
- The build workflow MUST set `NODE_OPTIONS=--max-old-space-size=6144` for MFE builds.
- The MFE build MUST run `scripts/qa/verify-mfe-image-branding.sh` before push and upload the verification log as artifact.
- The MFE branding verification MUST fail the build if the authn `index.html` references unbranded CSS or misses the expected revision marker.

#### Image Tag Immutability

- All images pushed to Artifact Registry MUST use immutable tags (git SHA or release tag). Mutable tags (`:latest`, `:nightly`) MUST NOT be used for production.
- The `prod-tag-guard` CI job MUST verify that no production Kustomize overlay references `:latest` tags.
- The `verify-dev-prod-image-parity.sh` script MUST verify that dev and production overlays use consistent image configurations.

#### GitOps Deployment (update-gitops job in build-tutor-images.yml)

- GitOps update MUST only execute when `update_gitops=true` is explicitly selected.
- GitOps update for manual dispatch MUST require `target_environment` to be explicitly selected (not `select-environment`).
- GitOps update MUST require both `build_openedx=true` and `build_mfe=true` so digests are captured deterministically.
- GitOps update MUST use `scripts/infra/release-openedx-gitops.sh` with `--apply --commit --push` flags.
- GitOps update MUST pass `--require-digests` and provide both `--openedx-digest` and `--mfe-digest` for production releases.
- GitOps update MUST block `target_environment=staging` unless repository variable `ENABLE_STAGING_ENV=true` is set.
- The `deploy_to_staging` input MUST be rejected with an error message directing users to `update_gitops`.
- GitOps update MUST validate that `GITOPS_PAT` secret is present before attempting cross-repo operations.
- GitOps update MUST configure git identity as `github-actions[bot]` for commits.

#### iOS Build Pipeline (build-ios-app.yml)

- The iOS workflow MUST trigger on push to `main` when files change in `mobile/ios/**` or `.github/workflows/build-ios-app.yml`.
- The iOS workflow MUST support `workflow_dispatch` for manual triggers.
- The iOS workflow MUST run on `macos-latest` with a 90-minute timeout.
- The iOS workflow MUST clone the latest release tag of `openedx/openedx-app-ios`.
- The iOS workflow MUST configure the app with bundle ID `com.mereka.academy.mobile`.
- The iOS workflow MUST use Fastlane Match for code signing with the `ios-certificates` repository.
- The iOS workflow MUST upload the built IPA to TestFlight via App Store Connect API.
- The iOS workflow MUST clean up SSH keys in the `always` cleanup step.
- The iOS workflow SHOULD cache Ruby gems and CocoaPods for faster builds.

#### Release Policy Checks (policy-checks.yml)

- Policy checks MUST be available via `workflow_dispatch` (manual trigger only).
- Policy checks MUST run all of the following verification scripts and all MUST pass:
  - `verify-release-automation.sh`
  - `verify-build-workflow-contract.sh`
  - `verify-release-workflow-invocation.sh`
  - `verify-release-dry-run-contract.sh`
  - `verify-release-evidence-workflow.sh`
  - `verify-kustomize-no-deprecated-keys.sh`
  - `verify-dev-prod-image-parity.sh`
  - `verify-site-id-hardening.sh`
  - `verify-no-latest-prod-tags.sh`
  - `lint-active-docs-env-model.sh`
- Policy checks MUST validate script syntax (`bash -n`) before execution.

#### Release Evidence (release-evidence.yml)

- Release evidence MUST be generated via `workflow_dispatch` with required inputs: `openedx_tag`, `mfe_tag`, `target_environment`.
- Release evidence MUST resolve image digests from the registry for provided tags.
- Release evidence MUST run all policy check scripts and capture their output to log files.
- Release evidence MUST execute a dry-run of `release-openedx-gitops.sh` (no `--apply --commit --push`).
- Release evidence MUST generate a `release-metadata.json` containing: `generated_at_utc`, `repo`, `run_id`, `run_number`, `sha`, `actor`, `ref`, tags, digests, and `target_environment`.
- Release evidence MUST upload all artifacts as a single bundle named `release-evidence-<env>-<run_number>`.

#### Scheduled Operations Workflows

- The `operations-gates-runtime.yml` workflow MUST run every 6 hours and MUST support `workflow_dispatch`.
- The `operations-gates-runtime.yml` workflow MUST authenticate to GKE and run `run-operations-gates.sh` with configurable environment scope (`prod`/`dev`/`both`).
- The `operations-gates-runtime.yml` workflow MUST upload gate artifacts with 30-day retention.
- The `observability-audit.yml` workflow MUST run daily and MUST produce JSON artifacts for both local and runtime audits.
- The `public-health-check.yml` workflow MUST run every 30 minutes and MUST verify branding gates (prod strict + dev) and auth surfaces (prod + dev).
- The `alert-routing-audit.yml` workflow MUST run daily and MUST verify alert routing configuration.
- The `dr-evidence-bundle.yml` workflow MUST run monthly (1st of each month at 02:30 UTC) and MUST upload DR evidence with 120-day retention.
- The `cloud-sql-backup.yml` workflow MUST only execute when repository variable `ENABLE_CLOUD_SQL_BACKUPS=true` is set.

#### Authenticated SSO Canary (authenticated-sso-canary.yml)

- The SSO canary workflow MUST run every 6 hours on schedule and MUST support `workflow_dispatch`.
- The SSO canary workflow MUST support `env_scope` input with options: `prod`, `dev`, `both` (default: `prod`).
- The SSO canary workflow MUST install Playwright with Chromium for browser automation.
- The SSO canary workflow MUST run `verify-authenticated-sso-canary.sh` with environment-scoped credentials.
- The SSO canary workflow MUST support environment-specific secrets: `SSO_CANARY_EMAIL_PROD`, `SSO_CANARY_PASSWORD_PROD`, `SSO_CANARY_EMAIL_DEV`, `SSO_CANARY_PASSWORD_DEV`.
- The SSO canary workflow SHOULD support optional Studio staff canary credentials: `SSO_CANARY_STUDIO_EMAIL_PROD`, `SSO_CANARY_STUDIO_PASSWORD_PROD`, `SSO_CANARY_STUDIO_EMAIL_DEV`, `SSO_CANARY_STUDIO_PASSWORD_DEV`.
- The SSO canary workflow MUST upload artifacts (screenshots, logs) from `var/auth-sso-canary/` with 30-day retention.
- The SSO canary workflow MUST upload artifacts even on failure (`if: always()`) for debugging.
- The SSO canary workflow MUST set `REQUIRE_SECRETS=1` to fail loudly if required secrets are missing.
- The SSO canary workflow SHOULD set `REQUIRE_STUDIO_CANARY=0` to keep Studio staff checks non-blocking.

#### Tutor Configuration Verification (tutor-config-verify.yml)

- The Tutor config verification workflow MUST trigger on push and pull requests when files change in `tutor_env/config.yml` or `infrastructure/tutor/**`.
- The Tutor config verification workflow MUST support `workflow_dispatch` for manual runs.
- The Tutor config verification workflow MUST install Tutor 21.0.0 for all jobs.
- The Tutor config verification workflow MUST install Python 3.12 with pip caching for faster runs.
- The workflow MUST include a `verify-patches` job that verifies MySQL authentication patch (`mysql_native_password`) and MFE Node.js patch (`NODE_OPTIONS=--max-old-space-size=6144`).
- The workflow MUST include a `verify-multi-site-domains` job that verifies all production domains (`academy.biji-biji.com`, `skillourfuture.academy.mereka.io`, `academyv2.mereka.io`) are present in `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS`.
- The workflow MUST include a `verify-enterprise-features` job that verifies custom apps (`mfe_oauth_fix`, `django_prometheus`) are installed.
- The workflow MUST include a `verify-idempotency` job that runs patches twice and verifies checksums remain identical.
- The workflow MUST generate a clean config from `infrastructure/tutor/config.example.yml` before running patches.
- The workflow MUST run `./infrastructure/tutor/apply-patches.sh` after `tutor config save` in all jobs.
- The workflow MUST upload patch failure artifacts (docker-compose.yml, Dockerfile, settings files) when verification fails.
- The workflow MUST post a PR comment on failure with common issues and remediation steps (requires `pull-requests: write` permission).
- All verification steps MUST use descriptive pass/fail messages (e.g., "✅ AC-001 PASSED: MySQL authentication patch applied").

#### Tutor Plugin Testing (tutor-plugin-test.yml)

- The Tutor plugin test workflow MUST trigger on push and pull requests when files change in `infrastructure/tutor/plugins/**`.
- The Tutor plugin test workflow MUST support `workflow_dispatch` for manual runs.
- The Tutor plugin test workflow MUST install Tutor 21.0.0 for all jobs.
- The workflow MUST include a `test-mfe-oauth-plugin` job that verifies plugin syntax (`py_compile`), enables the plugin, generates config, and verifies plugin patches are applied.
- The workflow MUST include a `test-plugin-lifecycle` job that tests enable, disable, and re-enable operations.
- The workflow MUST include a `verify-custom-app-structure` job that documents expected plugin structure and mount points.
- The workflow MUST include a `lint-plugins` job that runs ruff and black on plugin code.
- The workflow MUST include an `integration-test` job that verifies plugins work correctly with `apply-patches.sh` (both sets of patches present).
- The workflow MUST verify plugin metadata (`__version__`, hook registration via `hooks.Filters.CONFIG_DEFAULTS`).
- The workflow MUST verify plugin structure (presence of `hooks.Filters.ENV_PATCHES` and `openedx-lms-production-settings` patch target).
- The workflow MUST copy plugin to `tutor_env/plugins/` before enabling.
- The workflow MUST post a PR comment on failure with plugin-specific troubleshooting guidance (requires `pull-requests: write` permission).
- The workflow MUST verify that enabled plugins appear in `tutor plugins list` output.

#### Branch Protection and Merge Gates

- The `main` branch MUST require pull request reviews before merging.
- The `main` branch MUST require all CI status checks to pass before merging.
- The `main` branch SHOULD require linear history (no merge commits).
- Direct pushes to `main` SHOULD be restricted to repository administrators for emergency hotfixes only.
- Force pushes to `main` MUST NOT be allowed.

#### Artifact Management

- All workflow-produced artifacts MUST be uploaded via `actions/upload-artifact@v4`.
- Artifact retention MUST be:
  - CI artifacts (monitoring plans, branding logs): default (90 days)
  - Operations gate artifacts: 30 days
  - DR evidence bundles: 120 days
  - Release evidence bundles: default (90 days)
- Container images in Artifact Registry SHOULD be cleaned up via lifecycle policy after 90 days for non-production tags.
- The pipeline SHOULD NOT store build artifacts larger than 500MB per workflow run.

#### Rollback Mechanism

- Rollback MUST be performed by re-running `release-openedx-gitops.sh` with prior known-good tags.
- Rollback MUST NOT require a new image build -- it MUST reference previously built, immutable-tagged images.
- Rollback MUST complete within 10 minutes from operator decision to pod convergence.
- Rollback procedure MUST be documented in `docs/ops/runbooks/RELEASE_CHECKLIST.md` section 7.
- The pipeline SHOULD maintain a record of the last 5 successful production deployments (tag + digest pairs) for quick rollback reference.

#### Notification and Alerting

- All workflow failures on the `main` branch SHOULD notify the engineering team.
- The `public-health-check.yml` workflow failures (every 30 min) MUST trigger an alert since they indicate production degradation.
- Build workflow failures SHOULD include a step summary with actionable remediation guidance.
- Release evidence and policy check workflows SHOULD produce GitHub Step Summaries with pass/fail status for each check.

#### Cost Optimization

- CI workflows MUST use GitHub-hosted `ubuntu-latest` runners for all Linux jobs.
- iOS builds MUST use `macos-latest` runners (required for Xcode) with aggressive caching (gems, CocoaPods).
- The CI workflow SHOULD minimize redundant installs by caching pip dependencies where feasible.
- Build workflows SHOULD use `--no-cache` only when necessary (forced by config changes); incremental builds SHOULD be preferred for iteration speed.
- Scheduled workflows SHOULD avoid running when no changes have been pushed (use path filters or conditional logic where possible).
- The `cloud-sql-backup.yml` workflow MUST remain gated behind `ENABLE_CLOUD_SQL_BACKUPS` to avoid unnecessary GCP costs.

### Non-Functional Requirements

#### Performance

- CI quality gate jobs (lint, validate-k8s, spec-lint, security-scan) MUST complete within 10 minutes each.
- The full CI workflow (all parallel jobs) SHOULD complete within 15 minutes for a typical PR.
- OpenEdX image build SHOULD complete within 45 minutes on GitHub-hosted runners.
- MFE image build SHOULD complete within 20 minutes on GitHub-hosted runners.
- iOS build SHOULD complete within 90 minutes (timeout enforced).
- GitOps update (excluding image build) SHOULD complete within 5 minutes.

#### Reliability

- CI workflow pass rate on the `main` branch SHOULD be >= 95% (failures should be real issues, not flaky infrastructure).
- Scheduled workflows MUST handle transient GCP/GKE authentication failures gracefully (conditional steps with `|| true` for non-critical paths).
- Build workflows MUST produce deterministic outputs: same source commit MUST produce functionally identical images.

#### Security

- The pipeline MUST NOT expose secrets in workflow logs. All secret values MUST be masked by GitHub Actions.
- The pipeline MUST NOT store GCP service account keys in the repository. Keys MUST be in GitHub Actions secrets only.
- The pipeline MUST run TruffleHog secret scanning on every PR.
- The pipeline MUST run Hadolint on any Dockerfiles present in the repository.
- The `GITOPS_PAT` token MUST have minimum required permissions (contents:write on `bbi-infrastructure` only).
- Workflow permissions MUST follow least-privilege: `contents: write` only for workflows that push commits.
- The pre-commit secret scanning hook MUST detect hardcoded passwords, API keys, private keys, JWT tokens, and database connection strings with embedded credentials.

#### Observability

- Every workflow MUST produce a GitHub Step Summary with structured pass/fail results.
- Build workflows MUST log image tags, digests, and registry references in the step summary.
- Scheduled workflows MUST upload structured artifacts (JSON or log files) for post-hoc analysis.

## Acceptance Criteria

### Quality Gates

- [ ] AC-001: Given a PR is opened against `main`, when CI runs, then all 12 CI jobs execute and their pass/fail status is reported as GitHub commit status checks.
- [ ] AC-002: Given the `spec-lint` job runs, when specs in `specs/` have structural issues (missing frontmatter, missing required sections), then the job fails with specific error messages identifying the non-conforming spec.
- [ ] AC-003: Given the `lint` job runs, when Python files in `scripts/` or `services/` have ruff violations, then the job fails.
- [ ] AC-004: Given the `validate-k8s` job runs, when any YAML in `deploy/k8s/` is not a valid Kubernetes manifest, then kubeconform fails the job.
- [ ] AC-005: Given the `security-scan` job runs, when verified secrets are detected by TruffleHog, then the job fails and the finding is reported.
- [ ] AC-006: Given the `prod-tag-guard` job runs, when any production overlay references a `:latest` tag, then the job fails.
- [ ] AC-007: Given all CI jobs pass, when the PR is reviewed and approved, then the merge button is enabled.
- [ ] AC-008: Given a CI job fails, when a developer views the PR, then the merge button is disabled.

### Image Build

- [ ] AC-009: Given a push to `main` modifies `infrastructure/tutor/**`, when the build workflow triggers, then both openedx and MFE images are built, tagged with the git SHA and short SHA, and pushed to `ghcr.io/biji-biji-initiative/mereka-lms/`.
- [ ] AC-010: Given the openedx image is built, when it is pushed to Artifact Registry, then the job output contains the resolved image digest (sha256:...).
- [ ] AC-011: Given the MFE image is built, when the branding verification runs, then it validates that the authn index.html contains the expected branding revision marker.
- [ ] AC-012: Given a manual dispatch with `build_openedx=true` and `image_tag=v1.2.3`, when the build completes, then the image is tagged as `openedx:v1.2.3` and `openedx:<short-sha>`.
- [ ] AC-013: Given the build workflow, when images are pushed, then no `:latest` tag is published to Artifact Registry.

### GitOps Deployment

- [ ] AC-014: Given `update_gitops=true` and `target_environment=production`, when both builds succeed with digests, then `release-openedx-gitops.sh` is invoked with `--apply --commit --push --require-digests` and both digest flags.
- [ ] AC-015: Given `update_gitops=true` and `target_environment=select-environment`, when the workflow runs, then it fails with an error requiring explicit environment selection.
- [ ] AC-016: Given `update_gitops=true` and `target_environment=staging`, when `ENABLE_STAGING_ENV` is not set to `true`, then the workflow fails with a message indicating staging is disabled.
- [ ] AC-017: Given `deploy_to_staging=true` is used in manual dispatch, when the workflow runs, then it fails with a deprecation error directing the user to `update_gitops`.
- [ ] AC-018: Given `update_gitops=true` but `build_openedx=false`, when the workflow runs, then it fails requiring both builds for deterministic digest capture.

### Release Process

- [ ] AC-019: Given the `release-evidence.yml` workflow is dispatched with valid tags, when it completes, then a `release-evidence-<env>-<run>` artifact is uploaded containing: policy check logs, dry-run plan, resolved digests, and `release-metadata.json`.
- [ ] AC-020: Given the `policy-checks.yml` workflow is dispatched, when all verification scripts pass, then the workflow succeeds.
- [ ] AC-021: Given a production rollback is needed, when the operator runs `release-openedx-gitops.sh` with prior known-good tags, then the rollback completes without building new images and pods converge within 10 minutes.

### Scheduled Operations

- [ ] AC-022: Given the `public-health-check.yml` runs on schedule, when branding is correct on prod and dev, then no failures are reported and logs are uploaded as artifacts.
- [ ] AC-023: Given the `operations-gates-runtime.yml` runs on schedule, when GKE authentication succeeds, then operations gates execute against the live cluster and artifacts are uploaded with 30-day retention.
- [ ] AC-024: Given the `dr-evidence-bundle.yml` runs on the 1st of the month, when GKE access is available, then a DR evidence bundle is generated and uploaded with 120-day retention.

### iOS Build

- [ ] AC-025: Given the iOS workflow is manually dispatched, when it completes successfully, then a signed IPA is uploaded to TestFlight via App Store Connect API.
- [ ] AC-026: Given the iOS workflow runs, when it completes (pass or fail), then SSH keys used for Match are cleaned up.

### Security

- [ ] AC-027: Given the pre-commit hook is installed, when a developer attempts to commit a file containing a hardcoded secret pattern, then the commit is rejected with a warning.
- [ ] AC-028: Given any workflow runs, when secrets are used, then no secret values appear in workflow logs (GitHub Actions masking).

### SSO Canary

- [ ] AC-029: Given the `authenticated-sso-canary.yml` workflow runs on schedule (every 6h), when SSO credentials are valid, then the workflow successfully authenticates to both LMS and Studio (if configured) and uploads canary artifacts with 30-day retention.
- [ ] AC-030: Given the SSO canary fails authentication, when the workflow completes, then artifacts (screenshots, logs) are uploaded showing the failure point for debugging.

### Tutor Configuration Verification

- [ ] AC-031: Given the `tutor-config-verify.yml` workflow runs when changes are made to `tutor_env/config.yml` or `infrastructure/tutor/**`, when all patches are correctly applied, then the workflow succeeds with verification passing for MySQL auth patch, MFE Node.js patch, multi-site domains, and custom apps.
- [ ] AC-032: Given the Tutor config verification runs, when required patches are missing, then the job fails with specific error messages identifying which patch (MySQL, MFE, domains, or apps) is not applied.
- [ ] AC-033: Given the patch idempotency check runs, when patches are applied twice, then the checksums of all generated files remain identical.
- [ ] AC-034: Given the Tutor config verification fails on a PR, when a developer views the PR, then a comment is posted with common issues and remediation steps.

### Tutor Plugin Testing

- [ ] AC-035: Given the `tutor-plugin-test.yml` workflow runs when changes are made to `infrastructure/tutor/plugins/**`, when the plugin code is valid, then the workflow succeeds with plugin syntax verification, enable/disable lifecycle tests, and integration tests passing.
- [ ] AC-036: Given the plugin tests run, when the plugin patches are correctly applied, then the LMS settings file contains the expected plugin configuration (mfe_oauth_fix installed).
- [ ] AC-037: Given the plugin lifecycle test runs, when the plugin is enabled, disabled, and re-enabled, then all state transitions succeed without errors.
- [ ] AC-038: Given the integration test runs, when both plugin and apply-patches.sh are used together, then both sets of patches are present in the generated configuration.
- [ ] AC-039: Given plugin tests fail on a PR, when a developer views the PR, then a comment is posted with plugin-specific troubleshooting guidance.

## Edge Cases

### Build Failures

- **OOM during OpenEdX build**: The openedx image build requires 12GB+ RAM. GitHub-hosted runners provide 7GB. The workflow sets `DOCKER_OPTS=--memory=12g --memory-swap=16g` but this may not be effective on all runner configurations. If OOM persists, the build MUST fail clearly (not hang) and the step summary MUST suggest building locally or using self-hosted runners.
- **OOM during MFE build**: MFE webpack builds consume 6-8GB. The workflow sets `NODE_OPTIONS=--max-old-space-size=6144`. If the build OOMs, the error MUST be distinguishable from other failures.
- **Network failure during image push**: If `docker push` fails due to transient network issues, the workflow MUST fail (no silent partial push). Re-running the workflow MUST be safe (idempotent tag overwrite in Artifact Registry).
- **Stale Tutor cache**: If Tutor's cached state conflicts with config changes, `--no-cache` builds MUST produce correct results. The workflow uses `--no-cache` by default for CI builds.

### Deployment Failures

- **GitOps PAT expired**: If `GITOPS_PAT` is expired or invalid, the update-gitops job MUST fail before attempting git operations, with a clear error message about the PAT.
- **bbi-infrastructure merge conflict**: If the GitOps commit conflicts with concurrent changes in `bbi-infrastructure`, the push MUST fail and the operator MUST resolve manually. The workflow MUST NOT force-push.
- **Digest mismatch**: If image digests from build outputs do not match registry-resolved digests, `release-openedx-gitops.sh` with `--require-digests` MUST fail. This indicates a registry consistency issue.
- **Partial build success**: If openedx builds but MFE fails, the update-gitops job MUST NOT run (it depends on both build jobs via `needs`).

### Scheduled Workflow Failures

- **GKE auth failure in scheduled workflows**: Runtime workflows (`operations-gates-runtime`, `observability-audit`, `alert-routing-audit`) MUST handle GKE authentication failures gracefully. Non-strict mode (`strict_runtime=false`) SHOULD skip GKE-dependent checks and report them as warnings. Strict mode MUST fail the workflow.
- **Rate limiting**: If GitHub API rate limits are hit during scheduled workflows (every 30 min health checks), the workflow SHOULD fail gracefully without cascading failures.

### Concurrent Build Handling

- **Concurrent pushes to same branch**: If two commits are pushed to the same branch within minutes, the build workflow MUST use `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }` to cancel the older build. Only the latest commit's build should complete.
- **Concurrent image pushes**: Two workflows pushing the same image tag simultaneously MUST NOT corrupt the registry. Artifact Registry handles this atomically (last writer wins). The GitOps update MUST use the latest digest.
- **Concurrent GitOps updates**: If two builds complete simultaneously and both try to update `bbi-infrastructure`, the second push MUST fail (no force-push). The operator resolves by re-running the failed workflow, which picks up the latest state.
- **Scheduled workflow overlap**: If a scheduled workflow run overlaps with the previous run (e.g., health check takes longer than the schedule interval), the new run SHOULD be skipped via `concurrency` group to avoid resource contention.

### Retry/Timeout Behavior

- No automatic retry is implemented at the workflow level. Failed workflows MUST be manually re-run.
- Timeouts: iOS builds have a 90-minute timeout. All other jobs inherit the default 6-hour GitHub Actions timeout, which SHOULD be sufficient.
- The pipeline SHOULD set explicit `timeout-minutes` on long-running jobs to prevent runaway builds from consuming runner quota.

### Idempotency

- Re-running any build workflow with the same inputs MUST be safe. Image tags are overwritten in Artifact Registry (same tag points to new digest if source changed, or same digest if unchanged).
- Re-running GitOps update with the same tags MUST be safe. The release orchestrator script MUST produce an identical commit (or no-op if tags already match).
- Re-running release evidence generation MUST produce a new artifact bundle with a new `run_id`.

### Rate Limits and Quotas

- GitHub Actions: 2,000 minutes/month for free tier, 3,000 for Team. The current workflow set (11 workflows, some scheduled) SHOULD be estimated monthly:
  - CI: ~5 min/run x ~50 PRs/month = 250 min
  - Builds: ~60 min/run x ~10 builds/month = 600 min
  - Scheduled: ~5 min/run x (4 daily + 48 health checks + 4 ops gates) x 30 days = ~8,400 min
  - iOS: ~60 min/run x ~4 builds/month = 240 min (macOS minutes count 10x)
  - Total estimate: ~9,490+ min/month. This SHOULD be monitored and scheduled workflow frequency MAY be reduced if quotas are exceeded.
- GCP Artifact Registry: No per-push limits but storage costs apply. Images SHOULD be cleaned up per retention policy.

### Partial Failures

- If a CI job fails but others pass, the PR MUST still be blocked (all required checks must pass).
- If the branding preflight fails but lint passes, the failure reason MUST be clear in the check detail.
- If scheduled workflows fail intermittently, the next scheduled run MUST attempt fresh execution (no stuck state).

## Observability

### Logs

- Every workflow MUST produce GitHub Step Summaries with structured results (markdown tables of pass/fail).
- Build workflows MUST log: image name, tag, short SHA, digest, registry URL.
- GitOps workflows MUST log: target environment, tags applied, commit SHA, push result.
- Scheduled workflows MUST upload their output as artifacts in addition to step summaries.
- Failed steps MUST include the failing command's stderr in the step output.

### Metrics

- GitHub Actions usage (minutes consumed per workflow per month) SHOULD be tracked via the GitHub billing API or repository insights.
- Build duration per image type (openedx, MFE, iOS) SHOULD be tracked over time.
- CI pass rate per job SHOULD be tracked to identify flaky checks.
- Deployment frequency (GitOps updates per week) SHOULD be tracked as a DORA metric.
- Mean time to recovery (MTTR) after failed deployments SHOULD be tracked.

### Alerts

- `public-health-check.yml` failures MUST trigger a notification (GitHub Actions email or Slack webhook) since they indicate production branding/auth degradation.
- `operations-gates-runtime.yml` failures in strict mode SHOULD trigger a notification since they indicate operational drift.
- Build failures on the `main` branch (not PRs) SHOULD trigger a notification since they indicate broken trunk.
- DR evidence bundle failures SHOULD trigger a monthly review alert.

### Dashboards

- A GitHub Actions workflow status dashboard SHOULD be maintained (either via GitHub's native Actions tab or an external tool like Datadog CI Visibility).
- Build times and success rates SHOULD be visible to the engineering team.

## Rollout & Rollback

### Rollout Plan

1. **Phase 1 (current state)**: All 11 workflows are already deployed and running. This spec formalizes the existing contracts.
2. **Phase 2**: Add explicit `timeout-minutes` to all jobs that lack them. Add branch protection rules requiring CI status checks.
3. **Phase 3**: Add CI minute usage monitoring. Evaluate scheduled workflow frequency against quota.
4. **Phase 4**: Implement deployment frequency and MTTR tracking as DORA metrics.
5. **Phase 5**: Evaluate self-hosted runners for OpenEdX builds if OOM issues persist on GitHub-hosted runners.

### Feature Flags

- `ENABLE_STAGING_ENV` repository variable gates staging deployments.
- `ENABLE_CLOUD_SQL_BACKUPS` repository variable gates legacy backup workflow.
- `RUN_AUTHENTICATED_SSO_CANARY` repository variable gates credentialed SSO canary tests.
- Runtime workflows support `strict_runtime` input to toggle hard vs soft failure on GKE auth issues.

### Backward Compatibility

- The `deploy_to_staging` input on `build-tutor-images.yml` is retained for backward compatibility but MUST error with a deprecation message.
- Existing workflow file names MUST NOT change (external references, GitHub Actions badge URLs, and branch protection rules reference them by name).
- New workflows MUST be added as new files, never by renaming existing ones.

### Rollback Steps

1. **Workflow rollback**: Revert the workflow YAML change via a PR and merge to `main`. GitHub Actions will use the updated workflow on the next trigger.
2. **Production deployment rollback**: Run `release-openedx-gitops.sh` with the prior known-good tags and digests. No image rebuild required.
   ```bash
   ./scripts/infra/release-openedx-gitops.sh \
     --target-env production \
     --openedx-tag "<prior-good-tag>" \
     --mfe-tag "<prior-good-tag>" \
     --openedx-digest "sha256:<prior-good-digest>" \
     --mfe-digest "sha256:<prior-good-digest>" \
     --require-digests \
     --apply --commit --push
   ```
3. **iOS release rollback**: Use App Store Connect to expire the TestFlight build or push a new build with the prior version.
4. **Emergency hotfix**: Administrators MAY push directly to `main` (bypassing PR) for critical fixes. This MUST be documented post-hoc and a PR SHOULD be created retroactively.

## Open Questions

- **Self-hosted runners**: Should we provision a self-hosted runner (on the VPS or a dedicated GCE instance) for OpenEdX image builds to guarantee 12GB+ RAM? Current GitHub-hosted runners may OOM. Cost vs reliability tradeoff needs evaluation.
- **GitHub Actions minutes budget**: Current scheduled workflows consume significant minutes. Should health check frequency be reduced from every 30 minutes to every hour? Should operations gates frequency be reduced from every 6 hours to every 12 hours?
- **Notification channel**: What is the preferred notification mechanism for CI/CD failures? Options: GitHub email notifications (default), Slack webhook (requires new secret), PagerDuty (overkill for current team size).
- **Terraform plan in CI**: Should CI run `terraform plan` on infrastructure changes to detect drift? This would require Terraform state access and GCP credentials with broader permissions.
- **Container image signing**: Should images be signed with cosign/Sigstore for supply chain security? This adds complexity but provides tamper-evidence for production images.
- **Dependency scanning**: Should we add Dependabot or Renovate for automated dependency updates on GitHub Actions, Python packages, and Tutor plugins?
- **Performance regression testing**: Should we add automated performance benchmarking (e.g., response time assertions against production endpoints) as a post-deploy gate? Current health checks verify availability but not performance.
