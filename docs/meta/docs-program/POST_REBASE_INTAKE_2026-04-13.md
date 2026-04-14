# Post-Rebase Intake Board — 2026-04-13

_Audience: Docs Lead + maintainers · Owner: Docs Lead · Status: active intake board_

This board starts from current `origin/main` and defines what should be carried
forward from the preserved pre-rebase docs snapshot.

Root-level docs-program authority now lives in
[`authority-registry.v1.yaml`](authority-registry.v1.yaml). This board is an
execution view over that registry, not a peer truth store.
The current registry-derived state is summarized in
[`../../reference/generated/docs-program-authority-summary.md`](../../reference/generated/docs-program-authority-summary.md);
do not restate those counts manually here unless the summary model itself changes.
The merge-back review bundles now also have a machine-readable source of truth:
[`metadata/merge-back-waves.v1.yaml`](metadata/merge-back-waves.v1.yaml) with
the generated reviewer view at
[`../../reference/generated/docs-program-merge-back-waves.md`](../../reference/generated/docs-program-merge-back-waves.md).

It exists to prevent the wrong move:

- do **not** replay hundreds of historical docs commits blindly
- do **not** reopen broad cleanup
- do **not** treat every unique file on the old branch as still worth keeping

The correct move now is selective transplant.

## Current Base

- current branch head: `68376a84c`
- current `origin/main`: `ab3112cb9`
- current divergence: `ahead 114, behind 0`
- preserved pre-rebase snapshot: `docs/isolated-docs-20260413-snapshot`
- current fresh-intake backlog: none pending after the latest `#1723` sync

## Current Verified State

- the branch remains in review-and-hardening mode, not broad cleanup mode
- docs-side policy and hygiene gates still pass on `origin/main...HEAD`
- the branch is fully rebased onto current `origin/main`
- the learner-record docs contradiction is closed:
  - current source includes the build and route contract
  - current docs now describe deeper per-environment proof as a separate lane
- the Tutor rendered-authority cleanup lane is current through `#1718`
- conflicting upstream hook/spec deltas remain explicitly frozen pending
  adjudication; they are not accepted source truth by default
- the next best docs work is now structural compression and quality hardening,
  not another generic truth-sync sweep
- the docs-program root README now routes maintainers to the active intake
  board, review board, milestone ledger, and current `docs/architecture/**`
  front door instead of stale remediation and concept-root pointers
- the broader `docs/meta/README.md` front door now routes contributors into the
  active docs-program intake board instead of the stale remediation tracker
- `PROGRAM_UPDATE_V2_BRIEF.md` is now explicitly bounded as historical
  ADR-overlay context instead of reading like a current execution front door
- `IMPLEMENTATION_ROADMAP.md` is now explicitly bounded as a historical
  spec-coverage planning snapshot instead of reading like the current
  docs-program roadmap
- `AGENT_WORKPACKETS.md` is now explicitly bounded as a historical
  ADR-overlay work-packet snapshot instead of reading like the current
  docs-program execution front door
- `FOUNDATIONS_PROGRAM.md` is now explicitly bounded as a historical
  ADR-overlay target-state plan instead of reading like the current
  docs-program execution front door
- `DOCS_FIRST_CLASS_WEEKLY_EXECUTION_PLAN_20260306.md` is now explicitly
  bounded as a historical weekly execution snapshot instead of reading like a
  current docs-program plan
- `DOCS_GOVERNANCE_SIGNOFF_CHECKLIST_20260307.md` is now explicitly bounded as
  a historical governance closeout snapshot instead of reading like a current
  docs-program closure surface
- the Wave 3 closeout, review handoff, and execution tracker are now
  explicitly bounded as historical packet material instead of reading like the
  current review/control-plane front door
- the Wave 4 charter, reviewer checklist, closeout, execution tracker, and
  review handoff are now explicitly bounded as historical packet material
  instead of reading like the current review/control-plane front door
- the Wave 9 closeout, review handoff, and execution tracker are now
  explicitly bounded as historical packet material instead of reading like the
  current review/control-plane front door
