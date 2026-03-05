# Open edX Repo Audit - Implementor Kickoff Commands

Use with:
- `docs/architecture/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_IMPLEMENTOR_PR_TEMPLATE.md`

## Baseline Setup

```bash
cd /home/gurpreet/projects/k8s/mereka-lms
git checkout main
git pull --rebase
```

## Branch Naming Convention

```bash
# format: audit/<issue-id>-<phase>-<short-topic>
git checkout -b audit/215-a-evidence-redaction
```

## Issue #215 (PR-215-A)

```bash
git checkout -b audit/215-a-evidence-redaction
bash -n scripts/qa/verify-evidence-redaction.sh || true
STRICT=1 ./scripts/qa/verify-evidence-redaction.sh || true
```

## Issue #216 (PR-216-A)

```bash
git checkout -b audit/216-a-control-plane-fence
bash -n scripts/qa/verify-no-legacy-tutor-k8s-paths.sh || true
./scripts/qa/verify-no-legacy-tutor-k8s-paths.sh || true
```

## Issue #217 (PR-217-A)

```bash
git checkout -b audit/217-a-multibrand-sync
./scripts/branding/sync-brand-assets.sh
./scripts/qa/verify-brand-packages-drift.sh || true
```

## Issue #218 (PR-218-A)

```bash
git checkout -b audit/218-a-theme-artifact-policy
./scripts/branding/generate-tokens-from-canonical.sh --check || true
./scripts/qa/verify-token-drift.sh || true
./scripts/qa/verify-theme-artifacts-determinism.sh || true
```

## Issue #219 (PR-219-A)

```bash
git checkout -b audit/219-a-verify-manifest
./scripts/qa/verify-manifest-integrity.sh || true
```

## Issue #220 (PR-220-A)

```bash
git checkout -b audit/220-a-tenant-registry
./scripts/tenants/validate-tenant-registry.sh || true
```

## Issue #221 (PR-221-A)

```bash
git checkout -b audit/221-a-fulfillment-outbox
pytest services/purchase-gateway/tests -k "webhook or idempot" || true
```

## Issue #222 (PR-222-A)

```bash
git checkout -b audit/222-a-authn-submodule-contract
git config -f .gitmodules --get-regexp '^submodule\\..*\\.path$'
./scripts/qa/verify-authn-submodule-path-contract.sh || true
```

## PR Body Requirement

Always include:
1. Packet link
2. AC mapping table
3. gate output snippets
4. rollback path validated
