# Local Tutor Sandbox
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2025-11-09_

These instructions reproduce the nightly Open edX environment provisioned in this repository. For a day-to-day command cheat sheet, see [`WORKFLOW_LOCAL.md`](WORKFLOW_LOCAL.md). For the complete documentation index, visit [`docs/README.md`](README.md).

## Prerequisites

- macOS or Linux host with at least 8 vCPU, 16 GB RAM, 40 GB free disk.
- Docker Engine 28+ and Docker Compose v2.
- Python 3.12 (system) with `venv` module.
- GNU Make (optional, handy for future automation).
- `gcloud` CLI (already installed for future GCP work).

## Bootstrap

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install "tutor[full]==18.2.2" tutor-mfe==18.1.0

./infrastructure/tutor/apply-patches.sh
```

Installing `tutor[full]` pulls the Tutor 18 core plus the first-party plugins (discovery, ecommerce, notes, xqueue, forum). The separate `tutor-mfe` wheel pins the MFE plugin version used by our Redwood stack.

> ❗ The legacy `tutor-license` plugin does not compile against Python 3.12 (`longintrepr.h` removed). We will revisit licensing once an updated plugin is published.

## Environment helpers

Source the helper script whenever you enter a new shell:

```bash
source infrastructure/tutor/tutor-env.sh
```

This sets `TUTOR_ROOT=$REPO/tutor_env`, `OPENEDX_RELEASE=nightly`, and activates the local virtualenv. Re-run `./infrastructure/tutor/apply-patches.sh` after every `tutor config save` to keep the MFE build using Node 18 until Tutor ships an official fix.

### Docker resources

Redwood’s asset pipeline easily bursts past 6 GB of RAM while `npm run webpack` is running inside the `openedx` build. Configure Docker Desktop (Settings → Resources) with **at least 12 GB RAM** and **2–4 GB of swap** so the build does not OOM. You can verify the limit at any time via `docker info | grep "Total Memory"`.

## Configuration

The current configuration pins:

- `LMS_HOST=localhost`
- `CMS_HOST=studio.localhost`
- Open edX release branch: `open-release/redwood.master`
- MFE branch: `master` (frontends track the latest master while Redwood branches are published)
- Enabled plugins: `mfe`, `discovery`, `notes`, `ecommerce`, `forum`, `xqueue`

To regenerate the environment after editing configuration values:

```bash
source infrastructure/tutor/tutor-env.sh
tutor config save \
  --set LMS_HOST=localhost \
  --set CMS_HOST=studio.localhost \
  --set DISCOVERY_HOST=discovery.localhost \
  --set ECOMMERCE_HOST=ecommerce.localhost \
  --set MFE_HOST=apps.localhost \
  --set XQUEUE_HOST=xqueue.localhost \
  --set DOCKER_IMAGE_MYSQL=docker.io/mysql:8.0 \
  --set MYSQL_ROOT_HOST=% \
  --set OPENEDX_COMMON_VERSION=open-release/redwood.master \
  --set OPENEDX_LMS_VERSION=open-release/redwood.master \
  --set OPENEDX_CMS_VERSION=open-release/redwood.master \
  --set MFE_COMMON_VERSION=master \
  --set MFE_DOCKER_IMAGE=openedx-mfe:nightly
./infrastructure/tutor/apply-patches.sh
tutor plugins enable discovery ecommerce forum mfe notes xqueue
./infrastructure/tutor/apply-patches.sh
```

Enabling/disabling plugins regenerates the rendered Tutor environment, so always rerun `./infrastructure/tutor/apply-patches.sh` afterwards to keep the Caddy/MySQL tweaks in sync.

Secrets (`config.yml`) live in `tutor_env/` which is git-ignored. For reference, `infrastructure/tutor/config.example.yml` records the non-secret overrides.
> ℹ️ `tutor-credentials` has no Tutor 12-compatible release (latest wheel targets Tutor >=16). Skip certificate automation until Tutor publishes a 12.x build.

### Apply the Mereka Theme

The shared palette/typography overrides live under `infrastructure/tutor/themes/mereka` (see `docs/BRANDING.md`). After sourcing `infrastructure/tutor/tutor-env.sh`, point Tutor at that directory and rebuild the LMS/Studio images:

```bash
source infrastructure/tutor/tutor-env.sh
tutor config save \
  --set THEME_DIR="$(pwd)/infrastructure/tutor/themes" \
  --set THEME_NAME=mereka