- the Wave 4 review packet is now explicitly bounded as historical review
  material instead of reading like the current review/control-plane front door
- companion review now requires declared consumers and front doors to be real
  maintained links, not YAML-only claims
- the latest clean rebase onto current `origin/main` did not reopen a new
  docs-intake lane; the branch remains in structural compression mode
- current `origin/main` has now reopened one bounded Tutor/branding intake lane
  through `#1723` (`fix(authn): harden theme runtime contract`)
- `ARCHITECTURE_GOVERNANCE_OVERLAY.md` is now explicitly bounded as historical
  ADR-overlay context instead of reading like the current docs-program or
  architecture governance control plane
- `WAVE4_WRAPPER_RETIREMENT_LEDGER.md` is now explicitly bounded as historical
  Wave 4 compatibility-ledger context instead of reading like a current
  docs-program control-plane artifact
- the Wave architecture-root reset tracker, closeout, and review handoff now
  explicitly route readers back to the active intake/review surfaces instead of
  retaining canonical status under the superseded root-reset model
- the Wave branding-root reset tracker, closeout, and review handoff now
  explicitly route readers back to the active intake/review surfaces instead of
  remaining ambiguous current-authority packet material
- the Wave CI/CD-root reset tracker, closeout, and review handoff now
  explicitly route readers back to the active intake/review surfaces instead of
  remaining ambiguous current-authority packet material
- the Wave operations-root reset tracker, closeout, and review handoff now
  explicitly route readers back to the active intake/review surfaces instead of
  remaining ambiguous current-authority packet material
- the Wave runbooks-root reset tracker, closeout, and review handoff now
  explicitly route readers back to the active intake/review surfaces instead of
  remaining ambiguous current-authority packet material
- the Wave migrations-root reset tracker, closeout, and review handoff now
  explicitly route readers back to the active intake/review surfaces instead of
  remaining ambiguous current-authority packet material
- `PROGRAM_UPDATE_V2_BRIEF.md` now has honest historical metadata instead of
  still advertising canonical status while routing readers away from itself
- the Wave ADR reset tracker, closeout, and review handoff now explicitly
  route readers back to the active intake/review surfaces instead of remaining
  standalone historical packet material without current routing
- the live meta front doors now describe the current review-and-hardening phase
  directly instead of the older remediation-era framing:
  - `docs/meta/docs-program/README.md`
  - `docs/meta/README.md`
- the live metadata contract subroot has now been re-verified for the current
  phase, and the model explicitly excludes historical docs-program packet docs
  from first-pass canonical metadata normalization:
  - `docs/meta/docs-program/metadata/METADATA_MODEL.md`
  - `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`
  - `docs/meta/docs-program/metadata/governs-taxonomy.yaml`

## Intake Rule

Carry work forward only if all of these are true:

1. the surface is still absent or materially weaker on current `origin/main`
2. the surface still has a stable owner and real consumer
3. the surface matches review-and-hardening mode rather than reopening cleanup

If one of those fails:

- drop it
- re-audit it
- or fold it into a smaller follow-up tranche

## Docs-To-Code Sync Method

This branch is no longer in generic cleanup mode. The operating method is:

1. identify incoming source truth on current `origin/main`
2. locate the maintained current-owner docs that that truth invalidates
3. remove stale or inaccurate claims from those docs
4. replace them with the new source-backed logic in the owning canon
5. update plans and trackers only after the canon is corrected
6. regenerate machine-facing or review-facing surfaces only after authored canon
   is current

Use this method every time new code, workflow, verifier, or runtime behavior
lands. Do not append “also now” prose on top of contradicted statements. Replace
the wrong logic directly in the current owner doc.

## Statement Replacement Rules

When incoming repo truth changes documentation:

- remove inaccurate statements instead of leaving them beside the corrected rule
- prefer one current explanation in the owning doc over multiple partial notes
- treat plans and trackers as downstream reflections, not primary truth
- treat machine-facing bundles and generated runtime outputs as projections, not
  authored canon
- if a maintained doc cannot be made correct without inventing a new owner,
  record that as an intake gap instead of improvising a thin new front door

