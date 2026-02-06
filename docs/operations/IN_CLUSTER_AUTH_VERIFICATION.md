# In-Cluster Auth Verification (CronJob)
_Last updated: 2026-02-06_

This repo includes a **verify-only** Kubernetes CronJob template that continuously checks the public authentication surfaces without requiring credentials.

Why:
- CI checks are good, but an in-cluster Job makes drift visible even if CI is paused and gives you native Job failure signals.
- The checks are intentionally **public-surface** only (no DB access, no secrets).

## What It Checks (Prod)

See `infrastructure/k8s/cronjobs/auth-verify-prod.yaml`.

It validates:
- LMS OIDC entrypoints redirect to Authentik `/authorize` for all served LMS domains and aliases.
- MFE config + Authn MFE login are reachable.
- Discovery/Credentials/Ecommerce `/login/` starts the LMS OAuth2 handshake.
- Notes and Forum behave as API-first surfaces (Notes returns 200; Forum returns 401 unauthenticated).

## How To Deploy (Prod)

Production is GitOps-managed outside this repo.

1. Copy `infrastructure/k8s/cronjobs/auth-verify-prod.yaml` into the GitOps repo (the cluster manifests repo).
2. Apply via normal GitOps flow.
3. Verify Jobs are running:
   - `kubectl get cronjob -n mereka-lms auth-verify-prod`
   - `kubectl get jobs -n mereka-lms --sort-by=.metadata.creationTimestamp | tail`

## Alerting On Failures

This CronJob fails the Job when any check fails. To alert on it, the recommended approach is:
- Create a log-based metric on the Job pod logs containing `FAILED (` and alert on any non-zero rate.

Alternatively:
- Alert on Job failures via Kubernetes metrics if you have that pipeline wired into your monitoring stack.

## Notes

- This CronJob uses `curlimages/curl` and only depends on public HTTPS reachability.
- It will not detect "permissions drift" (staff/superuser) inside LMS/CMS, because those checks require privileged access.

