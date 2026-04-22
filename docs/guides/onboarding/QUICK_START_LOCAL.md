# Quick Start: Local Development Setup
_Audience: Developers + Agent Operators • Owner: Platform Team • Last verified: 2026-04-22 • Status: canonical_

## Fast Setup

```bash
git clone git@github.com:Biji-Biji-Initiative/mereka-lms.git
cd mereka-lms
git submodule update --init --recursive
./scripts/qa/verify-cold-start-onboarding-contract.sh
./scripts/shared/setup-local.sh
./scripts/infra/verify-local-bootstrap-readiness.sh
```

The first run builds local Open edX and MFE images, initializes Tutor data, starts the stack, and creates a local-only admin user. If `LOCAL_ADMIN_PASSWORD` is not set, the setup script writes generated credentials to `tutor_env/local-admin-credentials.txt`.

## Current Proof Snapshot

As of 2026-04-22, the canonical local setup path is the repo-owned source ->
Tutor render -> local image -> Tutor launch chain below. The image-build proof
lane is green for both MFE and Open edX images after PR #2006. Main CI is green
through the #2007 onboarding-doc guard rerun, and PR #2008 closed the staging
MFE host derivation bug. The current-head bootstrap rerun for #2007 is still in
progress, so do not call that specific proof closed until run `24757454326`
finishes readiness and provenance steps.

| Proof | Run | Commit | Result | What it proves |
|---|---|---|---|---|
| Static validation after #2008 | `24757968425` | `e025d4c15` | success | PR proof for the shared E2E host helper and runbook update, including static script shards and Python coverage. |
| MFE Build Tutor Images proof | `24756568100` | `a7d98293` | success | Re-proved generated MFE runtime verifier after the `TUTOR_ROOT` workflow portability fix in PR #2006. |
| Open edX Build Tutor Images proof | `24756779458` | `a7d98293` | success | Proved Open edX render preflight, build-context prep, image build, imports, blocking branding verification, SBOM, and Trivy artifact upload. |
| Main CI after #2007 | `24757454308` | `ec1ac294` | success | Rerun proved the first red attempt was runner shutdown/cancellation, not source regression. |
| Current-head Bootstrap Local Readiness | `24757454326` | `ec1ac294` | in progress | Still running at `Launch full local Tutor bootstrap` as of this update. Not closed until readiness/provenance steps complete. |
| PR #2008 merge | PR #2008 | `e807e515` | merged | Centralized staging/production MFE host derivation and clarified post-deploy E2E proof boundaries. |

These are shared proof lanes, not alternate build systems. Do not create a
second Dockerfile, Compose stack, or local-only build path to work around a
failure. Classify the failure, fix the source/render/build-helper chain, and
update the proof matrix when the contract changes.

## Host Requirements

- Docker Engine or Docker Desktop with Docker Compose v2.
- Python 3.12 with `venv`.
- At least 8 vCPU, 16 GB RAM, and 40 GB free disk.
- Docker Desktop on macOS: set RAM to 12 GB and swap to 2-4 GB before the first image build.

## Manual Equivalent

Use this when debugging the setup script step by step:

```bash
git submodule update --init --recursive

python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements-tutor.txt

source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"

./scripts/infra/tutor-config-save.sh \
  --set LMS_HOST=localhost \
  --set CMS_HOST=studio.localhost \
  --set MFE_HOST=apps.localhost \
  --set DISCOVERY_HOST=discovery.localhost \
  --set ECOMMERCE_HOST=ecommerce.localhost \
  --set XQUEUE_HOST=xqueue.localhost \
  --set RUN_MONGODB=true \
  --set RUN_MYSQL=true \
  --set RUN_REDIS=true \
  --set RUN_MEILISEARCH=true \
  --set RUN_SMTP=true \
  --set DOCKER_REGISTRY=mirror.gcr.io/ \
  --set DOCKER_IMAGE_OPENEDX=openedx:nightly \
  --set MFE_DOCKER_IMAGE=openedx-mfe:nightly \
  --set DOCKER_IMAGE_CADDY=mirror.gcr.io/library/caddy:2.7.4 \
  --set DOCKER_IMAGE_MEILISEARCH=mirror.gcr.io/getmeili/meilisearch:v1.8.4 \
  --set DOCKER_IMAGE_MONGODB=mirror.gcr.io/library/mongo:7.0.28 \
  --set DOCKER_IMAGE_MYSQL=mirror.gcr.io/library/mysql:8.4.0 \
  --set DOCKER_IMAGE_REDIS=mirror.gcr.io/library/redis:7.4.5 \
  --set DOCKER_IMAGE_SMTP=mirror.gcr.io/devture/exim-relay:4.96-r1-0 \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017 \
  --set MYSQL_PORT=3306 \
  --set MYSQL_ROOT_HOST=% \
  --set REDIS_PORT=6379 \
  --set ASPECTS_SUPERSET_DATABASE_HOST=clickhouse
```