## Current Workboard

The live work is now:

1. reduce real structural docs debt without reopening broad cleanup
2. compress duplicated or weakly justified companion/front-door surfaces
3. expand enforcement where drift is still caught by humans instead of gates
4. keep fresh-main truth sync as a bounded intake lane
5. route runtime-proof debt into runtime-proof lanes, not wording churn

## Execution Sequence

For every new intake slice, execute in this order:

1. identify the incoming source truth that changed on current `origin/main`
2. locate the maintained owner docs that now contain stale or inaccurate
   statements
3. replace the wrong statements directly in those owner docs
4. regenerate only the downstream derived surfaces that depend on those docs
5. rerun docs-side gates until the docs-side lane is green
6. only then move into adjacent shared-runtime or cross-repo drift if it still
   remains open

Do not invert this order. Do not start with trackers, generated files, or
cross-repo fallout before the owner docs are correct.

## Merge-Back Plan

This branch should not go back to `main` as one giant intake alteration.

Reintegration should happen as reviewable PR waves cut from current `main`,
with each wave scoped to one coherent docs truth family.

### PR Wave Rules

1. one truth family per PR
2. no mixed authored-canon and unrelated generated/runtime refreshes in the
   same PR unless the generated output is directly caused by that canon change
3. no “planning plus broad content rewrite plus verifier changes” bundles
4. each PR must state:
   - owner docs changed
   - validators run
   - what stayed intentionally out of scope
5. if a wave is mostly historical narration or tracker churn, do not open the
   PR

### Planned PR Waves

