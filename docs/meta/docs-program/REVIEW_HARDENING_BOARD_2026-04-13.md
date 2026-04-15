# Docs Review And Hardening Board — 2026-04-13

_Audience: Docs Lead + maintainers · Owner: Docs Lead · Status: closed review board (residual extraction merged 2026-04-15)_

> **Program status (2026-04-15):** the residual extraction program tracked by
> this board is **closed**. The 11 residual extraction PRs are merged on
> `origin/main` (`#1736`, `#1738`, `#1741`, `#1742`, `#1745`, `#1748`, `#1750`,
> `#1752`, `#1754`, `#1755`, `#1759`), plus two post-closeout micro-lanes
> `#1763` and `#1760` (2026-04-15). The residual execution ledger lives only
> on the frozen control branch `docs/rebased-intake-20260413` with final
> closeout commit `ee151c5e9`. Do not reopen this board to plan new waves.
> Any new docs work must start from a fresh branch off current `origin/main`,
> not from `docs/rebased-intake-20260413`. Companion-surface compression
> decisions captured in
> [`companion-surface-review.v1.yaml`](companion-surface-review.v1.yaml) are
> sealed at `v1` for this tranche and should not be re-scored without a fresh
> authority decision.

This board records the post-rebase review phase.

It does not reopen broad cleanup. It reviews the carried-forward docs wave by
theme and keeps compression and enforcement ahead of doc creation.
The current docs-program authority counts and retained-stub set live in
[`../../reference/generated/docs-program-authority-summary.md`](../../reference/generated/docs-program-authority-summary.md),
not in repeated board prose.

The active execution board lives in
[POST_REBASE_INTAKE_2026-04-13.md](POST_REBASE_INTAKE_2026-04-13.md).
The merge-back wave bundle definitions now live in
[`metadata/merge-back-waves.v1.yaml`](metadata/merge-back-waves.v1.yaml) and
the generated reviewer summary
[`../../reference/generated/docs-program-merge-back-waves.md`](../../reference/generated/docs-program-merge-back-waves.md).
The extracted branch receipts now live in
[`metadata/merge-back-wave-execution.v1.yaml`](metadata/merge-back-wave-execution.v1.yaml)
with the generated execution summary
[`../../reference/generated/docs-program-merge-back-execution.md`](../../reference/generated/docs-program-merge-back-execution.md).

## Bucket 1: Retired-Root Normalization

### What changed

- active maintained docs on the rebased branch no longer need retired
  `docs/runbooks/**`, `docs/onboarding/**`, or `docs/operations/**` paths to
  explain the carried-forward content-libraries, assessment, enterprise,
  gateway, video, mobile, middleware, and CI lanes
- concept-root authority is bounded enough that current canon can keep using
  `docs/architecture/**` as the stable owner root

### What is now true

- the rebased branch starts from current-root canon rather than cleanup-era
  tombstone routing
- unresolved missing surfaces are now owner-gap decisions, not fake legacy path
  references

### What might be over-created or redundant

- some companions created on the old branch were intentionally not replayed on
  the rebased branch because they had no durable owner or live consumer

### What still lacks enforcement

- unresolved current-root owner decisions must stay in a machine-readable
  ledger rather than drifting back into tracker prose

### What should be collapsed or deleted

- no delete action from this bucket right now

## Bucket 2: Companion-Surface Review

### What changed

- companion docs that still exist on the rebased branch are now explicitly
  classified as `KEEP` or `DOWNGRADE`
- missing old companions were not recreated by default; they were converted
  into post-rebase owner-gap decisions instead
- declared companion consumers and front doors now have to be real maintained
  links in content, not just ledger claims
- false platform-guide front doors were removed where the real maintained entry
  point was the generic troubleshooting router
- `MIDDLEWARE_VERIFICATION.md` is no longer treated as a primary `KEEP`
  surface; it now sits in the maintained `DOWNGRADE` class as a bounded
  deployment-verification companion
- downgraded companions are now explicitly bounded to one primary front door
- the ledger now forbids the same maintained ref from appearing as both a
  primary front door and a generic consumer
