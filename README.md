# Mereka Academy Open edX

This repository tracks the infrastructure-as-code, configuration, and runbooks for the Mereka Academy Open edX deployment. The goals are:

- provision a repeatable local sandbox using Tutor and the nightly Open edX release;
- evolve toward a production-grade deployment on Google Cloud Platform;
- keep documentation and automation in sync with upstream Open edX updates.

## Structure

- `docs/` – runbooks and architecture notes (local quickstart + GCP roadmap + `docs/BRANDING.md` for theme tokens/MFE workflow + `docs/MULTISITE.md` for microsite rollout).
- `docs/NEXT10_TASKS.md` – rolling backlog of the top ten items so we can reference “Task 1/4/7/9” in chat without ambiguity.
- `docs/mct/` – MCT migration documentation (`docs/mct/EXPORT_GUIDE.md` for complete export guide)
- `ops/` – configuration templates and helper scripts. Run `ops/tutor/apply-patches.sh` after each `tutor config save` to keep the MySQL flags compatible with 8.0.
- `tools/` – data export and migration scripts:
  - `tools/mct-export.mjs` – Microsoft Community Training data exporter (see `docs/mct/EXPORT_GUIDE.md`)
  - `tools/kajabi-export.mjs` – Kajabi data exporter
  - `tools/mongodb-to-atlas.sh` – MongoDB migration helper
  - `tools/mongodb-atlas-cutover.sh` – dumps data, updates Tutor config, and restarts workloads against Atlas
  - `tools/sync-brand-assets.sh` – copies fonts/logos into both LMS/Studio and MFE theme directories
  - `tools/setup-mfe-branding.sh` – clones the upstream MFEs, vendors fonts, and inserts the shared Mereka SCSS import
  - `tools/cloudflare-harden-zone.sh` – enforces TLS/HSTS defaults on the mereka.io zone
  - `tools/cloudflare-sync.sh` – idempotently updates Cloudflare DNS using `ops/cloudflare/records.json`
- `docs/SECRETS_SNAPSHOT.md` – temporary credentials generated for the initial rollout (rotate before production).

See `docs/LOCAL_SETUP.md` for step-by-step instructions to bootstrap the Tutor environment and `docs/GCP_ROADMAP.md` for the cloud deployment plan.

## Container Images

Tutor now pulls most runtime images from our Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx`):

| Service | Image | Notes |
|---------|-------|-------|
| LMS/CMS + workers | `openedx` | Built via `tutor images build openedx`. |
| Micro-frontends | `openedx-mfe` | Patched to build on Node 18. |
| Discovery | `openedx-discovery` | Uses Cloud SQL + OpenSearch. |
| Forum (cs_comments_service) | `openedx-forum` | Talks to Mongo `mongodb` headless service (migrating to Atlas). |
| Notes service | `openedx-notes` | Handles ORA notes. |
| **New:** Ecommerce web/worker | `openedx-ecommerce`, `openedx-ecommerce-worker` | Mirrored from Tutor 12.0.4. |
| **New:** XQueue | `openedx-xqueue` | Mirrored from Tutor 12.1.0. |

Remaining images (MySQL init job, Android builder, etc.) still come from the upstream Tutor repositories; mirror them later if we need tighter control.

## Automation

- `.github/workflows/cloud-sql-backup.yml` runs `tools/backup-db.sh` every three days (cron `0 18 */3 * *`). Add a service-account JSON with `roles/cloudsql.admin` and `roles/storage.objectAdmin` to the repo secrets as `GCP_SA_KEY` so the workflow can authenticate.
