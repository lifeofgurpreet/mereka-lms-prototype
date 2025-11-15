# Mereka Academy Open edX

This repository tracks the infrastructure-as-code, configuration, and runbooks for the Mereka Academy Open edX deployment. The goals are:

- provision a repeatable local sandbox using Tutor and the nightly Open edX release;
- evolve toward a production-grade deployment on Google Cloud Platform;
- keep documentation and automation in sync with upstream Open edX updates.

> 🧠 Prerequisite: configure Docker Desktop with at least **12 GB RAM** and **2 GB+ swap** (Settings → Resources) before running `tutor images build openedx`. The Redwood asset pipeline freely uses 6–8 GB during webpack and will OOM if the daemon stays on the default 2 GB cap.

## Structure

- `docs/` – Documentation organized by category:
  - `onboarding/` – Setup guides and getting started (start with [`docs/onboarding/QUICK_START_LOCAL.md`](docs/onboarding/QUICK_START_LOCAL.md))
  - `operations/` – Runbooks, troubleshooting, and operational procedures
  - `migrations/` – Migration playbooks for Kajabi and MCT
  - `architecture/` – System architecture and design decisions
  - `status/` – Status trackers and backlog (see [`docs/status/NEXT10_TASKS.md`](docs/status/NEXT10_TASKS.md))
- `infrastructure/` – Infrastructure-as-code:
  - `tutor/` – Tutor configuration templates and patches (`apply-patches.sh`, `tutor-env.sh`)
  - `terraform/` – Terraform modules and configs
  - `k8s/` – Kubernetes manifests
  - `themes/` – Mereka branding themes
- `scripts/` – Automation scripts organized by domain:
  - `infra/` – Infrastructure operations (GKE, Cloudflare, MongoDB, etc.)
  - `migrations/` – Data migration scripts (Kajabi, MCT)
  - `branding/` – Branding asset sync and theme helpers
  - `analytics/` – Analytics exports and reconciliation
  - `qa/` – Quality assurance and testing
- `services/` – Standalone microservices and webhooks
- `var/` – Runtime artifacts (gitignored): logs, exports, migration outputs

## 🚀 Quick Start (New Developers)

**One-Command Setup:**
```bash
./scripts/shared/setup-local.sh
```

Or use Make:
```bash
make bootstrap
make tutor-start
```

This automatically sets up everything you need for local development. See `README_SETUP.md` for details.

**For complete onboarding:** See [`docs/onboarding/DEVELOPER_ONBOARDING.md`](docs/onboarding/DEVELOPER_ONBOARDING.md)

See [`docs/onboarding/LOCAL_SETUP.md`](docs/onboarding/LOCAL_SETUP.md) for detailed setup instructions and [`docs/operations/GCP_ROADMAP.md`](docs/operations/GCP_ROADMAP.md) for the cloud deployment plan.

## Submodules

The official authentication micro-frontend, `frontend-app-authn`, is tracked as a Git submodule under `tmp/frontend-app-authn`. After cloning or pulling, run:

```bash
git submodule update --init --recursive
```

This ensures the login experience stays in sync with upstream Open edX changes. Treat changes inside the submodule as upstream contributions—commit them from within `tmp/frontend-app-authn` and push to its origin before updating the pointer in this repo (`git submodule update --remote` + commit).

## Container Images

Tutor now pulls most runtime images from our Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx`):

| Service | Image | Notes |
|---------|-------|-------|
| LMS/CMS + workers | `openedx` | Built via `tutor images build openedx`. |
| Micro-frontends | `openedx-mfe` | Patched to build on Node 18. |
| Discovery | `openedx-discovery` | Uses Cloud SQL + OpenSearch. |
| Forum (cs_comments_service) | `openedx-forum` | Uses MongoDB Atlas (managed service). |
| Notes service | `openedx-notes` | Handles ORA notes. |
| **New:** Ecommerce web/worker | `openedx-ecommerce`, `openedx-ecommerce-worker` | Mirrored from Tutor 12.0.4. |
| **New:** XQueue | `openedx-xqueue` | Mirrored from Tutor 12.1.0. |

Remaining images (MySQL init job, Android builder, etc.) still come from the upstream Tutor repositories; mirror them later if we need tighter control.

## Automation

- **Makefile**: Common tasks (`make tutor-start`, `make tutor-apply`, `make branding-sync`, etc.)
- **Pre-commit hooks**: Automatic code formatting and linting
- **CI/CD**: `.github/workflows/cloud-sql-backup.yml` runs `scripts/infra/backup-db.sh` every three days (cron `0 18 */3 * *`). Add a service-account JSON with `roles/cloudsql.admin` and `roles/storage.objectAdmin` to the repo secrets as `GCP_SA_KEY` so the workflow can authenticate.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for development workflow and code style guidelines.