1. live control layer and meta front doors
   - scope:
     - intake board
     - review board
     - milestone ledger
     - `docs/meta/README.md`
     - `docs/meta/docs-program/README.md`
     - metadata contract surfaces under `docs/meta/docs-program/metadata/**`
   - goal:
     - make the current control plane legible before asking reviewers to absorb
       historical packet cleanup or owner-doc sync waves
   - exact first bundle:
     - `docs/meta/docs-program/POST_REBASE_INTAKE_2026-04-13.md`
     - `docs/meta/docs-program/REVIEW_HARDENING_BOARD_2026-04-13.md`
     - `docs/meta/docs-program/DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
     - `docs/meta/docs-program/README.md`
     - `docs/meta/README.md`
     - `docs/meta/docs-program/metadata/METADATA_MODEL.md`
     - `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`
     - `docs/meta/docs-program/metadata/governs-taxonomy.yaml`
2. historical packet and reset-wave bounding
   - scope:
     - historical wave packets already normalized on this branch:
       - Wave 3 / Wave 4 / Wave 9 packet docs
       - ADR reset packet
       - architecture / branding / CI/CD / operations / runbooks / migrations
         reset packets
       - overlay / wrapper / weekly-plan / signoff / brief packet surfaces
   - goal:
     - land the stale-authority cleanup as one coherent structural-authority
       wave instead of scattering it across later content PRs
   - split plan:
     - Wave 2A: packet normalization
     - Wave 2B: reset-wave normalization
3. companion-surface compression
   - scope:
     - `companion-surface-review.v1.yaml`
     - `tools/docs/verify/verify_companion_surfaces.py`
     - direct companion classification outcomes such as keep/downgrade
       decisions and honest front-door routing
   - goal:
     - remove weakly justified companion surfaces before broader reintegration
4. front-door and authority normalization
   - scope:
     - maintained architecture/root/readme/guide/reference routing surfaces
     - bounded historical wording fixes where they still leak live routing
   - goal:
     - land the authority model as one reviewable docs-structure wave
5. machine-facing and enforcement layer
   - scope:
     - machine-facing runtime routing
     - docs-policy / maintained-doc hygiene / related verifiers
     - directly caused generated outputs
   - goal:
     - land executable enforcement separately from authored canon rewrites
6. CI and contract truth sync
   - scope:
     - branch-protection / CI contract docs
     - verification catalog / contract-derived docs tied to that truth
   - goal:
     - keep governance review separate from Tutor/operator docs
7. Tutor and branding authority sync
   - scope:
     - Tutor operator/reference/policy/runbook surfaces
     - branding owner docs tied to the rendered-authority and authn theme
       runtime contract
   - goal:
     - review the large Tutor family as one intentional operator-doc wave, not
       as dozens of isolated edits
8. future quality follow-through
   - scope:
     - only the outputs of the current quality/compression phase
   - goal:
     - avoid reopening already-reviewable waves for unrelated late polish

### Current Wave Readiness

1. wave 1 is effectively ready now
   - the active control surfaces, live meta front doors, and metadata contract
     refreshes are already coherent on this branch
2. wave 2 is also close to ready
   - the stale historical packet family is now broad but coherent enough to
     split cleanly
   - treat the split as the default, not as an emergency fallback:
     - Wave 2A: packet normalization
     - Wave 2B: reset-wave normalization
3. later waves should stay blocked on scope discipline, not on a wish to make
   the branch “perfect” before opening review

### Wave 1 Exact Bundle

Wave 1 should be a control-layer and live-meta-front-door PR cut from current
`main`, not a catch-all docs-program cleanup packet.

- include:
  - `docs/meta/docs-program/POST_REBASE_INTAKE_2026-04-13.md`
  - `docs/meta/docs-program/REVIEW_HARDENING_BOARD_2026-04-13.md`
  - `docs/meta/docs-program/DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
  - `docs/meta/docs-program/README.md`
  - `docs/meta/README.md`
  - `docs/meta/docs-program/metadata/METADATA_MODEL.md`
  - `docs/meta/docs-program/metadata/doc-class-schema-map.yaml`
  - `docs/meta/docs-program/metadata/governs-taxonomy.yaml`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`
- intentionally out of scope:
  - historical packet and reset-wave bounding docs
  - companion compression and review-source changes
  - Tutor, branding, CI, or contract-truth sync families
  - runtime-proof or cross-repo follow-through

### Wave 1 Extraction Recipe

Extract Wave 1 from current `main` as one current-file-state bundle only after
its prerequisite baseline-authority shards are already in base. Do not replay
the sequence of planning commits that produced it on this branch.

- extraction method:
  - merge or carry the prerequisite baseline shards first:
    - `wave-0a-concepts-root-authority`
    - `wave-0b-architecture-root-authority`
  - cut a fresh branch from current `origin/main`
  - carry the latest file state of the Wave 1 bundle only
  - if `origin/main` changes any Wave 1 file before PR open, rebase and refresh
    the bundle instead of opening stale review
- PR framing:
  - title: `docs: refresh active docs control plane`
  - reviewer ask:
    - confirm the active docs-program control plane is legible and bounded
    - confirm live meta front doors now route to current authority instead of
      historical remediation-era framing
    - confirm metadata contract surfaces reflect the current phase and current
      review dates
- stop rules:
  - do not cherry-pick historical packet-bounding commits into Wave 1
  - do not include companion compression or Tutor truth-sync changes
  - do not open Wave 1 if the diff turns into generic tracker churn instead of
    control-plane clarity

### Wave 2 Boundary

Wave 2 should stay structural and historical. If reviewer load is high, split
it before opening review rather than bloating Wave 1.

- default scope:
  - historical packet normalization
  - reset-wave normalization
- split recommendation if needed:
  - Wave 2A: packet normalization
  - Wave 2B: reset-wave normalization
- intentionally out of scope:
  - live meta front doors already claimed by Wave 1
  - companion compression
  - fresh source-truth intake families

### Wave 2A Exact Bundle

Wave 2A should carry the historical packet family that was normalized to stop
posing as the current control plane.

- include:
  - `docs/meta/docs-program/PROGRAM_UPDATE_V2_BRIEF.md`
  - `docs/meta/docs-program/IMPLEMENTATION_ROADMAP.md`
  - `docs/meta/docs-program/AGENT_WORKPACKETS.md`
  - `docs/meta/docs-program/FOUNDATIONS_PROGRAM.md`
  - `docs/meta/docs-program/DOCS_FIRST_CLASS_WEEKLY_EXECUTION_PLAN_20260306.md`
  - `docs/meta/docs-program/DOCS_GOVERNANCE_SIGNOFF_CHECKLIST_20260307.md`
  - `docs/meta/docs-program/ARCHITECTURE_GOVERNANCE_OVERLAY.md`
  - `docs/meta/docs-program/WAVE4_WRAPPER_RETIREMENT_LEDGER.md`
  - `docs/meta/docs-program/WAVE3_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE3_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE3_EXECUTION_TRACKER.md`
  - `docs/meta/docs-program/WAVE4_CHARTER.md`
  - `docs/meta/docs-program/WAVE4_REVIEWER_CHECKLIST.md`
  - `docs/meta/docs-program/WAVE4_REVIEW_FRONT_DOOR.md`
  - `docs/meta/docs-program/WAVE4_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE4_EXECUTION_TRACKER.md`
  - `docs/meta/docs-program/WAVE4_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE9_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE9_EXECUTION_TRACKER.md`
  - `docs/meta/docs-program/WAVE9_REVIEW_HANDOFF.md`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`
