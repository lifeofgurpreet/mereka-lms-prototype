# Build Authority Closure Tracker - 2026-04-23

Status: active
Owner: Platform/build authority lane
Scope: local build, CI image build, benchmark/cache proof, promotion evidence, and tracker governance
Last reconciled: 2026-04-23

This tracker is the current closure board for the build/local proof work. It
does not replace the stable contracts in
[`DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md`](../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md)
or the promotion model in
[`PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md`](../../architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md).
It records what is currently proved, what remains open, and which Beads/GitHub
issues own the remaining work.

## Truth Boundary

Report these states separately:

- `source_truth`: merged repository state and declared contracts.
- `ci_truth`: GitHub Actions runs, artifacts, cache metadata, and benchmark
  class output.
- `promotion_truth`: release object, promotion PR, and infra GitOps desired
  state.
- `realization_truth`: ArgoCD refresh/sync and Kubernetes workload image
  realization.
- `runtime_truth`: HTTP/browser/user-visible behavior.

A green workflow is not promotion proof. A merged promotion PR is not runtime
proof. A live `kubectl` observation is not durable source truth unless it is
owned by GitOps source.

## Current Verified Facts

Snapshot taken with GitHub Actions and Beads queries on 2026-04-23.

| Surface | Evidence | Truth level | Current interpretation |
|---|---|---|---|
| Current app `main` source | `baca28e076371ba33020bde0474b06e303fd0508` | source | Latest fetched `origin/main`; this local proof branch is rebased onto it for PR. |
| Latest green Build Tutor Images | Run `24855960086`, commit `9ff1073b8468248e5499876f94892ca1d2faa193` | CI artifact | Image build path was green after the recent build-authority fixes. This is not a promotion/runtime claim. |
| Promotion-proven build commit | Build Tutor Images run `24835465611`, commit `41c431e434e8705eba6cf9ca12f573183d9ba791` | CI artifact plus promotion | This is the commit that was promoted to dev through infra PR #3877 and later proved live. |
| Bootstrap local readiness | Run `24855960102`, commit `9ff1073b8468248e5499876f94892ca1d2faa193`; run `24835465623`, commit `41c431e434e8705eba6cf9ca12f573183d9ba791` | CI local/bootstrap | Recent bootstrap proof is green for those commits. The latest observed run `24858570926` on `49b7200740a676edd9528c7d6f665f269845452c` was still in progress when queried. |
| Local current-head proof branch | `fix/local-proof-2042` reran `setup-local.sh`, `make local-proof`, and `verify-local-runtime-readiness.sh` on 2026-04-23 against external `TUTOR_ROOT=/tmp/mereka-local-first-run-proof-20260422/tutor_env` | source/render/artifact/local runtime | This proves the current source changes honor external Tutor roots, build both local images from the resolved Tutor render contexts, create the local proof identity, pass initialized bootstrap readiness, and pass authenticated local runtime readiness. It is not browser-flow, GitOps, or machine-pristine proof. |
| Benchmark/cache class proof | Latest green Build Benchmark run `24721668598`, commit `39ae0fb868a9769b1fa557406152b37d73765035` | CI benchmark | Stale for current closure. It proves the older app-cache-cold class only; it is not post-#2099 runtime evidence and not machine-pristine proof. |
| Dev/staging GitOps realization proof | Infra Post-Merge Cluster Validation run `24857292026`, infra commit `737321b3d8da77d4807da1e39d9ef846b43b1773` | realization/runtime | Final manual proof lane succeeded after the infra false-green fix; dev and staging LMS app proof should now be workflow-owned, not manual folklore. |
| Infra false-green gap | bbi-infrastructure #3878 | governance | Closed after fail-closed refresh/runtime proof and manual app-list recovery path landed. |

## Open Closure Board

