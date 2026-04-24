---
title: Platform Admin Allowlist Audit — dev/staging/prod
date: 2026-04-20
author: operator-loop + 2 parallel research agents (Sentry+Authentik scope)
severity: P1 (silent dead middleware + cross-env drift in admin set)
status: drift-identified, unified-contract-proposed
---

# Platform Admin Allowlist Audit (2026-04-20)

## Why this audit happened

User question paraphrased: "isn't there a list of people who should get access via Sign in with Mereka? aren't these bound across dev/staging/prod? why does this keep breaking?"

Answer: the binding is 4 layers deep, the layers don't share state, and the
runtime backstop middleware is currently **dead (empty env var on all 3
envs)**. Admin state lives purely in the Django DB; any DB reset or new
deploy with a fresh DB would silently lose all admins until someone
manually runs `ensure-platform-admins.sh` again.

## Architecture (4 layers)

### Layer 1 — Authentik user (IdP account)

- 3 **separate** Authentik instances, each with its own user DB:
  - `auth0.mereka.dev` → `rke2-nonprod`/namespace=authentik
  - `staging.auth0.mereka.io` → `rke2-nonprod`/namespace=authentik-staging
  - `auth0.mereka.io` → `rke2-prod`/namespace=authentik
- Users auto-provisioned on first Google-SSO login via blueprint `bbi-infrastructure/branding/mereka/authentik/blueprints/97-google-sso-source.yaml`.
- Admin group `authentik Admins` is **declaratively seeded** in `bbi-infrastructure/branding/mereka/authentik/blueprints/05-admin-group-bindings.yaml` (GitOps, safe).
- `staff` group has **zero declarative membership** — empty by construction. Anything keying off "staff in Authentik" is broken.

### Layer 2 — LMS OIDC client ("Sign in with Mereka" button)

- One client_id `mereka-lms`, 24 redirect URIs, all envs.
- Blueprint: `bbi-infrastructure/apps/mereka-lms/authentik/mereka-lms-oidc-blueprint.yaml`. Declarative + safe.
- **Caveat**: the receiving-side ConfigMap `openedx-settings-lms-patched` is **MANUALLY created** per env (file `bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/patches/authentik-sso-settings.yaml` has a `MANUAL SETUP REQUIRED` header). If a pod restarts without it, OIDC breaks.

### Layer 3 — LMS user creation (JIT)

- First SSO login creates a Django User via `python-social-auth edx-oauth2`.
- Default: `is_staff=False, is_superuser=False, is_active=True`.
- **Authentik group membership is NOT propagated** to LMS. By design (AC-028 — `scripts/qa/verify-platform-admin-sso-isolation.sh`). Prevents compromised SAML assertions from elevating.

### Layer 4 — LMS admin allowlist (the fragile layer)

- `MerekaPlatformAdminMiddleware` reads env var `MEREKA_PLATFORM_ADMIN_EMAILS` on every authenticated request. If user.email in CSV → force `is_staff=True, is_superuser=True, is_active=True`.
- Middleware source: `bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/mereka_platform_admin.py`.
- Source of truth for the email list is **split across 4 places** and they don't agree.

## Drift found (live audit, 2026-04-20T03:50Z)

### Env var state (authoritative runtime)

Command: `kubectl --context $CTX -n $NS get deploy lms -o jsonpath='{range .spec.template.spec.containers[0].env[?(@.name=="MEREKA_PLATFORM_ADMIN_EMAILS")]}{.value}{"\n"}{end}'`

| Env | Context | Namespace | Value |
|---|---|---|---|
| Dev | rke2-nonprod | mereka-lms-dev | **empty string** |
| Staging | rke2-nonprod | stg-mereka-lms | **empty string** |
| Prod | rke2-prod | mereka-lms | **empty string** |

**Finding 1**: The middleware elevates nobody on any env. It is silent dead code.

### Actual superuser state in Django DB

Command: `kubectl exec deploy/lms -- ... get_user_model().objects.filter(is_superuser=True).values_list('email', flat=True)`

**Dev (10 superusers)**:
```
admin@greentactsolutions.com      ← UNKNOWN / SUSPICIOUS
gurpreet@biji-biji.com             ✓
malasari@mereka.my                 ✓
miranda@mereka.my                  ✓
faiz@mereka.io                     ✓
hira@mereka.io                     ✓
eugene@mereka.my                   ✓
testadmin@mereka.test              ✓ (synthetic canary)
lanea-platform-admin@synthetic.test ✓ (synthetic canary)
eugene@biji-biji.com               ✓
```