The config wrapper syncs the repo-local Tutor plugin mirror and enables the
canonical plugins with `tutor plugins enable mereka_lms` and
`tutor plugins enable mereka_lms_mfe_slots` before saving config.

```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/infra/ensure-buildx-dependency-mirror.sh
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
tutor local launch -I --skip-build
tutor local start -d
./scripts/infra/verify-local-bootstrap-readiness.sh
```

The local quick start builds `openedx:nightly` and `openedx-mfe:nightly`, then points Tutor at those exact tags. Render prep applies the named dependency-image mirror patch for Tutor-emitted hardcoded Docker Hub dependency refs, selects a repo-owned BuildKit builder with a `docker.io` registry mirror as a fallback guard, and uses `mirror.gcr.io` where Tutor exposes third-party service/helper image refs. That is dependency acquisition only; it does not create a second Dockerfile or image strategy.

To force a local image rebuild even when `openedx:nightly` or `openedx-mfe:nightly` already exists:

```bash
FORCE_LOCAL_IMAGE_BUILD=1 ./scripts/shared/setup-local.sh
```

## Verification Checklist

Run these to verify everything works:

```bash
# Check source/docs contract without starting Docker
./scripts/qa/verify-cold-start-onboarding-contract.sh

# Check initialized local Tutor state after setup
./scripts/infra/verify-local-bootstrap-readiness.sh

# Check containers
docker ps --filter "name=tutor_local" | wc -l
# Should show 20+ once the full Tutor stack is running

# Check config is local (not cloud)
grep -E "MYSQL_HOST|MONGODB_HOST" tutor_env/config.yml
# Should show: mysql, mongodb (NOT 10.97.0.2)

# Test URLs
curl -I http://localhost                    # LMS
curl -I http://studio.localhost             # Studio  
curl -I http://apps.localhost/authn/login   # MFE Login
```

## Separate CI Proof Lane

The clean bootstrap proof is [`.github/workflows/bootstrap-local-readiness.yml`](../../../.github/workflows/bootstrap-local-readiness.yml). It creates a fresh repo-scoped `TUTOR_ROOT`, launches `tutor local launch -I --skip-build`, validates image provenance, and runs `./scripts/infra/verify-local-bootstrap-readiness.sh`. Its artifact includes `bootstrap-phase-timings.tsv` and `bootstrap-phase-summary.md` so long runs show which phase consumed time instead of leaving operators with only a final pass/fail.

The bootstrap workflow uses the same Tutor render path as local setup, including the named dependency-image mirror patch for Tutor-emitted hardcoded Docker Hub refs and `mirror.gcr.io` settings where Tutor exposes dependency images. The benchmark image-build proof also configures BuildKit with a `docker.io` registry mirror as a fallback guard, but the explicit render patch is what makes the known upstream dependency refs deterministic. Those mirror settings are not build semantic changes; they exist so proof and first-run setup do not depend on anonymous Docker Hub quota.

The CI bootstrap and build workflows also perform bounded pre-checkout cleanup
for repo-generated state (`tutor_env`, `var/bootstrap-readiness`, `var/ci`,
and `.buildx-cache`). That cleanup exists because containerized Tutor steps can
leave root-owned files on persistent fastlane runners. It is runner hygiene only;
it does not change build semantics.

