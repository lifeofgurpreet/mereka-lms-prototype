# Open edX Repo Audit - Execution Board

Last updated: 2026-03-05  
Parent issue: https://github.com/Biji-Biji-Initiative/mereka-lms/issues/214

## Current Implementation Status (Live)

| Issue | Status | PR |
|------:|--------|----|
| #215 | Implemented (awaiting review/merge) | https://github.com/Biji-Biji-Initiative/mereka-lms/pull/224 |
| #216 | Implemented (awaiting review/merge) | https://github.com/Biji-Biji-Initiative/mereka-lms/pull/225 |
| #217 | Implemented (awaiting review/merge) | https://github.com/Biji-Biji-Initiative/mereka-lms/pull/227 |
| #218 | Implemented (awaiting review/merge) | https://github.com/Biji-Biji-Initiative/mereka-lms/pull/228 |
| #219 | Implemented (awaiting review/merge) | https://github.com/Biji-Biji-Initiative/mereka-lms/pull/229 |
| #220 | Implemented (awaiting review/merge) | https://github.com/Biji-Biji-Initiative/mereka-lms/pull/230 |
| #221 | Implemented (awaiting review/merge) | https://github.com/Biji-Biji-Initiative/mereka-lms/pull/232 |
| #222 | Implemented (awaiting review/merge) | https://github.com/Biji-Biji-Initiative/mereka-lms/pull/226 |

## Purpose

Operational board for implementors to execute child issues in safe order with clear entry PR, gate commands, and rollback triggers.

## Canonical Inputs

- `docs/architecture/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_IMPLEMENTOR_SPECS.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_IMPLEMENTOR_PR_TEMPLATE.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_IMPLEMENTOR_KICKOFF.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_215_PACKET.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_216_PACKET.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_217_PACKET.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_218_PACKET.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_219_PACKET.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_220_PACKET.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_221_PACKET.md`
- `docs/architecture/OPENEDX_REPO_AUDIT_ISSUE_222_PACKET.md`

---

## Queue

| Order | Issue | Track | First PR Scope | Depends On | Exit Gate |
|------:|------:|-------|----------------|------------|-----------|
| 1 | #215 | Security | Redaction checker + pre-commit + CI wiring | none | `verify-evidence-redaction.sh` passing in CI |
| 2 | #216 | Release safety | Deprecate/fence legacy Tutor K8s scripts | #215 optional | `verify-no-legacy-tutor-k8s-paths.sh` passing |
| 3 | #222 | Repo contract | Normalize authn submodule path references | none | submodule path checker passing |
| 4 | #217 | Branding | Multi-brand sync orchestrator + manifest | #215 | brand package drift check passing |
| 5 | #218 | Theming | Artifact policy + determinism gate | #217 recommended | theme determinism + token drift passing |
| 6 | #219 | QA operability | Verify-manifest inventory + lane wrappers | #216 recommended | manifest integrity gate passing |
| 7 | #220 | Tenant architecture | Tenant registry + apply orchestrator | #216 strongly recommended | tenant registry drift gate passing |
| 8 | #221 | Payments resilience | Outbox model + async worker | none | webhook idempotency + async fulfillment tests passing |

---

## Definition of Done

For each child issue:

1. Packet PR-A implemented.
2. CI gate added and green.
3. Docs updated and linked from packet.
4. Rollback path tested in dry run.
5. Issue comment updated with:
   - merged PR link
   - gate output snippet
   - known follow-up debt.

---

## Gate Command Matrix

| Issue | Minimum local gates before PR |
|------:|-------------------------------|
| #215 | `bash -n scripts/qa/verify-evidence-redaction.sh` and `STRICT=1 ./scripts/qa/verify-evidence-redaction.sh` |
| #216 | `bash -n scripts/qa/verify-no-legacy-tutor-k8s-paths.sh` and `./scripts/qa/verify-no-legacy-tutor-k8s-paths.sh` |
| #217 | `./scripts/branding/sync-brand-assets.sh` and `./scripts/qa/verify-brand-packages-drift.sh` |
| #218 | `./scripts/qa/verify-theme-artifacts-determinism.sh` and `./scripts/qa/verify-token-drift.sh` |
| #219 | `./scripts/qa/verify-manifest-integrity.sh` |
| #220 | `./scripts/tenants/validate-tenant-registry.sh` and `./scripts/qa/verify-tenant-registry-drift.sh --mode local` |
| #221 | `pytest services/purchase-gateway/tests` and stripe webhook replay test |
| #222 | `./scripts/qa/verify-authn-submodule-path-contract.sh` and `git submodule status` |

---

## Rollback Triggers

| Issue | Trigger | Immediate rollback action |
|------:|---------|---------------------------|
| #215 | false-positive flood blocks normal docs PRs | set gate warn-only temporarily; keep logging |
| #216 | emergency deployment blocked by deprecation fences | allow one-time `ALLOW_LEGACY_TUTOR_K8S=1` path |
| #217 | brand sync rewrites unexpected package assets | revert manifest/script change, keep wrapper |
| #218 | missing runtime `/theme/*.min.css` after policy change | revert to tracked artifact mode |
| #219 | lane wrapper fails and obscures root failure | revert workflow to direct script call temporarily |
| #220 | tenant apply orchestrator partially applies | fallback to existing per-tenant scripts; rerun idempotent apply |
| #221 | worker/outbox backlog grows uncontrollably | disable async flag, fallback sync path |
| #222 | submodule path move breaks local bootstrap | revert path move, keep docs normalization |

---

## Suggested Parallelization

- Lane A (security/control): #215 + #216
- Lane B (frontend governance): #217 + #218 + #222
- Lane C (platform ops): #219 + #220
- Lane D (payments reliability): #221

Keep #220 blocked on #216 completion to avoid locking in conflicting control planes.

---

## Handoff Protocol

Before handing each child issue to implementor:

1. Link issue packet.
2. Confirm first PR scope only (avoid multi-phase bundling).
3. Confirm expected rollback switch exists.
4. Require gate output in PR description.
