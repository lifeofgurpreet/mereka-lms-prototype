# In-Cluster Auth Verification (CronJob)
_Audience: Platform Operators • Owner: Security Domain Owner • Last verified: 2026-03-06 • Status: supporting_

This repo includes a **verify-only** Kubernetes CronJob template that continuously checks the public authentication surfaces without requiring credentials.

Why:
- CI checks are good, but an in-cluster Job makes drift visible even if CI is paused and gives you native Job failure signals.
- The checks are intentionally **public-surface** only (no DB access, no secrets).
- Callback/session validation is covered by a separate credentialed browser canary script:
  `scripts/qa/verify-authenticated-sso-canary.sh`.

## What It Checks (Prod)

See `infrastructure/k8s/cronjobs/auth-verify-prod.yaml`.

It validates:
- LMS OIDC entrypoints redirect to Authentik `/authorize` for all served LMS domains and aliases.
- MFE config + Authn MFE login are reachable.
- Discovery/Credentials/Ecommerce `/login/` starts the LMS OAuth2 handshake.
- Notes and Forum behave as API-first surfaces (Notes returns 200; Forum returns 401 unauthenticated).

## TLS Certificate Verification (Prod)

See `infrastructure/k8s/cronjobs/cert-verify-prod.yaml`.

It validates:
- Each public hostname serves a real TLS certificate (not the NGINX fake ingress cert).
- Each hostname is present in the certificate SANs (either exact SAN or a valid wildcard).

## How To Deploy (Prod)

Production is GitOps-managed outside this repo.

GitOps source of truth (prod):
- ArgoCD Application: `mereka-lms-local` (namespace: `argocd`)
- GitOps repo: `Biji-Biji-Initiative/BBI-K8` (older environments/docs may still refer to `infrastructure`)
- Path: `apps/mereka-lms/overlays/prod`

Status:
- These CronJobs are already deployed in production via GitOps.

When updating the checks:
1. Update `infrastructure/k8s/cronjobs/auth-verify-prod.yaml` and/or `infrastructure/k8s/cronjobs/cert-verify-prod.yaml` in this repo.
2. Bump the pinned base ref in `BBI-K8/apps/mereka-lms/base/kustomization.yaml` to the new commit SHA.
3. ArgoCD will apply the updated manifests.
4. Verify CronJobs are running:
   - `kubectl get cronjob -n mereka-lms auth-verify-prod`
   - `kubectl get cronjob -n mereka-lms cert-verify-prod`
   - `kubectl get jobs -n mereka-lms --sort-by=.metadata.creationTimestamp | tail`

## How To Run Manually (Prod)

This is useful after adding a new hostname/microsite, after a cert renewal, or when validating monitoring.

Auth surface check:
```bash
ts=$(date +%Y%m%d-%H%M%S)
kubectl -n mereka-lms create job auth-verify-manual-$ts --from=cronjob/auth-verify-prod
kubectl -n mereka-lms wait --for=condition=complete job/auth-verify-manual-$ts --timeout=180s
kubectl -n mereka-lms logs job/auth-verify-manual-$ts
```

TLS cert/SAN check:
```bash
ts=$(date +%Y%m%d-%H%M%S)
kubectl -n mereka-lms create job cert-verify-manual-$ts --from=cronjob/cert-verify-prod
kubectl -n mereka-lms wait --for=condition=complete job/cert-verify-manual-$ts --timeout=180s
kubectl -n mereka-lms logs job/cert-verify-manual-$ts
```

## Alerting On Failures

This CronJob fails the Job when any check fails. To alert on it, the recommended approach is:
- Create a log-based metric on the Job pod logs containing `FAILED (` and alert on any non-zero rate.

Alternatively:
- Alert on Job failures via Kubernetes metrics if you have that pipeline wired into your monitoring stack.

This repo includes templates (GCP):
- Metric: `infrastructure/monitoring/logging-metrics/auth-verify-cronjob-failures.json`
- Alert: `infrastructure/monitoring/alerts/log-auth-verify-cronjob-failures.json`

This repo also includes templates (GCP) for TLS verification:
- Metric: `infrastructure/monitoring/logging-metrics/cert-verify-cronjob-failures.json`
- Alert: `infrastructure/monitoring/alerts/log-cert-verify-cronjob-failures.json`

## Notes

- This CronJob uses `curlimages/curl` and only depends on public HTTPS reachability.
- It will not detect "permissions drift" (staff/superuser) inside LMS/CMS, because those checks require privileged access.
- It will not detect OIDC token-exchange failures on callback (for example `Invalid client secret` at `/application/o/token/`), because it is intentionally non-credentialed.
- Use `scripts/qa/verify-authenticated-sso-canary.sh --env prod` for credentialed callback/session verification.
- Use `scripts/qa/verify-oidc-user-password-state.sh --env prod` to catch the `Your account is disabled` regression (active OIDC users with unusable LMS passwords).
- Runtime workflow can enable the canary via `.github/workflows/operations-gates-runtime.yml` input `run_authenticated_sso_canary=true` (requires canary secrets).
- Verify runtime canary wiring with:
  - `./scripts/qa/audit-authenticated-sso-canary-wiring.sh`
  - `STRICT=1 ./scripts/qa/audit-authenticated-sso-canary-wiring.sh`
