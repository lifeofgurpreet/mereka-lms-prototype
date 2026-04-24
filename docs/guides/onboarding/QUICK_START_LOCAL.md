# Quick Start: Local Development Setup
_Audience: Developers + Agent Operators • Owner: Platform Team • Last verified: 2026-04-23 • Status: canonical_

## Fast Setup

```bash
git clone git@github.com:Biji-Biji-Initiative/mereka-lms.git
cd mereka-lms
make local-first-run
```

`make local-first-run` expands to the canonical three-command chain: `git submodule update --init --recursive`, `./scripts/qa/verify-cold-start-onboarding-contract.sh`, and `./scripts/shared/setup-local.sh`. The setup script owns the rest of the governed bootstrap: it builds local Open edX and MFE images when needed, runs `tutor local launch -I --skip-build` to converge Tutor data, starts the stack, runs the initialized-state readiness verifier exactly once with `./scripts/infra/verify-local-bootstrap-readiness.sh`, creates a local-only admin user, and creates the `smoke-test` runtime proof user with Registration and UserProfile rows. Directory presence under `tutor_env/data/` is not treated as proof of initialization. If `LOCAL_ADMIN_PASSWORD` or `LOCAL_PROOF_PASSWORD` is not set, the setup script writes generated credentials under `TUTOR_ROOT` at `local-admin-credentials.txt` and `local-proof-credentials.txt`.

For isolated worktrees, devspaces, or CI repros, set `TUTOR_ROOT=/path/to/tutor_env` before running the Make targets. The Tutor plugin mirror defaults to `$TUTOR_ROOT/plugins`; use `TUTOR_PLUGINS_ROOT` only when you deliberately need another mirror.

## Current Proof Contract

As of 2026-04-23, the canonical local setup path is still one chain:
repo source -> Tutor render -> Bake-backed local images -> Tutor launch ->
readiness verification. The proof commands below are the authority; this guide
is not a live CI status board.

| Proof | Command or workflow | What it proves | What it does not prove |
|---|---|---|---|
| Offline onboarding contract | `./scripts/qa/verify-cold-start-onboarding-contract.sh` | Docs, setup scripts, build helpers, and workflow contracts still agree. | Docker can start the stack on this machine. |
| Local initialized-state proof | `./scripts/infra/verify-local-bootstrap-readiness.sh` | The current `tutor_env` stack has local services, expected image refs, and LMS/MFE HTTP readiness. | A fresh first boot from an empty `TUTOR_ROOT`. |
| Local authenticated runtime proof | `./scripts/qa/verify-local-runtime-readiness.sh` | The current initialized stack can answer LMS/Discovery shell checks and has the local proof identity, Registration, and UserProfile rows needed for authenticated smoke work. | Fresh image build, first-boot timing, or production identity proof. |
| CI bootstrap proof | `.github/workflows/bootstrap-local-readiness.yml` | A clean repo-scoped `TUTOR_ROOT` can render, launch, prove image provenance, and pass readiness. | Machine-cold image build timing. |
| App-cache-cold image proof | `.github/workflows/build-benchmark.yml` with `benchmark_class=app-cache-cold` | Open edX and MFE build helpers work with app-level BuildKit cache imports disabled. | Pristine Docker daemon/base-image state. |

Check current GitHub truth with `gh run list --workflow bootstrap-local-readiness.yml`
and `gh run list --workflow "Build Tutor Images"`, or use the current tracking
issue when one is active. Do not call onboarding fixed from an old green run if
a newer source/render/build-helper change has not passed its required proof.

These are shared proof lanes, not alternate build systems. Do not create a
second Dockerfile, Compose stack, or local-only build path to work around a
failure. Classify the failure, fix the source/render/build-helper chain, and
update the proof matrix when the contract changes.

The initialized-state verifier is the only local first-run route authority. It
uses bounded HTTP retries because LMS, Studio, MFEs, and Discovery can warm at
different speeds after `tutor local start -d`. A readiness failure still means
the stack did not converge; rerun `./scripts/infra/verify-local-bootstrap-readiness.sh`
after checking the named route logs instead of treating one successful service
as whole-stack proof.

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
for plugin in mfe discovery forum notes xqueue; do tutor plugins enable "$plugin"; done
tutor plugins disable aspects ecommerce

./scripts/infra/tutor-config-save.sh \
  --set LMS_HOST=localhost \
  --set CMS_HOST=studio.localhost \
  --set MFE_HOST=apps.localhost \
  --set DISCOVERY_HOST=discovery.localhost \
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
  --set REDIS_PORT=6379