- intentionally out of scope:
  - reset-wave families
  - `WAVE9_FINDINGS_LEDGER.md` historical evidence
  - live control surfaces already claimed by Wave 1
  - companion compression and fresh source-truth intake

### Wave 2B Exact Bundle

Wave 2B should carry the reset-wave families that were bounded back to the
active control plane.

- include:
  - `docs/meta/docs-program/WAVE_ADR_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_ADR_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_ADR_RESET_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_ARCHITECTURE_ROOT_RESET_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_BRANDING_ROOT_RESET_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_CI_CD_ROOT_RESET_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_OPERATIONS_ROOT_RESET_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_RUNBOOKS_ROOT_RESET_REVIEW_HANDOFF.md`
  - `docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_TRACKER.md`
  - `docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_CLOSEOUT.md`
  - `docs/meta/docs-program/WAVE_MIGRATIONS_ROOT_RESET_REVIEW_HANDOFF.md`
- validators:
  - `bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD`
  - `git diff --check`
- intentionally out of scope:
  - packet-normalization files claimed by Wave 2A
  - live control surfaces already claimed by Wave 1
  - companion compression and fresh source-truth intake

### Merge-Back Stop Rules

- do not wait for “everything” before opening the first PR wave
- do not mix runtime-proof debt with authored-doc structural cleanup
- do not bundle frozen upstream-regression adjudication into a wave that is
  otherwise ready for review
- if a wave exceeds coherent reviewer scope, split it again

## Current Open Lanes

1. companion-surface compression audit
   - review every kept or downgraded companion against:
     - stable owner
     - live front door
     - maintained inbound links
     - non-duplication with current canon
   - expected outputs:
     - keep
     - merge
     - downgrade
     - retire
   - first targets:
     - `docs/guides/admin/CONTENT_LIBRARIES_ENTERPRISE_ONBOARDING.md`
     - `docs/ops/runbooks/MIDDLEWARE_TROUBLESHOOTING.md`
     - `docs/ops/runbooks/MIDDLEWARE_VERIFICATION.md`
     - any kept companion whose only front door is another companion
   - first-slice result:
     - no honest merge or retire decision yet
     - machine-readable review metadata was tightened to use direct maintained
       consumers/front doors
   - second-slice result:
     - false platform-guide front doors for the content-libraries operator
       runbook were removed instead of being kept by wishful routing
     - the generic troubleshooting router now explicitly fronts the assessment
       and middleware companions it already depended on operationally
     - mobile and purchase-gateway owner docs now link back to their
       architecture-root companions directly
     - next slice should move from route realism to duplicate-front-door and
       merge/downgrade pressure on the remaining `KEEP` set
   - third-slice result:
     - duplicate-front-door audit was reduced to a real compression decision
       instead of a fake collision hunt
     - `MIDDLEWARE_VERIFICATION.md` was downgraded from `KEEP` to `DOWNGRADE`
       because its stable entry point is the deployment runbook, not a
       standalone primary front door
     - next slice should pressure the remaining content-library/admin and
       architecture-owner entries rather than reopening the middleware
       verification boundary
   - fourth-slice result:
     - downgraded companions now have an executable bound: exactly one primary
       front door
     - `CONTENT_LIBRARIES_ENTERPRISE_ONBOARDING.md` was tightened to a single
       primary handbook entry point while keeping `PLATFORM_START_HERE.md` only
       as a maintained consumer
     - next slice should keep testing whether any remaining `KEEP` entries are
       actually primary surfaces or only bounded companions hiding behind shared
       routers
   - fifth-slice result:
     - the ledger now separates primary front doors from other maintained
       consumers instead of allowing the same reference to count as both
     - remaining overlap noise was removed from the content-library,
       assessment, and middleware entries
     - next slice should force real classification pressure on the remaining
       `KEEP` set rather than spending more time on route metadata hygiene
   - sixth-slice result:
     - `KEEP` companions are now bounded to exactly one primary front door, not
       just `DOWNGRADE` companions
     - this tranche converted an already-true branch invariant into executable
       enforcement after the `#1716` rebase confirmed no new source-truth docs
       sync was needed
