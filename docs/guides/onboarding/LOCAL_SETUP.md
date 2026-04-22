# Local Tutor Sandbox
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2026-04-22 • Status: supporting_

These instructions reproduce the nightly Open edX environment provisioned in this repository. For a day-to-day command cheat sheet, see [`WORKFLOW_LOCAL.md`](WORKFLOW_LOCAL.md). For the complete documentation index, visit [`docs/README.md`](../../README.md).

## Prerequisites

- macOS or Linux host with at least 8 vCPU, 16 GB RAM, 40 GB free disk.
- Docker Engine 28+ and Docker Compose v2.
- Python 3.12 (system) with `venv` module.
- GNU Make (optional, handy for future automation).
- GitHub CLI (`gh`) only if you want to dispatch the cold-start proof workflow from your shell.

## Bootstrap

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements-tutor.txt
source infrastructure/tutor/tutor-env.sh
```

Installing from `requirements-tutor.txt` pulls the exact Tutor version used by this repo plus required first-party Tutor plugins. Tutor Indigo is retired; Mereka owns theme, MFE runtime, and plugin-slot behavior through the repo-local `mereka_lms` and `mereka_lms_mfe_slots` plugins.
The first rendered build-context refresh happens after configuration below, via `./scripts/infra/prepare-tutor-build-context.sh --target all`; do not use the low-level patch helper as the bootstrap front door.

> ❗ The legacy `tutor-license` plugin does not compile against Python 3.12 (`longintrepr.h` removed). We will revisit licensing once an updated plugin is published.

## Environment helpers

Source the helper script whenever you enter a new shell:

```bash
source infrastructure/tutor/tutor-env.sh
```

This sets `TUTOR_ROOT=$REPO/tutor_env`, `OPENEDX_RELEASE=nightly`, and activates the local virtualenv. For normal setup and config edits, use `./scripts/infra/tutor-config-save.sh`; it enables the canonical plugins, syncs the plugin mirror, renders Tutor state, and prepares build contexts. If you are debugging a low-level render path, `./scripts/infra/prepare-tutor-build-context.sh --target all` is the governed refresh step after render.

### Docker resources

The Ulmo asset pipeline easily bursts past 6 GB of RAM while `npm run webpack` is running inside the `openedx` build. Configure Docker Desktop (Settings → Resources) with **at least 12 GB RAM** and **2–4 GB of swap** so the build does not OOM. You can verify the limit at any time via `docker info | grep "Total Memory"`.

## Configuration

The current configuration pins:

- `LMS_HOST=localhost`
- `CMS_HOST=studio.localhost`
- Open edX release branch: `release/ulmo`
- MFE branch: `release/ulmo.2`
- Enabled repo-owned plugins: `mereka_lms`, `mereka_lms_mfe_slots`; the wrapper also preserves the Tutor service plugins required by the selected configuration.

To regenerate the environment after editing configuration values:

```bash
source infrastructure/tutor/tutor-env.sh
./scripts/infra/tutor-config-save.sh \
  --set LMS_HOST=localhost \
  --set CMS_HOST=studio.localhost \
  --set DISCOVERY_HOST=discovery.localhost \
  --set ECOMMERCE_HOST=ecommerce.localhost \
  --set MFE_HOST=apps.localhost \
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
  --set MYSQL_ROOT_HOST=% \
  --set ASPECTS_SUPERSET_DATABASE_HOST=clickhouse \
  --set OPENEDX_COMMON_VERSION=release/ulmo \
  --set OPENEDX_LMS_VERSION=release/ulmo \
  --set OPENEDX_CMS_VERSION=release/ulmo \
  --set MFE_COMMON_VERSION=release/ulmo.2
