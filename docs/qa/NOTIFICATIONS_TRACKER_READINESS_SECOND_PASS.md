# Notifications / Email Pipeline — Tracker Readiness Review (Second Pass)

_Date: 2026-02-25_
_Target: Release readiness review for local/dev + non-prod + production parity_

## 0) Scope and evidence used

- AC source: `specs/email-notifications-pipeline_spec.md`
- AC test coverage source: `specs/testmaps/email-notifications-pipeline_spec.testmap.yml`
- Prior parity matrix: `docs/qa/DEPLOYMENT_TRACKER_AC_MATRIX.md`
- Tracker source used for ownership: `.beads/beads.db`
- Runtime/runtime-like checks reviewed via existing scripts and manifest inventory in repo (no live cluster probing was executed by the reviewer)

## 1) Executive finding

The biggest remaining blocker for notification/email parity is **implementation gap**, not script inventory.

- Existing tracker work is focused on migration/deployment hardening and CI/CD parity.
- There is **no active tracker title explicitly owning notification/email pipeline delivery ACs** at the moment.
- The email spec AC set is well-defined, but the corresponding functional work is mostly not implemented yet.
- If the goal is “dev + staging parity + prod,” the current signal is:
  - deployment lanes are converging on `local` / `rke2-nonprod` / `production`
  - notification/email capability is not yet the ready baseline for any lane.

## 2) Live vs not-live from repo evidence (notifications domain)

### What is already present in-repo

- Base spec and AC set exists.
- Email verification harness scripts exist (for example, `scripts/qa/verify-email-*.sh`).
- Supporting plugins are present:
  - `infrastructure/tutor/plugins/email-preferences`
  - `infrastructure/tutor/plugins/email-suppression`
- Monitoring contract exists for part of this domain:
  - `deploy/k8s/base/monitoring/prometheusrule-email.yaml`

### What is not live / not yet owned by trackers

- No dedicated open/in-progress tracker ticket currently indicates ownership of ACE multi-channel/email notifications implementation.
- Core ACs for channel dispatch, preferences, push, digests, bulk campaign management, engagement analytics, and GDPR deletion/export flows are still effectively unimplemented from AC perspective.
- Several ACs have automated/manual verification scripts, but without an execution lane there is no tracker closure yet.

## 3) Active tracker surface (for this topic)

Open/in-progress tracker entries currently in `.beads/beads.db`:

- In progress:
  - `mereka-lms-5ngf`
  - `mereka-lms-5ngf.2`
  - `mereka-lms-288f`
  - `mereka-lms-3bm2`
  - `mereka-lms-1jsy`
  - `mereka-lms-2s47`
  - `mereka-lms-1kwf`
  - `mereka-lms-3st7`
  - `mereka-lms-bims`
  - `mereka-lms-i8lo`
  - `mereka-lms-mci9`
  - `mereka-lms-1bdm`
- Open:
  - `mereka-lms-1kwf.1`
  - `mereka-lms-aza7`

No active ticket title currently matches `email`, `notification`, `ses`, `smtp`, `push`, `digests`, `preferences`, or `bulk campaign`.

## 4) AC split by domain (tracker-actionable)

Legend
- **status-live**: infrastructure/scripts exist but functional behavior is not fully delivered via owned tracker lane
- **status-blocked**: explicitly marked in testmap as feature-not-yet-implemented

### Track A — SES and base email delivery (`AC-001` to `AC-005`)

- `AC-001`, `AC-002`: domain verification and DNS control checks exist, but no tracker-owned execution evidence.
- `AC-003`, `AC-004`, `AC-005`: transport/tenant-branding behavior still blocked in testmap.

Proposed work stream:
- Child issue `NOTIF-A-SES-FOUNDATION` (AC-001, AC-002, AC-004)
- Child issue `NOTIF-B-SES-TENANT-SENDER` (AC-003, AC-005)

### Track B — ACE multi-channel transport (`AC-006` to `AC-009`)

- `AC-006` to `AC-009` are explicitly feature-blocked.

Proposed work stream:
- Child issue `NOTIF-C-ACE-CHANNELS` (AC-006, AC-007, AC-008, AC-009)

### Track C — In-app notification APIs (`AC-010` to `AC-014`)

- `AC-010` to `AC-014` are feature-blocked.

Proposed work stream:
- Child issue `NOTIF-D-INAPP-API` (AC-010, AC-011, AC-012, AC-013, AC-014)

### Track D — Push notifications (`AC-015` to `AC-019`)

