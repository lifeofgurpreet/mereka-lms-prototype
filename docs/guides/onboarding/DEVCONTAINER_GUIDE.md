# Devcontainer Guide

_Last updated: 2026-04-21_

_One-click dev environment for Mereka LMS_

## Prerequisites

| Requirement | Minimum | Notes |
|-------------|---------|-------|
| Docker Desktop | 4.x | RAM: 12 GB, Swap: 2-4 GB |
| VS Code | 1.85+ | Or any IDE with Dev Containers support |
| Dev Containers extension | latest | `ms-vscode-remote.remote-containers` |
| Free disk space | 40 GB | Images + data volumes |

Docker Desktop RAM setting: Settings > Resources > Advanced > Memory: 12 GB (16 GB recommended for image builds).

## Opening in a Devcontainer

1. Clone the repository:
   ```bash
   git clone <repo-url> mereka-lms
   cd mereka-lms
   ```

2. Open the folder in VS Code:
   ```bash
   code .
   ```

3. When prompted "Reopen in Container", click it. Or open the Command Palette (`Ctrl+Shift+P`) and run `Dev Containers: Reopen in Container`.

4. VS Code builds the container image and runs `post-create.sh` automatically. This takes 5-10 minutes on first run.

5. After the container starts, a terminal opens inside the container. The post-create script prints next steps when it finishes.

## What Is Pre-configured

The devcontainer sets up the following automatically:

- Python 3.12 with a `.venv` virtual environment
- Node 24+ (required for the current Tutor MFE build contract)
- Tutor and plugins per requirements-tutor.txt
- shellcheck, shfmt, ruff, pre-commit, uv, gh CLI
- kubectl and helm (via devcontainer features)
- Docker-in-Docker (so Tutor can run Docker Compose services)
- Git submodules initialised
- Pre-commit hooks installed
- Tutor configured through `./scripts/infra/tutor-config-save.sh` with local Docker service names (`mysql`, `mongodb`, `redis`)
- Tutor build context prepared by the canonical wrapper
- `TUTOR_ROOT` environment variable set to `<workspace>/tutor_env`
- A named Docker volume (`mereka-lms-tutor-env`) mounts at `tutor_env/` so data persists across container rebuilds

VS Code extensions installed automatically:

- Python + Pylance (Python language support)
- YAML (schema validation for Kustomize)
- ShellCheck (shell script linting)
- Kubernetes (cluster explorer)
- Docker (container management)
- GitLens (enhanced git history)
- Prettier (code formatting)

## Running Tutor Local

On first run you need to build images (30-45 minutes, requires 12 GB RAM):

```bash
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

Then run the first launch and readiness proof:

```bash
tutor local launch -I --skip-build
tutor local restart
./scripts/infra/verify-local-bootstrap-readiness.sh
```

After the first launch has initialized databases, daily starts can use the Makefile wrapper. Do not use `make tutor-start` as a replacement for the first launch on a fresh `tutor_env`.

```bash
make tutor-start
```

Create a local admin user after first launch:

```bash
export LOCAL_ADMIN_PASSWORD='<choose-a-local-only-password>'
docker exec -e LOCAL_ADMIN_PASSWORD tutor_local-lms-1 \
  python /openedx/edx-platform/manage.py lms shell -c "
import os
from django.contrib.auth import get_user_model
User = get_user_model()
u, _ = User.objects.get_or_create(username='admin')
u.set_password(os.environ['LOCAL_ADMIN_PASSWORD'])
u.is_staff = True
u.is_superuser = True
u.save()
print('Admin ready')
"
```

Access URLs (forward ports are configured in `devcontainer.json`):

| Service | URL |
|---------|-----|
| LMS | http://localhost |
| Studio | http://studio.localhost |
| MFE Login | http://apps.localhost/authn/login |
| Admin | http://localhost/admin |

Use the local-only username/password you created during setup. Do not paste shared credentials into this guide or into devcontainer config.

## Daily Workflow

```bash
# Start services
make tutor-start

# Stop services
make tutor-stop

# After Tutor config changes (preferred)
./scripts/infra/tutor-config-save.sh --set KEY=value

# Manual advanced path
tutor config save --set KEY=value
./scripts/infra/prepare-tutor-build-context.sh --target all
make tutor-restart
```

## Running Tests and Lint

```bash
# Spec lint (fast, <30 s)
make check-fast

# Full spec quality suite
make check

# Run smoke tests
make qa-smoke

# Run lint (Python, shell, JS)
make lint
```

## Seeding a Demo Course

Set the environment variable before creating the container to auto-seed, or run manually:

```bash
# Opt-in at container creation time
SEED_DEMO_COURSE=true  # set this in your shell or .env before reopening in container

# Or run manually once services are up
tutor local do importdemocourse
```

## Tutor_env Volume Persistence

`tutor_env/` is mounted from a named Docker volume (`mereka-lms-tutor-env`). This means:

- Data (MySQL, MongoDB, Redis) persists when you rebuild the container image.
- To reset to a clean state, remove the volume:
  ```bash
  docker volume rm mereka-lms-tutor-env
  ```

## Troubleshooting

### Container build fails

Check Docker Desktop has enough RAM (12 GB minimum). Then rebuild:

```bash
# VS Code command palette
Dev Containers: Rebuild Container
```

### "tutor: command not found"

Tutor is installed system-wide in the container. If you are inside `.venv` and it is shadowed, use the full path or deactivate:

```bash
deactivate
tutor --version
```

### Config shows cloud IPs

The post-create script sets local service names. If you see `MYSQL_HOST: 10.97.0.2`:

```bash
./scripts/infra/tutor-config-save.sh \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set RUN_MONGODB=true \
  --set DOCKER_IMAGE_OPENEDX=openedx:nightly \
  --set MFE_DOCKER_IMAGE=openedx-mfe:nightly
make tutor-restart
```

### "Docker daemon not running"

Docker-in-Docker needs a moment to start after container creation. Wait 10-15 seconds, then:

```bash
docker info
```

If it still fails, rebuild the container.

### Services not accessible from host browser

VS Code auto-forwards ports 80, 443, 8000, 8001, 8002. Check the Ports panel (`Ctrl+Shift+P` > `Forward a Port`) and verify forwarding is active.

## Reference

- Quick start: `docs/guides/onboarding/QUICK_START_LOCAL.md`
- Full setup guide: `docs/guides/onboarding/LOCAL_SETUP.md`
- Troubleshooting: `docs/ops/runbooks/TROUBLESHOOTING.md`
- Standing orders: `docs/meta/standing-orders/README.md`
- Architecture authority: `docs/architecture/PLATFORM_AUTHORITY_MAP.md`
