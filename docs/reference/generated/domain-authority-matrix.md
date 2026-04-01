# Domain Authority Matrix

_Generated from `deploy/k8s/tenancy/tenant-registry.yaml` v1.5.0 on 2026-04-01._
_Do not hand-edit. Regenerate with: `python scripts/domains/generate_domain_authority_matrix.py`_

## production

| Tenant | Env | Hostname | Role | Status | Namespace | Cluster | ArgoCD App | Priority |
|--------|-----|----------|------|--------|-----------|---------|------------|----------|
| biji-biji | production | `analytics.academy.biji-biji.com` | analytics | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| biji-biji | production | `credentials.academy.biji-biji.com` | credentials | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| biji-biji | production | `admin.academy.biji-biji.com` | enterprise-admin | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| biji-biji | production | `learner.academy.biji-biji.com` | enterprise-learner | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| biji-biji | production | `apps.academy.biji-biji.com` | mfe | active | mereka-lms | prod-gke | mereka-lms-prod | P0 |
| biji-biji | production | `preview.academy.biji-biji.com` | preview | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| biji-biji | production | `academy.biji-biji.com` | primary | active | mereka-lms | prod-gke | mereka-lms-prod | P0 |
| biji-biji | production | `studio.academy.biji-biji.com` | studio | active | mereka-lms | prod-gke | mereka-lms-prod | P0 |
| mereka | production | `analytics.academyv2.mereka.io` | analytics | active | mereka-lms | prod-gke | mereka-lms-prod | P1 |
| mereka | production | `auth0.mereka.io` | auth | active | mereka-lms | prod-gke | mereka-lms-prod | P0 |
| mereka | production | `credentials.academyv2.mereka.io` | credentials | active | mereka-lms | prod-gke | mereka-lms-prod | P1 |
| mereka | production | `discovery.academyv2.mereka.io` | discovery | active | mereka-lms | prod-gke | mereka-lms-prod | P0 |
| mereka | production | `ecommerce.academyv2.mereka.io` | ecommerce | deprecated | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| mereka | production | `admin.academyv2.mereka.io` | enterprise-admin | active | mereka-lms | prod-gke | mereka-lms-prod | P1 |
| mereka | production | `learner.academyv2.mereka.io` | enterprise-learner | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| mereka | production | `forum.academyv2.mereka.io` | forum | active | mereka-lms | prod-gke | mereka-lms-prod | P1 |
| mereka | production | `apps.academyv2.mereka.io` | mfe | active | mereka-lms | prod-gke | mereka-lms-prod | P0 |
| mereka | production | `notes.academyv2.mereka.io` | notes | active | mereka-lms | prod-gke | mereka-lms-prod | P1 |
| mereka | production | `preview.academyv2.mereka.io` | preview | active | mereka-lms | prod-gke | mereka-lms-prod | P1 |
| mereka | production | `academyv2.mereka.io` | primary | active | mereka-lms | prod-gke | mereka-lms-prod | P0 |
| mereka | production | `studio.academyv2.mereka.io` | studio | active | mereka-lms | prod-gke | mereka-lms-prod | P0 |
| skillourfuture | production | `analytics.skillourfuture.academyv2.mereka.io` | analytics | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| skillourfuture | production | `credentials.skillourfuture.academyv2.mereka.io` | credentials | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| skillourfuture | production | `admin.skillourfuture.academyv2.mereka.io` | enterprise-admin | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| skillourfuture | production | `learner.skillourfuture.academyv2.mereka.io` | enterprise-learner | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| skillourfuture | production | `apps.skillourfuture.academy.mereka.io` | mfe | deprecated | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| skillourfuture | production | `apps.skillourfuture.academyv2.mereka.io` | mfe | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| skillourfuture | production | `preview.skillourfuture.academyv2.mereka.io` | preview | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| skillourfuture | production | `skillourfuture.academy.mereka.io` | primary | active | mereka-lms | prod-gke | mereka-lms-prod | P0 |
| skillourfuture | production | `skillourfuture.academyv2.mereka.io` | primary | active | mereka-lms | prod-gke | mereka-lms-prod | P1 |
| skillourfuture | production | `studio.skillourfuture.academy.mereka.io` | studio | deprecated | mereka-lms | prod-gke | mereka-lms-prod | P2 |
| skillourfuture | production | `studio.skillourfuture.academyv2.mereka.io` | studio | active | mereka-lms | prod-gke | mereka-lms-prod | P2 |

## staging

