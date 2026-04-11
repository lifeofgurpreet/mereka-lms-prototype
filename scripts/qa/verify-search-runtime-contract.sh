#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LMS_PRODUCTION="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS_PRODUCTION="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"
SECRETS_FILE="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
CRONJOB_FILE="$REPO_ROOT/deploy/k8s/base/monitoring/cronjob-course-reindex.yaml"
CADDY_FILE="$REPO_ROOT/deploy/k8s/base/apps/caddy/Caddyfile"
DISCOVERY_SYNC_CRONJOB="$REPO_ROOT/deploy/k8s/base/jobs/discovery-sync-cronjob.yaml"
DISCOVERY_PRODUCTION="$REPO_ROOT/deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py"
DISCOVERY_DEVELOPMENT="$REPO_ROOT/deploy/k8s/base/plugins/discovery/apps/settings/tutor/development.py"
ENTERPRISE_CATALOG_DEPLOY="$REPO_ROOT/deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml"
ENTERPRISE_CATALOG_WORKER_DEPLOY="$REPO_ROOT/deploy/k8s/base/apps/enterprise/workers/enterprise-catalog-worker-deployment.yaml"
SEARCH_ARCH_DOC="$REPO_ROOT/docs/reference/architecture/SEARCH_ARCHITECTURE.md"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -q "$pattern" "$file"; then
    pass "$message"
  else
    fail "$message"
  fi
}

require_literal() {
  local file="$1"
  local text="$2"
  local message="$3"
  if rg -Fq "$text" "$file"; then
    pass "$message"
  else
    fail "$message"
  fi
}

forbid_literal() {
  local file="$1"
  local text="$2"
  local message="$3"
  if rg -Fq "$text" "$file"; then
    fail "$message"
  else
    pass "$message"
  fi
}

require_pattern "$LMS_PRODUCTION" 'MEILISEARCH_API_KEY = \(os\.environ\.get\("MEILISEARCH_API_KEY", ""\) or ""\)\.rstrip\("\\r\\n"\)' \
  "LMS trims trailing newlines from MEILISEARCH_API_KEY"
require_pattern "$CMS_PRODUCTION" 'MEILISEARCH_API_KEY = \(os\.environ\.get\("MEILISEARCH_API_KEY", ""\) or ""\)\.rstrip\("\\r\\n"\)' \
  "CMS trims trailing newlines from MEILISEARCH_API_KEY"
require_literal "$DISCOVERY_PRODUCTION" 'BACKEND_SERVICE_EDX_OAUTH2_SECRET = (' \
  "Discovery production settings define DISCOVERY_BACKEND_OAUTH2_SECRET via a helper expression"
require_literal "$DISCOVERY_PRODUCTION" ').rstrip("\r\n")' \
  "Discovery production settings trim trailing newlines from DISCOVERY_BACKEND_OAUTH2_SECRET"
require_literal "$DISCOVERY_DEVELOPMENT" 'BACKEND_SERVICE_EDX_OAUTH2_SECRET = (' \
  "Discovery development settings define DISCOVERY_BACKEND_OAUTH2_SECRET via a helper expression"
require_literal "$DISCOVERY_DEVELOPMENT" ').rstrip("\r\n")' \
  "Discovery development settings trim trailing newlines from DISCOVERY_BACKEND_OAUTH2_SECRET"
require_pattern "$CMS_PRODUCTION" 'SEARCH_ENGINE = "search\.meilisearch\.MeilisearchEngine"' \
  "CMS explicitly uses MeilisearchEngine when Meilisearch is enabled"
require_pattern "$CMS_PRODUCTION" 'def _apply_meilisearch_runtime_contract\(\):' \
  "CMS defines the Meilisearch runtime contract helper"
require_pattern "$CMS_PRODUCTION" 'unsupported primary key' \
  "CMS refuses non-empty Meilisearch indexes with the wrong primary key"
require_literal "$CMS_PRODUCTION" '_apply_meilisearch_runtime_contract()' \
  "CMS applies the Meilisearch runtime contract at settings load"
require_pattern "$LMS_PRODUCTION" 'def _is_mongodb_srv_uri\(raw_value\):' \
  "LMS defines SRV URI detection helper"
require_pattern "$CMS_PRODUCTION" 'def _is_mongodb_srv_uri\(raw_value\):' \
  "CMS defines SRV URI detection helper"
require_pattern "$LMS_PRODUCTION" 'def _is_mongodb_atlas_host\(raw_value\):' \
  "LMS defines Atlas host detection helper"
require_pattern "$CMS_PRODUCTION" 'def _is_mongodb_atlas_host\(raw_value\):' \
  "CMS defines Atlas host detection helper"
require_pattern "$LMS_PRODUCTION" 'if not _is_mongodb_srv_uri\(MONGODB_HOST\):' \
  "LMS omits hardcoded Mongo port for SRV modulestore URIs"
require_pattern "$CMS_PRODUCTION" 'if not _is_mongodb_srv_uri\(MONGODB_HOST\):' \
  "CMS omits hardcoded Mongo port for SRV modulestore URIs"
require_pattern "$SECRETS_FILE" 'secretKey: MEILISEARCH_MASTER_KEY' \
  "External secrets define MEILISEARCH_MASTER_KEY"
