# Repository Guidelines

## Project Structure & Module Organization
Most automation lives under `ops/`: `ops/tutor/` hosts the Tutor configuration templates and the `apply-patches.sh` helper, while `ops/tutor-env.sh` bootstraps the repo-aware shell environment. Reference runbooks and roadmaps sit in `docs/`. The generated Tutor state (`tutor_env/`) is git-ignored; use `ops/tutor/config.example.yml` as a starting point for new overrides.

## Build, Test, and Development Commands
- `python3 -m venv .venv` then `source ops/tutor-env.sh` to refresh and activate the local toolchain.
- `tutor images build mfe` rebuilds the micro-frontend image with the Node 18 patch applied.
- `tutor local quickstart -I` performs an end-to-end configure + launch of the nightly stack.
- `tutor local start -d` / `tutor local stop` manage day-to-day lifecycle; add `tutor local dc ps` to inspect container health and `tutor local logs --tail=100` to debug.
- `./ops/tutor/apply-patches.sh` keeps both the MFE Dockerfile on Node 18 and injects `MYSQL_ROOT_HOST` into Tutor’s compose templates so the `mysql/mysql-server:5.7` image accepts remote root connections.

## Branding Maintenance
- Theme tokens/fonts live in `ops/themes/mereka` with the spec documented in `docs/BRANDING.md`; sync new assets into `assets/branding/` first, then copy to `ops/themes/mereka/common/static/`.
- Enable the LMS/Studio theme locally by running `tutor config save --set THEME_DIR="$(pwd)/ops/themes" --set THEME_NAME=mereka`, followed by `tutor images build openedx` and `tutor local start -d`.
- For MFEs cloned under `tutor_env/dev/frontend-app-*`, create a local SCSS entrypoint that imports `../../ops/themes/mereka/scss/theme.scss` (override `$mereka-font-path` to point at the app’s `public/fonts/` directory) so every app consumes the same Paragon overrides.
- After any theme edit, rebuild `openedx`/`mfe` images (or rerun `npm start`) and capture screenshots before shipping.

## Coding Style & Naming Conventions
Shell scripts should begin with `#!/usr/bin/env bash`, enable `set -euo pipefail`, and prefer descriptive function names over inline command chains. Keep Bash indented with two spaces; YAML templates should mirror Tutor defaults and group environment variables in uppercase (e.g., `OPENEDX_RELEASE`). When extending scripts, mirror the existing comment style that summarizes intent rather than mechanics.

## Testing Guidelines
Treat `tutor local quickstart -I` as the acceptance test for major changes—capture failures before opening a PR. Use `tutor local dc ps` to confirm every service reports `Up`, and spot-check critical logs with `tutor local logs --tail=50 service`. If you alter the MFE patches, confirm `node:18` appears in the generated Dockerfile under `tutor_env/env/plugins/mfe/build/mfe/`, and sanity-check `tutor_env/env/local/docker-compose.yml` still exposes `MYSQL_ROOT_HOST: "%"`.

## Commit & Pull Request Guidelines
There is no upstream history yet, so follow Conventional Commits (`feat:`, `fix:`, `docs:`) to seed a consistent log; e.g., `fix: ensure tutor env script exits when .venv missing`. PRs should include a concise summary, the Tutor commands you ran, and links to any relevant docs you touched. Attach log excerpts or screenshots whenever behaviour changes, and request review before rolling out infrastructure-affecting adjustments.

## Security & Configuration Notes
Never commit secrets—`tutor_env/config.yml` stays local and is recreated from `ops/tutor/config.example.yml`. Run `tutor local do backup-db` before upgrades and stash dumps outside the repo. When experimenting with new Tutor plugins or releases, isolate the changes under a feature branch and document toggles in `docs/` so operators can reproduce the configuration, and re-run the patch script immediately after each `tutor config save`.
