# Build Authority Closure Tracker - 2026-04-23

Status: active
Owner: Platform/build authority lane
Scope: local build, CI image build, benchmark/cache proof, promotion evidence, and tracker governance
Last reconciled: 2026-04-24

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

Snapshot taken with GitHub Actions and Beads queries on 2026-04-24.

| Surface | Evidence | Truth level | Current interpretation |
|---|---|---|---|
| Current app `main` source | `799b8d52dfba1f1ae307b1b45aba4339c93012e8` | source | Latest fetched `origin/main`; this source includes the benchmark maintenance-window guard merged in #2125. |
| Latest green Build Tutor Images | Run `24855960086`, commit `9ff1073b8468248e5499876f94892ca1d2faa193` | CI artifact | Image build path was green after the recent build-authority fixes. This is not a promotion/runtime claim. |
| Promotion-proven build commit | Build Tutor Images run `24835465611`, commit `41c431e434e8705eba6cf9ca12f573183d9ba791` | CI artifact plus promotion | This is the commit that was promoted to dev through infra PR #3877 and later proved live. |
| Bootstrap local readiness | Run `24855960102`, commit `9ff1073b8468248e5499876f94892ca1d2faa193`; run `24835465623`, commit `41c431e434e8705eba6cf9ca12f573183d9ba791` | CI local/bootstrap | Recent bootstrap proof is green for those commits. The latest observed run `24858570926` on `49b7200740a676edd9528c7d6f665f269845452c` was still in progress when queried. |
| Local current-head proof branch | `fix/local-proof-2042` reran `setup-local.sh`, `make local-proof`, and `verify-local-runtime-readiness.sh` on 2026-04-23 against external `TUTOR_ROOT=/tmp/mereka-local-first-run-proof-20260422/tutor_env` | source/render/artifact/local runtime | This proves the current source changes honor external Tutor roots, build both local images from the resolved Tutor render contexts, create the local proof identity, pass initialized bootstrap readiness, and pass authenticated local runtime readiness. It is not browser-flow, GitOps, or machine-pristine proof. |
| Benchmark/cache class proof | Build Benchmark run `24872620974`, commit `799b8d52dfba1f1ae307b1b45aba4339c93012e8`; earlier supporting runs `24865486499`, `24865940897`, `24865999510` | CI benchmark | Post-hardening proof is current: scan-only/both fastlane, registry-warm/both fastlane, registry-warm/both ARC heavy, and app-cache-cold/both fastlane all passed. App-cache-cold proved OpenEdX `1511s` with `0/130` cached layers and MFE `1536s` with `0/579` cached layers, both with measured-job L1 wipe evidence and `machine_cold_claim=false`. |
| Dev/staging GitOps realization proof | Infra Post-Merge Cluster Validation run `24857292026`, infra commit `737321b3d8da77d4807da1e39d9ef846b43b1773` | realization/runtime | Final manual proof lane succeeded after the infra false-green fix; dev and staging LMS app proof should now be workflow-owned, not manual folklore. |
| Infra false-green gap | bbi-infrastructure #3878 | governance | Closed after fail-closed refresh/runtime proof and manual app-list recovery path landed. |
| CI metrics receiver health | `ci-metrics-receiver` PM2 service recovered 2026-04-24; local and external `/health` 200, `/ready` 200 with taxonomy version `1` and 5 entries, Prometheus target `up=1` | receiver runtime | The receiver is live again after being absent from PM2 and returning Cloudflare `502`. vps-infrastructure PRs #116/#117/#118 are merged/deployed. A signed post-restart canary proved cache/layer enrichment under receiver-owned `runner_class="arc-heavy"` context and VPS Prometheus scrape freshness for `workflow_run_id=1777012124622`. |

## Open Closure Board

| Priority | Bead | GitHub | State | Closure condition |
|---|---|---|---|---|
| P0 | `mereka-lms-0z5g` | #1780 | open | Umbrella stays open until local proof, benchmark proof, runner/cache governance, and release-bundle authority have current evidence. |
| P0 | `mereka-lms-0z5g.20` | #1780 | open | This tracker, proof matrix, stale active docs, and Beads/GitHub mapping are merged and accepted as the canonical execution board. |
| P0 | `mereka-lms-0z5g.21` | #2042 | in progress | Branch-local proof now has current-head source/render/artifact and authenticated local runtime evidence. Close only after the source fix is merged, PR/CI proof is clean, and #2042 is updated without claiming browser or machine-pristine semantics. |
| P0 | `mereka-lms-0z5g.22` | #2045 | closing | Post-hardening benchmark class evidence was rerun and published. Run `24872620974` closes app-cache-cold/both fastlane on current head; machine-pristine remains intentionally out of scope and separately tracked by `mereka-lms-0z5g.2`. |
| P0 | `mereka-lms-0z5g.5` | #1777, #1778 | in progress | Fastlane/containerd/Buildx hygiene is durable, current-main bootstrap reruns are green or reclassified, and host lock ownership is not a per-job fallback. |
| P1 | `mereka-lms-0z5g.5.1` | #1778 | open | `/tmp/fastlane-docker-prune.lock` ownership is versioned in infra/runner provisioning and proven under concurrent fastlane jobs. |
| P1 | `mereka-lms-0z5g.3` | #1780 | open | Fastlane and ARC heavy lanes prove one cache-aware strategy without divergent bake/build semantics. |
| P1 | `mereka-lms-0z5g.23` | #2043 | closure PR | App producer schema is reconciled; live receiver health was recovered; vps-infrastructure PRs #116/#117/#118 are merged/deployed; bbi-infrastructure PR #3950 corrected the stale operator runbook; a signed post-restart canary proved cache/layer Prometheus samples use receiver-owned runner-context enrichment instead of `runner_class="other"` fallback. Close after this tracker update lands. |
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
3. Close `mereka-lms-0z5g.22` / #2045 after publishing run `24872620974`:
   post-hardening benchmark evidence now separates `app-cache-cold`,
   registry-warm, runner-local cache, ARC/fastlane runner class, and
   machine-pristine semantics.
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
- Do not use old run `24721668598` as closure evidence; #2045 closure is based
  on post-hardening run `24872620974` plus the supporting scan/registry-warm
  runs listed above.
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
- #2045 closed, with the explicitly deferred machine-pristine question still
  tracked outside the app-cache-cold proof claim.
- #1777/#1778 moved out of ambiguous runner folklore into versioned infra/runner
  ownership.
- #2043/#2046/#2047 updated with current receiver/spec/taxonomy truth.
- #1406/#1381 either designed into release-object authority or explicitly
  rejected with replacement promotion semantics.
- This document and the proof matrix updated with every proof run that changes
  the closure state.
