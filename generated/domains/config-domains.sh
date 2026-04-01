#!/usr/bin/env bash
# =============================================================================
# Domain Settings — GENERATED from tenant-registry.yaml
# DO NOT EDIT — regenerate with:
#   python scripts/domains/generate_config_domains.py
# =============================================================================

# Canonical app-owned tenant/domain source lives in
# deploy/k8s/tenancy/tenant-registry.yaml.
# This file provides derived shell defaults for scripts and must stay aligned
# with the tenant registry rather than becoming a second authority plane.
# Production
export LMS_DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
export STUDIO_DOMAIN="${STUDIO_DOMAIN:-studio.academyv2.mereka.io}"
export MFE_DOMAIN="${MFE_DOMAIN:-apps.academyv2.mereka.io}"
export AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth0.mereka.io}"
export PREVIEW_DOMAIN="${PREVIEW_DOMAIN:-preview.academyv2.mereka.io}"
export DISCOVERY_DOMAIN="${DISCOVERY_DOMAIN:-discovery.academyv2.mereka.io}"

# Legacy Oscar ecommerce (deprecated — being replaced by purchase-gateway)
# Kept during dual-stack transition period; will be removed after AC-027/AC-028 close
export ECOMMERCE_DOMAIN="${ECOMMERCE_DOMAIN:-ecommerce.academyv2.mereka.io}"
export NOTES_DOMAIN="${NOTES_DOMAIN:-notes.academyv2.mereka.io}"
export CREDENTIALS_DOMAIN="${CREDENTIALS_DOMAIN:-credentials.academyv2.mereka.io}"
export FORUM_DOMAIN="${FORUM_DOMAIN:-forum.academyv2.mereka.io}"

# Enterprise MFE domains
export ENTERPRISE_ADMIN_DOMAIN="${ENTERPRISE_ADMIN_DOMAIN:-admin.academyv2.mereka.io}"
export ENTERPRISE_PORTAL_DOMAIN="${ENTERPRISE_PORTAL_DOMAIN:-learner.academyv2.mereka.io}"

# Alternative domains (multisite)
export BIJI_DOMAIN="${BIJI_DOMAIN:-academy.biji-biji.com}"
export BIJI_STUDIO_DOMAIN="${BIJI_STUDIO_DOMAIN:-studio.academy.biji-biji.com}"
export BIJI_MFE_DOMAIN="${BIJI_MFE_DOMAIN:-apps.academy.biji-biji.com}"
export SKILLOURFUTURE_DOMAIN="${SKILLOURFUTURE_DOMAIN:-skillourfuture.academy.mereka.io}"
export SKILLOURFUTURE_STUDIO_DOMAIN="${SKILLOURFUTURE_STUDIO_DOMAIN:-studio.skillourfuture.academyv2.mereka.io}"
export SKILLOURFUTURE_MFE_DOMAIN="${SKILLOURFUTURE_MFE_DOMAIN:-apps.skillourfuture.academyv2.mereka.io}"

# Biji-Biji dedicated subdomains (public DNS)

# Development
export DEV_LMS_DOMAIN="${DEV_LMS_DOMAIN:-academyv2.mereka.dev}"
export DEV_STUDIO_DOMAIN="${DEV_STUDIO_DOMAIN:-studio.academyv2.mereka.dev}"
export DEV_MFE_DOMAIN="${DEV_MFE_DOMAIN:-apps.academyv2.mereka.dev}"
export DEV_AUTHENTIK_DOMAIN="${DEV_AUTHENTIK_DOMAIN:-auth0.mereka.dev}"
export DEV_PREVIEW_DOMAIN="${DEV_PREVIEW_DOMAIN:-preview.academyv2.mereka.dev}"
export DEV_DISCOVERY_DOMAIN="${DEV_DISCOVERY_DOMAIN:-discovery.academyv2.mereka.dev}"
export DEV_NOTES_DOMAIN="${DEV_NOTES_DOMAIN:-notes.academyv2.mereka.dev}"
export DEV_CREDENTIALS_DOMAIN="${DEV_CREDENTIALS_DOMAIN:-credentials.academyv2.mereka.dev}"
export DEV_FORUM_DOMAIN="${DEV_FORUM_DOMAIN:-forum.academyv2.mereka.dev}"