- kept companions are now bounded to one primary front door as well

### What is now true

- the branch has fewer fake “kept” surfaces
- companions that remain now have explicit live consumers and front doors
- the middleware lane now distinguishes more honestly between:
  - deployment verification companion
  - incident-routing troubleshooting companion
- the downgraded class is now tighter and more legible:
  - one primary entry point
  - other maintained links can remain consumers without pretending to be equal
    front doors
- the machine-readable review source is less ambiguous about which links are
  actual entry points versus mere maintained consumers
- the kept class is now equally legible:
  - one primary entry point
  - other maintained links can remain consumers without pretending to be
    co-equal front doors

### What might be over-created or redundant

- `docs/guides/admin/CONTENT_LIBRARIES_ENTERPRISE_ONBOARDING.md` remains useful
  but bounded
- no deferred proctoring companion is treated as active canon on this rebased
  branch

### What still lacks enforcement

- companion review must continue to require real inbound maintained links
- kept or downgraded companions should not survive on spec-only references or
  circular companion justification
- the next useful compression check is duplicate maintained front doors, not
  more fake-route cleanup

### What should be collapsed or deleted

- do not create new companion docs by default
- if a future companion loses its front door, either merge it or retire it

## Bucket 3: Machine-Facing Runtime Hardening

### What changed

- cross-repo read-first/runtime outputs were made portable again on the rebased
  branch
- machine-facing surfaces were refreshed only after current owner docs were
  carried forward
- the Wave 7 task runtime and Wave 8 agent-consumption runtime no longer share
  one bundle directory, so their generated outputs can be verified
  independently without false bundle-set conflicts

### What is now true

- generators are less likely to promote legacy deep-dives or dead local paths
  as current authority
- current task bundles now keep bounded concept-root architecture docs out of
  `read_first` and `affected_truth_surfaces` when stable current-owner docs
  already exist

### What might be over-created or redundant

- generated outputs remain numerous, but that is runtime surface area rather
  than authored doc sprawl

### What still lacks enforcement

- any future machine-facing authority drift still needs targeted verification
  when new generator paths land
- parser-sensitive frontmatter in retained concept-root standards is now back
  under enforcement because the malformed tenant-operating-system summary was
  fixed and the full knowledge runtime regenerated successfully

### What should be collapsed or deleted

- no authored-doc deletion in this bucket

## Bucket 4: Link Integrity And Portability

### What changed

- repo-wide maintained-doc hygiene is now executable on the rebased branch
- broken maintained local links and leaked absolute local filesystem paths are
  now explicit gate failures

### What is now true

- maintained docs can be reviewed for link and path hygiene without manual
  scanning
- the rebased branch currently sits at zero known maintained-doc broken local
  links and zero absolute path leaks

### What might be over-created or redundant

- none in this bucket; the work is enforcement, not expansion

### What still lacks enforcement

- orphan handling is still a separate policy decision and should not be widened
  blindly

### What should be collapsed or deleted

- no delete action from this bucket

## Bucket 5: Docs-To-Code Truth Sync

### What changed

- the rebased branch now carries forward only current-owner canon that still
  matters on top of fresh `main`
- stale statements in carried-forward owner docs were replaced directly instead
  of piling corrections on top of contradicted logic
- the latest Tutor intake slices corrected owner docs after `#1717` and
  `#1718` narrowed `build-optimizations.sh` to residual rendered Open edX
  Dockerfile wrapper surgery only

### What is now true

- the docs workflow on this branch is selective transplant plus statement
  replacement, not replaying old cleanup history
- maintained operator docs no longer route GitOps enforcement through the old
  `.claude` rules path when the current execution canon already owns that rule
- maintained root/readme/standards docs now route architecture authority
  through `docs/architecture/**`, not through the legacy concept-root model
- maintained onboarding/admin/tenant-enterprise fronts now route through the
  current architecture split instead of treating generic concept-root
  overviews as the default front door
- maintained root indexes, contributor guides, and evidence/status standards
  now route readers through the documentation index and architecture root
  instead of the retired authority-resolver front door
