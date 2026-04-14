# Docs Tranche Milestone Ledger — 2026-04-13

_Audience: Docs Lead + maintainers · Owner: Docs Lead · Status: active milestone ledger_

This file is the closeout log for the post-rebase review-and-hardening wave.

The active execution board lives in
[POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md).

## Purpose

Keep milestone narration out of the active intake board.

Use this ledger for:

- completed tranche summaries
- review outcomes by milestone
- closeout notes that would otherwise bloat the intake board

## Current Milestones

### Wave-1 Extraction Recipe Lock

Outcomes:

- Wave 1 is now defined as a current-file-state extraction from fresh `main`,
  not as a replay of the planning commits that produced the control surfaces on
  this branch
- the proposed Wave 1 reviewer framing is now explicit:
  - active docs-program control plane only
  - live meta front doors only
  - current metadata contract refresh only
- the control board now names a concrete Wave 1 PR title:
  - `docs: refresh active docs control plane`
- the stop rules are explicit:
  - no historical packet or reset-wave files
  - no companion compression
  - no Tutor / branding / CI truth-sync families

### Exact Wave-2 Split Lock

Outcomes:

- Wave 2 is no longer left as one broad historical-structural bucket
- it is now split into:
  - Wave 2A: packet normalization
  - Wave 2B: reset-wave normalization
- Wave 2A now explicitly carries the historical packet family:
  - brief / roadmap / weekly-signoff / overlay-wrapper surfaces
  - Wave 3 / Wave 4 / Wave 9 packet docs
- Wave 2B now explicitly carries the reset-wave families:
  - ADR
  - architecture
  - branding
  - CI/CD
  - operations
  - runbooks
  - migrations
- the split keeps historical evidence like `WAVE9_FINDINGS_LEDGER.md` out of
  the review bundles unless a later reason reopens it

### Exact Wave-1 Bundle Lock

Outcomes:

- Wave 1 is no longer just a label; it now has an exact review bundle:
  - `docs/meta/docs-program/POST_REBASE_INTAKE_2026-04-13.md`
  - `docs/meta/docs-program/REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `docs/meta/docs-program/DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/meta/docs-program/README.md`
  - `docs/meta/README.md`
  - `docs/meta/docs-program/metadata/METADATA_MODEL.md`
  - `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`
  - `docs/meta/docs-program/metadata/governs-taxonomy.yaml`
- Wave 1 now has explicit out-of-scope boundaries:
  - no historical packet or reset-wave docs
  - no companion compression outcomes
  - no Tutor, branding, CI, or contract truth-sync families
- Wave 2 is now explicitly the next historical-structural bundle and can be
  split into packet normalization versus reset-wave normalization if reviewer
  load requires it

### Merge-Back Wave Shaping Refresh

Outcomes:

- the abstract merge-back plan was converted into concrete current branch wave
  boundaries
- the first ready waves are now explicit:
  - live control layer and meta front doors
  - historical packet and reset-wave bounding
- the branch no longer claims that companion compression is automatically the
  next best move if wave-boundary shaping gives higher review leverage

### Metadata Contract Refresh

Outcomes:

- `docs/meta/docs-program/metadata/METADATA_MODEL.md` was re-verified for the
  current review-and-hardening phase
- the metadata model now states explicitly that retained historical
  docs-program packet docs are out of scope for first-pass canonical metadata
  normalization
- the machine-readable metadata contracts were refreshed to current review
  dates:
  - `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`
  - `docs/meta/docs-program/metadata/governs-taxonomy.yaml`

### Meta Front-Door Phase Refresh

Outcomes:

- `docs/meta/docs-program/README.md` now describes the active
  review-and-hardening / structural-compression phase directly instead of the
  older remediation-era program framing
- `docs/meta/README.md` now mirrors that same live phase language for the
  broader contributor-facing meta root
- both live front doors were re-verified and now carry current verification
  dates

### Historical ADR-Reset Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE_ADR_RESET_TRACKER.md` no longer behaves like a
  current docs-program execution board
- `docs/meta/docs-program/WAVE_ADR_RESET_CLOSEOUT.md` no longer behaves like a
  current docs-program closeout surface
- `docs/meta/docs-program/WAVE_ADR_RESET_REVIEW_HANDOFF.md` no longer behaves
  like a current review handoff surface
- all three surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Brief Metadata Normalization

Outcomes:

- `docs/meta/docs-program/PROGRAM_UPDATE_V2_BRIEF.md` no longer carries a
  stale canonical label while describing itself as historical
- the brief now routes readers to the full active control surface set:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Migrations-Root Reset Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_TRACKER.md` no longer
  behaves like a current docs-program execution board
- `docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_CLOSEOUT.md` no longer
  behaves like a current docs-program closeout surface
- `docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_REVIEW_HANDOFF.md` no
  longer behaves like a current review handoff surface
- all three surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Runbooks-Root Reset Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_TRACKER.md` no longer
  behaves like a current docs-program execution board
- `docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_CLOSEOUT.md` no longer
  behaves like a current docs-program closeout surface
- `docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_REVIEW_HANDOFF.md` no
  longer behaves like a current review handoff surface
- all three surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Operations-Root Reset Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_TRACKER.md` no longer
  behaves like a current docs-program execution board
- `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_CLOSEOUT.md` no longer
  behaves like a current docs-program closeout surface
- `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_REVIEW_HANDOFF.md` no
  longer behaves like a current review handoff surface
- all three surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical CI/CD-Root Reset Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_TRACKER.md` no longer behaves
  like a current docs-program execution board
- `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_CLOSEOUT.md` no longer behaves
  like a current docs-program closeout surface
- `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_REVIEW_HANDOFF.md` no longer
  behaves like a current review handoff surface
- all three surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Branding-Root Reset Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_TRACKER.md` no longer
  behaves like a current docs-program execution board
- `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_CLOSEOUT.md` no longer
  behaves like a current docs-program closeout surface
- `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_REVIEW_HANDOFF.md` no
  longer behaves like a current review handoff surface
- all three surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Architecture-Root Reset Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_TRACKER.md` no longer
  behaves like a current docs-program execution board
- `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_CLOSEOUT.md` no longer
  behaves like a current docs-program closeout surface
- `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_REVIEW_HANDOFF.md` no
  longer behaves like a current review handoff surface
- all three surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Wrapper Retirement Ledger Bounding

Outcomes:

- `docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md` no longer
  behaves like a current docs-program compatibility-control artifact
- the ledger now states the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`
- the wrapper inventory it contains remains available as historical packet
  context instead of implied current control-plane canon

### Historical Governance Overlay Bounding

Outcomes:

- `docs/meta/docs-program/ARCHITECTURE_GOVERNANCE_OVERLAY.md` no longer
  behaves like a current docs-program or architecture-governance control plane
- the overlay now states the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`
- the ADR-overlay material it references remains available as historical
  governance context instead of implied current front-door canon