**Staging (10 superusers)**:
```
admin@greentactsolutions.com      ← UNKNOWN / SUSPICIOUS (same as dev)
gurpreet@biji-biji.com             ✓
malasari@mereka.my                 ✓
miranda@mereka.my                  ✓
faiz@mereka.io                     ✓
hira@mereka.io                     ✓
eugene@mereka.my                   ✓
miranda@mereka.io                  ← DOMAIN DRIFT (dev+prod use .my)
lanea-platform-admin@synthetic.test ✓
eugene@biji-biji.com               ✓
```

**Prod (8 superusers)**:
```
lanea-platform-admin@synthetic.test ✓
gurpreet@biji-biji.com             ✓
malasari@mereka.my                 ✓
miranda@mereka.my                  ✓
hira@mereka.io                     ✓
eugene@biji-biji.com               ✓
faiz@mereka.io                     ✓
eugene@mereka.my                   ✓
```

**Finding 2**: 3 anomalies across envs:
- `admin@greentactsolutions.com` is a superuser on **dev + staging** but **not prod**. Likely legacy from a previous consultant. Should be audited: valid account? should it be removed?
- `miranda@mereka.io` on **staging only**. Dev and prod use `miranda@mereka.my`. Either staging drifted or a new email was added only there. Worth reconciling.
- `testadmin@mereka.test` on **dev only**. Acceptable (synthetic test). Not needed on prod.

**Finding 3**: All 3 envs currently have 8 "core" platform admins plus synthetic canaries, roughly matching intent. But this state is **only in the DB** — if DB is reset or a fresh deploy runs without `ensure-platform-admins.sh`, all 3 envs would lose all admins.

### Defaults in the repo (app-repo git)

Two scripts have hardcoded defaults that don't match each other:

- `scripts/infra/ensure-platform-admins.sh:30` — 7 emails:
  `gurpreet@biji-biji.com,malasari@mereka.my,miranda@mereka.my,hira@mereka.io,eugene@biji-biji.com,eugene@mereka.my,faiz@mereka.io`
- `scripts/qa/verify-platform-admin-env.sh` — 2 emails (the "required" set):
  `gurpreet@biji-biji.com,malasari@mereka.my`
- Django production.py patch (in bbi-infra): reads `MEREKA_PLATFORM_ADMIN_EMAILS` but no overlay YAML sets a value — the kustomize deployment env var defaults to `""`.

**Finding 4**: There is no canonical declarative list. Three different "hardcoded defaults" plus a runtime env var with no declared source = drift is inevitable.

## Why this keeps breaking (root causes)

