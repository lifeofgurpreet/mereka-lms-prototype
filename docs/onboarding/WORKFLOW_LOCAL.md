# Local Workflow Cheat Sheet
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2025-11-09_

Your daily reference for working on the Tutor sandbox. For detailed setup instructions see [`LOCAL_SETUP.md`](LOCAL_SETUP.md).

_Last verified: 2025‑11‑09_

## 1. Environment Prep

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install "tutor[full]==18.2.2" tutor-mfe==18.1.0
```

Whenever you open a new shell:

```bash
source infrastructure/tutor/tutor-env.sh
```

## 2. Regenerate / Apply Patches

After any `tutor config save` or plugin change:

```bash
tutor config save --env-only        # regenerates tutor_env/env
./infrastructure/tutor/apply-patches.sh        # keeps MySQL flags, forum env, Dockerfiles, etc.
```

> **Why?** Tutor rewrites rendered templates each time you save. The patch script re-applies our Node 18 tweaks, theme pointers, and forum/env adjustments.

## 3. Start / Stop Cycle

First boot (runs migrations + init jobs):

```bash
tutor local launch -I --skip-build
./infrastructure/tutor/apply-patches.sh
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
tutor local run --volume="$(pwd)/ops/migrations/kajabi/scripts/openedx_bulk_import.py:/tmp/openedx_bulk_import.py:ro" \
  --volume="$(pwd)/ops/migrations/kajabi/output/openedx/users_import.csv:/tmp/kajabi-users.csv:ro" \
  lms python /tmp/openedx_bulk_import.py users --csv /tmp/kajabi-users.csv --settings=lms.envs.tutor.production
```

Enrollments: same command with the `enrollments` sub-command and CSV. See [`KAJABI_MIGRATION.md`](KAJABI_MIGRATION.md) for the full pipeline.

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
tutor images build openedx                # LMS/Studio theme rebuild
tutor images build mfe                    # optional if bundling MFEs
```

## 8. Screenshots & QA

Use the Playwright helper bundled in the repo or your browser DevTools to capture:
- `http://localhost` (LMS)
- `http://studio.localhost`
- `http://discovery.localhost`
- `http://ecommerce.localhost` (after logging in via LMS)

Store screenshots under `screenshots/` with a descriptive filename (e.g., `screenshots/lms-home.png`) and link them from `docs/BRANDING_PLAN.md` when checking off tasks.

## 9. Troubleshooting Highlights

- **LMS/Studio return 500** → rerun `tutor local do init` (recreates MySQL users & migrations).
- **Forum stuck restarting** → `tutor local run forum rake search:initialize` (creates Elasticsearch indexes).
- **Ecommerce “Access denied”** → `tutor local do init --limit=ecommerce`.
- **MySQL refuses connections** → stop stack, `rm -rf tutor_env/data/mysql`, rerun launch.

Refer to [`LOCAL_SETUP.md`](LOCAL_SETUP.md#troubleshooting) for the full table of failure modes.