### Tutor Theme Runtime Contract Sync

Outcomes:

- carried forward the new Tutor/branding source-truth family from current
  `origin/main`:
  - `fix(authn): harden theme runtime contract (#1723)`
- current owner docs now reflect the hardened contract:
  - branding runtime proof no longer assumes one generic Mereka authn payload
  - live branding verifiers now prove host-specific `/theme/*-brand.min.css`,
    host-specific `SITE_NAME`, and host-specific logo-path expectations on
    MFE authn/runtime config surfaces
  - Tutor MFE Dockerfile ownership now explicitly covers both raw object-form
    and IIFE-wrapped `PARAGON_THEME` payload rewrites before tenant-specific
    runtime theme URLs are realized

### Historical Wave 4 Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE4_CHARTER.md` no longer behaves like a current
  packet charter
- `docs/meta/docs-program/WAVE4_REVIEWER_CHECKLIST.md` no longer behaves like
  a current reviewer front door
- `docs/meta/docs-program/WAVE4_CLOSEOUT.md` no longer behaves like a current
  review/control-plane front door
- `docs/meta/docs-program/WAVE4_EXECUTION_TRACKER.md` no longer behaves like a
  current docs-program execution board
- `docs/meta/docs-program/WAVE4_REVIEW_HANDOFF.md` no longer behaves like a
  current review handoff surface
- all five surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Wave 3 Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE3_CLOSEOUT.md` no longer behaves like a current
  review/control-plane front door
- `docs/meta/docs-program/WAVE3_REVIEW_HANDOFF.md` no longer behaves like a
  current review handoff surface
- `docs/meta/docs-program/WAVE3_EXECUTION_TRACKER.md` no longer behaves like a
  current docs-program execution board
- all three surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Wave 9 Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE9_CLOSEOUT.md` no longer behaves like a current
  review/control-plane front door
- `docs/meta/docs-program/WAVE9_REVIEW_HANDOFF.md` no longer behaves like a
  current review handoff surface
- `docs/meta/docs-program/WAVE9_EXECUTION_TRACKER.md` no longer behaves like a
  current docs-program execution board
- all three surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Weekly Plan And Sign-Off Bounding

Outcomes:

- `docs/meta/docs-program/DOCS_FIRST_CLASS_WEEKLY_EXECUTION_PLAN_20260306.md`
  no longer behaves like a current docs-program execution plan
- `docs/meta/docs-program/DOCS_GOVERNANCE_SIGNOFF_CHECKLIST_20260307.md` no
  longer behaves like a current docs-program closure surface
- both surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Overlay Program Bounding

Outcomes:

- `docs/meta/docs-program/AGENT_WORKPACKETS.md` no longer behaves like a
  current docs-program execution front door
- `docs/meta/docs-program/FOUNDATIONS_PROGRAM.md` no longer behaves like a
  current docs-program target-state plan
- both surfaces now state the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`

### Historical Review Packet Bounding

Outcomes:

- `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md` no longer behaves like a
  current review/control-plane entry point
- `docs/meta/docs-program/WAVE4_REVIEW_HANDOFF.md` no longer behaves like a
  current handoff front door
- both surfaces now route readers back to:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`

### Historical Roadmap Bounding

Outcomes:

- `docs/meta/docs-program/IMPLEMENTATION_ROADMAP.md` no longer behaves like a
  current execution roadmap
- the roadmap now states the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`
- the old spec-coverage percentages and sprint framing are now explicitly
  bounded as historical snapshot context

### Historical Brief Bounding

Outcomes:

- `docs/meta/docs-program/PROGRAM_UPDATE_V2_BRIEF.md` no longer behaves like a
  current execution front door
- the brief now states the current routing explicitly:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `docs/architecture/README.md`
- the ADR corpus is now described there as a decision ledger, not the sole
  authoritative starting state for current docs-program work

### Meta Front-Door Normalization

Outcomes:

- `docs/meta/README.md` no longer routes contributors into
  `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
- the maintained meta front door now points at:
  - `docs/meta/docs-program/README.md`
  - `docs/meta/docs-program/POST_REBASE_INTAKE_2026-04-13.md`
- this tranche reduced contributor-routing debt above the docs-program root
  without reopening old remediation-era tracking surfaces

### Tutor Translation Wrapper Scope Sync

Outcomes:

- rebased onto current `origin/main` again:
  - branch content head `5f6d328b3`
  - current `origin/main` `6aa56321f`
  - divergence `ahead 87, behind 0`
- carried forward the next Tutor source-truth commit from `origin/main`:
  - `fix(tutor): narrow translation wrapper scope (#1718)`
- updated owner docs to match the narrowed scope:
  - `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`
  - `docs/policies/operations/TUTOR_CONFIG_SAFETY.md`
- the current Tutor contract is now explicit again:
  - `build-optimizations.sh` no longer scans the Tutor Dockerfile template path
  - the remaining patch-owned scope is rendered Open edX Dockerfile wrapper
    surgery only
  - `verify-tutor-config.sh` now proves the stale Tutor Dockerfile-template
    target scan stays absent

### Docs Program Front-Door Normalization

Outcomes:

- `docs/meta/docs-program/README.md` no longer routes maintainers through the
  stale remediation tracker or the legacy concept-root architecture front door
- current docs-program entry points are now explicit:
  - `POST_REBASE_INTAKE_2026-04-13.md`
  - `REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/architecture/README.md`
- this tranche reduced process-surface routing debt without reopening broad
  cleanup or inventing another docs-program wrapper

### Tutor Residual Target Scope Sync

Outcomes:

- rebased onto current `origin/main` again:
  - branch content head `69d353954`
  - current `origin/main` `34603a081`
  - divergence `ahead 85, behind 0`
- carried forward the next Tutor source-truth commit from `origin/main`:
  - `fix(tutor): drop dead mysql compose rewrite (#1717)`
- updated owner docs to match the narrowed scope:
  - `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`
  - `docs/policies/operations/TUTOR_CONFIG_SAFETY.md`
- the current Tutor contract is now explicit again:
  - `build-optimizations.sh` no longer claims rendered `docker-compose.yml`,
    settings/assets, nginx, or Caddy ownership
  - build-context mirror sync is no longer attributed to
    `build-optimizations.sh`
  - `verify-tutor-config.sh` now proves the dead MySQL auth compatibility
    rewrite and stale target scans stay absent

### Companion Compression Audit Slice 6

Outcomes:

- `KEEP` companions now have the same executable boundedness rule as
  `DOWNGRADE` companions: exactly one primary front door