```

The wrapper enables the canonical first-party plugins and runs `./scripts/infra/prepare-tutor-build-context.sh --target all` after configuration. Local setup builds `openedx:nightly` and `openedx-mfe:nightly`, then points Tutor at those tags. The render prep applies `infrastructure/tutor/patches/dependency-image-mirrors.sh` for Tutor-emitted hardcoded Docker Hub dependency refs, selects `scripts/infra/ensure-buildx-dependency-mirror.sh` as a BuildKit fallback guard, and uses `mirror.gcr.io` image refs where Tutor exposes third-party service images. If you deliberately enable or disable plugins outside the wrapper, rerun `./scripts/infra/prepare-tutor-build-context.sh --target all` afterwards.

Secrets (`config.yml`) live in `tutor_env/` which is git-ignored. For reference, `infrastructure/tutor/config.example.yml` records the non-secret overrides.

### Apply the Mereka Theme

The shared palette/typography overrides live under `infrastructure/tutor/themes/mereka` (see `docs/guides/branding/BRANDING.md`). After sourcing `infrastructure/tutor/tutor-env.sh`, point Tutor at that directory and rebuild the LMS/Studio images:

```bash
source infrastructure/tutor/tutor-env.sh
./scripts/infra/tutor-config-save.sh \
  --set THEME_DIR="$(pwd)/infrastructure/tutor/themes" \
  --set THEME_NAME=mereka
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
make tutor-start
```

Tutor will copy everything under `infrastructure/tutor/themes/` into `tutor_env/build/openedx/themes` and compile the SCSS entrypoints located at `infrastructure/tutor/themes/mereka/{lms,cms}/static/sass/theme.scss`. Re-run the Open edX build helper whenever you edit the theme SCSS or add new assets.

## Initial launch

```bash
source infrastructure/tutor/tutor-env.sh
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
tutor local launch -I --skip-build
make tutor-start
./scripts/infra/verify-local-bootstrap-readiness.sh
```

The launch wizard will:

1. Use the local `openedx:nightly` and `openedx-mfe:nightly` images built above.
2. Create MySQL and MongoDB data volumes.
3. Run database migrations and seed demo content.
4. Start the LMS, Studio, forum, MFEs, discovery, and supporting Tutor services.

Use `make tutor-start` / `make tutor-stop` for whole-stack daily use, and drop
to `tutor local dc ps` or `tutor local logs --tail=100` only for low-level
runtime inspection. After first launch or a full reset, run
`./scripts/infra/verify-local-bootstrap-readiness.sh` before treating the
sandbox as ready.

> `tutor local launch` may run for 10-60+ minutes on the first pass depending on Docker resources, image freshness, and database init time. If your terminal times out, re-run `tutor local do init` until it completes. The `openedx` MySQL user will be missing otherwise, and the LMS/Studio will 500 with "Access denied for user 'openedx'". Use the bootstrap workflow phase-timing artifact as the current CI reference point instead of assuming a fixed laptop duration.

### Local vs Production Data

- The stack uses Dockerized MySQL/Mongo/Redis under `tutor_env/data/`; **no production data is copied** unless you import it.
- To work with real Kajabi data locally, generate the CSVs/tarballs under `scripts/migrations/kajabi/output/` (see [`KAJABI_MIGRATION.md`](../../ops/runbooks/migrations/kajabi/KAJABI_MIGRATION.md)), then run the import helpers described in [`WORKFLOW_LOCAL.md`](WORKFLOW_LOCAL.md#5-data-imports-kajabi).
- When you finish testing, you can reset the sandbox via:
  ```bash
  make tutor-stop
  rm -rf tutor_env/data/mysql tutor_env/data/mongodb tutor_env/data/redis
  tutor local launch -I --skip-build
  ```
- Production data stores are managed outside local `tutor_env`; never copy secrets or dumps back into git. Store sanitized dumps only in the approved secure storage referenced by the current operations runbooks.

### Access

Modern browsers resolve `*.localhost` to `127.0.0.1`, so no hosts-file entries are required. Once `tutor local launch` completes you can hit:

- http://localhost (LMS)
- http://studio.localhost (Studio)
- http://apps.localhost (MFE shell + OAuth redirect target)
- http://discovery.localhost (Course Discovery)
- http://ecommerce.localhost (Otto console)
- http://notes.localhost (Open edX Notes)
- http://xqueue.localhost (XQueue dashboard)

> Use `curl -I http://localhost` to sanity-check that the LMS is returning `200 OK` instead of `500`. When in doubt re-run `tutor local do init` to recreate the `openedx` MySQL user and migrations.

Create a superuser for manual testing:

```bash
source infrastructure/tutor/tutor-env.sh
tutor local createuser --superuser --staff -p mereka_admin mereka_admin mereka@example.com
```

## Daily development workflow

- Start/stop stack: `make tutor-start` / `make tutor-stop`.
- Bring services back after config changes: rerun `./scripts/infra/tutor-config-save.sh`, then `make tutor-restart`.
- Keep databases clean while iterating on configuration: `make tutor-stop && tutor local down -v && rm -rf tutor_env/data`. After wiping Tutor data, re-run `tutor local launch -I --skip-build` (or at least `tutor local do init`) so service schemas and users are recreated before you hit the LMS.

