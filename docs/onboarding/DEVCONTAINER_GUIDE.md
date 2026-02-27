# Devcontainer Guide

_Last updated: 2026-02-27_

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
- Node 18 (required for Tutor MFE builds)
- Tutor 18.2.2 + tutor-mfe 18.1.0
- shellcheck, shfmt, ruff, pre-commit, uv, gh CLI
- kubectl and helm (via devcontainer features)
- Docker-in-Docker (so Tutor can run Docker Compose services)
- Git submodules initialised
- Pre-commit hooks installed
- Tutor configured with local Docker service names (`mysql`, `mongodb`, `redis`)
- Mereka patches applied via `apply-patches.sh`
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
# Build Open edX platform image
tutor images build openedx

# Build micro-frontends image
tutor images build mfe
```

Then start the platform:

```bash
# Option A: full launch (initialises DB, creates admin, starts everything)
tutor local launch -I --skip-build
./infrastructure/tutor/apply-patches.sh
tutor local restart

# Option B: use Makefile wrapper
make tutor-start
```

Create an admin user after first launch:

```bash
docker exec tutor_local-lms-1 python /openedx/edx-platform/manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
u, _ = User.objects.get_or_create(username='admin')
u.set_password('admin123')
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

Default credentials: `admin` / `admin123`.

## Daily Workflow

```bash
# Start services
make tutor-start

# Stop services
make tutor-stop

# After Tutor config changes (CRITICAL: always run apply-patches.sh)
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh
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
tutor config save --set MYSQL_HOST=mysql --set MONGODB_HOST=mongodb --set REDIS_HOST=redis
./infrastructure/tutor/apply-patches.sh
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

- Quick start: `docs/onboarding/QUICK_START_LOCAL.md`
- Full setup guide: `docs/onboarding/DEVELOPER_ONBOARDING.md`
- Troubleshooting: `docs/operations/TROUBLESHOOTING.md`
- CLAUDE.md: project conventions and agent workflow
