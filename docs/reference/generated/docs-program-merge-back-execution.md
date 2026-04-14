# Docs Program Merge-Back Execution

_Generated from `docs/meta/docs-program/metadata/merge-back-wave-execution.v1.yaml` (last updated 2026-04-14)._
_Do not hand-edit. Regenerate with: `python3 tools/docs/build_docs_program_merge_back_execution_summary.py`_

## Overview

| Measure | Count |
|---|---:|
| Defined waves | 5 |
| Recorded executions | 5 |
| Execution manifest errors | 0 |

## wave-0a-concepts-root-authority: Concepts root authority baseline

- status: `superseded`
- branch: `docs/wave-0a-concepts-root-authority-20260414-v2`
- tip commit: `7c39f2377`
- PR: https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1727
- superseded by: `wave-0b-architecture-root-authority`
- depends on: none
- proposed PR title: `docs: align concepts architecture root authority`
- include paths: `5`
- remove paths: `1`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`

## wave-0b-architecture-root-authority: Stable architecture root authority baseline

- status: `merged`
- branch: `docs/wave-0b-architecture-root-authority-20260414-v2`
- tip commit: `dc5db65dd`
- PR: https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1731
- merged commit: `2279cfb8b19fe5aaaa28d824d3ad59de2f5bc0e9`
- depends on: `wave-0a-concepts-root-authority`
- proposed PR title: `docs: align stable architecture root authority`
- include paths: `6`
- remove paths: `0`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`

## wave-1-control-plane: Active docs control plane

- status: `merged`
- branch: `docs/wave-1-control-plane-20260414-v2`
- tip commit: `0c2697bed`
- PR: https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1730
- merged commit: `39b1127426aff886648ae11742d5db2c97c5b9e4`
- depends on: `wave-0a-concepts-root-authority, wave-0b-architecture-root-authority`
- proposed PR title: `docs: refresh active docs control plane`
- include paths: `14`
- remove paths: `0`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`

## wave-2a-packet-normalization: Historical packet normalization

- status: `merged`
- branch: `docs/wave-2a-packet-normalization-20260414-v2`
- tip commit: `f8ad4ef64`
- PR: https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1728
- merged commit: `62233a7893e39a48f6f03e80685fd8ab2cf9d907`
- depends on: `wave-1-control-plane`
- proposed PR title: `docs: bound historical docs program packets`
- include paths: `20`
- remove paths: `0`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`

## wave-2b-reset-wave-normalization: Historical reset-wave normalization

- status: `merged`
- branch: `docs/wave-2b-reset-wave-normalization-20260414-v2`
- tip commit: `52d5dfb9c`
- PR: https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1729
- merged commit: `7e5bdf410a463f50652089ad408115bff94940a1`
- depends on: `wave-1-control-plane`
- proposed PR title: `docs: bound reset-wave packet families`
- include paths: `21`
- remove paths: `0`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`