### MFE development

Tutor’s dev plugin hot-reloads micro-frontends without rebuilding Docker images:

```bash
source infrastructure/tutor/tutor-env.sh
tutor dev start mfe --detach
./scripts/branding/setup-mfe-branding.sh # clones + wires Mereka SCSS/fonts
cd tutor_env/dev/frontend-app-learning   # repeat per app
npm install
npm start
```

Run unit tests with `tutor dev run mfe npm test -- --watch`. Re-run `./scripts/infra/prepare-tutor-build-context.sh --target all` whenever Tutor regenerates templates so the rendered build context and remaining patch-only sync stay current.
Design work references Paragon components and tokens (`https://edx.github.io/paragon/`); theme overrides live alongside the cloned MFEs.

### Previewing the Mereka theme locally

1. Sync fonts/logos into both theme directories:
   ```bash
   ./scripts/branding/sync-brand-assets.sh
   ```
2. Ensure Tutor points at the custom theme:
   ```bash
   ./scripts/infra/tutor-config-save.sh --set THEME_DIR="$(pwd)/infrastructure/tutor/themes" --set THEME_NAME=mereka
   ```
3. Re-run the canonical build-context prepare step so LMS/Studio templates and the rendered MFE build context pick up the latest SCSS, then restart your stack:
   ```bash
   ./scripts/infra/prepare-tutor-build-context.sh --target all
   make tutor-start
   ```
4. Rebuild MFEs with `./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast` to bundle the same SCSS inside `frontend-app-*`. The plugin automatically imports `theme-source/mereka.scss`.

### Backend customization & QA

- Django shell/tests: `tutor local run lms ./manage.py lms shell` or `tutor local run lms ./manage.py lms test <app>`.
- Regression checklist after config or plugin changes:
  1. `tutor local dc ps` shows every container `Up`.
  2. LMS/Studio login with `mereka_admin` succeeds.
  3. Commerce dashboard loads and can sync catalogs (`tutor local run ecommerce ./manage.py migrate` if queues fall behind).
  4. `tutor local logs mfe --tail=50` stays clean after page refresh.

## Maintenance

- Capture backups before upgrades: `make tutor-stop && tutor local do backup-db`. Store dumps outside this repo.
- Update packages regularly: `pip install -r requirements-tutor.txt` (version pins live in `requirements-tutor.txt`).
- After any upgrade, rerun `./scripts/infra/prepare-tutor-build-context.sh --target all` before rebuilding MFEs.
- Apply Tutor upgrades: `source infrastructure/tutor/tutor-env.sh && tutor local do upgrade`.

## Cold-start proof lane

- Source/docs contract: `./scripts/qa/verify-cold-start-onboarding-contract.sh`
- Initialized local state proof: `./scripts/infra/verify-local-bootstrap-readiness.sh`
- Clean bootstrap proof: [`.github/workflows/bootstrap-local-readiness.yml`](../../../.github/workflows/bootstrap-local-readiness.yml)
- App-cache-cold image-build proof: [`.github/workflows/build-benchmark.yml`](../../../.github/workflows/build-benchmark.yml) with `benchmark_class=app-cache-cold` and `image_family=both`

Run the GitHub workflow from a branch with:

```bash
gh workflow run bootstrap-local-readiness.yml --ref "$(git branch --show-current)"
gh workflow run build-benchmark.yml --ref "$(git branch --show-current)" \
  -f runner_class=fastlane \
  -f benchmark_class=app-cache-cold \
  -f image_family=both
```

When fastlane is being investigated, run the same bootstrap proof on the ARC
fallback lane instead of changing the build path:

```bash
gh workflow run bootstrap-local-readiness.yml \
  --ref "$(git branch --show-current)" \
  -f lane_mode=fallback
```

## Troubleshooting

- Docker image pulls are large; if `tutor local launch` fails mid-way, rerun `tutor local launch -I --skip-build` after ensuring adequate disk space (and rerun `tutor local do init` if the LMS still 500s).
- If the forum container keeps restarting, check logs with `tutor local logs forum` — forum v2 is Python-based and uses Meilisearch (no rake commands or Elasticsearch).
- Ecommerce returning `OperationalError: Access denied for user 'ecommerce'` means the init job didn’t finish—rerun `tutor local do init --limit=ecommerce` to recreate the database, user, and OAuth clients.
- For plugin template changes, run `./scripts/infra/tutor-config-save.sh` to regenerate YAML manifests and rendered build contexts.