- retained concept-root governance docs now describe themselves as bounded
  detailed-reference context behind `docs/architecture/**`, not as the default
  system root
- machine-facing skill runtime packs now use the same front-door model and no
  longer reject `docs/architecture/**` as forbidden canonical input
- residual ADR review, status closeout, migration closeout, and knowledge
  closeout surfaces no longer preserve stale “living architecture lives in
  docs/concepts/architecture/**” wording where those surfaces still influence
  human review or read-first routing
- superseded architecture-reset tracker, closeout, and review-handoff docs are
  now explicitly historical instead of silently contradicting the restored
  architecture-root model
- Wave 9 process docs and the metadata schema layer now reflect the same root
  split instead of leaving resolver-first or concept-root-only routing in
  still-consumed guidance and canonical-root definitions
- the generated docs/specs bridge bundle now uses the maintained docs index and
  platform authority map, so machine-facing cross-root intake no longer
  reintroduces the resolver-era path
- current mainline CI/branch-protection truth was imported onto the branch
  first, then the owner docs were corrected to match it instead of leaving this
  lane as tracker-only intake
- current Tutor owner docs no longer claim that `build-optimizations.sh` still
  owns rendered `docker-compose.yml`, settings/assets, nginx/Caddy rewrites, or
  build-context mirror sync; those stale ownership claims are closed through
  `#1718`
- current branding owner docs now describe the hardened `#1723` authn theme
  runtime contract:
  - tenant-specific `/theme/*-brand.min.css` paths per host
  - tenant-specific `SITE_NAME` proof on `/api/mfe_config/v1`
  - tenant-specific logo-path proof on authn/runtime config surfaces
- the docs-program root README now routes maintainers through the active intake
  board and `docs/architecture/**` instead of stale remediation and
  concept-root fronts
- the higher-level `docs/meta/README.md` front door now routes contributors to
  the active docs-program intake surface instead of the stale remediation
  tracker
- `PROGRAM_UPDATE_V2_BRIEF.md` now declares itself historical and routes
  readers back to the active intake/review surfaces plus `docs/architecture/**`
  instead of treating the ADR corpus as the single current starting state
- `IMPLEMENTATION_ROADMAP.md` now declares itself historical and routes readers
  back to the active intake/review surfaces plus `docs/architecture/**`
  instead of behaving like the current docs-program roadmap
- `AGENT_WORKPACKETS.md` now declares itself historical and routes readers
  back to the active intake/review surfaces plus `docs/architecture/**`
  instead of behaving like the current docs-program execution board
- `FOUNDATIONS_PROGRAM.md` now declares itself historical and routes readers
  back to the active intake/review surfaces plus `docs/architecture/**`
  instead of behaving like the current docs-program target-state plan
- `DOCS_FIRST_CLASS_WEEKLY_EXECUTION_PLAN_20260306.md` now declares itself
  historical and routes readers back to the active intake/review surfaces plus
  `docs/architecture/**` instead of behaving like the current docs-program
  execution plan
- the Wave 3 closeout, review handoff, and execution tracker now declare
  themselves historical and route readers back to the active intake/review
  surfaces instead of behaving like the current review/control-plane packet
- the Wave 4 charter, reviewer checklist, closeout, execution tracker, and
  review handoff now declare themselves historical and route readers back to
  the active intake/review surfaces instead of behaving like the current
  review/control-plane packet
- the Wave 9 closeout, review handoff, and execution tracker now declare
  themselves historical and route readers back to the active intake/review
  surfaces instead of behaving like the current review/control-plane packet
- `DOCS_GOVERNANCE_SIGNOFF_CHECKLIST_20260307.md` now declares itself
  historical and routes readers back to the active intake/review surfaces plus
  `docs/architecture/**` instead of behaving like the current docs-program
  closure checklist
- the Wave 4 review packet now declares itself historical and routes readers
  back to the active intake/review surfaces instead of behaving like the
  current review/control-plane entry point
- `ARCHITECTURE_GOVERNANCE_OVERLAY.md` now declares itself historical and
  routes readers back to the active intake/review surfaces plus
  `docs/architecture/**` instead of behaving like the current docs-program or
  architecture governance control plane
- `WAVE4_WRAPPER_RETIREMENT_LEDGER.md` now declares itself historical and
  routes readers back to the active intake/review surfaces plus
  `docs/architecture/**` instead of behaving like a current docs-program
  compatibility-control artifact
- the architecture-root reset tracker, closeout, and review handoff now
  declare themselves historical packet material and route readers back to the
  active intake/review surfaces plus `docs/architecture/**` instead of
  retaining canonical status under the superseded root-reset model
- the branding-root reset tracker, closeout, and review handoff now declare
  themselves historical packet material and route readers back to the active
  intake/review surfaces plus `docs/architecture/**` instead of remaining
  ambiguous current-authority packet material
- the CI/CD-root reset tracker, closeout, and review handoff now declare
  themselves historical packet material and route readers back to the active
  intake/review surfaces plus `docs/architecture/**` instead of remaining
  ambiguous current-authority packet material
- the operations-root reset tracker, closeout, and review handoff now declare
  themselves historical packet material and route readers back to the active
  intake/review surfaces plus `docs/architecture/**` instead of remaining
  ambiguous current-authority packet material
- the runbooks-root reset tracker, closeout, and review handoff now declare
  themselves historical packet material and route readers back to the active
  intake/review surfaces plus `docs/architecture/**` instead of remaining
  ambiguous current-authority packet material
- the migrations-root reset tracker, closeout, and review handoff now declare
  themselves historical packet material and route readers back to the active
  intake/review surfaces plus `docs/architecture/**` instead of remaining
  ambiguous current-authority packet material
- `PROGRAM_UPDATE_V2_BRIEF.md` now declares itself historical at the metadata
  layer as well as in body text, so it no longer carries a self-contradicting
  canonical label
- the ADR-reset tracker, closeout, and review handoff now declare themselves
  historical packet material and route readers back to the active
  intake/review surfaces plus `docs/architecture/**` instead of standing
  alone as stale review/control packets
- the live meta front doors now describe the active review-and-hardening phase
  directly instead of carrying older remediation-program framing
- the metadata model, class map, and governs taxonomy were re-verified for the
  current phase, and the model now states explicitly that historical
  docs-program packet records are out of scope for first-pass canonical
  metadata normalization
- retained operations-root, branding-root, and CI/CD-root reset-wave records
  no longer present their completed reset conditions as current routing law;
  they now state the current maintained roots directly and mark themselves as
  historical

### What might be over-created or redundant

- any surface that exists only to satisfy an old plan placeholder remains under
  owner-gap review instead of being kept by inertia

### What still lacks enforcement

- docs-to-code truth sync still depends on deliberate intake review whenever new
  mainline truth lands
- residual history/process docs that are still read in practice need the same
  statement-replacement discipline as primary owner docs when they encode live
  routing logic

### What should be collapsed or deleted

- no immediate collapse beyond the owner-gap decisions already recorded

## Machine-Readable Review Sources

- companion classifications:
  [companion-surface-review.v1.yaml](companion-surface-review.v1.yaml)
- unresolved or collapsed owner decisions:
  [owner-gap-ledger.v1.yaml](owner-gap-ledger.v1.yaml)

## Immediate Open Work

1. keep maintained-doc hygiene at zero known broken links and zero absolute path
   leaks
2. keep unresolved owner debt in the ledger, not in tracker prose
3. keep companion creation closed by default
   - only reopen it when stable owner, live consumer, maintained inbound path,
     and non-duplication are all proven on the rebased branch
4. the current next active lane is companion-surface compression
   - re-audit every `KEEP` and `DOWNGRADE` decision in
     `companion-surface-review.v1.yaml`
   - convert weak keep decisions into merge, downgrade, or retire outcomes
   - update the machine-readable review source before broadening narrative docs
   - first audit slice result:
     - no honest merge/retire among the initial content-library and middleware
       targets
     - review metadata was tightened to use direct maintained consumers/front
       doors instead of weaker circular justification
   - second audit slice result:
     - route realism is now enforced
     - content-library operator routing no longer claims handbook front doors
       that do not exist
     - assessment and middleware companions now have explicit maintained
       generic-router entry points
     - mobile and purchase-gateway companions now have direct runbook-to-
       architecture routing
   - third audit slice result:
     - `MIDDLEWARE_VERIFICATION.md` was downgraded from `KEEP` to `DOWNGRADE`
     - duplicate-front-door review is now expected to force classification
       changes only when a surface is clearly bounded behind another current
       owner, not merely because routers are shared
   - fourth audit slice result:
     - `DOWNGRADE` now means exactly one primary front door
     - `CONTENT_LIBRARIES_ENTERPRISE_ONBOARDING.md` was tightened to that
       bound without losing its maintained handbook consumers
   - fifth audit slice result:
     - overlap between `front_doors` and `live_consumers` is now invalid
     - the review source now encodes route hierarchy more honestly
   - sixth audit slice result:
     - `KEEP` now means exactly one primary front door
     - the remaining compression pressure should now focus on classification
       decisions, not route-shape ambiguity
5. expand enforcement only where the rule is now stable
   - strongest candidates:
     - kept companion docs with zero maintained inbound links
     - duplicate front-door surfaces inside maintained roots
     - historical/process docs that still encode live-routing language
6. keep fresh-main intake bounded
   - the branch is currently rebased onto `origin/main`
   - when new source truth lands, only open a docs tranche if a maintained
     owner doc is actually invalidated
7. keep runtime-proof work separate from repo-truth sync
   - learner-record wording is closed on repo truth
   - deeper environment proof must come from runtime evidence, not from another
     docs-only restatement pass
8. keep conflicting upstream regressions frozen until adjudicated
   - `.githooks/pre-commit`
   - `.githooks/pre-tutor-config`
   - Tutor spec/plan/testmap deltas that revert current rendered-authority or
     Node 24 canon
9. keep these lanes closed unless a verifier or new mainline truth reopens them
   - Tutor/MFE rendered-authority sync
   - machine-facing runtime normalization
   - cross-repo contract runtime follow-through
   - branch-protection docs-to-code sync
10. preserve sequencing discipline:
    - owner-doc statement replacement first
    - derived-surface regeneration second
    - docs-side gates third
    - shared-runtime or cross-repo fallout only after the docs-side lane is green
11. prepare merge-back in reviewable waves
    - do not reintroduce this branch to `main` as one giant intake PR
    - group reintegration by coherent truth family
    - keep verifier/runtime changes separate from unrelated authored-canon edits
    - current ready-first order is:
      - live control layer and meta front doors
      - historical packet and reset-wave bounding
      - companion compression
    - wave 1 exact bundle is now locked to:
      - `POST_REBASE_INTAKE_2026-04-13.md`
      - `REVIEW_HARDENING_BOARD_2026-04-13.md`
      - `DOCS_TRANCHE_MILESTONE_LEDGER_2026-04-13.md`
      - `docs/meta/docs-program/README.md`
      - `docs/meta/README.md`
      - `docs/meta/docs-program/metadata/**`
    - keep out of wave 1:
      - historical packet and reset-wave docs
      - companion compression outcomes
      - Tutor / branding / CI / contract truth-sync families
    - extract Wave 1 by carrying current file state onto fresh `main` only
      after `wave-0a-concepts-root-authority` and
      `wave-0b-architecture-root-authority` are already in base
    - do not replay the shaping commits one by one
    - proposed Wave 1 PR title:
      - `docs: refresh active docs control plane`
    - if wave 2 feels too large, split it before review:
      - packet normalization
      - reset-wave normalization
    - Wave 2A packet-normalization bundle should carry:
      - historical packet docs such as the brief, roadmap, weekly/signoff,
        overlay/wrapper, and Wave 3 / Wave 4 / Wave 9 packet surfaces
    - Wave 2B reset-wave bundle should carry:
      - ADR reset
      - architecture-root reset
      - branding-root reset
      - CI/CD-root reset
      - operations-root reset
      - runbooks-root reset
      - migrations-root reset
