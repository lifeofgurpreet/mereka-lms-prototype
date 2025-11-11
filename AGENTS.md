# Repository Guidelines

## Project Structure & Module Organization
Most automation lives under `ops/`: `ops/tutor/` hosts the Tutor configuration templates and the `apply-patches.sh` helper, while `ops/tutor-env.sh` bootstraps the repo-aware shell environment. Reference runbooks and roadmaps sit in `docs/`. The generated Tutor state (`tutor_env/`) is git-ignored; use `ops/tutor/config.example.yml` as a starting point for new overrides.

## Build, Test, and Development Commands
- `python3 -m venv .venv` then `source ops/tutor-env.sh` to refresh and activate the local toolchain.
- Redwood’s asset build needs headroom: configure Docker Desktop with ≥12 GB RAM and 2–4 GB swap (Settings → Resources) before running `tutor images build openedx`.
- `tutor images build mfe` rebuilds the micro-frontend image with the Node 18 patch applied.
- `tutor local quickstart -I` performs an end-to-end configure + launch of the nightly stack.
- `tutor local start -d` / `tutor local stop` manage day-to-day lifecycle; add `tutor local dc ps` to inspect container health and `tutor local logs --tail=100` to debug.
- `./ops/tutor/apply-patches.sh` keeps Tutor’s rendered local/k8s templates using `--default-authentication-plugin=mysql_native_password` so MySQL 8 starts cleanly after `tutor config save` regenerations.

## Branding Maintenance
- Theme tokens/fonts live in `ops/themes/mereka` with the spec documented in `docs/BRANDING.md`; sync new assets into `assets/branding/` first, then copy to `ops/themes/mereka/common/static/`.
- Enable the LMS/Studio theme locally by running `tutor config save --set THEME_DIR="$(pwd)/ops/themes" --set THEME_NAME=mereka`, executing `./ops/tutor/apply-patches.sh` (fixes MySQL flags), rebuilding `openedx`, and starting the stack.
- Use `./tools/setup-mfe-branding.sh` after `tutor dev start mfe --detach` to clone the canonical MFEs, copy the fonts, and drop `src/styles/mereka.scss` + import stubs. Each repo then runs `npm install && npm start` from `tutor_env/dev/frontend-app-*`.
- After any theme edit, rebuild `openedx`/`mfe` images (or rerun `npm start`) and capture screenshots before shipping.

## Coding Style & Naming Conventions
Shell scripts should begin with `#!/usr/bin/env bash`, enable `set -euo pipefail`, and prefer descriptive function names over inline command chains. Keep Bash indented with two spaces; YAML templates should mirror Tutor defaults and group environment variables in uppercase (e.g., `OPENEDX_RELEASE`). When extending scripts, mirror the existing comment style that summarizes intent rather than mechanics.

## Testing Guidelines
Treat `tutor local quickstart -I` as the acceptance test for major changes—capture failures before opening a PR. Use `tutor local dc ps` to confirm every service reports `Up`, and spot-check critical logs with `tutor local logs --tail=50 service`. If you alter the MFE patches, confirm `node:18` appears in the generated Dockerfile under `tutor_env/env/plugins/mfe/build/mfe/`, and sanity-check `tutor_env/env/local/docker-compose.yml` still exposes `MYSQL_ROOT_HOST: "%"`.

## Commit & Pull Request Guidelines
There is no upstream history yet, so follow Conventional Commits (`feat:`, `fix:`, `docs:`) to seed a consistent log; e.g., `fix: ensure tutor env script exits when .venv missing`. PRs should include a concise summary, the Tutor commands you ran, and links to any relevant docs you touched. Attach log excerpts or screenshots whenever behaviour changes, and request review before rolling out infrastructure-affecting adjustments.

## Security & Configuration Notes
Never commit secrets—`tutor_env/config.yml` stays local and is recreated from `ops/tutor/config.example.yml`. Run `tutor local do backup-db` before upgrades and stash dumps outside the repo. When experimenting with new Tutor plugins or releases, isolate the changes under a feature branch and document toggles in `docs/` so operators can reproduce the configuration, and re-run the patch script immediately after each `tutor config save`.

## Troubleshooting & Site Recovery
**🚨 If the site is down**, start with `docs/ops/TROUBLESHOOTING.md`—it has a 5-command diagnostic checklist. The most common issue is service selector mismatches after pod restarts. Quick fix: run `./tools/fix-service-selectors.sh` to automatically sync all service selectors with current pod instance IDs. Always check `kubectl get endpoints -n mereka-lms` first—empty endpoints (`<none>`) mean services can't route traffic. After any pod restarts or `tutor k8s` commands, verify endpoints are populated.