```

The config wrapper syncs the repo-local Tutor plugin mirror and enables the
canonical plugins with `tutor plugins enable mereka_lms` and
`tutor plugins enable mereka_lms_mfe_slots` before saving config.
The local first-run wrapper also enables `mfe`, `discovery`, `forum`, `notes`,
and `xqueue`, and disables optional `aspects`/legacy `ecommerce` for the default
local lane. Aspects/Superset is reserved for the Kubernetes/devspace preview lane
unless you explicitly own host port `8088`.

```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/infra/ensure-buildx-dependency-mirror.sh
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
tutor local launch -I --skip-build
make tutor-start
./scripts/infra/verify-local-bootstrap-readiness.sh
```

Always run the launch/init step in the first-run lane, even if `tutor_env/data/mysql`
already exists from a failed or interrupted attempt. A data directory can exist
without the `openedx` MySQL user, migrations, or Django site rows that readiness
requires.

The local quick start builds `openedx:nightly` and `openedx-mfe:nightly`, then points Tutor at those exact tags. The build helpers may skip rebuilding only when the existing local tag carries matching rendered context, build-profile, and build-scope labels. A `proof` image tagged as `:nightly` is not reusable for the default `fast` local setup just because its context hash matches. Render prep applies the named dependency-image mirror patch for Tutor-emitted hardcoded Docker Hub dependency refs, selects a repo-owned BuildKit builder with a `docker.io` registry mirror as a fallback guard, and uses `mirror.gcr.io` where Tutor exposes third-party service/helper image refs. That is dependency acquisition only; it does not create a second Dockerfile or image strategy.

Before reusing the repo-owned local BuildKit builder, `./scripts/infra/ensure-buildx-dependency-mirror.sh` also checks whether the idle builder container still has stale build executor processes such as `npm`, `node`, or shell wrappers from an interrupted image build. If the builder is idle, the helper recreates only that repo-owned builder. If any `docker buildx build`, `docker buildx bake`, `docker pull`, or `buildctl` process is still active, it refuses to mutate the builder and prints the active process evidence. That failure means another build is in flight; wait for it to finish before rerunning setup.

For whole-stack daily runtime control after first launch, use the existing
Makefile lifecycle wrappers. Keep raw `tutor local ...` commands for first
launch, `do init`, targeted service recovery, and low-level debugging only.

To force a local image rebuild even when `openedx:nightly` or `openedx-mfe:nightly` already exists:

```bash
FORCE_LOCAL_IMAGE_BUILD=1 ./scripts/shared/setup-local.sh
```

To force recreation of only the local dependency-mirror BuildKit builder after an interrupted build:

```bash
MEREKA_RECREATE_BUILDX_MIRROR=1 ./scripts/infra/ensure-buildx-dependency-mirror.sh
```

The command is guarded; it will fail instead of removing the builder while another Docker/BuildKit build or pull is active.

## Verification Checklist

Run these to verify everything works:

```bash
# Check source/docs contract without starting Docker
./scripts/qa/verify-cold-start-onboarding-contract.sh

# Check initialized local Tutor state after setup
./scripts/infra/verify-local-bootstrap-readiness.sh

# Optional: inspect the rendered Compose state directly
tutor local dc ps

# Check config is local (not cloud)
grep -E "MYSQL_HOST|MONGODB_HOST" tutor_env/config.yml
# Should show: mysql, mongodb (NOT 10.97.0.2)

# Test URLs
curl -I http://localhost                    # LMS
curl -I http://studio.localhost             # Studio  
curl -I http://apps.localhost/authn/login   # MFE Login
curl -I http://discovery.localhost          # Discovery
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

If a current-head bootstrap run is cancelled after a successful `tutor local
launch` phase, rerun the proof before calling the source broken. If it fails
with a real error, classify the failure first as source-truth bug,
rendered-truth bug, workflow portability bug, runner-capacity issue, or
bootstrap harness bug before changing code or verifiers.

## Daily Commands

```bash
# Whole-stack daily runtime control
make tutor-start

# Stop
make tutor-stop

# After config changes
./scripts/infra/tutor-config-save.sh --set KEY=value
make tutor-restart

# Fast local image rebuilds through the canonical helpers
make local-build-openedx
make local-build-mfe

# Initialized-state readiness proof after setup
make local-proof
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

**"MFE build keeps failing after a cancelled npm/build stage"**
```bash
MEREKA_RECREATE_BUILDX_MIRROR=1 ./scripts/infra/ensure-buildx-dependency-mirror.sh
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```
If the helper reports active build processes, do not remove Buildx containers by hand; wait for the active build or pull to finish, then rerun the command.

**Config shows cloud IPs**
```bash
./scripts/infra/tutor-config-save.sh --set MYSQL_HOST=mysql --set MONGODB_HOST=mongodb
make tutor-restart
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
