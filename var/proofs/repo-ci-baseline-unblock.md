# Proof: Repo-Only CI Baseline Unblock

**Lane**: F (Repo/CI Stabilization)
**Branch**: `stabilization/repo-ci-baseline-unblock`
**PR**: #876
**Date**: 2026-03-11 → 2026-03-12

## Problem

CI was false-red on `main` and every open PR. Four jobs failed systematically:
Static Validation, Tutor Configuration Tests, Security Scans, Python test coverage.

Each fix layer revealed the next hidden failure (cascade pattern).

## Fix Chain (8 commits)

| # | Fix | Root Cause |
|---|-----|-----------|
| 1 | CRLF → LF (64 YAML files) + `.gitattributes` | Windows line endings broke yamllint |
| 2 | lint-repo-conventions (regex, shebangs, naming, pinning) | 64 failures across 4 categories |
| 3 | Blocker ledger update | Documentation |
| 4 | shellcheck install (replace GH Action with direct binary + Python lzma) | ARC runners lack xz-utils |
| 5 | shellcheck error fixes (2 pre-existing bugs) | SC1087, SC1072/SC1073 |
| 6 | kubeconform exclusions (3 non-K8s YAML files) | Data files lack `kind` key |
| 7 | lsb_release stub in setup-python-env composite action | ARC runners lack lsb-release package |
| 8 | Stabilization docs + guardrail scripts | Deliverables |

## Verification

- shellcheck `--severity=error` on all 954 scripts: 0 errors
- yamllint on all YAML: 0 errors
- lint-repo-conventions: 14 PASS, 0 FAIL
- lsb_release stub tested locally: handles -rs, -is, -a, combined flags
- 5 guardrail scripts pass shellcheck and run locally

## Deliverables Created

### Documents
- `docs/stabilization/FAILURE_TAXONOMY.md` — 9 failure modes, 5 categories
- `docs/stabilization/EXECUTION_INVARIANTS.md` — 10 binding invariants
- `docs/stabilization/AGENT_OPERATING_MODEL.md` — Lane system, turn discipline
- `docs/stabilization/ARC_RUNNER_CAPABILITY_CONTRACT.md` — Runner capabilities/gaps

### Guardrail Scripts
- `scripts/qa/verify-agent-context-lock.sh` — Repo/branch identity check
- `scripts/qa/verify-clean-tree-before-mutation.sh` — Clean tree gate
- `scripts/qa/verify-worktree-sanity.sh` — Worktree health check
- `scripts/qa/verify-mutation-scope.sh` — Lane boundary enforcement
- `scripts/qa/verify-arc-runner-contract.sh` — Runner capability matrix

## CI Status

- `lsb_release` fix pushed, CI run queued (ARC runners processing)
- Pre-existing docs compliance gate failure is Lane E scope
- Expected: all 4 previously-failing jobs should now pass

## Status: IN_PROGRESS

Pending: CI confirmation that all 4 jobs pass with the lsb_release stub.
