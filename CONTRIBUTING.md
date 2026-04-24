# Contributing to Mereka Academy

Thank you for contributing to the Mereka Academy Open edX project!

## Getting Started

1. Read [`docs/onboarding/DEVELOPER_ONBOARDING.md`](docs/onboarding/DEVELOPER_ONBOARDING.md)
2. Set up your local environment: `make bootstrap`
3. Review the codebase structure in [`README.md`](README.md)

## Code Organization

- **Infrastructure**: `infrastructure/` - Tutor configs, Terraform, K8s manifests
- **Scripts**: `scripts/` - Automation scripts organized by domain
- **Services**: `services/` - Standalone microservices and webhooks
- **Documentation**: `docs/` - Organized by category (onboarding, operations, migrations, etc.)

## Development Workflow

1. Create a feature branch from `main`
2. Make your changes
3. Run linters: `make lint`
4. Format code: `make format`
5. Test locally: `make tutor-start` and `make qa-smoke`
6. Commit using [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `refactor:` for code refactoring
   - `chore:` for maintenance tasks
7. Push and create a pull request

## Code Style

### Python
- Use `ruff` for linting and formatting
- Follow PEP 8 with line length of 100
- Use type hints where appropriate

### Shell Scripts
- Use `#!/usr/bin/env bash`
- Enable `set -euo pipefail`
- Use `shellcheck` for linting
- Format with `shfmt`

### JavaScript/Node
- Use ES modules (`.mjs` extension)
- Follow Prettier formatting
- Use ESLint for linting

## Adding New Scripts

1. Place scripts in the appropriate `scripts/` subdirectory:
   - `infra/` - Infrastructure operations
   - `migrations/` - Data migration scripts
   - `branding/` - Branding asset sync
   - `analytics/` - Analytics exports
   - `qa/` - Quality assurance
   - `shared/` - Shared utilities

2. Add a shebang and error handling
3. Document usage in script header comments
4. Update `scripts/README.md`

## Adding Documentation

1. Place docs in the appropriate `docs/` category:
   - `onboarding/` - Setup and getting started
   - `operations/` - Runbooks and troubleshooting
   - `migrations/` - Migration playbooks
   - `architecture/` - System architecture
   - `status/` - Status trackers

2. Add front-matter metadata (owner, last-verified date)
3. Update `docs/README.md` index
4. Cross-link related documents

## Testing

- Run smoke tests: `make qa-smoke`
- Test Tutor workflows: `make tutor-start` and verify services
- Test migrations: `make migrations-prepare` and `make migrations-verify`

## Pre-commit Hooks

Pre-commit hooks are automatically installed with `make bootstrap`. They will:
- Format Python, Shell, and JavaScript code
- Lint code for common issues
- Check for secrets and large files
- Validate YAML and JSON

## Questions?

- Check [`docs/README.md`](docs/README.md) for documentation
- Review [`AGENTS.md`](AGENTS.md) for repository guidelines
- Ask in team channels or create an issue

