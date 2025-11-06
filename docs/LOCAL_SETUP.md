# Local Tutor Sandbox

These instructions reproduce the nightly Open edX environment provisioned in this repository.

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
pip install \
  tutor-openedx==12.2.0 \
  tutor-mfe==12.1.0 \
  tutor-discovery==12.0.4 \
  tutor-notes==12.0.0 \
  tutor-android==12.0.1 \
  tutor-ecommerce==12.0.4 \
  tutor-xqueue==12.1.0

./ops/tutor/apply-patches.sh
```

> ❗ The legacy `tutor-license` plugin does not compile against Python 3.12 (`longintrepr.h` removed). We will revisit licensing once an updated plugin is published.

## Environment helpers

Source the helper script whenever you enter a new shell:

```bash
source ops/tutor-env.sh
```

This sets `TUTOR_ROOT=$REPO/tutor_env`, `OPENEDX_RELEASE=nightly`, and activates the local virtualenv. Re-run `./ops/tutor/apply-patches.sh` after every `tutor config save` to keep the MFE build using Node 18 until Tutor ships an official fix.

## Configuration

The current configuration pins:

- `LMS_HOST=local.merekaacademy.test`
- `CMS_HOST=studio.local.merekaacademy.test`
- Open edX release branch: `open-release/redwood.master`
- MFE branch: `master` (frontends track the latest master while Redwood branches are published)
- Enabled plugins: `mfe`, `discovery`, `notes`, `android`, `ecommerce`, `xqueue`

To regenerate the environment after editing configuration values:

```bash
source ops/tutor-env.sh
tutor config save \
  --set LMS_HOST=local.merekaacademy.test \
  --set CMS_HOST=studio.local.merekaacademy.test \
  --set DOCKER_IMAGE_MYSQL=docker.io/mysql/mysql-server:5.7 \
  --set MYSQL_ROOT_HOST=% \
  --set OPENEDX_COMMON_VERSION=open-release/redwood.master \
  --set OPENEDX_LMS_VERSION=open-release/redwood.master \
  --set OPENEDX_CMS_VERSION=open-release/redwood.master \
  --set MFE_COMMON_VERSION=master \
  --set MFE_DOCKER_IMAGE=openedx-mfe:nightly
./ops/tutor/apply-patches.sh
tutor plugins enable ecommerce xqueue
tutor local init --limit=ecommerce,xqueue
```

Secrets (`config.yml`) live in `tutor_env/` which is git-ignored. For reference, `ops/tutor/config.example.yml` records the non-secret overrides.
> ℹ️ `tutor-credentials` has no Tutor 12-compatible release (latest wheel targets Tutor >=16). Skip certificate automation until Tutor publishes a 12.x build.

## Initial launch

```bash
source ops/tutor-env.sh
tutor images build mfe        # builds openedx-mfe:nightly with Node 18
tutor local quickstart -I     # configure + start everything in detached mode
```

The launch wizard will:

1. Pull nightly Docker images.
2. Create MySQL and MongoDB data volumes.
3. Run database migrations and seed demo content.
4. Start the LMS, Studio, forum, MFEs, discovery, and Android build services.

Use `tutor local start -d` / `tutor local stop` for daily use, and `tutor local dc ps` or `tutor local logs --tail=100` to inspect health.

### Access

Add the following to `/etc/hosts` (or `C:\Windows\System32\drivers\etc\hosts`):

```
127.0.0.1   local.merekaacademy.test studio.local.merekaacademy.test
127.0.0.1   apps.local.merekaacademy.test discovery.local.merekaacademy.test
127.0.0.1   ecommerce.local.merekaacademy.test xqueue.local.merekaacademy.test
```

Then browse to:

- http://local.merekaacademy.test (LMS)
- http://studio.local.merekaacademy.test (Studio)
- http://apps.local.merekaacademy.test (Micro-Frontends shell)
- http://discovery.local.merekaacademy.test (Course Discovery)
- http://ecommerce.local.merekaacademy.test (Otto commerce console)
- http://xqueue.local.merekaacademy.test (XQueue status dashboard)

Create a superuser for manual testing:

```bash
source ops/tutor-env.sh
tutor local createuser --superuser --staff -p mereka_admin mereka_admin mereka@example.com
```

## Daily development workflow

- Start/stop stack: `tutor local start -d` / `tutor local stop`.
- Bring services back after config changes: rerun `tutor config save`, `./ops/tutor/apply-patches.sh`, then `tutor local restart lms cms mfe ecommerce`.
- Keep databases clean while iterating on configuration: `docker-compose -f tutor_env/env/local/docker-compose.yml -f tutor_env/env/local/docker-compose.prod.yml down -v && rm -rf tutor_env/data`.

### MFE development

Tutor’s dev plugin hot-reloads micro-frontends without rebuilding Docker images:

```bash
source ops/tutor-env.sh
tutor dev start mfe --detach
cd tutor_env/dev/frontend-app-learning   # example app after tutor clones it
npm install
npm start
```

Run unit tests with `tutor dev run mfe npm test -- --watch`. The Node 18 patch is idempotent; re-run `./ops/tutor/apply-patches.sh` whenever Tutor regenerates templates.
Design work references Paragon components and tokens (`https://edx.github.io/paragon/`); theme overrides live alongside the cloned MFEs.

### Backend customization & QA

- Django shell/tests: `tutor local run lms ./manage.py lms shell` or `tutor local run lms ./manage.py lms test <app>`.
- Regression checklist after config or plugin changes:
  1. `tutor local dc ps` shows every container `Up`.
  2. LMS/Studio login with `mereka_admin` succeeds.
  3. Commerce dashboard loads and can sync catalogs (`tutor local run ecommerce ./manage.py migrate` if queues fall behind).
  4. `tutor local logs mfe --tail=50` stays clean after page refresh.

## Maintenance

- Capture backups before upgrades: `tutor local stop && tutor local do backup-db`. Store dumps outside this repo.
- Update packages regularly: `pip install --upgrade tutor-openedx tutor-mfe tutor-discovery tutor-notes tutor-android tutor-ecommerce tutor-xqueue` (keeping within the 12.x line until we intentionally move to Tutor 20+).
- After any upgrade, rerun `./ops/tutor/apply-patches.sh` before rebuilding MFEs.
- Apply Tutor upgrades: `source ops/tutor-env.sh && tutor local do upgrade`.

## Troubleshooting

- Docker image pulls are large; if the quickstart fails mid-way, rerun `tutor local quickstart -I` after ensuring adequate disk space.
- For plugin template changes, run `tutor config save` to regenerate YAML manifests.
- If you see `pkg_resources` deprecation warnings, they are safe with Tutor 12.x; the upstream plan is to replace the dependency before 2025.