The bootstrap workflow also removes stale `tutor_local` Docker containers,
volumes, and networks before a new run starts. That guard exists for cancelled
or interrupted persistent-runner jobs; it keeps the proof lane clean without
creating another build path.

The app-cache-cold image-build proof is [`.github/workflows/build-benchmark.yml`](../../../.github/workflows/build-benchmark.yml) with `benchmark_class=app-cache-cold` and `image_family=both`. That lane proves the Open edX and MFE image build helpers with app-level BuildKit cache imports disabled; persistent runner Docker daemon/base-image state can still exist. The bootstrap lane proves the rendered Tutor stack initializes from a clean `TUTOR_ROOT`. The old `benchmark_class=true-cold` input remains accepted as a legacy alias, but new evidence should use `app-cache-cold`.

To run it from a branch:

```bash
gh workflow run bootstrap-local-readiness.yml --ref "$(git branch --show-current)"
gh run list --workflow bootstrap-local-readiness.yml --limit 5

gh workflow run build-benchmark.yml --ref "$(git branch --show-current)" \
  -f runner_class=fastlane \
  -f benchmark_class=app-cache-cold \
  -f image_family=both
```

If fastlane is under runner-substrate investigation and you need the same
bootstrap proof on ARC, force the workflow's fallback lane:

```bash
gh workflow run bootstrap-local-readiness.yml \
  --ref "$(git branch --show-current)" \
  -f lane_mode=fallback
```

Do not mark cold-start onboarding fixed until the offline contract passes, the bootstrap workflow is green for the branch being merged, app-cache-cold image build proof is either green or explicitly waived with a fresh reason, and any route/theme checks required by the proof matrix are either green or explicitly listed as not covered by that lane.

Current follow-up: run `24757454326` is the active current-head bootstrap proof for #2007 and is still running. If it fails, classify the failure first as source-truth bug, rendered-truth bug, workflow portability bug, runner-capacity issue, or bootstrap harness bug before changing code or verifiers.

## Daily Commands

```bash
# Start
source infrastructure/tutor/tutor-env.sh
export TUTOR_ROOT="$(pwd)/tutor_env"
tutor local start -d

# Stop
tutor local stop

# After config changes
./scripts/infra/tutor-config-save.sh --set KEY=value
tutor local restart
```

## Common Issues

**"Can't connect to MySQL"**
```bash
grep MYSQL_HOST tutor_env/config.yml  # Should be "mysql"
tutor local restart mysql
sleep 10
tutor local restart lms cms
```

**"MFE login white screen"**
```bash
curl http://localhost/api/mfe_config/v1?mfe=authn  # Check API
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
tutor local restart mfe
```

**Config shows cloud IPs**
```bash
./scripts/infra/tutor-config-save.sh --set MYSQL_HOST=mysql --set MONGODB_HOST=mongodb
tutor local restart
```

## 📚 Full Documentation

- **Full setup:** [`LOCAL_SETUP.md`](LOCAL_SETUP.md)
- **Daily workflow:** [`WORKFLOW_LOCAL.md`](WORKFLOW_LOCAL.md)
- **Repository map:** [`REPOSITORY_GUIDE.md`](REPOSITORY_GUIDE.md)
- **Troubleshooting:** [`../../ops/runbooks/TROUBLESHOOTING.md`](../../ops/runbooks/TROUBLESHOOTING.md)

## 🌐 Access URLs

- LMS: http://localhost
- Studio: http://studio.localhost
- MFE Login: http://apps.localhost/authn/login
- Admin: http://localhost/admin
- Admin credentials: local-only values you created during setup

---

**Remember:** For local Tutor regeneration, use `./scripts/infra/tutor-config-save.sh` rather than calling `apply-patches.sh` directly. Always verify config uses local Docker services (`mysql`, `mongodb`, `redis`) not cloud IPs, and never commit local passwords or copied secrets.
