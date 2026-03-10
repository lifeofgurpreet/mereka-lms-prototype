# Repository Structure Guide
_Audience: Developers & AI Agents • Owner: Engineering Team • Last updated: 2026-02-11_

**Purpose**: Understand the Mereka LMS repository layout, find files quickly, and place new files in the correct location.

**TL;DR**: Everything has its place. Scripts in `scripts/`, K8s manifests in `deploy/k8s/`, docs in `docs/`, specs in `specs/`. Deprecated paths (`tools/`, `ops/`) are gone. This guide is your map.

---

## Table of Contents

- [Directory Overview](#directory-overview)
- [Directory Details](#directory-details)
  - [deploy/](#deploy)
  - [scripts/](#scripts)
  - [infrastructure/](#infrastructure)
  - [docs/](#docs)
  - [specs/](#specs)
  - [services/](#services)
  - [assets/](#assets)
  - [apps/](#apps)
- [Root-Level Files](#root-level-files)
- [Deprecated Directories](#deprecated-directories)
- [Common File Paths](#common-file-paths)
- [Finding Things](#finding-things)
- [Adding New Files](#adding-new-files)
- [Verification](#verification)

---

## Directory Overview

The repository is organized into **8 top-level directories**, each with a clear purpose:

```
mereka-lms/
├── deploy/                # Kubernetes manifests, Kustomize configs
├── scripts/               # All executable automation scripts
├── infrastructure/        # Infrastructure-as-code (Tutor, Terraform, monitoring)
├── docs/                  # All documentation
├── specs/                 # Machine-checkable specifications
├── services/              # Microservices source code
├── assets/                # Static assets (logos, brand files)
├── apps/                  # Application submodules (MFEs)
├── var/                   # Runtime artifacts (gitignored)
└── tutor_env/             # Tutor-generated state (gitignored)
```

**Gitignored directories**: `var/`, `tutor_env/` — these contain runtime artifacts and generated configs, never commit them.

---

## Directory Details

### deploy/

**Purpose**: Kubernetes deployment manifests and Kustomize overlays.

> **Boundary reference**: For the authoritative classification of what belongs here vs in
> `infrastructure` (historical name: `infrastructure`), see [DEPLOYMENT_CONTRACT.md](../../reference/architecture/DEPLOYMENT_CONTRACT.md)
> and [RESOURCE_OWNERSHIP_MATRIX.md](../../reference/architecture/RESOURCE_OWNERSHIP_MATRIX.md).

**Structure**:
```
deploy/k8s/
├── base/                      # Base Kustomize resources (APP_RUNTIME — stays here)
│   ├── secrets/               # ExternalSecret manifests + ClusterSecretStore
│   │   └── external-secrets.yaml  # Maps Infisical/GCP SM → K8s secrets
│   ├── apps/                  # App-specific configs (lms, cms, enterprise, multi-tenancy, etc.)
│   ├── arc/                   # ARC runner manifests (PLATFORM_SHARED — ownership in infrastructure)
│   ├── logging/               # Promtail DaemonSet (PLATFORM_SHARED — ownership in infrastructure)
│   ├── monitoring/            # ServiceMonitors, PrometheusRules (APP_RUNTIME)
│   ├── network-policies/      # Namespace network policies (APP_RUNTIME)
│   ├── operational/           # PDB, HPA baselines (APP_RUNTIME)
│   ├── policies/              # Kyverno ClusterPolicies (PLATFORM_SHARED — ownership in infrastructure)
│   └── plugins/               # Plugin configs (discovery, mfe, credentials, notes, aspects)
└── overlays/                  # Environment-specific overrides
    ├── local/                 # Local Kind development (APP_LOCAL_ONLY — stays here)
    ├── production/            # Production GKE (ENVIRONMENT_SPECIFIC — ownership in infrastructure)
    ├── rke2-nonprod/          # Dev RKE2 cluster (ENVIRONMENT_SPECIFIC — ownership in infrastructure)
    └── staging/               # Staging overlay (ENVIRONMENT_SPECIFIC — deprecated)
```

**Key files**:
- `deploy/k8s/base/kustomization.yaml` — Base resources list (stable export path)
- `deploy/k8s/base/secrets/external-secrets.yaml` — Secret sync configuration
- `deploy/k8s/overlays/local/` — The only overlay that permanently stays in this repo

**Where to add**:
- New app K8s resource → `deploy/k8s/base/apps/<service>/`
- New secret → Add to `external-secrets.yaml` (never hardcode secrets)
- Local dev override → `deploy/k8s/overlays/local/`
- Environment-specific config → `infrastructure` repo (not here)

**Related docs**: `docs/adr/rfc/027-deployment-contract-ownership-lanes.md`, `docs/reference/architecture/DEPLOYMENT_CONTRACT.md`, `docs/reference/architecture/RESOURCE_OWNERSHIP_MATRIX.md`, `specs/k8s-deployment_spec.md`, `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md`

---

### scripts/

**Purpose**: All executable automation organized by domain.

**Structure**:
```
scripts/
├── shared/                    # Common utilities and configuration
│   ├── config.sh              # Central config (GCP_PROJECT, LMS_DOMAIN)
│   └── setup-local.sh         # Local environment setup
├── infra/                     # Infrastructure management
│   ├── tutor-config-save.sh   # Safe Tutor config wrapper
│   ├── verify-tutor-config.sh # Verify patches applied
│   ├── apply-kind-overlay.sh  # Kind deployment
│   └── release-openedx-gitops.sh  # GitOps release automation
├── migrations/                # Data migration scripts
│   ├── kajabi-*.sh            # Kajabi import scripts
│   └── mct-*.sh               # MCT import scripts
├── branding/                  # Theme and branding
│   ├── sync-brand-assets.sh   # Sync assets to Tutor themes
│   └── setup-mfe-branding.sh  # MFE branding setup
├── analytics/                 # Analytics exports
│   ├── delete-user-events.sh  # GDPR user data deletion
│   └── verify-user-deletion.sh # Verify deletion complete
└── qa/                        # QA, smoke tests, verification
    ├── smoke-test.sh          # Critical path smoke tests
    ├── verify-*.sh            # 100+ verification scripts
    └── spec-tools/            # Spec verification tools
```

**Key pattern**: All scripts **SHOULD source** `scripts/shared/config.sh` for common variables:

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../shared/config.sh"  # Adjust path as needed
echo "Deploying to $GCP_PROJECT in $GCP_REGION"
```

**Where to add**:
- Infrastructure script → `scripts/infra/`
- Migration script → `scripts/migrations/`
- Verification script → `scripts/qa/`
- Common utility → `scripts/shared/`

**Never put scripts at repository root** — they belong in `scripts/`.

**Related docs**: `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md`

---

### infrastructure/

**Purpose**: Infrastructure-as-code for deployment tools, cloud resources, monitoring.

**Structure**:
```
infrastructure/
├── tutor/                     # Tutor configuration and patches
│   ├── apply-patches.sh       # CRITICAL: Run after tutor config save
│   ├── patches/               # Jinja2 patch templates
│   │   ├── lms-env-features   # Feature flags
│   │   ├── openedx-dockerfile-post-python-requirements  # Build patches
│   │   └── caddyfile           # Caddy reverse proxy config
│   ├── plugins/               # Tutor plugins
│   │   └── multi-tenancy/     # Multi-tenancy plugin
│   ├── custom-apps/           # Custom Django apps
│   │   ├── mfe_oauth_fix/     # MFE OAuth middleware
│   │   └── openedx_prometheus/  # Prometheus metrics
│   └── themes/                # Open edX themes
│       └── mereka/            # Mereka branding theme
├── cloudflare/                # DNS record definitions
│   └── dns-records.json       # Cloudflare DNS automation
├── terraform/                 # Terraform infrastructure
│   ├── gcp/                   # GCP resources (GKE, Cloud SQL, VPC)
│   └── modules/               # Reusable Terraform modules
└── monitoring/                # Monitoring configs
    ├── prometheus/            # Prometheus rules and scrape configs
    │   ├── rules/             # Recording and alerting rules
    │   └── configs/           # ServiceMonitor configs
    └── grafana/               # Grafana dashboards
        └── dashboards/        # Dashboard JSON definitions
```

**Critical workflow**: After modifying Tutor config:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh --set KEY=value  # Safe wrapper
# OR manually:
tutor config save --set KEY=value
./infrastructure/tutor/apply-patches.sh  # MUST RUN!
tutor local restart
```

**Where to add**:
- Tutor patch → `infrastructure/tutor/patches/`
- Custom Django app → `infrastructure/tutor/custom-apps/`
- Monitoring rule → `deploy/k8s/base/monitoring/`
- Terraform resource → `infrastructure/terraform/`

**Related docs**: `specs/tutor-configuration_spec.md`, `docs/meta/standing-orders/README.md`, `docs/reference/operations/RELEASE_PROCESS.md`

---

### docs/

**Purpose**: All documentation organized by audience and purpose.

**Structure**:
```
docs/
├── adr/                       # Architecture Decision Records
│   ├── README.md              # ADR index
│   └── 001-mongodb-atlas.md   # Numbered ADRs
├── onboarding/                # Setup and getting started
│   ├── QUICK_START_LOCAL.md   # 5-minute setup
│   ├── DEVELOPER_ONBOARDING.md  # Complete onboarding
│   └── REPOSITORY_GUIDE.md    # This file
├── operations/                # Runbooks and operational procedures
│   ├── TROUBLESHOOTING.md     # Site down diagnostic
│   ├── ACCESS_URLS.md         # All service URLs
│   └── SECRETS_SNAPSHOT.md    # Secrets inventory
├── migrations/                # Migration playbooks
│   ├── kajabi/                # Kajabi migration docs
│   └── mct/                   # MCT migration docs
├── architecture/              # System design
│   └── DATABASE_ARCHITECTURE.md  # Database overview
├── sprints/                   # Sprint planning
│   ├── SPRINT-01-foundation-complete.md
│   ├── SPRINT-02-multi-tenancy.md
│   └── SPRINT-03-auth-sso-phase1.md
└── archive/                   # Historical documentation
    └── FINAL_STATUS_REPORT.md
```

**Naming conventions**:
- ADRs: `NNN-<slug>.md` (numbered)
- Guides: `SHOUTY_SNAKE_CASE.md` (all caps with underscores)
- READMEs: `README.md` (lowercase) for directory indexes

**Where to add**:
- New runbook → `docs/ops/runbooks/`
- Getting started guide → `docs/guides/onboarding/`
- Architecture doc → `docs/concepts/architecture/`
- ADR → `docs/adr/` (numbered sequentially)

**Never add docs at repository root** — they belong in `docs/` (except root allowlist).

**Related docs**: `docs/guides/standards/STYLE_GUIDE.md`, `docs/README.md`

---

### specs/

**Purpose**: Machine-checkable specifications (testable contracts, not documentation).

**Structure**:
```
specs/
├── repository-structure_spec.md      # This repo's structure (you are here!)
├── secrets-management_spec.md        # Secret naming, ExternalSecrets
├── k8s-deployment_spec.md            # K8s deployment requirements
├── tutor-configuration_spec.md       # Tutor config management
├── multi-tenancy-architecture_spec.md  # Multi-tenancy design
├── auth-sso-enterprise_spec.md       # Enterprise SSO integration
├── cross-cutting-requirements_spec.md  # Platform-wide shared requirements
├── IMPLEMENTATION_ORDER.md           # Dependency graph (computed)
└── plans/manual_verifications.yaml   # Non-automated verification entries
```

**Spec vs Doc**:
- **Specs** (this directory): Define WHAT MUST BE TRUE (acceptance criteria, verification commands)
- **Docs** (`docs/`): Explain HOW and WHY (tutorials, runbooks, architecture)

**Naming convention**: `<slug>_spec.md` (always ends with `_spec.md`)

**Verification**: Every spec has acceptance criteria (AC-NNN) verified by test scripts with `@covers` annotations.

**Where to add**: New feature spec → `specs/<feature-name>_spec.md`

**Related docs**: `../meta/docs-program/IMPLEMENTATION_ROADMAP.md`, `team-skills/ONBOARDING.md` (V3 verification method)

---

### services/

**Purpose**: Microservices source code (not part of core Open edX platform).

**Structure**:
```
services/
├── hubspot-webhook/           # HubSpot → Open edX user registration
│   ├── index.js               # Firebase Cloud Function
│   ├── package.json
│   └── README.md
├── purchase-gateway/          # Stripe payment integration
│   ├── app/                   # FastAPI application
│   ├── tests/
│   ├── Dockerfile
│   └── requirements.txt
└── kajabi-webhook/            # Kajabi webhook handlers
    └── main.py
```

**Pattern**: Each service is a standalone application with its own:
- Source code
- Tests
- Dockerfile
- K8s manifests (in `deploy/k8s/base/apps/<service>/`)
- README explaining purpose

**Where to add**: New microservice → `services/<service-name>/`

**Related specs**: `specs/proposals/external-registration-hubspot_spec.md`, `specs/ecommerce-purchase-gateway_spec.md`

---

### assets/

**Purpose**: Static assets (logos, images, brand files).

**Structure**:
```
assets/
├── logos/                     # Mereka Academy logos
│   ├── mereka-logo.png
│   └── mereka-logo.svg
├── images/                    # General images
└── branding/                  # Brand color palettes, fonts
```

**Where to add**: Logo, image, or brand file → `assets/<category>/`

**Related docs**: `docs/guides/branding/BRANDING.md`

---

### tmp/

**Purpose**: Temporary/vendor source checkouts (including upstream submodules).

**Structure**:
```
tmp/
└── frontend-app-authn/        # Git submodule: Open edX authn MFE
    ├── src/
    └── package.json
```

**Submodule workflow**:
```bash
# Initialize submodules
git submodule update --init --recursive

# Update submodule
cd tmp/frontend-app-authn
git pull origin main
cd ../..
git add tmp/frontend-app-authn
git commit -m "chore: update authn MFE"
```

**Where to add**: Temporary vendor checkouts → `tmp/<name>/`

**Related docs**: `../../reference/architecture/MFE_COMPLETE_LIST.md`

---

## Root-Level Files

**Allowlist** (ONLY these markdown files are allowed at repository root):

| File | Purpose |
|------|---------|
| `README.md` | Project overview, badges, quick links |
| `docs/meta/standing-orders/README.md` | Canonical standing orders for maintainers and agents |
| `AGENTS.md` | Agent guidelines, data protection rules |
| `CONTRIBUTING.md` | Contributor guide |
| `MIGRATION_CHECKLIST.md` | Active migration tracking |
| `CHANGES.md` | Repository changelog |
| `GEMINI.md` | Cross-tool adapter for Gemini |

**Important**: Any other markdown file at root **MUST be moved** to `docs/` or `docs/archive/`.

**Other root files**:
- `.gitignore` — Gitignore rules
- `.gitattributes` — Git attributes
- `.gitmodules` — Submodule configs
- `.pre-commit-config.yaml` — Pre-commit hook config
- `Makefile` — Make targets for common tasks
- `pyproject.toml` — Python project metadata
- `package.json` — Node.js project metadata

---

## Deprecated Directories

**DELETED**: `tools/`, `ops/`

These directories were reorganized in February 2026:
- `tools/` → moved to `scripts/`
- `ops/` → moved to `infrastructure/` and `scripts/`

**If you see these directories**, they should contain ONLY a `README.md` redirect file. Any other files are violations.

**Why deleted**: Prevented confusion about where to put new scripts and configs.

---

## Common File Paths

Quick reference for frequently accessed files:

### Configuration
- Central script config: `scripts/shared/config.sh`
- Tutor patch runner: `infrastructure/tutor/apply-patches.sh`
- Tutor config example template: `infrastructure/tutor/config.example.yml`
- Local Tutor runtime config (gitignored): `tutor_env/config.yml`
- Makefile targets: `Makefile`

### Deployment
- Production image tags: `deploy/k8s/overlays/production/kustomization.yaml`
- Secret mappings: `deploy/k8s/base/secrets/external-secrets.yaml`
- LMS K8s manifest: `deploy/k8s/base/apps/lms/deployment.yaml`

### Documentation
- Quick start: `docs/guides/onboarding/QUICK_START_LOCAL.md`
- Troubleshooting: `docs/ops/runbooks/TROUBLESHOOTING.md`
- Service URLs: `docs/ops/quickref/access-urls.md`
- Doc index: `docs/README.md`

### Verification
- Repo structure check: `scripts/qa/verify-repo-structure.sh`
- Tutor config check: `scripts/infra/verify-tutor-config.sh`
- Spec verification: `scripts/qa/spec-tools/spec_verify.py`
- Coverage report: `scripts/qa/spec-tools/spec_coverage_report.py`

### Specs
- Repository structure: `specs/repository-structure_spec.md`
- Secrets management: `specs/secrets-management_spec.md`
- K8s deployment: `specs/k8s-deployment_spec.md`
- Implementation order: `specs/plans/IMPLEMENTATION_ORDER.md`

---

## Finding Things

### By Task

| I need to... | Look in... |
|-------------|-----------|
| Deploy to K8s | `deploy/k8s/overlays/production/` + `scripts/infra/` |
| Run local Tutor | `scripts/infra/tutor-config-save.sh` + `infrastructure/tutor/` |
| Migrate data | `scripts/migrations/` + `docs/ops/runbooks/migrations/` + `docs/reference/migrations/` |
| Update branding | `infrastructure/tutor/themes/mereka/` + `scripts/branding/` |
| Verify a spec | `scripts/qa/verify-*.sh` matching the spec name |
| Find URLs | `docs/ops/quickref/access-urls.md` |
| Troubleshoot outage | `docs/ops/runbooks/TROUBLESHOOTING.md` |
| Add a secret | `deploy/k8s/base/secrets/external-secrets.yaml` |
| Add monitoring | `infrastructure/monitoring/` |
| Write an ADR | `docs/adr/NNN-<slug>.md` (next number) |

### By Technology

| Technology | Location |
|-----------|----------|
| Kubernetes | `deploy/k8s/`, `scripts/infra/*k8s*.sh` |
| Tutor | `infrastructure/tutor/`, `scripts/infra/tutor-*.sh` |
| Open edX | `infrastructure/tutor/custom-apps/`, `infrastructure/tutor/themes/` |
| Django | `infrastructure/tutor/custom-apps/` |
| Prometheus | `infrastructure/monitoring/` |
| Terraform | `infrastructure/terraform/` |
| Cloudflare | `infrastructure/cloudflare/` |
| Kajabi | `scripts/migrations/kajabi-*.sh`, `docs/ops/runbooks/migrations/kajabi/`, `docs/reference/migrations/kajabi/` |

### By Grep

```bash
# Find all verification scripts
ls scripts/qa/verify-*.sh

# Find all specs
ls specs/*_spec.md

# Find all K8s deployments
find deploy/k8s -name "deployment.yaml"

# Find all Tutor patches
ls infrastructure/tutor/patches/

# Find monitoring rules
find infrastructure/monitoring -name "*.yml"
```

---

## Adding New Files

### Checklist

Before adding a new file, ask:

1. **What category is this?**
   - Deployment manifest → `deploy/k8s/`
   - Script → `scripts/`
   - Infrastructure code → `infrastructure/`
   - Documentation → `docs/`
   - Spec → `specs/`
   - Microservice → `services/`
   - Asset → `assets/`

2. **What subdirectory?**
   - Check the structure above for the correct subdirectory
   - If unsure, look for similar existing files

3. **Does it fit the naming convention?**
   - Scripts: kebab-case with `.sh` extension
   - Specs: `<slug>_spec.md`
   - Docs: `SHOUTY_SNAKE_CASE.md` or `README.md`
   - K8s: lowercase with hyphens

4. **Do I need to update an index?**
   - Added doc? Update `docs/README.md`
   - Added spec? Check if `IMPLEMENTATION_ORDER.md` needs updating
   - Added script? Check if `Makefile` should have a target for it

### Examples

**Adding a new verification script**:
```bash
# 1. Create the script
cat > /tmp/verify-my-feature.sh <<'EOF'
#!/usr/bin/env bash
# @covers AC-123, AC-124
# @spec: my-feature_spec.md
set -euo pipefail

source "$(dirname "$0")/../shared/config.sh"

# Your verification logic here
EOF

# 2. Make it executable
chmod +x /tmp/verify-my-feature.sh

# 3. Test it
/tmp/verify-my-feature.sh

# 4. Run coverage report to verify @covers annotation is picked up
python3 scripts/qa/spec-tools/spec_coverage_report.py
```

**Adding a new spec**:
```bash
# 1. Create from template (use spec-write skill)
# /spec-write to write a spec for the new feature

# 2. Verify spec format
python3 scripts/qa/spec-tools/mereka_spec_lint.py specs/my-feature_spec.md

# 3. Add dependencies in frontmatter
# Add "depends_on" list if this spec depends on others

# 4. Update IMPLEMENTATION_ORDER.md
python3 scripts/qa/spec-tools/compute_dependency_graph.py \
  --specs-dir specs/ --format markdown > specs/plans/IMPLEMENTATION_ORDER.md
```

**Adding a new doc**:
```bash
# 1. Determine correct subdirectory
# Onboarding? → docs/guides/onboarding/
# Runbook? → docs/ops/runbooks/
# Architecture? → docs/concepts/architecture/

# 2. Create the file
# Use SHOUTY_SNAKE_CASE.md naming

# 3. Add metadata at top
cat > MY_NEW_RUNBOOK.md <<'EOF'
# My New Runbook
_Audience: Operations • Owner: Infra Team • Last updated: 2026-02-11_

Your content here...
EOF

# 4. Update docs/README.md to include the new doc in the index
```

---

## Verification

Run the repository structure verification script to check compliance:

```bash
./scripts/qa/verify-repo-structure.sh
```

This script checks:
- ✅ All required top-level directories exist
- ✅ Root markdown files match allowlist
- ✅ Required subdirectories exist
- ✅ No files in deprecated directories
- ✅ Spec naming convention
- ✅ Gitignore entries

**Expected output**:
```
[PASS] Top-level directory deploy/ exists
[PASS] Top-level directory scripts/ exists
...
[PASS] Deprecated directory tools/ does not exist
[PASS] Deprecated directory ops/ does not exist
...
RESULT: PASS (all checks passed)
```

**If verification fails**, fix the violation before committing.

---

## Related Resources

- **Spec**: `specs/repository-structure_spec.md` — Full specification
- **Roadmap**: `../meta/docs-program/IMPLEMENTATION_ROADMAP.md` — Implementation progress
- **Onboarding**: `docs/guides/onboarding/DEVELOPER_ONBOARDING.md` — Complete setup guide
- **Quick Start**: `docs/guides/onboarding/QUICK_START_LOCAL.md` — 5-minute setup
- **Agent Guide**: `AGENTS.md` — Agent-specific guidelines

---

## Questions?

- Check `docs/README.md` for documentation index
- Check `docs/meta/standing-orders/README.md` for active standing orders
- Check `docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md` for canonical doc roots
- Check `AGENTS.md` for repository guidelines
- Run `./scripts/qa/verify-repo-structure.sh` to verify compliance
