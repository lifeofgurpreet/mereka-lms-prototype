# Docs Program Merge-Back Waves

_Generated from `docs/meta/docs-program/metadata/merge-back-waves.v1.yaml` (last updated 2026-04-14)._
_Do not hand-edit. Regenerate with: `python3 tools/docs/build_docs_program_merge_back_wave_summary.py`_

## Overview

| Measure | Count |
|---|---:|
| Defined waves | 5 |
| Missing manifest paths | 0 |
| Overlapping include paths | 0 |
| Dependency errors | 0 |

## Extraction Order

1. `wave-0a-concepts-root-authority`
2. `wave-0b-architecture-root-authority`
3. `wave-1-control-plane`
4. `wave-2a-packet-normalization`
5. `wave-2b-reset-wave-normalization`

## wave-0a-concepts-root-authority: Concepts root authority baseline

- readiness: `ready`
- depends on: none
- proposed PR title: `docs: align concepts architecture root authority`
- include paths: `5`
- remove paths: `1`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`
- out of scope:
  - stable architecture root retirement and deprecation-ledger cleanup
  - active docs-program control-plane refresh
  - historical packet and reset-wave normalization
- bundle:
  - [`docs/concepts/architecture/ARCHITECTURE_CHARTER.md`](../../concepts/architecture/ARCHITECTURE_CHARTER.md)
  - [`docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md`](../../concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
  - [`docs/concepts/architecture/README.md`](../../concepts/architecture/README.md)
  - [`docs/concepts/architecture/TENANT_OPERATING_SYSTEM.md`](../../concepts/architecture/TENANT_OPERATING_SYSTEM.md)
  - `tools/docs/verify/verify_concepts_architecture_clean.py`
- removes:
  - `docs/concepts/architecture/WS4_PROMOTION_CONTRACT.md`

## wave-0b-architecture-root-authority: Stable architecture root authority baseline

- readiness: `ready`
- depends on: `wave-0a-concepts-root-authority`
- proposed PR title: `docs: align stable architecture root authority`
- include paths: `6`
- remove paths: `0`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`
- out of scope:
  - concepts-root authority cleanup already claimed by Wave 0A
  - active docs-program control-plane refresh
  - historical packet and reset-wave normalization
- bundle:
  - [`docs/reference/governance/DEPRECATION_LEDGER.md`](../../reference/governance/DEPRECATION_LEDGER.md)
  - [`docs/stabilization/RETIRED_ROOT_REMEDIATION_LEDGER.md`](../../stabilization/RETIRED_ROOT_REMEDIATION_LEDGER.md)
  - `infrastructure/monitoring/grafana/dashboards/public-endpoints.json`
  - `scripts/qa/lint-repo-conventions.sh`
  - `tools/docs/verify/verify-docs-policy.sh`
  - `tools/docs/verify/verify_legacy_architecture_root.py`

## wave-1-control-plane: Active docs control plane

- readiness: `ready`
- depends on: `wave-0a-concepts-root-authority, wave-0b-architecture-root-authority`
- proposed PR title: `docs: refresh active docs control plane`
- include paths: `14`
- remove paths: `0`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`
- out of scope:
  - historical packet and reset-wave docs
  - companion compression and review-source changes
  - Tutor, branding, CI, or contract-truth sync families
  - runtime-proof or cross-repo follow-through
- bundle:
  - [`docs/meta/docs-program/authority-registry.v1.yaml`](../../meta/docs-program/authority-registry.v1.yaml)
  - [`docs/meta/docs-program/companion-surface-review.v1.yaml`](../../meta/docs-program/companion-surface-review.v1.yaml)
  - [`docs/meta/docs-program/POST_REBASE_INTAKE_2026-04-13.md`](../../meta/docs-program/POST_REBASE_INTAKE_2026-04-13.md)
  - [`docs/meta/docs-program/REVIEW_HARDENING_BOARD_2026-04-13.md`](../../meta/docs-program/REVIEW_HARDENING_BOARD_2026-04-13.md)
  - [`docs/meta/docs-program/DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`](../../meta/docs-program/DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)
  - [`docs/meta/docs-program/README.md`](../../meta/docs-program/README.md)
  - [`docs/meta/docs-program/owner-gap-ledger.v1.yaml`](../../meta/docs-program/owner-gap-ledger.v1.yaml)
  - [`docs/meta/README.md`](../../meta/README.md)
  - [`docs/meta/docs-program/metadata/METADATA_MODEL.md`](../../meta/docs-program/metadata/METADATA_MODEL.md)
  - [`docs/meta/docs-program/metadata/doc-class-schema-map.yaml`](../../meta/docs-program/metadata/doc-class-schema-map.yaml)
  - [`docs/meta/docs-program/metadata/governs-taxonomy.yaml`](../../meta/docs-program/metadata/governs-taxonomy.yaml)
  - [`docs/meta/docs-program/metadata/merge-back-waves.v1.yaml`](../../meta/docs-program/metadata/merge-back-waves.v1.yaml)
  - [`docs/reference/generated/docs-program-authority-summary.md`](../../reference/generated/docs-program-authority-summary.md)
  - [`docs/reference/generated/docs-program-merge-back-waves.md`](../../reference/generated/docs-program-merge-back-waves.md)

## wave-2a-packet-normalization: Historical packet normalization

- readiness: `ready`
- depends on: `wave-1-control-plane`
- proposed PR title: `docs: bound historical docs program packets`
- include paths: `20`
- remove paths: `0`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`
- out of scope:
  - reset-wave families
  - docs/meta/docs-program/WAVE9_FINDINGS_LEDGER.md historical evidence
  - live control surfaces already claimed by Wave 1
  - companion compression and fresh source-truth intake
