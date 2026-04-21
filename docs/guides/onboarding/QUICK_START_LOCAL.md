# Quick Start: Local Development Setup
_Audience: Developers + Agent Operators • Owner: Platform Team • Last verified: 2026-04-21 • Status: canonical_

## Fast Setup

```bash
git clone git@github.com:Biji-Biji-Initiative/mereka-lms.git
cd mereka-lms
./scripts/qa/verify-cold-start-onboarding-contract.sh
./scripts/shared/setup-local.sh
./scripts/infra/verify-local-bootstrap-readiness.sh
```

The first run builds local Open edX and MFE images, initializes Tutor data, starts the stack, and creates a local-only admin user. If `LOCAL_ADMIN_PASSWORD` is not set, the setup script writes generated credentials to `tutor_env/local-admin-credentials.txt`.

## Latest Proof

Current `main` proof from 2026-04-21:

| Proof | Run | Commit | Result | What it proves |
|---|---|---|---|---|
| Build Tutor Images | `24711505579` | `e7a4472cd` | success | Existing source/render/build-helper path builds and scans both Open edX and MFE images. |
| Bootstrap Local Readiness | `24711453019` | `e7a4472cd` | success | A clean repo-scoped `TUTOR_ROOT` can launch the local Tutor baseline and pass readiness checks. |

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
  --set REDIS_PORT=6379
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

The clean bootstrap proof is [`.github/workflows/bootstrap-local-readiness.yml`](../../../.github/workflows/bootstrap-local-readiness.yml). It creates a fresh repo-scoped `TUTOR_ROOT`, launches `tutor local launch -I --skip-build`, validates image provenance, and runs `./scripts/infra/verify-local-bootstrap-readiness.sh`.

The bootstrap workflow uses the same Tutor render path as local setup, including the named dependency-image mirror patch for Tutor-emitted hardcoded Docker Hub refs and `mirror.gcr.io` settings where Tutor exposes dependency images. The benchmark image-build proof also configures BuildKit with a `docker.io` registry mirror as a fallback guard, but the explicit render patch is what makes the known upstream dependency refs deterministic. Those mirror settings are not build semantic changes; they exist so proof and first-run setup do not depend on anonymous Docker Hub quota.

The CI bootstrap and build workflows also perform bounded pre-checkout cleanup
for repo-generated state (`tutor_env`, `var/bootstrap-readiness`, `var/ci`,
and `.buildx-cache`). That cleanup exists because containerized Tutor steps can
leave root-owned files on persistent fastlane runners. It is runner hygiene only;
it does not change build semantics.

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

Do not mark cold-start onboarding fixed until the offline contract passes, the bootstrap workflow is green for the branch being merged, and app-cache-cold image build proof is either green or explicitly waived with a fresh reason.

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