1. **Middleware backstop is always off in practice** — the env var is never populated by any overlay, so the middleware's "auto-elevate on login" path is dormant. Admins only survive because the DB state persists across pod restarts. A fresh DB (migration rebuild, disaster recovery, new env bring-up) loses everyone silently.
2. **Three hardcoded lists disagree** — `ensure-platform-admins.sh` has 7, `verify-platform-admin-env.sh` has 2, Django overlay has 0. None of them is the source of truth. Operators don't know which to trust.
3. **No single "onboard a person" entry point** — adding a new admin means remembering to update: Authentik admin-group blueprint, `MEREKA_PLATFORM_ADMIN_EMAILS` overlay env (which doesn't exist yet), `ensure-platform-admins.sh` default, enterprise-tenants.yaml if tenant-linked, then re-run ensure-platform-admins.sh to seed the DB.
4. **No verification that the 3 envs agree** — no CI job diffs dev vs staging vs prod superuser sets against an authoritative list. Drift (like `admin@greentactsolutions.com`, `miranda@mereka.io`) goes undetected for weeks.
5. **OIDC ConfigMap is MANUAL SETUP REQUIRED** — breaks on pod restart if the ConfigMap is absent. Separate fragility from the allowlist, but lives in the same architecture gap.

## Proposed durable fix: `config/platform-access.yaml`

Create **one YAML in the app repo** that drives all four layers. Generators render into each layer's native form:

```yaml
# config/platform-access.yaml
schema_version: "1.0"

platform_admins:
  - email: gurpreet@biji-biji.com
    envs: [dev, staging, prod]
    role: platform_admin          # → is_staff=True + is_superuser=True
    authentik_groups: [authentik Admins]
  - email: malasari@mereka.my
    envs: [dev, staging, prod]
    role: platform_admin
    authentik_groups: [authentik Admins]
  - email: miranda@mereka.my
    envs: [dev, staging, prod]
    role: platform_admin
  - email: hira@mereka.io
    envs: [dev, staging, prod]
    role: platform_admin
  - email: eugene@biji-biji.com
    envs: [dev, staging, prod]
    role: platform_admin
  - email: eugene@mereka.my
    envs: [dev, staging, prod]
    role: platform_admin
  - email: faiz@mereka.io
    envs: [dev, staging, prod]
    role: platform_admin

# Synthetic canaries used by smoke tests and health probes.
# Tests run on all envs, but synthetic accounts only need to exist on dev+staging.
synthetic_canaries:
  - email: lanea-platform-admin@synthetic.test
    envs: [dev, staging, prod]
    role: platform_admin
  - email: testadmin@mereka.test
    envs: [dev]
    role: platform_admin

# Enterprise admins continue to flow through config/enterprise-tenants/{env}.enterprise-tenants.yaml.
# This file is for PLATFORM-level staff only.
```

**Generators (one per layer)**:

1. `scripts/governance/render-authentik-admin-binding.py`
   → writes `bbi-infrastructure/branding/mereka/authentik/blueprints/05-admin-group-bindings.yaml`
2. `scripts/governance/render-platform-admin-env.py`
   → writes `MEREKA_PLATFORM_ADMIN_EMAILS` value into `bbi-infrastructure/apps/mereka-lms/overlays/{env}/patches/` env-injection YAML (this is the missing piece)
3. `scripts/infra/ensure-platform-admins.sh`
   → reads `config/platform-access.yaml` directly instead of hardcoded CSV
4. `scripts/qa/verify-platform-access-invariants.sh`
   → single check that reconciles all 4 layers against the YAML:
   - Authentik blueprint lists match YAML
   - `MEREKA_PLATFORM_ADMIN_EMAILS` env var on live deploys matches YAML per-env
   - Django DB `is_superuser=True` set matches YAML
   - Enterprise-tenant canaries exist per yaml

**CI gate**: `verify-platform-access-invariants.sh` runs on every PR; drift fails the build. Runs nightly against live clusters for runtime verification.

**ConfigMap elevation**: convert `openedx-settings-lms-patched` from "MANUAL SETUP REQUIRED" to a kustomize template generated from `config/platform-access.yaml` + env-specific values. ArgoCD then ensures it exists at every reconcile.

## Immediate actionable follow-ups (priority order)

1. **P0 — audit `admin@greentactsolutions.com`** on dev + staging. Is it a live account? Who owns it? Remove if dormant / unknown.
2. **P0 — reconcile `miranda@mereka.io` vs `miranda@mereka.my`** on staging. Is this intentional dual-admin, or did staging drift from dev/prod?
3. **P1 — set `MEREKA_PLATFORM_ADMIN_EMAILS` on all 3 envs** to the 7-admin baseline immediately, so the middleware backstop actually does something. Doesn't wait for the full consolidation PR.
4. **P1 — ship `config/platform-access.yaml` + 4 generators + verifier** as an epic (proposed bead prefix `auth-unified-access-control` or similar).
5. **P2 — convert `openedx-settings-lms-patched` ConfigMap to declarative** kustomize template.
6. **P2 — add ensure-platform-admins.sh to a scheduled CronJob** (or a pre-deploy migration-style Job) per env, so admin state self-heals after DB resets.

## Filed artifacts

- Evidence doc: this file
- Proposed beads (tracker is corrupted, will be filed post-repair):
  - `auth-allowlist-01` — audit + remediate greentactsolutions.com
  - `auth-allowlist-02` — reconcile miranda@mereka.io vs .my on staging
  - `auth-allowlist-03` — populate MEREKA_PLATFORM_ADMIN_EMAILS on all 3 overlays (short-term fix)
  - `auth-allowlist-04` — create config/platform-access.yaml + 4 generators (durable fix, epic)
  - `auth-allowlist-05` — migrate openedx-settings-lms-patched to declarative kustomize
  - `auth-allowlist-06` — scheduled ensure-platform-admins CronJob for self-healing
