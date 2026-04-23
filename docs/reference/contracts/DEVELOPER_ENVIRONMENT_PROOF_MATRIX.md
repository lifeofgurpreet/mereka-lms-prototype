# Developer Environment Proof Matrix
_Audience: Developers, platform operators, and agents | Owner: Platform Team | Last verified: 2026-04-23 | Status: canonical_

This contract keeps local development, CI bootstrap, devspace, and Kubernetes preview work on one source to render to artifact chain. A developer environment is not supported until it names its source authority, artifact authority, cache class, and proof lane here or in a contract that links back here.

## Non-Negotiables

1. Every lane MUST consume the same source authority: Tutor plugins/config, `docker-bake.hcl`, canonical build-context helpers, and GitOps overlays where Kubernetes is involved.
2. No lane may quietly become a second Dockerfile, Compose, or manifest generator.
3. Cache state MUST be classified as durable registry cache, runner-local cache, developer-local cache, or disabled app-level cache.
4. Proof artifacts MUST say what they prove and what they do not prove.
5. Runtime claims MUST separate repo truth, GitHub/runner proof, GitOps realization, and live cluster/user truth.

## Current and Planned Lanes

| Lane | Status | Source authority | Render/artifact authority | Cache class | Required proof | Non-goal |
|---|---|---|---|---|---|---|
| Local laptop quick start | Active | `scripts/shared/setup-local.sh`, `scripts/infra/ensure-buildx-dependency-mirror.sh`, `scripts/infra/buildx-builder-health.sh`, `scripts/infra/build-openedx-image.sh`, `scripts/infra/build-mfe-image.sh`, `scripts/infra/build-image-freshness.sh`, `infrastructure/tutor/**` including Discovery init source hooks, Mereka LMS theme/Mako guards, and installed `openedx_tenant_cache.runtime_urls` helpers also imported by deployed LMS multisite settings, `docker-bake.hcl` | repo-scoped Tutor render under `tutor_env/`, local Compose, local image tags `openedx:nightly` / `openedx-mfe:nightly`; local image freshness is owned by build helpers, not `setup-local.sh`, and reuse requires matching context, build-profile, and build-scope labels | developer-local BuildKit worker cache, not client-side `type=local` `.buildx-cache/*-fast` dirs; dependency-image mirror normalization; BuildKit `docker.io` registry mirror fallback; guarded idle-builder recreation only; `mirror.gcr.io` dependency pulls | `./scripts/qa/verify-cold-start-onboarding-contract.sh`; `./scripts/qa/test-build-image-freshness.sh`; `./scripts/qa/test-build-image-profile-guards.sh`; `./scripts/qa/test-discovery-init-task-contract.sh`; `./scripts/qa/test-buildx-builder-health.sh`; `./scripts/qa/verify-mako-template-syntax.sh`; initialized state via `./scripts/infra/verify-local-bootstrap-readiness.sh` | production deployment proof |
| CI local bootstrap | Active | same as local laptop quick start | `.github/workflows/bootstrap-local-readiness.yml` rendered Compose + pulled image provenance; `lane_mode=fallback` may force ARC when fastlane substrate is under investigation | `mirror.gcr.io` dependency pulls; no image-build cache claim | green bootstrap workflow with redacted artifact | machine-cold image build proof |
| App-cache-cold image build | Active | `docker-bake.hcl`, `scripts/infra/prepare-tutor-build-context-ci.sh`, `scripts/infra/build-openedx-image.sh`, `scripts/infra/build-mfe-image.sh` | `build-benchmark.yml` no-cache bake targets and local Docker output | dependency-image mirror normalization plus `mirror.gcr.io` dependency pulls; BuildKit `docker.io` registry mirror fallback; app-level BuildKit cache imports disabled | `build-benchmark.yml` with `benchmark_class=app-cache-cold`, `image_family=both`; failed measured build outcomes fail the workflow | pristine daemon/base-image proof |
| Registry-warm build | Active | same bake/build helpers | GHCR image + provenance artifacts | durable GHCR BuildKit registry cache, runner-local cache optional | build workflow or benchmark registry-warm artifact | new source authority |
| ARC heavy build | Active | same bake/build helpers | ARC DinD builder output | ARC PVC cache plus GHCR cache where enabled | CI workflow proof on `mereka-k8s-heavy-builders` | assuming PVC cache is the source of truth |
| Fastlane VPS build | Active | same bake/build helpers | fastlane runner builder output | fastlane host-local cache plus GHCR cache where enabled | selected workflow proof with lane decision artifact | replacing ARC or bake semantics |
| RKE2 dev GitOps | Active | app repo source + infra repo `profiles/dev` overlay | ArgoCD-realized Kubernetes manifests | image pulls; no local build cache claim | `./scripts/qa/verify-rke2-dev-readiness.sh`; live checks when cluster access exists | local Tutor bootstrap proof |
| Kubernetes preview | Planned | app repo source + infra repo preview overlay | GitOps-realized preview namespace/manifests | must be declared before launch | preview readiness verifier before supported use | ad-hoc namespaces or hand-applied manifests |
| Devspace development | Planned | same app source/build contracts as local and GitOps lanes | devspace config may sync code, but must consume canonical images/settings | developer-local sync/cache, explicitly declared | devspace readiness verifier before supported use | independent Dockerfile/build semantics |

