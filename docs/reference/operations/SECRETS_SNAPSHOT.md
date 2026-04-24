# Secrets Snapshot (Redacted)
_Audience: Platform Eng • Owner: Infra Team • Last updated: 2026-02-06_

This file intentionally contains **no secret values**.

Policy:
- **Never commit secrets** (passwords, private keys, SMTP creds, service-account JSON, etc.) anywhere in this repo, including under `docs/` and `docs/archive/`.
- **Infisical is the single source of truth** for secrets (see `AGENTS.md`).
- Downstream stores (GCP Secret Manager, K8s Secrets via ESO, GitHub Actions secrets) are **sync targets**, not places to manually edit.

## Where Secrets Live

- Infisical: `secrets.mereka.io` (edit here)
- GCP Secret Manager: synced from Infisical
- Kubernetes secrets: synced from GCP via External Secrets Operator
- GitHub Actions: store only the minimum required CI credentials

## How To Retrieve (No Printing To Terminal History)

Prefer runtime injection:

```bash
infisical run --domain https://secrets.mereka.io/api --env prod --path / -- <command>
```

If you must retrieve a single value for a specific operation, do it in a way that avoids pasting into docs or leaving it in shell history, and rotate immediately after any accidental exposure.

## Canonical Secret Names (Examples)

Do not put values here, only names:
- `MEREKA_LMS_MONGODB_PASSWORD` (Atlas)
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (SES API)
- `ses-smtp-username`, `ses-smtp-password` (SMTP relay)

## Incident Note

If secrets were ever committed historically, treat it as an incident:
- Rotate affected credentials in Infisical (source of truth)
- Confirm sync to GCP + K8s
- Invalidate old keys and tokens at the provider