| Tenant | Env | Hostname | Role | Status | Namespace | Cluster | ArgoCD App | Priority |
|--------|-----|----------|------|--------|-----------|---------|------------|----------|
| biji-biji | staging | `analytics.staging.academy.biji-biji.com` | analytics | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| biji-biji | staging | `credentials.staging.academy.biji-biji.com` | credentials | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| biji-biji | staging | `admin.staging.academy.biji-biji.com` | enterprise-admin | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| biji-biji | staging | `learner.staging.academy.biji-biji.com` | enterprise-learner | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| biji-biji | staging | `apps.staging.academy.biji-biji.com` | mfe | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| biji-biji | staging | `preview.staging.academy.biji-biji.com` | preview | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| biji-biji | staging | `staging.academy.biji-biji.com` | primary | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| biji-biji | staging | `studio.staging.academy.biji-biji.com` | studio | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| mereka | staging | `analytics.staging.academyv2.mereka.io` | analytics | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| mereka | staging | `staging.auth0.mereka.io` | auth | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| mereka | staging | `staging.credentials.academyv2.mereka.io` | credentials | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| mereka | staging | `staging.discovery.academyv2.mereka.io` | discovery | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P1 |
| mereka | staging | `staging.admin.academyv2.mereka.io` | enterprise-admin | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P1 |
| mereka | staging | `staging.learner.academyv2.mereka.io` | enterprise-learner | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| mereka | staging | `staging.forum.academyv2.mereka.io` | forum | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| mereka | staging | `staging.apps.academyv2.mereka.io` | mfe | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| mereka | staging | `staging.notes.academyv2.mereka.io` | notes | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| mereka | staging | `staging.preview.academyv2.mereka.io` | preview | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P1 |
| mereka | staging | `staging.academyv2.mereka.io` | primary | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| mereka | staging | `staging.studio.academyv2.mereka.io` | studio | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| skillourfuture | staging | `analytics.staging.skillourfuture.academyv2.mereka.io` | analytics | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| skillourfuture | staging | `credentials.staging.skillourfuture.academyv2.mereka.io` | credentials | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| skillourfuture | staging | `admin.staging.skillourfuture.academyv2.mereka.io` | enterprise-admin | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| skillourfuture | staging | `learner.staging.skillourfuture.academyv2.mereka.io` | enterprise-learner | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| skillourfuture | staging | `apps.staging.skillourfuture.academy.mereka.io` | mfe | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| skillourfuture | staging | `apps.staging.skillourfuture.academyv2.mereka.io` | mfe | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P1 |
| skillourfuture | staging | `preview.staging.skillourfuture.academyv2.mereka.io` | preview | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P2 |
| skillourfuture | staging | `staging.skillourfuture.academy.mereka.io` | primary | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| skillourfuture | staging | `staging.skillourfuture.academyv2.mereka.io` | primary | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P1 |
| skillourfuture | staging | `studio.staging.skillourfuture.academy.mereka.io` | studio | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P0 |
| skillourfuture | staging | `studio.staging.skillourfuture.academyv2.mereka.io` | studio | active | stg-mereka-lms | nonprod-rke2 | mereka-lms-staging | P1 |

## dev

| Tenant | Env | Hostname | Role | Status | Namespace | Cluster | ArgoCD App | Priority |
|--------|-----|----------|------|--------|-----------|---------|------------|----------|
| biji-biji | dev | `analytics.biji-biji.academyv2.mereka.dev` | analytics | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| biji-biji | dev | `credentials.biji-biji.academyv2.mereka.dev` | credentials | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| biji-biji | dev | `admin.biji-biji.academyv2.mereka.dev` | enterprise-admin | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| biji-biji | dev | `learner.biji-biji.academyv2.mereka.dev` | enterprise-learner | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| biji-biji | dev | `apps.biji-biji.academyv2.mereka.dev` | mfe | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| biji-biji | dev | `preview.biji-biji.academyv2.mereka.dev` | preview | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| biji-biji | dev | `biji-biji.academyv2.mereka.dev` | primary | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| biji-biji | dev | `studio.biji-biji.academyv2.mereka.dev` | studio | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| mereka | dev | `analytics.academyv2.mereka.dev` | analytics | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | dev | `auth0.mereka.dev` | auth | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| mereka | dev | `credentials.academyv2.mereka.dev` | credentials | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | dev | `discovery.academyv2.mereka.dev` | discovery | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| mereka | dev | `admin.academyv2.mereka.dev` | enterprise-admin | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | dev | `learner.academyv2.mereka.dev` | enterprise-learner | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | dev | `forum.academyv2.mereka.dev` | forum | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | dev | `apps.academyv2.mereka.dev` | mfe | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| mereka | dev | `notes.academyv2.mereka.dev` | notes | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | dev | `preview.academyv2.mereka.dev` | preview | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | dev | `academyv2.mereka.dev` | primary | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| mereka | dev | `studio.academyv2.mereka.dev` | studio | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| skillourfuture | dev | `analytics.skillourfuture.academyv2.mereka.dev` | analytics | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| skillourfuture | dev | `credentials.skillourfuture.academyv2.mereka.dev` | credentials | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| skillourfuture | dev | `admin.skillourfuture.academyv2.mereka.dev` | enterprise-admin | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| skillourfuture | dev | `learner.skillourfuture.academyv2.mereka.dev` | enterprise-learner | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| skillourfuture | dev | `apps.skillourfuture.academyv2.mereka.dev` | mfe | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| skillourfuture | dev | `preview.skillourfuture.academyv2.mereka.dev` | preview | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| skillourfuture | dev | `skillourfuture.academyv2.mereka.dev` | primary | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| skillourfuture | dev | `studio.skillourfuture.academyv2.mereka.dev` | studio | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |

## profiles-dev

| Tenant | Env | Hostname | Role | Status | Namespace | Cluster | ArgoCD App | Priority |
|--------|-----|----------|------|--------|-----------|---------|------------|----------|
| mereka | profiles-dev | `credentials-dev.mereka.dev` | credentials | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | profiles-dev | `discovery-dev.mereka.dev` | discovery | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | profiles-dev | `admin-dev.mereka.dev` | enterprise-admin | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | profiles-dev | `learner-dev.mereka.dev` | enterprise-learner | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | profiles-dev | `mfe-dev.mereka.dev` | mfe | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| mereka | profiles-dev | `notes-dev.mereka.dev` | notes | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | profiles-dev | `preview-dev.mereka.dev` | preview | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P2 |
| mereka | profiles-dev | `lms-dev.mereka.dev` | primary | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |
| mereka | profiles-dev | `studio-dev.mereka.dev` | studio | active | mereka-lms-dev | nonprod-rke2 | mereka-lms-dev | P1 |

## Summary

- **Total domains**: 100
- **Active**: 97
- **Deprecated**: 3
- **Environments**: dev, production, profiles-dev, staging
- **Tenants**: biji-biji, mereka, skillourfuture