- bundle:
  - [`docs/meta/docs-program/PROGRAM_UPDATE_V2_BRIEF.md`](../../meta/docs-program/PROGRAM_UPDATE_V2_BRIEF.md)
  - [`docs/meta/docs-program/IMPLEMENTATION_ROADMAP.md`](../../meta/docs-program/IMPLEMENTATION_ROADMAP.md)
  - [`docs/meta/docs-program/AGENT_WORKPACKETS.md`](../../meta/docs-program/AGENT_WORKPACKETS.md)
  - [`docs/meta/docs-program/FOUNDATIONS_PROGRAM.md`](../../meta/docs-program/FOUNDATIONS_PROGRAM.md)
  - [`docs/meta/docs-program/DOCS_FIRST_CLASS_WEEKLY_EXECUTION_PLAN_20260306.md`](../../meta/docs-program/DOCS_FIRST_CLASS_WEEKLY_EXECUTION_PLAN_20260306.md)
  - [`docs/meta/docs-program/DOCS_GOVERNANCE_SIGNOFF_CHECKLIST_20260307.md`](../../meta/docs-program/DOCS_GOVERNANCE_SIGNOFF_CHECKLIST_20260307.md)
  - [`docs/meta/docs-program/ARCHITECTURE_GOVERNANCE_OVERLAY.md`](../../meta/docs-program/ARCHITECTURE_GOVERNANCE_OVERLAY.md)
  - [`docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md`](../../meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md)
  - [`docs/meta/docs-program/WAVE3_CLOSEOUT.md`](../../meta/docs-program/WAVE3_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE3_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE3_REVIEW_HANDOFF.md)
  - [`docs/meta/docs-program/WAVE3_EXECUTION_TRACKER.md`](../../meta/docs-program/WAVE3_EXECUTION_TRACKER.md)
  - [`docs/meta/docs-program/WAVE4_CHARTER.md`](../../meta/docs-program/WAVE4_CHARTER.md)
  - [`docs/meta/docs-program/WAVE4_REVIEWER_CHECKLIST.md`](../../meta/docs-program/WAVE4_REVIEWER_CHECKLIST.md)
  - [`docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md`](../../meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md)
  - [`docs/meta/docs-program/WAVE4_CLOSEOUT.md`](../../meta/docs-program/WAVE4_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE4_EXECUTION_TRACKER.md`](../../meta/docs-program/WAVE4_EXECUTION_TRACKER.md)
  - [`docs/meta/docs-program/WAVE4_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE4_REVIEW_HANDOFF.md)
  - [`docs/meta/docs-program/WAVE9_CLOSEOUT.md`](../../meta/docs-program/WAVE9_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE9_EXECUTION_TRACKER.md`](../../meta/docs-program/WAVE9_EXECUTION_TRACKER.md)
  - [`docs/meta/docs-program/WAVE9_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE9_REVIEW_HANDOFF.md)

## wave-2b-reset-wave-normalization: Historical reset-wave normalization

- readiness: `ready`
- depends on: `wave-1-control-plane`
- proposed PR title: `docs: bound reset-wave packet families`
- include paths: `21`
- remove paths: `0`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`
- out of scope:
  - packet-normalization files claimed by Wave 2A
  - live control surfaces already claimed by Wave 1
  - companion compression and fresh source-truth intake
- bundle:
  - [`docs/meta/docs-program/WAVE_ADR_RESET_TRACKER.md`](../../meta/docs-program/WAVE_ADR_RESET_TRACKER.md)
  - [`docs/meta/docs-program/WAVE_ADR_RESET_CLOSEOUT.md`](../../meta/docs-program/WAVE_ADR_RESET_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE_ADR_RESET_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE_ADR_RESET_REVIEW_HANDOFF.md)
  - [`docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_TRACKER.md`](../../meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_TRACKER.md)
  - [`docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_CLOSEOUT.md`](../../meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_REVIEW_HANDOFF.md)
  - [`docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_TRACKER.md`](../../meta/docs-program/WAVE_BRANDING_ROOT_RESET_TRACKER.md)
  - [`docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_CLOSEOUT.md`](../../meta/docs-program/WAVE_BRANDING_ROOT_RESET_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE_BRANDING_ROOT_RESET_REVIEW_HANDOFF.md)
  - [`docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_TRACKER.md`](../../meta/docs-program/WAVE_CI_CD_ROOT_RESET_TRACKER.md)
  - [`docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_CLOSEOUT.md`](../../meta/docs-program/WAVE_CI_CD_ROOT_RESET_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE_CI_CD_ROOT_RESET_REVIEW_HANDOFF.md)
  - [`docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_TRACKER.md`](../../meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_TRACKER.md)
  - [`docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_CLOSEOUT.md`](../../meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_REVIEW_HANDOFF.md)
  - [`docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_TRACKER.md`](../../meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_TRACKER.md)
  - [`docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_CLOSEOUT.md`](../../meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_REVIEW_HANDOFF.md)
  - [`docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_TRACKER.md`](../../meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_TRACKER.md)
  - [`docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_CLOSEOUT.md`](../../meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_CLOSEOUT.md)
  - [`docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_REVIEW_HANDOFF.md`](../../meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_REVIEW_HANDOFF.md)

