# Local Workflow Cheat Sheet
_Audience: Platform Eng • Owner: Infra Team • Last verified: 2026-04-23 • Status: supporting_

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

After any Tutor config or plugin change:

```bash
./scripts/infra/tutor-config-save.sh
```

> **Why?** Tutor rewrites rendered templates each time you save. The canonical wrapper regenerates config, re-prepares the Tutor build context, and runs verification in one path.

## 3. Start / Stop Cycle

Fast first boot from a fresh checkout:

```bash
make local-first-run
```

That wrapper expands to the canonical onboarding chain: `git submodule update --init --recursive`, `./scripts/qa/verify-cold-start-onboarding-contract.sh`, and `./scripts/shared/setup-local.sh`. `setup-local.sh` owns exactly one bounded initialized-state readiness proof via `./scripts/infra/verify-local-bootstrap-readiness.sh`.
It always runs `tutor local launch -I --skip-build` after image convergence; a
partial `tutor_env/data/mysql` directory is not initialized database truth.

Manual first boot when debugging the setup script step by step:

```bash
source infrastructure/tutor/tutor-env.sh
./scripts/infra/tutor-config-save.sh
./scripts/infra/prepare-tutor-build-context.sh --target all
./scripts/infra/ensure-buildx-dependency-mirror.sh
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
tutor local launch -I --skip-build
./scripts/infra/verify-local-bootstrap-readiness.sh
```

`verify-local-bootstrap-readiness.sh` is the local first-run route authority. It
performs bounded HTTP retries because app workers can finish warm-up after
Compose reports the containers as running. A route failure after that window is
still actionable runtime evidence and should be fixed at the owning source/render
path.

The Buildx dependency-mirror helper is local builder hygiene, not a separate
build lane. It checks for stale `npm`, `node`, and shell executor processes in
the repo-owned idle BuildKit builder, recreates that builder only when safe, and
refuses cleanup while another Docker/BuildKit build or pull is active.

Whole-stack daily runtime control after bootstrap:

```bash
make tutor-start         # bring the stack up
make tutor-stop          # stop all containers
make tutor-restart       # re-apply rendered config to the whole stack
make local-proof         # recheck initialized-state readiness
make local-build-openedx # rebuild Open edX through the canonical helper
make local-build-mfe     # rebuild MFEs through the canonical helper
```

Use raw `tutor local ...` subcommands below only for low-level `run`, `logs`,
targeted service recovery, or first-launch/bootstrap operations.

## 4. Quick Service Health Checks

```bash
tutor local dc ps                           # rendered Docker Compose status
curl -I http://localhost                    # LMS
curl -I http://studio.localhost             # Studio
curl -I http://discovery.localhost          # Discovery
```

If forum restarts repeatedly, run the troubleshooting commands documented in [`LOCAL_SETUP.md`](LOCAL_SETUP.md#troubleshooting).

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

Store screenshots under `screenshots/` with a descriptive filename (e.g., `screenshots/lms-home.png`) and attach them to the current evidence or status surface rather than a guide-root tracker.

## 9. Troubleshooting Highlights

- **LMS/Studio return 500** → rerun `make local-first-run` or `tutor local launch -I --skip-build` (recreates MySQL users & migrations).
- **Forum stuck restarting** → check forum v2 logs via `tutor local logs forum` (forum is Python-based, no rake commands).
- **MySQL refuses connections** → stop stack, `rm -rf tutor_env/data/mysql`, rerun launch.
- **Buildx/MFE build still looks stuck after an interrupted build** → run `MEREKA_RECREATE_BUILDX_MIRROR=1 ./scripts/infra/ensure-buildx-dependency-mirror.sh`; if active build evidence is printed, wait for that build or pull to finish instead of deleting Buildx containers by hand.

Refer to [`LOCAL_SETUP.md`](LOCAL_SETUP.md#troubleshooting) for the full table of failure modes.