| Priority | Bead | GitHub | State | Closure condition |
|---|---|---|---|---|
| P0 | `mereka-lms-0z5g` | #1780 | open | Umbrella stays open until local proof, benchmark proof, runner/cache governance, and release-bundle authority have current evidence. |
| P0 | `mereka-lms-0z5g.20` | #1780 | open | This tracker, proof matrix, stale active docs, and Beads/GitHub mapping are merged and accepted as the canonical execution board. |
| P0 | `mereka-lms-0z5g.21` | #2042 | in progress | Branch-local proof now has current-head source/render/artifact and authenticated local runtime evidence. Close only after the source fix is merged, PR/CI proof is clean, and #2042 is updated without claiming browser or machine-pristine semantics. |
| P0 | `mereka-lms-0z5g.22` | #2045 | open | Post-hardening benchmark class evidence is rerun and published with cache source, runner class, measured outcome, and stale/machine-pristine boundaries. |
| P0 | `mereka-lms-0z5g.5` | #1777, #1778 | in progress | Fastlane/containerd/Buildx hygiene is durable, current-main bootstrap reruns are green or reclassified, and host lock ownership is not a per-job fallback. |
| P1 | `mereka-lms-0z5g.5.1` | #1778 | open | `/tmp/fastlane-docker-prune.lock` ownership is versioned in infra/runner provisioning and proven under concurrent fastlane jobs. |
| P1 | `mereka-lms-0z5g.3` | #1780 | open | Fastlane and ARC heavy lanes prove one cache-aware strategy without divergent bake/build semantics. |
| P1 | `mereka-lms-0z5g.23` | #2043 | open | CI metrics receiver schema, workflow artifacts, Prometheus ingestion, and dashboard truth are reconciled. |
| P1 | `mereka-lms-0z5g.24` | #2046 | open | The approved CI/CD spec is reconciled with current build authority and active workflow contracts. |
| P1 | `mereka-lms-0z5g.25` | #2047 | open | First-party action authority and runner taxonomy drift gates are versioned and fail closed. |
| P1 | `mereka-lms-0z5g.26` | #1406, #1381 | open | Single-image promotion is supported through release-object authority or explicitly rejected with a safer design. |
| P1 | `mereka-lms-0z5g.2` | #2045 | open | Machine-pristine cold proof is either implemented as a separate class or rejected/deferred without overclaiming `app-cache-cold`. |
| P2 | `mereka-lms-0z5g.27` | #2096 | open | L3 final-image cache fallback has an evidence ledger and retirement/extension criteria. |
| P2 | `mereka-lms-0z5g.4` | #2044 | open | Devspace/vCluster preview lane is specified before implementation and consumes canonical build/GitOps contracts. |

Closed historical beads under `mereka-lms-0z5g.*` remain useful evidence, but
they are not current closure work unless reopened. Do not recreate closed child
IDs from old worktrees; create new beads with auto IDs and link them here.

## Execution Order

1. Merge this tracker reconciliation.
2. Close `mereka-lms-0z5g.21` / #2042: merge the current-head local proof fix,
   then update #2042 with setup, `local-proof`, and authenticated runtime
   readiness evidence.
3. Close `mereka-lms-0z5g.22` / #2045: collect post-hardening benchmark
   evidence and separate `app-cache-cold`, registry-warm, runner-local cache,
   and machine-pristine semantics.
4. Advance `mereka-lms-0z5g.5` and `.5.1`: prove fastlane cleanup and prune-lock
   ownership are durable substrate truth, not app-source behavior.
5. Reconcile observability/spec/governance: `.23`, `.24`, `.25`.
6. Resolve release-bundle authority: `.26` with #1406/#1381.
7. Start L3 fallback retirement only after fresh L2 evidence exists: `.27`.
8. Keep devspace/vCluster preview work behind `.4` until the proof lane is
   specified.

## Close Rules

- Do not close #2042 from bootstrap proof alone; it needs the beyond-bootstrap
  local proof boundary to be explicit.
- Do not close #2045 from old run `24721668598`; it is pre-hardening evidence.
- Do not call `app-cache-cold` machine-pristine proof.
- Do not close runner issues from app-repo source changes without host/runner
  substrate evidence.
- Do not promote or runtime-prove from a dirty worktree.
- Use `./scripts/kube dev|staging|prod ...` from `bbi-infrastructure` for
  interactive cluster evidence. Raw `kubectl --context ...` belongs in committed
  scripts/CI only when the wrapper would recurse or is unavailable.

## Weekly Target

The next week should end with:

- #2042 closed or blocked by a named substrate/runtime issue with fresh proof.
- #2045 closed or reduced to the explicitly deferred machine-pristine question.
- #1777/#1778 moved out of ambiguous runner folklore into versioned infra/runner
  ownership.
- #2043/#2046/#2047 updated with current receiver/spec/taxonomy truth.
- #1406/#1381 either designed into release-object authority or explicitly
  rejected with replacement promotion semantics.
- This document and the proof matrix updated with every proof run that changes
  the closure state.