## Accepted Proof History And Current Gaps

This matrix records proof classes and accepted evidence. It is not a live CI dashboard.
For current-head status, query GitHub Actions with `gh run list`,
`gh run view`, and the active tracking issue before calling a lane closed.

| Proof class | Latest accepted evidence | Status meaning | Current gap discipline |
|---|---|---|---|
| Offline onboarding contract | `verify-cold-start-onboarding-contract.sh` on the branch being reviewed | Docs, setup scripts, build helpers, and workflow contracts agree. | Rerun after any onboarding, Tutor render, build helper, or workflow edit. |
| Bootstrap Local Readiness | Latest green `bootstrap-local-readiness.yml` run for the commit being claimed | A clean repo-scoped `TUTOR_ROOT` rendered, launched, proved image provenance, and passed readiness. | A cancelled GitHub job after a successful launch phase is not a source failure; rerun before changing source or verifiers. |
| App-cache-cold image build | Latest green `build-benchmark.yml` with `benchmark_class=app-cache-cold` and `image_family=both` | Open edX and MFE build helpers work with app-level BuildKit cache imports disabled. | Do not market this as pristine machine-cold proof; persistent runner daemon/base-image state may exist. |
| Registry-warm Build Tutor Images | Latest green build workflow for the commit being claimed | GHCR image build, cache, provenance, and post-build checks passed for that commit. | Cache-health summaries must inspect the expected L2 app cache ref, not just any registry import. |

The proof set covers repo-owned pre-checkout generated workspace cleanup,
Docker-level stale Tutor project cleanup, Buildx orphan cleanup, redacted
bootstrap artifacts, and phase timing artifacts. Host Docker/containerd health
remains a separate runner substrate truth. Fastlane or ARC failures during
image pull/extract, job cancellation, or runner shutdown must be classified as
runner/control-plane evidence unless logs show a source/render/build-helper
error.

Local laptop Buildx builder health is narrower than runner cleanup. The local
dependency-mirror helper may recreate only the repo-owned
`mereka-dependency-mirror` builder when its idle BuildKit container still has
stale build executor processes. It must refuse mutation while another Docker or
BuildKit build/pull is active, and it must not change bake targets, Dockerfile
semantics, cache authority, or proof class names.

Known current gaps:

- Bootstrap proof is initialized-state and image-provenance proof. It is not a
  branded runtime visual proof, browser login proof, promotion proof, or
  machine-cold image timing proof.
- `app-cache-cold` disables app-level BuildKit cache imports and records the
  measured-job wipe state, but it can still run on a persistent runner with
  existing Docker daemon/base-image state.
- Devspace and Kubernetes preview lanes are planned only. They cannot be called
  supported until they add source, artifact, cache, and proof contracts here.
- Any remaining post-render build mutation must stay in the explicit
  build-optimization delta ledger and have retirement criteria; new developer
  lanes must not copy that logic into another generator.

## Entry Criteria for New Developer Lanes

Before a new devspace, preview namespace, or local workflow is called supported, it MUST add:

- A row in this matrix or a linked contract with the same fields.
- A copy-paste setup command in onboarding docs.
- A verifier or workflow that fails when the row's source, render, artifact, or cache promise drifts.
- A redacted artifact or log path that a new developer can attach when setup fails.
- A failure taxonomy entry that says whether a red result is source, render, artifact, cache, runner, GitOps, or live-runtime class.

## Forbidden Drift

- Bash wrappers that rewrite rendered Dockerfiles beyond the explicit build-optimization delta ledger.
- Devspace or preview configs that maintain their own image build semantics.
- Quick-start docs that advertise a command not covered by `verify-cold-start-onboarding-contract.sh`.
- Benchmarks marketed as pristine cold when they only disable app-level cache imports.
- Runner-local cache treated as durable authority instead of an acceleration layer.
- Local or CI bootstrap pulling third-party/Tutor helper images anonymously from Docker Hub when the mirrored image refs are available.

## Related Proof Surfaces

- [VERIFIER_CONTRACT_CATALOG.md](VERIFIER_CONTRACT_CATALOG.md)
- [PLATFORM_AUTHORITY_MAP.md](../../architecture/PLATFORM_AUTHORITY_MAP.md)
- [QUICK_START_LOCAL.md](../../guides/onboarding/QUICK_START_LOCAL.md)
- [RKE2_DEV_READINESS.md](../../ops/runbooks/RKE2_DEV_READINESS.md)