2. quality-and-structure enforcement expansion
   - evaluate new validators for:
     - kept companion docs with zero maintained inbound links
     - duplicated primary front doors inside maintained roots
     - active status/process docs that still encode live-routing language after
       becoming historical
   - stop rule:
     - only add a gate when the rule is stable enough to avoid noisy debt churn
3. fresh mainline intake
   - currently dormant because the branch is rebased to current `origin/main`
     and the latest bounded `#1717` owner-doc sync is already closed
   - when new source truth lands, apply the owner-doc-first intake method
   - stop rule:
     - if no maintained owner doc is invalidated, record “no docs tranche”
4. runtime-proof refresh
   - keep learner-record wording closed unless new runtime proof arrives
   - if deeper per-environment proof is needed, collect runtime evidence and
     update runtime-status/readiness docs from that evidence, not from repo-only
     inference
5. upstream-regression adjudication
   - keep these deltas frozen until a deliberate decision is made:
     - `.githooks/pre-commit`
     - `.githooks/pre-tutor-config`
     - Tutor spec/plan/testmap deltas that revert to raw helper-first or older
       Node/toolchain wording
   - stop rule:
     - do not import these as “latest truth” without source-owner adjudication
6. closed-unless-reopened follow-through
   - machine-facing runtime
   - cross-repo contract runtime
   - maintained-doc hygiene
   - Tutor/MFE rendered-authority sync
   - only reopen one of these if new mainline truth or a failing verifier proves
     drift again
7. merge-back preparation
   - shape current branch work into the concrete PR waves above instead of a
     single giant reintegration
   - prepare wave 1 first unless new source truth forces a resequence

## Recently Closed Lanes

See
[DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md](DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md)
for full milestone history. The current branch has already closed:

- architecture-root and front-door normalization across maintained canon
- docs-side hygiene, portability, and enforcement reactivation
- machine-facing runtime normalization and knowledge-runtime parser recovery
- branch-protection and docs-only CI truth sync
- Tutor/MFE rendered-authority and prepare-path synchronization through `#1718`
- learner-record packaging/route docs contradiction on current dev truth

## Stop Rules

- do not reopen broad cleanup
- do not replay historical snapshot tranches just because they were once useful
- do not treat runtime-proof gaps as docs wording gaps
- do not import upstream hook/spec deltas that regress the current rendered
  authority model without explicit adjudication
- do not keep a companion doc alive just because it once filled a placeholder

## Immediate Next Action

1. shape current branch work into the exact wave-1 bundle above
2. keep historical packet and companion changes out of wave 1
3. prepare Wave 1 as a current-file-state extraction from current `main`, not
   as a replay of historical planning commits
4. treat wave 2 as two review bundles:
   - Wave 2A: packet normalization
   - Wave 2B: reset-wave normalization
5. only then resume deeper companion compression if review-boundary work no
   longer gives a better return
6. update the machine-readable review sources before changing narrative boards
7. only after that, decide which enforcement rule is mature enough to promote
   into docs policy