./infrastructure/tutor/apply-patches.sh
tutor images build openedx
tutor local start -d
```

Tutor will copy everything under `infrastructure/tutor/themes/` into `tutor_env/build/openedx/themes` and compile the SCSS entrypoints located at `infrastructure/tutor/themes/mereka/{lms,cms}/static/sass/theme.scss`. Re-run `tutor images build openedx` whenever you edit the theme SCSS or add new assets (fonts, logos).

## Initial launch

```bash
source infrastructure/tutor/tutor-env.sh
tutor images build mfe        # rebuild if you've touched the shared SCSS
tutor local launch -I --skip-build
./infrastructure/tutor/apply-patches.sh
tutor local restart lms cms mfe caddy
```

The launch wizard will:

1. Pull nightly Docker images.
2. Create MySQL and MongoDB data volumes.
3. Run database migrations and seed demo content.
4. Start the LMS, Studio, forum, MFEs, discovery, and Android build services.

Use `tutor local start -d` / `tutor local stop` for daily use, and `tutor local dc ps` or `tutor local logs --tail=100` to inspect health.

> ⏱ `tutor local launch` may run for 10–15 minutes on the first pass while it runs Django migrations. If your terminal times out, re-run `tutor local do init` until it completes—the `openedx` MySQL user will be missing otherwise, and the LMS/Studio will 500 with “Access denied for user 'openedx'”.

### Local vs Production Data

- The stack uses Dockerized MySQL/Mongo/Redis under `tutor_env/data/`; **no production data is copied** unless you import it.
- To work with real Kajabi data locally, generate the CSVs/tarballs under `scripts/migrations/kajabi/output/` (see [`KAJABI_MIGRATION.md`](KAJABI_MIGRATION.md)), then run the import helpers described in [`WORKFLOW_LOCAL.md`](WORKFLOW_LOCAL.md#5-data-imports-kajabi).
- When you finish testing, you can reset the sandbox via:
  ```bash
  tutor local stop
  rm -rf tutor_env/data/mysql tutor_env/data/mongodb tutor_env/data/redis
  tutor local launch -I --skip-build
  ```
- Production uses Cloud SQL / Atlas / managed Redis—never copy secrets or dumps back into git. Store sanitized dumps in the secure bucket referenced in `SECRETS_SNAPSHOT.md`.

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

- Start/stop stack: `tutor local start -d` / `tutor local stop`.
- Bring services back after config changes: rerun `tutor config save`, `./infrastructure/tutor/apply-patches.sh`, then `tutor local restart lms cms mfe ecommerce`.
- Keep databases clean while iterating on configuration: `docker-compose -f tutor_env/env/local/docker-compose.yml -f tutor_env/env/local/docker-compose.prod.yml down -v && rm -rf tutor_env/data`. After wiping `tutor_env/data/mysql`, re-run `tutor local launch -I --skip-build` (or at least `tutor local do init`) so the `openedx` schema and users are recreated before you hit the LMS.

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

Run unit tests with `tutor dev run mfe npm test -- --watch`. Re-run `./infrastructure/tutor/apply-patches.sh` whenever Tutor regenerates templates so the MySQL command stays compatible with 8.0.
Design work references Paragon components and tokens (`https://edx.github.io/paragon/`); theme overrides live alongside the cloned MFEs.

### Previewing the Mereka theme locally

1. Sync fonts/logos into both theme directories:
   ```bash
   ./scripts/branding/sync-brand-assets.sh
   ```
2. Ensure Tutor points at the custom theme:
   ```bash
   tutor config save --set THEME_DIR="$(pwd)/infrastructure/tutor/themes" --set THEME_NAME=mereka
   ```
3. Re-run the patch helper so LMS/Studio templates and the Indigo plugin pick up the latest SCSS, then restart your stack:
   ```bash
   ./infrastructure/tutor/apply-patches.sh
   tutor local start -d
   ```
4. Rebuild MFEs (`tutor images build mfe` or `tutor dev start mfe`) to bundle the same SCSS inside `frontend-app-*`. The plugin automatically imports `mereka/mereka.scss`.

### Backend customization & QA

- Django shell/tests: `tutor local run lms ./manage.py lms shell` or `tutor local run lms ./manage.py lms test <app>`.
- Regression checklist after config or plugin changes:
  1. `tutor local dc ps` shows every container `Up`.
  2. LMS/Studio login with `mereka_admin` succeeds.
  3. Commerce dashboard loads and can sync catalogs (`tutor local run ecommerce ./manage.py migrate` if queues fall behind).
  4. `tutor local logs mfe --tail=50` stays clean after page refresh.

## Maintenance

- Capture backups before upgrades: `tutor local stop && tutor local do backup-db`. Store dumps outside this repo.
- Update packages regularly: `pip install --upgrade "tutor[full]" tutor-mfe` (stay on Tutor 18.2.2 unless we intentionally rebase on the next LTS).
- After any upgrade, rerun `./infrastructure/tutor/apply-patches.sh` before rebuilding MFEs.
- Apply Tutor upgrades: `source infrastructure/tutor/tutor-env.sh && tutor local do upgrade`.

## Troubleshooting

- Docker image pulls are large; if `tutor local launch` fails mid-way, rerun `tutor local launch -I --skip-build` after ensuring adequate disk space (and rerun `tutor local do init` if the LMS still 500s).
- If the forum container keeps restarting with `search:validate_indices` errors, create the expected Elasticsearch indexes with `tutor local run forum rake search:initialize`, then recheck `tutor local status`.
- Ecommerce returning `OperationalError: Access denied for user 'ecommerce'` means the init job didn’t finish—rerun `tutor local do init --limit=ecommerce` to recreate the database, user, and OAuth clients.
- For plugin template changes, run `tutor config save` to regenerate YAML manifests.
- If you see `pkg_resources` deprecation warnings, they are safe with Tutor 12.x; the upstream plan is to replace the dependency before 2025.
