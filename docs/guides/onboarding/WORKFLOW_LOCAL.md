# Local Workflow Cheat Sheet
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2026-04-21 • Status: supporting_

Your daily reference for working on the Tutor sandbox. For detailed setup instructions see [`LOCAL_SETUP.md`](LOCAL_SETUP.md).

## 1. Environment Prep

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements-tutor.txt
```

Whenever you open a new shell:

```bash
source infrastructure/tutor/tutor-env.sh
```

## 2. Regenerate / Apply Patches

After any `tutor config save` or plugin change:

```bash
./scripts/infra/tutor-config-save.sh
```

> **Why?** Tutor rewrites rendered templates each time you save. The canonical wrapper regenerates config, re-prepares the Tutor build context, and runs verification in one path.

## 3. Start / Stop Cycle

First boot (runs migrations + init jobs):

```bash
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
tutor local launch -I --skip-build
```

Daily use:

```bash
tutor local start -d     # bring the stack up
tutor local stop         # stop all containers
```

## 4. Quick Service Health Checks

```bash
tutor local status                          # docker-compose ps
curl -I http://localhost                    # LMS
curl -I http://studio.localhost             # Studio
curl -I http://discovery.localhost          # Discovery
curl -I http://ecommerce.localhost          # expect 302→/dashboard/login
```

If ecommerce or forum restart repeatedly, run the troubleshooting commands documented in [`LOCAL_SETUP.md`](LOCAL_SETUP.md#troubleshooting).

## 5. Data Imports (Kajabi)

Users (local sandbox):

```bash
tutor local run --volume="$(pwd)/scripts/migrations/kajabi/openedx_bulk_import.py:/tmp/openedx_bulk_import.py:ro" \
  --volume="$(pwd)/scripts/migrations/kajabi/output/openedx/users_import.csv:/tmp/kajabi-users.csv:ro" \
  lms python /tmp/openedx_bulk_import.py users --csv /tmp/kajabi-users.csv --settings=lms.envs.tutor.production
```

Enrollments: same command with the `enrollments` sub-command and CSV. See [`KAJABI_MIGRATION.md`](../../ops/runbooks/migrations/kajabi/KAJABI_MIGRATION.md) for the full pipeline.

## 6. Micro-Frontend Development

```bash
tutor dev start mfe --detach
./scripts/branding/setup-mfe-branding.sh # clones/wires fonts + logos
cd tutor_env/dev/frontend-app-learning
npm install
npm start                                # hot reload on localhost:<port>
```

Lint all MFEs:

```bash
for app in frontend-app-learning frontend-app-account frontend-app-authn frontend-app-profile frontend-app-gradebook frontend-app-course-authoring; do
  (cd tutor_env/dev/$app && npm run lint)
done
```

## 7. Theme Asset Sync

When brand files change:

```bash
./scripts/branding/sync-brand-assets.sh   # updates infrastructure/tutor/themes/mereka/* and MFE copies
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

## 8. Screenshots & QA

Use the Playwright helper bundled in the repo or your browser DevTools to capture:
- `http://localhost` (LMS)
- `http://studio.localhost`
- `http://discovery.localhost`
- `http://ecommerce.localhost` (after logging in via LMS)

Store screenshots under `screenshots/` with a descriptive filename (e.g., `screenshots/lms-home.png`) and attach them to the current evidence or status surface rather than a guide-root tracker.

## 9. Troubleshooting Highlights

- **LMS/Studio return 500** → rerun `tutor local do init` (recreates MySQL users & migrations).
- **Forum stuck restarting** → check forum v2 logs via `tutor local logs forum` (forum is Python-based, no rake commands).
- **Ecommerce “Access denied”** → `tutor local do init --limit=ecommerce`.
- **MySQL refuses connections** → stop stack, `rm -rf tutor_env/data/mysql`, rerun launch.

Refer to [`LOCAL_SETUP.md`](LOCAL_SETUP.md#troubleshooting) for the full table of failure modes.
