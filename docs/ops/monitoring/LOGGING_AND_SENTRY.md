# Logging and Sentry
_Audience: Operators + Platform Eng • Last updated: 2026-02-09_

This document defines the canonical logging path and optional Sentry error telemetry
contract for Mereka LMS services.

## 1) Current Logging Path

Open edX services write Python/Django logs to:
- `/openedx/data/logs/all.log`
- `/openedx/data/logs/tracking.log`

Key settings references:
- `deploy/k8s/base/apps/openedx/config/lms.env.yml`
- `deploy/k8s/base/apps/openedx/settings/lms/production.py`
- `deploy/k8s/base/apps/openedx/settings/cms/production.py`

Cluster log flow:
1. Container logs are scraped by Promtail (`deploy/k8s/base/logging/`).
2. Promtail forwards logs to Loki (`https://loki.mereka.dev/loki/api/v1/push`).
3. GCP log-based metrics and alert policies are managed in
   `infrastructure/monitoring/logging-metrics/` and `infrastructure/monitoring/alerts/`.

## 2) Sentry Wiring Contract

Sentry initialization is now guarded in production settings for:
- LMS, CMS
- Discovery
- Ecommerce + Ecommerce Worker
- Credentials

Runtime audit matrix:
- Required services: `lms`, `cms`, `lms-worker`, `cms-worker`, `discovery`, `ecommerce`, `credentials`
- Optional services: `ecommerce-worker`, `notes`, `notes-worker`, `forum`, `forum-worker`

Behavior:
- If `SENTRY_DSN` is empty: no-op (no Sentry init).
- If `SENTRY_DSN` is set but `sentry_sdk` is unavailable: warning only, no crash.
- If both are present: initialize Sentry with env-driven options.

Supported env vars:
- `SENTRY_DSN`
- `SENTRY_ENVIRONMENT` (fallback: `LOGGING_ENV`, then `production`)
- `SENTRY_RELEASE`
- `SENTRY_TRACES_SAMPLE_RATE` (float, default `0.0`)
- `SENTRY_PROFILES_SAMPLE_RATE` (float, default `0.0`)
- `SENTRY_SEND_DEFAULT_PII` (`true|false`, default `false`)

Canonical standards and ownership references:
- `docs/ops/monitoring/OBSERVABILITY_OWNERSHIP.md` (ownership and SoT boundaries)
- `scripts/qa/verify-sentry-wiring.sh` and `scripts/qa/verify-sentry-cli-contract.sh` (enforcement/audit contract)
- `infrastructure/monitoring/README.md` (platform monitoring stack SoT)

Historical references (deprecated workspace, read-only context):
- `/home/gurpreet/projects/observability/specs/16-error-tracking/SENTRY-STANDARD.md`
- `/home/gurpreet/projects/observability/specs/16-error-tracking/SENTRY-K8S-INTEGRATION.md`
- `/home/gurpreet/projects/observability/specs/16-error-tracking/SENTRY-PROJECT-REGISTRY.md`

Current org/project contract:
- Org: `biji-biji-non-profits`
- Project: `mereka-lms-web`
- Infisical DSN key (registry convention): `SENTRY_DSN__mereka-lms__web`

## 3) Verification

Repo contract check:
```bash
./scripts/qa/verify-sentry-wiring.sh --mode local
```

Runtime check (cluster):
```bash
./scripts/qa/verify-sentry-wiring.sh --mode runtime
```

Strict runtime enforcement:
```bash
STRICT_RUNTIME=1 ./scripts/qa/verify-sentry-wiring.sh --mode runtime
```

Unified ops gate (opt-in):
```bash
RUN_SENTRY_WIRING_AUDIT=1 SENTRY_AUDIT_MODE=local ./scripts/qa/run-operations-gates.sh --env both
```

Sentry CLI contract (auth + org + project):
```bash
./scripts/qa/verify-sentry-cli-contract.sh
```

## 4) Rollout Sequence (Recommended)

1. Configure `SENTRY_*` secrets in Infisical (`/k8s/mereka-lms`).
2. Sync Infisical -> GCP Secret Manager -> K8s ExternalSecret target.
3. Reconcile workloads (GitOps sync / rollout restart as needed).
4. Run:
   - `./scripts/qa/verify-sentry-wiring.sh --mode runtime`
   - `STRICT_RUNTIME=1 ./scripts/qa/verify-sentry-wiring.sh --mode runtime`
5. Enable gate enforcement for scheduled/runtime checks once strict mode passes.

## 5) Notes

- This contract verifies wiring and SDK availability, not event delivery health in Sentry SaaS.
- Add a controlled non-production test event during maintenance windows before making
  strict Sentry gating mandatory in CI/runtime workflows.
- `SENTRY_AUTH_TOKEN` must stay CI/build-only; never inject it into runtime pods.
