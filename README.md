# Mereka Academy Open edX

This repository tracks the infrastructure-as-code, configuration, and runbooks for the Mereka Academy Open edX deployment. The goals are:

- provision a repeatable local sandbox using Tutor and the nightly Open edX release;
- evolve toward a production-grade deployment on Google Cloud Platform;
- keep documentation and automation in sync with upstream Open edX updates.

## Structure

- `docs/` – runbooks and architecture notes (local quickstart + GCP roadmap).
- `ops/` – configuration templates and helper scripts, including `ops/tutor/apply-patches.sh` to pin the MFEs to Node 18 until Tutor ships native support.
- `docs/SECRETS_SNAPSHOT.md` – temporary credentials generated for the initial rollout (rotate before production).

See `docs/LOCAL_SETUP.md` for step-by-step instructions to bootstrap the Tutor environment and `docs/GCP_ROADMAP.md` for the cloud deployment plan.