- `AC-015` to `AC-019` are feature-blocked.

Proposed work stream:
- Child issue `NOTIF-E-PUSH` (AC-015, AC-016, AC-017, AC-018, AC-019)

### Track E — Preferences and consent (`AC-020` to `AC-024`)

- `AC-020` to `AC-024` are feature-blocked.

Proposed work stream:
- Child issue `NOTIF-F-PREFERENCES` (AC-020, AC-021, AC-022, AC-023, AC-024)

### Track F — Multilingual + tenant template rendering (`AC-025` to `AC-028`)

- `AC-025` to `AC-028` are feature-blocked.

Proposed work stream:
- Child issue `NOTIF-G-TEMPLATES` (AC-025, AC-026, AC-027, AC-028)

### Track G — Bulk campaign orchestration (`AC-029` to `AC-032`)

- `AC-029` to `AC-032` are feature-blocked.

Proposed work stream:
- Child issue `NOTIF-H-BULK-CAMPAIGNS` (AC-029, AC-030, AC-031, AC-032)

### Track H — Bounce/complaint + suppression + alerting (`AC-033` to `AC-036`)

- `AC-033`, `AC-034`, `AC-035` are feature-blocked.
- `AC-036` has alerting artifacts and is closest to completion; needs lane parity/runtime verification to close.

Proposed work stream:
- Child issue `NOTIF-I-RELIABILITY` (AC-033, AC-034, AC-035, AC-036)

### Track I — Digest engine (`AC-037` to `AC-039`)

- `AC-037` to `AC-039` are feature-blocked.

Proposed work stream:
- Child issue `NOTIF-J-DIGESTS` (AC-037, AC-038, AC-039)

### Track J — Engagement analytics (`AC-040` to `AC-042`)

- `AC-040` to `AC-042` are feature-blocked.

Proposed work stream:
- Child issue `NOTIF-K-ANALYTICS` (AC-040, AC-041, AC-042)

### Track K — GDPR + lifecycle controls (`AC-043` to `AC-045`)

- `AC-043` to `AC-045` are feature-blocked.

Proposed work stream:
- Child issue `NOTIF-L-GDPR` (AC-043, AC-044, AC-045)

## 5) Dependency order for implementation handoff

1. Foundation hardening (Track A)
2. ACE transport (Track B)
3. In-app and push rails (Tracks C + D)
4. Preferences + suppression/compliance (Tracks E + H + K)
5. Templates + bulk + digests + analytics (Tracks F + G + I + J)

## 6) Tracker wiring recommendation

No active notification parent exists. Recommend creating one parent issue and attaching the children above:

- Parent (proposed): `NOTIFICATIONS-PRODUCTION-PARITY-000`
- Children:
  - `NOTIF-A-SES-FOUNDATION`
  - `NOTIF-B-SES-TENANT-SENDER`
  - `NOTIF-C-ACE-CHANNELS`
  - `NOTIF-D-INAPP-API`
  - `NOTIF-E-PUSH`
  - `NOTIF-F-PREFERENCES`
  - `NOTIF-G-TEMPLATES`
  - `NOTIF-H-BULK-CAMPAIGNS`
  - `NOTIF-I-RELIABILITY`
  - `NOTIF-J-DIGESTS`
  - `NOTIF-K-ANALYTICS`
  - `NOTIF-L-GDPR`

Assign execution evidence of AC outcomes to existing open lanes:

- `mereka-lms-3bm2`: CI evidence and pipeline hardening dependencies.
- `mereka-lms-aza7`: operational readiness and rollout confidence for non-prod→prod.
- `mereka-lms-288f`, `mereka-lms-5ngf`, `mereka-lms-5ngf.2`, `mereka-lms-1jsy`, `mereka-lms-3st7`: non-prod parity checks and tenant-route validation where overlap with notification services occurs.

## 7) What must be done before parity claim

- `local`, `rke2-nonprod`, and `production` must have equivalent notification feature enablement and behavior, with only intentional environment deltas documented.
- Every Track child above must contain:
  - AC list
  - implementation artifact link
  - proof commands/output or runbook section references
  - rollout evidence for each lane
- No explicit “staging” canonical parity claim unless staging overlay is reactivated as active target.

## 8) Ready-to-copy status for implementer
- Done/partial: spec + testmap + verification scripts + plugin scaffolding.
- Missing: ownership and execution closure of AC-003..AC-045 (except AC-001 and AC-002 needing final runtime proof).
- Action: create the parent + children and bind each to release-readiness lanes listed above.