- this tranche did not require companion content edits because the current
  branch already satisfied the stricter invariant
- the compression lane is now positioned for real keep-vs-downgrade decisions
  instead of more route-shape cleanup

### Companion Compression Audit Slice 5

Outcomes:

- the machine-readable companion review source now forbids a maintained ref
  from appearing in both `front_doors` and `live_consumers`
- content-library, assessment, and middleware entries were normalized so the
  same handbook or runbook page no longer counts as both an entry point and a
  generic consumer
- this tranche improved route hierarchy clarity without changing the current
  `KEEP`/`DOWNGRADE` counts

### Companion Compression Audit Slice 4

Outcomes:

- downgraded companions now have an executable boundedness rule:
  exactly one primary front door
- `docs/guides/admin/CONTENT_LIBRARIES_ENTERPRISE_ONBOARDING.md` now uses
  `docs/guides/INDEX_BY_AUDIENCE.md` as its single primary handbook front door
- `docs/guides/platform/PLATFORM_START_HERE.md` remains a maintained consumer
  of that guide, but no longer counts as a second competing front door
- this tranche tightened the `DOWNGRADE` class without forcing a premature
  merge/retire decision

### Companion Compression Audit Slice 3

Outcomes:

- duplicate-front-door review produced a real classification change instead of
  another abstract audit note
- `docs/ops/runbooks/MIDDLEWARE_VERIFICATION.md` moved from `KEEP` to
  `DOWNGRADE`
- the middleware verification doc now states the correct boundary explicitly:
  it is a maintained deployment-verification companion entered through
  `DEPLOYMENT_RUNBOOK.md`
- the branch now has a smaller `KEEP` set and a cleaner next target for the
  remaining compression wave

### Companion Compression Audit Slice 2

Outcomes:

- companion enforcement now requires declared consumers and front doors to be
  actual maintained links, not review-metadata claims
- `CONTENT_LIBRARIES_V2_RUNBOOK.md` no longer pretends handbook router pages
  are its operator front doors; the maintained front door is now recorded as
  `TROUBLESHOOTING.md`
- `TROUBLESHOOTING.md` now explicitly fronts:
  - `ASSESSMENT_OPERATIONS_RUNBOOK.md`
  - `MIDDLEWARE_TROUBLESHOOTING.md`
- `MOBILE_APPS_RUNBOOK.md` now links back to
  `docs/architecture/mobile-apps-overview.md` as its stable architecture owner
- `PURCHASE_GATEWAY_K8S.md` and `STRIPE_WEBHOOKS_SETUP.md` now link back to
  `docs/architecture/purchase-gateway-overview.md`
- this tranche tightened route realism without forcing a merge/retire decision
  that the current branch still does not justify

### Post-Rebase Quality Phase Shift

Outcomes:

- the branch is rebased onto current `origin/main` again:
  - branch head `173b6611f`
  - current `origin/main` `59d819846`
  - divergence `ahead 72, behind 0`
- the active board now treats structural compression and quality debt reduction
  as the primary next phase
- fresh-main truth sync remains active, but only as a bounded intake lane after
  new source truth lands
- the immediate next execution lane is now companion-surface compression rather
  than another generic Tutor truth-sync pass

### Merge-Back Wave Planning

Outcomes:

- reintegration into `main` is now explicitly planned as reviewable PR waves,
  not one giant intake alteration
- the active board now defines a wave order:
  - control-layer and roadmap hygiene
  - companion-surface compression
  - front-door and authority normalization
  - machine-facing and enforcement layer
  - CI and contract truth sync
  - Tutor authority sync
  - future quality follow-through
- each wave is expected to declare:
  - owner docs changed
  - validators run
  - what remained out of scope

### Companion Compression Audit Slice 1

Outcomes:

- audited the first compression targets from the active board:
  - `CONTENT_LIBRARIES_ENTERPRISE_ONBOARDING.md`
  - `MIDDLEWARE_VERIFICATION.md`
  - `MIDDLEWARE_TROUBLESHOOTING.md`
- no honest merge or retire decision was justified in this slice
- the machine-readable review source was tightened instead:
  - direct maintained consumers and front doors now reflect actual inbound
    routing more closely
  - weaker circular justification was reduced
- one stale authority pointer was corrected during the same tranche:
  - `specs/ecommerce-purchase-gateway_spec.md` now points at
    `docs/architecture/purchase-gateway-overview.md` instead of the legacy
    concept-root overview
- companion enforcement is now stricter:
  - `KEEP` and `DOWNGRADE` companions must have at least one inbound docs-root
    link
  - declared front doors for `KEEP` and `DOWNGRADE` must include a docs-root
    path

### Post-Rebase Roadmap Tightening

Outcomes:

- the active intake board now reflects the actual current branch state instead
  of the earlier intake snapshot:
  - branch head `fbb15213e`
  - current `origin/main` `d75371ab6`
  - divergence `ahead 71, behind 2`
- the intake board now separates:
  - fresh mainline intake
  - runtime-proof refresh
  - upstream-regression adjudication
  - closed-unless-reopened follow-through
- the next concrete intake family is now named explicitly:
  - `fix(tutor): drop dead translation compile rewrites (#1704)`
  - `fix(tutor): remove dead tutor-user cleanup shim (#1703)`
- the oversized narrative closeout block was compressed so the active board is
  an execution surface again instead of a changelog

### Post-Rebase Review Pivot

Outcomes:

- the rebased branch stayed in review-and-hardening mode instead of reopening
  broad cleanup
- the thematic review source of truth now lives in
  [REVIEW_HARDENING_BOARD_2026-04-13.md](REVIEW_HARDENING_BOARD_2026-04-13.md)

### Companion-Surface Classification

Outcomes:

- only companions that still exist and still have live consumers on the rebased
  branch were classified
- the classification source of truth is now
  [companion-surface-review.v1.yaml](companion-surface-review.v1.yaml)

### Owner-Gap Compression

Outcomes:

- unresolved or intentionally collapsed companion decisions now live in
  [owner-gap-ledger.v1.yaml](owner-gap-ledger.v1.yaml)
- missing old companions are no longer implied to exist just because they
  existed on the snapshot branch

### Enforcement Tightening

Outcomes:

- `verify-docs-policy.sh` now validates companion classifications and owner-gap
  ledger structure
- maintained-doc hygiene is executable through
  `tools/docs/verify/verify_maintained_doc_hygiene.py`
- world-class docs gates now include maintained-doc hygiene directly

### Maintained-Doc Front-Door Repair

Outcomes:

- maintained owner docs that still pointed at missing companions were corrected
  directly instead of leaving broken links in current canon
- architecture, proctoring, assessment, and SLO owner surfaces were brought
  into line with the review layer

### Owner-Gap Compression Follow-Through

Outcomes:

- the remaining open owner-gap items were collapsed into current canon instead
  of spawning new docs
- `POST_DEPLOY_GATE.md` now owns deployment-gate exception logging and evidence
  minimums
- `docs/ops/runbooks/migrations/README.md` is now the explicit unified
  migration execution front door, with the reference root routing there

### Maintained-Doc Hygiene Closure

Outcomes:

- the rebased branch now passes
  `python3 tools/docs/verify/verify_maintained_doc_hygiene.py --repo-root .`
- the residual stale-link families were drained in bounded groups instead of a
  broad cleanup sweep:
  - MFE selector and plugin-slot canon
  - operator runbooks and front doors
  - CI runner policy references
  - migration reference surfaces
- absolute local filesystem path leaks were removed from maintained canon
- full docs policy now passes on `origin/main...HEAD` after those hygiene
  repairs

### GitOps Enforcement Pointer Normalization

Outcomes:

- maintained operator and stabilization docs no longer point at the retired
  `.claude/rules/gitops-enforcement.md` path as if it were the canonical owner
- the current execution rule now routes through
  `docs/reference/operations/AGENT_EXECUTION_WORKFLOW.md` in:
  - preview redirect
  - ArgoCD health troubleshooting
  - purchase gateway operations
  - agent operating model

### Architecture Root Front-Door Normalization

Outcomes:

- maintained root/readme/standards surfaces no longer teach
  `docs/concepts/architecture/**` as the primary living architecture root
- the current governance front doors now consistently route readers through
  `docs/architecture/**`, with concept-root material treated as bounded
  detailed-reference context
- this normalization covered:
  - policy root front door
  - reference root front door
  - architecture-reference root front door
  - documentation standards and style guidance
  - docs/specs boundary guidance

### Tenant And Enterprise Front-Door Normalization

Outcomes:

- maintained onboarding, admin, tenant-branding, tenant-provisioning, and
  enterprise-navigation docs no longer send readers to generic
  `multi-tenancy-overview.md` or `enterprise-services-overview.md` as the
  default current front door
- current routing now uses the actual maintained owner split on this rebased
  branch:
  - `docs/architecture/**` for stable architecture front doors
  - `docs/reference/operations/RUNTIME_TRUTH_MATRIX.md` for declared host and
    environment mapping
  - `docs/concepts/architecture/TENANT_OPERATING_SYSTEM.md` and
    `docs/concepts/architecture/TENANT_LIFECYCLE.md` for the retained
    explicitly canonical tenant standards
- onboarding guidance no longer points contributors at the retired
  documentation authority resolver as if it were the active root model

### Root Index And Contributor Front-Door Normalization

Outcomes:

- maintained root indexes, contributor guidance, and evidence/status standards
  no longer route readers through the retired documentation authority resolver
  as the default root-selection surface
- `docs/README.md` now reflects the actual current split:
  - `docs/architecture/**` is the stable architecture front door
  - `docs/concepts/architecture/**` is bounded detailed reference plus the
    retained explicitly canonical standards
- contributing, guides, status, evidence, and tutor-config safety docs now use
  the documentation index and platform authority map as their current routing
  surfaces

### Concept-Root Governance Normalization

Outcomes:

- retained concept-root governance docs no longer declare
  `docs/concepts/architecture/**` the primary architecture front door
- `ARCHITECTURE_CHARTER.md`, `DOCUMENTATION_AUTHORITY_RESOLVER.md`, and the
  concept-root README now describe the correct split:
  - `docs/architecture/**` owns the stable architecture front doors
  - `docs/concepts/architecture/**` keeps retained standards and deep
    reference/overview material where explicitly canonical