require_pattern "$SECRETS_FILE" 'secretKey: MEILISEARCH_API_KEY' \
  "External secrets define MEILISEARCH_API_KEY"
require_pattern "$CRONJOB_FILE" "(echo y \\| python manage\\.py cms reindex_course --all|printf 'y\\\\n' \\| python manage\\.py cms reindex_course --all)" \
  "Course reindex cronjob is non-interactive"
require_pattern "$CRONJOB_FILE" 'SEARCH_ENGINE=' \
  "Course reindex cronjob resolves SEARCH_ENGINE at runtime"
require_literal "$CRONJOB_FILE" 'search.elastic.ElasticSearchEngine)' \
  "Course reindex cronjob handles Elasticsearch verification"
require_literal "$CRONJOB_FILE" 'search.meilisearch.MeilisearchEngine)' \
  "Course reindex cronjob handles Meilisearch verification"
require_literal "$LMS_PRODUCTION" 'FEATURES["ENABLE_COURSE_DISCOVERY"] = True' \
  "LMS still publishes ENABLE_COURSE_DISCOVERY as a compatibility contract"
require_literal "$LMS_PRODUCTION" '"DISCOVERY_API_BASE_URL": MEREKA_DISCOVERY_BASE_URL' \
  "LMS still publishes DISCOVERY_API_BASE_URL as a compatibility contract"
require_literal "$REPO_ROOT/scripts/tenants/bootstrap-enterprise-service-deps.sh" '"discovery|discovery_worker|client-credentials|DISCOVERY_BACKEND_OAUTH2_SECRET"' \
  "Enterprise service bootstrap script creates the Discovery backend OAuth client"
require_literal "$REPO_ROOT/scripts/tenants/bootstrap-enterprise-service-deps.sh" "'programs_api_url': ''" \
  "Enterprise service bootstrap script leaves programs_api_url empty when LMS has no legacy programs API"
require_literal "$REPO_ROOT/scripts/tenants/bootstrap-enterprise-service-deps.sh" 'if [[ ! "$NAMESPACE" =~ dev ]]; then' \
  "Enterprise service bootstrap script restricts stale prod-domain site cleanup to dev namespaces"
require_literal "$DISCOVERY_SYNC_CRONJOB" 'http://discovery:8000' \
  "Discovery sync cronjob still targets the Discovery service"
require_literal "$DISCOVERY_SYNC_CRONJOB" 'course_discovery.settings.tutor.production' \
  "Discovery sync cronjob uses the Tutor production settings module"
require_literal "$DISCOVERY_SYNC_CRONJOB" 'docker.io/overhangio/openedx-discovery:21.0.1' \
  "Discovery sync cronjob uses the Discovery image instead of the LMS image"
require_literal "$DISCOVERY_SYNC_CRONJOB" '/openedx/discovery/course_discovery/settings/tutor/production.py' \
  "Discovery sync cronjob mounts the Discovery production settings bundle"
require_literal "$DISCOVERY_SYNC_CRONJOB" 'name: discovery-settings' \
  "Discovery sync cronjob mounts the discovery-settings configmap"
require_literal "$DISCOVERY_SYNC_CRONJOB" 'search_index --rebuild -f --disable-change-limit' \
  "Discovery sync cronjob rebuilds empty indexes when update_index hits missing-index bootstrap"
require_literal "$DISCOVERY_SYNC_CRONJOB" 'Discovery metadata refresh failed' \
  "Discovery sync cronjob fails loudly instead of masking metadata-refresh errors"
forbid_literal "$DISCOVERY_SYNC_CRONJOB" 'refresh_program_metadata' \
  "Discovery sync cronjob does not call the removed refresh_program_metadata command"
require_literal "$DISCOVERY_SYNC_CRONJOB" 'Discovery index update failed' \
  "Discovery sync cronjob fails loudly instead of masking index-update errors"
require_literal "$ENTERPRISE_CATALOG_DEPLOY" 'DISCOVERY_SERVICE_URL' \
  "Enterprise catalog deployment still references DISCOVERY_SERVICE_URL"
require_literal "$ENTERPRISE_CATALOG_DEPLOY" 'DISCOVERY_SERVICE_API_URL' \
  "Enterprise catalog deployment still references DISCOVERY_SERVICE_API_URL"
require_literal "$ENTERPRISE_CATALOG_WORKER_DEPLOY" 'DISCOVERY_SERVICE_URL' \
  "Enterprise catalog worker still references DISCOVERY_SERVICE_URL"
require_literal "$ENTERPRISE_CATALOG_WORKER_DEPLOY" 'DISCOVERY_SERVICE_API_URL' \
  "Enterprise catalog worker still references DISCOVERY_SERVICE_API_URL"
require_literal "$CADDY_FILE" 'redir @discovery_root /health/' \
  "Base Caddyfile redirects Discovery root to /health/"
require_pattern "$CADDY_FILE" 'Query Preview UI' \
  "Base Caddyfile documents why Discovery root is redirected"
require_literal "$SEARCH_ARCH_DOC" '### Remaining Discovery Consumers' \
  "Canonical search architecture documents the remaining Discovery consumers"
require_literal "$SEARCH_ARCH_DOC" 'Discovery retirement criteria' \
  "Canonical search architecture documents Discovery retirement criteria"

printf '\nSummary: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
  exit 1
fi