# Enterprise MFE domains (dev)
export DEV_ENTERPRISE_ADMIN_DOMAIN="${DEV_ENTERPRISE_ADMIN_DOMAIN:-admin.academyv2.mereka.dev}"
export DEV_ENTERPRISE_PORTAL_DOMAIN="${DEV_ENTERPRISE_PORTAL_DOMAIN:-learner.academyv2.mereka.dev}"

# DEV tenant-pattern domains
export DEV_BIJI_DOMAIN="${DEV_BIJI_DOMAIN:-biji-biji.academyv2.mereka.dev}"
export DEV_BIJI_STUDIO_DOMAIN="${DEV_BIJI_STUDIO_DOMAIN:-studio.biji-biji.academyv2.mereka.dev}"
export DEV_BIJI_MFE_DOMAIN="${DEV_BIJI_MFE_DOMAIN:-apps.biji-biji.academyv2.mereka.dev}"
export DEV_SKILLOURFUTURE_DOMAIN="${DEV_SKILLOURFUTURE_DOMAIN:-skillourfuture.academyv2.mereka.dev}"
export DEV_SKILLOURFUTURE_STUDIO_DOMAIN="${DEV_SKILLOURFUTURE_STUDIO_DOMAIN:-studio.skillourfuture.academyv2.mereka.dev}"
export DEV_SKILLOURFUTURE_MFE_DOMAIN="${DEV_SKILLOURFUTURE_MFE_DOMAIN:-apps.skillourfuture.academyv2.mereka.dev}"

# Purchase Gateway is path-routed under the LMS host via /payments/*.
# There is no standalone payments.<domain> hostname in the active platform contract.

# Staging (active non-prod lane on shared rke2-nonprod today)
export STAGING_LMS_DOMAIN="${STAGING_LMS_DOMAIN:-staging.academyv2.mereka.io}"
export STAGING_STUDIO_DOMAIN="${STAGING_STUDIO_DOMAIN:-staging.studio.academyv2.mereka.io}"
export STAGING_MFE_DOMAIN="${STAGING_MFE_DOMAIN:-staging.apps.academyv2.mereka.io}"
export STAGING_AUTHENTIK_DOMAIN="${STAGING_AUTHENTIK_DOMAIN:-staging.auth0.mereka.io}"
export STAGING_PREVIEW_DOMAIN="${STAGING_PREVIEW_DOMAIN:-staging.preview.academyv2.mereka.io}"
export STAGING_DISCOVERY_DOMAIN="${STAGING_DISCOVERY_DOMAIN:-staging.discovery.academyv2.mereka.io}"
export STAGING_NOTES_DOMAIN="${STAGING_NOTES_DOMAIN:-staging.notes.academyv2.mereka.io}"
export STAGING_CREDENTIALS_DOMAIN="${STAGING_CREDENTIALS_DOMAIN:-staging.credentials.academyv2.mereka.io}"
export STAGING_FORUM_DOMAIN="${STAGING_FORUM_DOMAIN:-staging.forum.academyv2.mereka.io}"

# Enterprise MFE domains (staging)
export STAGING_ENTERPRISE_ADMIN_DOMAIN="${STAGING_ENTERPRISE_ADMIN_DOMAIN:-staging.admin.academyv2.mereka.io}"
export STAGING_ENTERPRISE_PORTAL_DOMAIN="${STAGING_ENTERPRISE_PORTAL_DOMAIN:-staging.learner.academyv2.mereka.io}"

# Purchase Gateway (staging)