- connected governance surfaces were synced to the same model:
  - `docs/stabilization/DOCS_ROOT_AUTHORITY_CONTRACT.md`
  - `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
  - `docs/reference/governance/DEPRECATION_LEDGER.md`

### Machine-Facing Skill Runtime Normalization

Outcomes:

- the skill runtime no longer treats `docs/architecture/**` as forbidden
  canonical input
- skill-runtime authoritative policy and review skills now seed from:
  - `docs/README.md`
  - `docs/architecture/PLATFORM_AUTHORITY_MAP.md`
  - `docs/reference/governance/DEPRECATION_LEDGER.md` where retirement logic is
    the real owner
- generated skill packs and read-first outputs were rebuilt from the updated
  source model, and the runtime verifiers now pass with explicit repo-root
  overrides for sibling repos on this machine

### Residual Process And Status Routing Normalization

Outcomes:

- still-consumed process/history surfaces no longer preserve stale statements
  that declare `docs/concepts/architecture/**` the living architecture root
- the current split is now explicit in:
  - `docs/meta/adr-process/adr-review.md`
  - `docs/status/active/DOCS_WAVE2_CONTROL_PLANE_STATUS_2026-03-08.md`
  - `docs/status/migrations/2026-03-wave-2b-final-closeout.md`
  - `docs/meta/knowledge/WAVE10_CLOSEOUT.md`
- those surfaces now route readers through:
  - `docs/architecture/**` for stable architecture front doors
  - `docs/concepts/architecture/**` for retained standards and deep reference
  - `docs/architecture/PLATFORM_AUTHORITY_MAP.md` as the maintained read-first
    authority map instead of the retired resolver-first model

### Superseded Architecture-Reset Record Normalization

Outcomes:

- docs-program root-collapse and architecture-reset records no longer read like
  live repo law
- the following surfaces are now explicitly historical about a superseded reset
  attempt:
  - `docs/meta/docs-program/root-collapse/README.md`
  - `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_REVIEW_HANDOFF.md`
- those records now state current truth directly:
  - `docs/architecture/**` is the stable architecture front-door root
  - `docs/concepts/architecture/**` is bounded retained standards and deep
    reference context

### Wave 9 And Metadata Model Normalization

Outcomes:

- Wave 9 closeout and review handoff no longer send readers to the retired
  resolver-first path as the default architecture read-first surface
- the metadata model and schema layer now allow the actual current split:
  - `docs/architecture` as a valid stable architecture canonical root
  - `docs/concepts/architecture` only where retained explicitly canonical
    standards still live
- normalized surfaces:
  - `docs/meta/docs-program/WAVE9_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE9_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/metadata/METADATA_MODEL.md`
  - `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`
  - `docs/meta/docs-program/metadata/frontmatter-schema.json`
- docs catalog outputs were regenerated after the metadata/doc updates:
  - `docs/catalog.json`
  - `generated/catalogs/docs-catalog.json`

### Docs/Specs Bundle Read-First Normalization

Outcomes:

- the docs/specs hot-path generator no longer emits a concept-root
  charter-plus-resolver read-first set
- source and generated surfaces now use the maintained cross-root entrypoints:
  - `docs/README.md`
  - `docs/architecture/PLATFORM_AUTHORITY_MAP.md`
  - `docs/guides/standards/DOCS_SPECS_CONTRACT.md`
- normalized surfaces:
  - `tools/specs/build_spec_bundles.py`
  - `docs/_generated/bundles/60-docs-specs-contract.md`

### Branch Protection And Docs-Only CI Truth Sync

Outcomes:

- incoming mainline source-truth changes were carried forward onto this branch
  for:
  - `config/branch-protection-contract.yaml`
  - `scripts/qa/verify-branch-protection.sh`
  - `config/admin-merge-exception-ledger.yaml`
  - `scripts/qa/verify-admin-merge-exceptions.sh`
  - `.github/workflows/ci.yml`
  - `.github/workflows/dependency-review.yml`
  - `.github/workflows/iac-scan.yml`
  - `scripts/qa/verify-manifest-integrity.sh`
  - `verification/catalogs/verification_catalog.json`
- owner docs were then corrected to match the imported source truth:
  - `docs/policies/operations/BRANCH_PROTECTION.md`
  - `docs/stabilization/CI_FALSE_RED_PREVENTION.md`
  - `docs/ops/runbooks/CI_CD_RUNBOOK.md`
  - `docs/status/active/PRODUCTION_READINESS_AUDIT_2026-04-04.md`
- generated catalogs were refreshed after the authored updates:
  - `docs/catalog.json`
  - `generated/catalogs/docs-catalog.json`
  - `verification/catalogs/verification_catalog.json`

### Retired-Root Reset Record Normalization

Outcomes:

- completed reset-wave records for retired operations, branding, and CI/CD
  roots no longer read like live routing law on the rebased branch
- the following docs-program records are now explicitly historical and state
  the current maintained roots directly:
  - `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_REVIEW_HANDOFF.md`
- current truth is now stated directly in those records:
  - `docs/ops/**`, `docs/reference/operations/**`, and
    `docs/policies/operations/**` own operations routing
  - `docs/guides/branding/**` owns branding guidance
  - `docs/ops/ci-cd/**` owns CI/CD operator guidance

### Machine-Facing Knowledge Runtime Separation

Outcomes:

- the current task runtime and the older Wave 8 agent-consumption runtime no
  longer write incompatible bundle sets into the same generated directory
- Wave 8 agent-consumption bundles now live under:
  - `generated/knowledge/agent-task-bundles/`
- stale hyphenated agent-bundle markdown files were removed from:
  - `generated/knowledge/task-bundles/`
- machine-facing knowledge runtime now redirects bounded concept-root
  architecture deep-dives to current owner docs in `affected_truth_surfaces`
  instead of promoting those concept-root files as active authority by default
- validated surfaces and tools:
  - `tools/knowledge/change_runtime.py`
  - `tools/knowledge/skill_runtime.py`
  - `tools/knowledge/build_agent_task_bundles.py`
  - `tools/knowledge/build_agent_readiness_report.py`
  - `tools/knowledge/verify_agent_consumption_runtime.py`
  - `scripts/qa/run-agent-readiness-gates.sh`
  - `docs/meta/knowledge/AGENT_REVIEW_HANDOFF.md`
- the following checks now pass for this slice:
  - `python3 tools/knowledge/build_agent_entrypoints.py --repo-root .`
  - `python3 tools/knowledge/build_agent_entrypoints.py --check --repo-root .`
  - `python3 tools/knowledge/build_agent_task_bundles.py --repo-root . --range origin/main...HEAD --output-dir generated/knowledge/agent-task-bundles`
  - `python3 tools/knowledge/build_agent_task_bundles.py --check --repo-root . --range origin/main...HEAD --output-dir generated/knowledge/agent-task-bundles`
  - `python3 tools/knowledge/build_agent_readiness_report.py --repo-root . --range origin/main...HEAD`
  - `python3 tools/knowledge/build_agent_readiness_report.py --check --repo-root . --range origin/main...HEAD`
  - `python3 tools/knowledge/verify_agent_consumption_runtime.py --repo-root . --range origin/main...HEAD`
  - `python3 tools/knowledge/verify_task_runtime.py --repo-root . --range origin/main...HEAD`

### Knowledge Runtime Parser And Regeneration Closure

Outcomes:

- malformed YAML frontmatter in
  `docs/concepts/architecture/TENANT_OPERATING_SYSTEM.md` no longer blocks
  parser-based knowledge reporting
- the frontmatter summary is now quoted correctly, which restored:
  - `python3 tools/knowledge/report_knowledge_control_plane.py --repo-root .`
  - `bash scripts/qa/run-knowledge-runtime-gates.sh`
- downstream generated surfaces were regenerated and brought back under check:
  - `generated/catalogs/knowledge-catalog.json`
  - `generated/graphs/knowledge-graph.json`
  - `generated/knowledge/change-manifest.json`
  - `generated/knowledge/review-bundle.md`
  - `generated/knowledge/truth-impact-report.json`
  - `specs/catalog.json`
- the docs-side knowledge runtime lane is now green end to end
- the remaining broader runtime blocker after this closure is separate:
  - `run-task-runtime-gates.sh` still continues into
    `run-cross-repo-contract-gates.sh`, which currently reports
    `CROSS_REPO_MANIFEST_DRIFT`

### Planning Reset After Docs-Side Runtime Closure

Outcomes:

- the execution board now states the intended order explicitly:
  - ingest incoming `origin/main` truth
  - replace stale statements in current owner docs
  - regenerate only the derived surfaces affected by those corrections
  - rerun docs-side gates
  - only then move into shared-runtime or cross-repo drift
- the next open lane is now named concretely instead of left as implied drift:
  - `CROSS_REPO_MANIFEST_DRIFT`
- the board also now distinguishes:
  - docs-side sync work
  - cross-repo runtime drift
  - bounded machine-facing follow-through

### Cross-Repo Contract Runtime Refresh

Outcomes:

- the Wave 6 cross-repo contract lane is back under check after refreshing:
  - `generated/contracts/cross-repo-manifest.json`
  - `generated/contracts/deployment-impact-report.json`
  - `generated/contracts/release-obligations.md`
- `bash scripts/qa/run-cross-repo-contract-gates.sh` now returns
  `CROSS_REPO_CONTRACT_GATES_OK`
- current generated contract truth no longer says infra follow-through is not
  needed; it now records `infra_counterpart_required` for the touched branch
  scope
- the active intake board no longer treats `CROSS_REPO_MANIFEST_DRIFT` as the
  next blocker
- the next open lane after this refresh is fresh mainline docs-to-code intake,
  with cross-repo runtime left as bounded follow-through instead of generic docs
  cleanup

### Tutor MFE Authority Sync

Outcomes:

- imported the new `origin/main` Tutor/MFE authority fixes before updating docs:
  - rendered MFE Dockerfile snapshot is now the reviewable authority surface
  - local brand package install is `@edx/brand@file:./brand-mereka`
  - stale production-stage theme-copy surgery was removed from
    `apply-patches.sh`
  - prereq guards now verify rendered snapshot parity and production theme
    payload copy directly
- maintained owner docs were then corrected to match that source truth:
  - onboarding/devcontainer workflows now route through
    `scripts/infra/prepare-tutor-build-context.sh`
  - version/reference/architecture docs now describe the current Node 24 and
    local brand-package contract instead of the old external Indigo package or
    removed build ARGs
  - branding and enterprise-MFE operator docs now describe plugin-hook-rendered
    authority plus bounded patch-only build-context sync, not generic
    post-render Dockerfile surgery
- the next follow-through for this family, if needed at all, is limited to any
  remaining maintained spec/quickref surfaces that still teach the old model

### Tutor MFE Maintained Surface Sync

Outcomes:

- the maintained spec and operator mirror now matches the Tutor/MFE source truth:
  - Tutor configuration specs and plans now use the canonical
    `prepare-tutor-build-context.sh` workflow where operator sequencing matters
  - acceptance criteria and maintained testmaps no longer describe Node 18 as
    the active MFE build contract
  - quick-reference and CI operator docs no longer treat `apply-patches.sh` as
    the primary MFE Dockerfile authority
- the residual architecture/policy surfaces in this family were also corrected:
  - no maintained surface in this tranche now says we still patch the MFE
    Dockerfile back down to Node 18
  - no maintained surface in this tranche still describes removed cookie-domain
    build args as current MFE truth
- this closes the obvious maintained Tutor/MFE truth-sync residue on the rebased
  branch; the next open lane should come from new incoming `origin/main` truth,
  not more reflex churn in this family

## Current Rule

When a tranche closes:

1. update enforcement if the closure created a repeatable invariant
2. update the machine-readable review or owner ledger if classification changed
3. record the milestone here
4. keep the active intake board focused on what is still open now

### Tutor MFE Retry Boundary Sync

Milestones:

- `a9e878a89` — `fix(tutor): carry forward MFE retry boundary`

What changed:

- imported the next `origin/main` Tutor/MFE source truth commit on top of the
  rendered-authority tranche:
  - `apply-patches.sh` now documents and enforces the single remaining rendered
    MFE Dockerfile rewrite boundary around `wrap_mfe_pull_translations_retry`
  - `verify-mfe-build-prereqs.sh` now proves that the rendered MFE Dockerfile
    path is only targeted for that retry exception and that the generated
    Dockerfile carries the retry sentinel consistently
  - `tests/test_mfe_build_snapshot.py` now asserts the tracked snapshot keeps
    only the wrapped `pull_translations` contract, not a raw unwrapped line
- the follow-through owner-doc sync then removed stale wording from maintained
  architecture, operations, playbook, and spec surfaces that still implied
  broader rendered MFE Dockerfile surgery

Why it mattered:

- the previous tranche had already restored the rendered MFE Dockerfile snapshot
  as authority, but it still left room for readers to overestimate what
  `apply-patches.sh` is allowed to mutate
- this tranche closes that gap: plugin hooks own the durable Dockerfile
  contract, the prepare wrapper owns the build-context refresh path, and
  `apply-patches.sh` keeps one explicit retry exception until an upstream or
  hookable alternative exists

### Tutor Custom-App Mirror Sync

Milestones:

- `20ebc7520` — `fix(tutor): mirror rendered custom apps cleanly`

What changed:

- imported the next `origin/main` Tutor/Open edX build-context truth:
  - `build-optimizations.sh` now clears the rendered custom-app destination
    before copying source apps into `tutor_env/env/build/openedx/...`
  - `verify-tutor-config.sh` now proves the rendered custom-app root mirrors the
    source tree instead of checking only a couple of individual app folders
- the maintained owner docs now say the same thing:
  - custom-app verification is about exact mirror semantics, not just presence
  - stale deleted custom apps in `tutor_env/` are now treated as drift, not an
    acceptable leftover state

### Tutor Theme-Asset Mirror Sync

Milestones:

- `ff97d0fc6` — `fix(tutor): mirror rendered theme assets cleanly`

What changed:

- imported the next `origin/main` Tutor/Open edX build-context truth:
  - `build-optimizations.sh` now mirrors LMS and CMS theme image/font trees by
    clearing rendered destinations first and then copying the full source tree
  - `verify-tutor-config.sh` now proves the rendered theme image/font
    directories match source instead of checking only for a few hand-picked
    files
- the maintained owner docs now say the same thing:
  - theme asset sync is a mirror contract, not a “copy these specific logos”
    contract
  - stale rendered theme assets are now drift, not acceptable residue

### Branch-Protection Debt Truth Refresh

Milestones:

- `f4769bec9` — `fix(ci): refresh branch protection debt truth`

What changed:

- imported the next `origin/main` CI governance truth:
  - `config/branch-protection-contract.yaml` now records that `mereka-lms`
    remains aligned while `bbi-infrastructure` still drifts on
    `strict_status_checks` and required contexts
  - `config/structural-debt-register.yaml` reopens `DEBT-014` as an active
    cross-repo governance gap instead of treating it as fully resolved
  - `verification/catalogs/verification_catalog.json` and `BRANCH_PROTECTION.md`
    now match that stricter contract reading
- the maintained status/tracker surfaces now say the same thing:
  - repo-local branch-protection truth is explicit and current
  - cross-repo `--live` failure is still real governance drift, not historical
    residue

### Verification Catalog Refresh

What changed:

- regenerated `verification/catalogs/verification_catalog.json` after the latest
  branch-protection, Tutor/MFE, and status/reference doc updates
- current script reference counts now match branch truth again instead of
  lagging behind the maintained owner docs

### Theme Sync Spec Normalization

What changed:

- normalized maintained spec language that was still teaching the older
  theme-sync model:
  - `branding-system_spec.md`
  - `studio-customization_spec.md`
  - `tutor-configuration-resilience_spec.md`
- those specs now distinguish the canonical Tutor prepare flow from the
  low-level `apply-patches.sh` helper and describe theme asset sync as a
  rendered mirror contract instead of a selective file-copy step

### Tutor Refresh Path Normalization

What changed:

- normalized the remaining maintained onboarding, branding, theme-deployment,
  and Tutor safety surfaces that still told operators to use
  `apply-patches.sh` as the default front door after config changes
- those owner docs now say the current contract directly:
  - `scripts/infra/tutor-config-save.sh` is the preferred config-save wrapper
  - `scripts/infra/prepare-tutor-build-context.sh --target ...` is the manual
    post-render refresh path
  - `infrastructure/tutor/apply-patches.sh` is the low-level helper that the
    prepare path delegates to
- the Tutor pre-commit safety hook and generic pre-commit remediation text now
  use the same governed refresh-path language, so the enforcement layer no
  longer contradicts the maintained docs

### Rendered Tutor Authority Follow-Through

What changed:

- normalized the remaining maintained contributor, branding, and enterprise MFE
  owner docs that were still lagging behind the latest rendered-authority
  cleanup
- those surfaces now reflect the current truth:
  - the tracked rendered MFE Dockerfile snapshot is the reviewable authority
    surface
  - stale MFE production-stage theme-copy surgery has been removed
  - the governed prepare path, not direct `apply-patches.sh`, is the manual
    operator refresh step after raw Tutor regeneration

### Tutor Quickref And Checklist Normalization

What changed:

- normalized the remaining maintained operational quickrefs and checklist
  surfaces that still told operators to rerun `apply-patches.sh` directly after
  config saves
- those surfaces now point to:
  - `scripts/infra/tutor-config-save.sh` as the preferred wrapper
  - `scripts/infra/prepare-tutor-build-context.sh --target all` as the manual
    post-render refresh path
- this covered:
  - `docs/ops/quickref/tutor-commands.md`
  - `docs/ops/runbooks/VISUAL_PARITY_CHECKPOINTS.md`
  - `docs/ops/runbooks/BUILD_CACHE_PIPELINE_RUNBOOK.md`
  - `docs/meta/templates/RELEASE_DEPLOYMENT_TEMPLATE.md`

### Tutor Brand Compile Ownership Sync

What changed:

- imported the next Tutor source-truth commit removing the stale duplicate
  brand compile tail shim from `build-optimizations.sh`
- corrected the maintained owner docs so they no longer claim that
  `build-optimizations.sh` owns:
  - brand SASS compilation
  - Google Fonts stripping
  - conditional webpack behavior
- those are now described as source-owned rendered Dockerfile authority, while
  `build-optimizations.sh` remains the Open edX rendered-file surgery and
  build-context mirror-sync layer
- updated:
  - `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`
  - `docs/ops/runbooks/architecture/ENTERPRISE_MFE_MAINTENANCE.md`

### Tutor Front-Door Operator Sync

What changed:

- removed the remaining direct `apply-patches.sh` operator instructions from
  maintained onboarding, admin, deployment, and troubleshooting front doors
- those surfaces now point at the current governed interfaces instead:
  - `scripts/infra/tutor-config-save.sh` for config-save wrapper flow
  - `scripts/infra/prepare-tutor-build-context.sh --target ...` for manual
    post-render refresh
- updated:
  - `docs/guides/onboarding/AGENT_SETUP_CHECKLIST.md`
  - `docs/guides/admin/MULTI_SITE_GUIDE.md`
  - `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md`
  - `docs/ops/quickref/common-troubleshooting.md`

### Tutor Policy And Playbook Sync

What changed:

- updated the remaining policy/playbook owner docs that still encoded direct
  `apply-patches.sh` reruns as the operator protocol
- those surfaces now teach:
  - `scripts/infra/tutor-config-save.sh` as the safe config-save wrapper
  - `scripts/infra/prepare-tutor-build-context.sh --target ...` as the manual
    post-render refresh path
- updated:
  - `docs/policies/operations/MERGE_FIRST_DEPLOYMENT_PROTOCOL.md`
  - `docs/ops/playbooks/DJANGO_SETTINGS_CHANGE.md`

### Tutor MCT Reference Sync

What changed:

- corrected the maintained MCT/program setup references that still used raw
  `apply-patches.sh` in Discovery/Credentials service-enable workflows
- those flows now use manual `tutor config save` followed by the governed
  prepare path instead of direct helper invocation
- updated:
  - `docs/reference/migrations/mct/PROGRAMS_SETUP_PLAN.md`
  - `docs/reference/migrations/mct/OPENEDX_PROGRAMS_SETUP.md`
  - `docs/reference/migrations/mct/PROGRAMS_QUICK_REFERENCE.md`

### Tutor Policy Reference Residue Sync

What changed:

- corrected the remaining policy/reference owner docs that still showed direct
  `apply-patches.sh` execution in runtime CSS verification or plugin-enable
  recovery sequences
- those flows now point at the governed prepare path instead of the low-level
  helper
- updated:
  - `docs/policies/architecture/WCAG_CONTRAST_POLICY_V2.md`
  - `docs/reference/architecture/ASPECTS_DEPLOYMENT_READINESS.md`

### Tutor Runbook Front-Door Sync

What changed:

- corrected the remaining current runbooks that still used raw
  `apply-patches.sh` execution in Tutor upgrade or Open edX rebuild flows
- those runbooks now point at:
  - `scripts/infra/tutor-config-save.sh` for full config regeneration
  - `scripts/infra/prepare-tutor-build-context.sh --target openedx` for manual
    Open edX build-context refresh before rebuild
- updated:
  - `docs/ops/runbooks/TUTOR_PLUGIN_MIGRATION_RUNBOOK.md`
  - `docs/ops/runbooks/architecture/MFE_OAUTH_FIX_DEPLOYMENT.md`

### Tutor Domain And Tenant Handoff Sync

What changed:

- corrected the remaining current domain and tenant handoff docs that still
  described hostname-routing or local rebuild recovery through direct
  `apply-patches.sh` execution
- those surfaces now point at the governed prepare path for local/bootstrap
  refresh and the real Caddy patch source file for hostname review
- updated:
  - `docs/ops/runbooks/DOMAIN_MANAGEMENT.md`
  - `docs/guides/branding/TENANT_CONFIG_HANDOFF.md`

### Tutor CI Reference Sync

What changed:

- corrected the maintained Tutor CI reference that still named superseded
  workflow files and described an outdated plugin-test shape
- the owner doc now matches current workflow truth:
  - `.github/workflows/ci.yml` owns the `tutor-config-tests` lane
  - `.github/workflows/tutor-plugin-test.yml` owns the plugin/render-contract
    preflight lane
  - operator guidance still uses `scripts/infra/tutor-config-save.sh` and
    `scripts/infra/prepare-tutor-build-context.sh --target ...`
  - CI implementation truth still includes direct
    `infrastructure/tutor/apply-patches.sh` after a clean render baseline
- updated:
  - `docs/reference/operations/TUTOR_CONFIG_CI.md`

### Tenant Onboarding Refresh-Path Sync

What changed:

- corrected the current tenant-onboarding runbook where repair steps still told
  operators to rerun `apply-patches.sh` directly
- preserved `apply-patches.sh` as the source-owned host/CSRF patch location,
  but routed refresh and recovery through the governed prepare path instead
- updated:
  - `docs/ops/runbooks/TENANT_ONBOARDING_PLAYBOOK.md`

### Tutor Quickref And Branding Contract Sync

What changed:

- corrected the remaining quickref and branding-contract operator sequences that
  still told humans to run `apply-patches.sh` directly after Tutor config
  changes
- those surfaces now point at
  `scripts/infra/prepare-tutor-build-context.sh --target all` for post-render
  refresh before restart
- updated:
  - `docs/ops/quickref/tutor-commands.md`
  - `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`

### Tutor Targeted Runbook Sync

What changed:

- corrected the remaining current runbooks that still used raw
  `apply-patches.sh` in operator recovery flows
- those runbooks now use precise governed refresh targets:
  - `scripts/infra/prepare-tutor-build-context.sh --target openedx` for
    Open edX settings and LMS rebuild paths
  - `scripts/infra/prepare-tutor-build-context.sh --target mfe` for MFE/footer
    render recovery paths
- updated:
  - `docs/ops/runbooks/PROCTORING_RUNBOOK.md`
  - `docs/ops/runbooks/site-down.md`
  - `docs/ops/runbooks/architecture/LEGACY_FOOTER_REMOVAL.md`
  - `docs/ops/runbooks/architecture/MFE_FOOTER_SLOT_MIGRATION.md`

### Security Supply-Chain Runbook Sync

What changed:

- corrected the remaining current security runbook example that still used raw
  `apply-patches.sh` as the Tutor dependency-block follow-through step
- that runbook now points at
  `scripts/infra/prepare-tutor-build-context.sh --target openedx` for the
  rendered Open edX refresh path
- updated:
  - `docs/ops/runbooks/SECURITY_INCIDENT_SUPPLY_CHAIN.md`

### Tutor Build-Optimizations Truth Sync

What changed:

- carried forward the newest Tutor source truth from `origin/main` for:
  - `infrastructure/tutor/patches/build-optimizations.sh`
  - `scripts/infra/verify-tutor-config.sh`
- that source truth removes stale scrubber logic from the owner patch script:
  - legacy translation preflight scrubbers
  - local requirements reinstall scrubber
  - legacy base requirements pin scrubbers
  - late broad theme-copy shim
  - duplicate production-stage custom-app reinjection scrubbers
- the verifier now enforces those absences explicitly and also checks:
  - exactly one rendered `DEFAULT_SITE_THEME = "mereka"` assignment
  - full rendered theme/custom-app mirror correctness
- updated owner docs:
  - `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`
  - `docs/policies/operations/TUTOR_CONFIG_SAFETY.md`

### Tutor I18n And Pip Bootstrap Cleanup Sync

What changed:

- carried forward the next Tutor source-truth commit from `origin/main` for:
  - `infrastructure/tutor/patches/build-optimizations.sh`
  - `scripts/infra/verify-tutor-config.sh`
- that source truth removes the remaining stale:
  - openedx-i18n archive rewrite
  - openedx-i18n version rewrites
  - ancient pip bootstrap rewrite
- the verifier now enforces their absence explicitly
- updated owner docs:
  - `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`
  - `docs/policies/operations/TUTOR_CONFIG_SAFETY.md`

### CI Governance Status Sync

What changed:

- aligned the remaining CI governance follow-through from `origin/main` on this
  branch:
  - `docs/status/active/PRODUCTION_READINESS_AUDIT_2026-04-04.md` no longer
    claims unresolved cross-repo branch-protection drift
  - `verification/catalogs/verification_catalog.json` is refreshed to the
    current reference-count truth

### Tutor Configuration Test-Planning Sync

What changed:

- corrected the maintained Tutor configuration planning/verifier layer that was
  still mixing old Node 18 language with current Node 24 build truth
- updated:
  - `specs/plans/tutor-configuration_testplan.md`
  - `scripts/qa/verify-mfe-build-contract.sh`
  - `scripts/qa/verify-mfe-build-prereqs.sh`
  - `specs/_generated/testmaps/tutor-configuration_spec.testmap.yml`
  - `docs/reference/architecture/PLUGIN_MIGRATION_SURVEY.md`
- the current contract is now explicit again:
  - AC-006 is the Node 24 rendered MFE build contract, not a generic Node 18+
    or "supported image" check
  - local operator examples use `tutor-config-save.sh` and
    `prepare-tutor-build-context.sh`, not raw helper-first refresh steps
  - the generated Tutor configuration testmap now matches the current source
    AC-006 description
  - the plugin migration survey no longer describes the Node toolchain row as
    live script-only Node 18 debt

### Readiness Rollout-Step Sync

What changed:

- corrected the remaining live readiness surfaces that still told operators to
  execute `apply-patches.sh` directly as the rollout step
- updated:
  - `docs/status/readiness/PROCTORING_VENDOR_READINESS.md`
  - `docs/status/readiness/TENANT_BRANDING_READINESS_RAG.md`
- the current contract is now explicit:
  - proctoring rollout uses the governed Open edX refresh path
    `scripts/infra/prepare-tutor-build-context.sh --target openedx`
  - tenant-branding rollout uses `scripts/infra/tutor-config-save.sh` for the
    config mutation and only treats `prepare-tutor-build-context.sh --target all`
    as the manual post-render refresh step

### Learner-Record Status Sync

What changed:

- corrected the live status/readiness surfaces that still carried the stale
  "learner-record missing / Node 18 build chain broken" story after the source
  contract and later proof had already moved on
- updated:
  - `docs/status/active/BROWSER_PROOF_MATRIX_2026-04-09.md`
  - `docs/status/active/RUNTIME_AUTHORITY_MATRIX_2026-04-09.md`
  - `docs/status/readiness/CREDENTIALS_READINESS.md`
- the current line is now consistent:
  - learner-record is present in the tracked MFE build contract
  - learner-record route exists in the MFE Caddyfile contract
  - current dev proof reaches L1 authenticated-route confirmation
  - deeper environment/runtime proof is still a separate follow-through lane

### Tutor Raw-Render Cleanup Sync

What changed:

- carried forward the next Tutor source-truth commit from `origin/main`:
  - `fix(tutor): drop dead raw-render compatibility rewrites (#1702)`
- updated owner docs to reflect that the dead rewrite set is even smaller now:
  - `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`
  - `docs/policies/operations/TUTOR_CONFIG_SAFETY.md`
- the current line is now explicit:
  - `build-optimizations.sh` no longer carries dead compilejsi18n source rewrites
  - obsolete edx-platform cherry-pick scrubbers are gone
  - escaped Google Fonts rewrites are gone
  - raw pyenv clone compatibility rewrites are gone
  - `verify-tutor-config.sh` enforces the absence of all of the above
