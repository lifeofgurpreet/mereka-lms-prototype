# Developer Environment Proof Matrix
_Audience: Developers, platform operators, and agents | Owner: Platform Team | Last verified: 2026-04-21 | Status: canonical_

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
| Local laptop quick start | Active | `scripts/shared/setup-local.sh`, `scripts/infra/ensure-buildx-dependency-mirror.sh`, `infrastructure/tutor/**`, `docker-bake.hcl` | repo-scoped Tutor render under `tutor_env/`, local Compose, local image tags `openedx:nightly` / `openedx-mfe:nightly` | developer-local build cache; dependency-image mirror normalization; BuildKit `docker.io` registry mirror fallback; `mirror.gcr.io` dependency pulls | `./scripts/qa/verify-cold-start-onboarding-contract.sh`; initialized state via `./scripts/infra/verify-local-bootstrap-readiness.sh` | production deployment proof |
| CI local bootstrap | Active | same as local laptop quick start | `.github/workflows/bootstrap-local-readiness.yml` rendered Compose + pulled image provenance; `lane_mode=fallback` may force ARC when fastlane substrate is under investigation | `mirror.gcr.io` dependency pulls; no image-build cache claim | green bootstrap workflow with redacted artifact | machine-cold image build proof |
| App-cache-cold image build | Active | `docker-bake.hcl`, `scripts/infra/prepare-tutor-build-context-ci.sh`, `scripts/infra/build-openedx-image.sh`, `scripts/infra/build-mfe-image.sh` | `build-benchmark.yml` no-cache bake targets and local Docker output | dependency-image mirror normalization plus `mirror.gcr.io` dependency pulls; BuildKit `docker.io` registry mirror fallback; app-level BuildKit cache imports disabled | `build-benchmark.yml` with `benchmark_class=app-cache-cold`, `image_family=both`; failed measured build outcomes fail the workflow | pristine daemon/base-image proof |
| Registry-warm build | Active | same bake/build helpers | GHCR image + provenance artifacts | durable GHCR BuildKit registry cache, runner-local cache optional | build workflow or benchmark registry-warm artifact | new source authority |
| ARC heavy build | Active | same bake/build helpers | ARC DinD builder output | ARC PVC cache plus GHCR cache where enabled | CI workflow proof on `mereka-k8s-heavy-builders` | assuming PVC cache is the source of truth |
| Fastlane VPS build | Active | same bake/build helpers | fastlane runner builder output | fastlane host-local cache plus GHCR cache where enabled | selected workflow proof with lane decision artifact | replacing ARC or bake semantics |
| RKE2 dev GitOps | Active | app repo source + infra repo `profiles/dev` overlay | ArgoCD-realized Kubernetes manifests | image pulls; no local build cache claim | `./scripts/qa/verify-rke2-dev-readiness.sh`; live checks when cluster access exists | local Tutor bootstrap proof |
| Kubernetes preview | Planned | app repo source + infra repo preview overlay | GitOps-realized preview namespace/manifests | must be declared before launch | preview readiness verifier before supported use | ad-hoc namespaces or hand-applied manifests |
| Devspace development | Planned | same app source/build contracts as local and GitOps lanes | devspace config may sync code, but must consume canonical images/settings | developer-local sync/cache, explicitly declared | devspace readiness verifier before supported use | independent Dockerfile/build semantics |

## Latest Accepted Proofs And Current Gaps

| Date | Proof | Run | Commit | Result | Interpretation |
|---|---|---|---|---|---|
| 2026-04-21 | App-cache-cold image build | `24721668598` | `39ae0fb86` | success | Open edX and MFE image helpers build with app-level BuildKit cache imports disabled. This is not pristine machine-cold proof. |
| 2026-04-21 | Last accepted Bootstrap Local Readiness baseline | `24711453019` | `e7a4472cd` | success | A clean repo-scoped `TUTOR_ROOT` launched and passed readiness checks before the current fastlane host incident. |
| 2026-04-21 | Current-main Bootstrap Local Readiness rerun | `24730265503` | `12db1b6` | success | Clean repo-scoped Tutor bootstrap readiness passed after repo Buildx cleanup and fastlane hook repair. This is initialized-state proof, not MFE authn route or branded runtime image proof. |
| 2026-04-21 | Branch Bootstrap Local Readiness attempt | `24736358890` | `1506f9d90` | cancelled | Fastlane runner/control plane cancelled during active migrations. No source stack trace or readiness proof was produced. |
| 2026-04-21 | Branch Bootstrap Local Readiness rerun | `24737898005` | `1506f9d90` | failed | Persistent-runner state from the cancelled run left stale `tutor_local` Docker project resources and opaque plugin-enable output. The branch now adds Docker-level Tutor cleanup and idempotent canonical plugin enable handling. |
| 2026-04-21 | Branch Bootstrap Local Readiness rerun | `24738471266` | `878994d0c` | success | ARC fallback proof passed pre-clean, render, image refresh, `tutor local launch -I --skip-build`, image provenance, and local readiness. MFE authn route returned HTTP 302. |

The 2026-04-21 proof set also covers the repo-owned pre-checkout generated
workspace cleanup and Buildx orphan cleanup, but host Docker/containerd health
remains a separate runner substrate truth. Fastlane failures while extracting
`mirror.gcr.io/overhangio/openedx:21.0.4` layers are runner/host failures until
fresh evidence proves otherwise. They must not be fixed by inventing a second
developer build lane or weakening the source/render/artifact contract.
Cancelled persistent-runner bootstrap runs can also leave `tutor_local` Docker
containers, volumes, and networks behind; the bootstrap workflow owns bounded
cleanup for that stale proof state before checkout.
Run `24738471266` showed the launch phase can take about 56 minutes before
readiness passes; post-merge run `24743995049` on `2b86de8` confirmed that long
launches are normal enough to need first-class operator feedback. The bootstrap
workflow now emits `bootstrap-phase-timings.tsv` and
`bootstrap-phase-summary.md` so proof artifacts show phase duration instead of
only final pass/fail.

Known coverage gaps from the same green bootstrap run:

- `http://apps.localhost/authn/login` returned HTTP 400 in a live runner probe
  because Django rejected `apps.localhost` as an `ALLOWED_HOSTS` value. This is
  a source/render contract gap for MFE-prefixed LMS routes, not verifier
  accommodation. This branch adds the source fix and makes local readiness fail
  closed on non-200/302 MFE authn responses; branch bootstrap proof must rerun.
- LMS logs reported `Theme 'mereka' not found` while the upstream bootstrap
  image served `localhost` with HTTP 200. This branch skips SiteTheme convergence
  when `/openedx/themes/mereka` is absent, so the upstream bootstrap lane stays
  explicitly unbranded. Branded runtime proof still belongs to a repo-built image
  lane; do not let a SiteTheme database check stand in for branded asset proof.

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
