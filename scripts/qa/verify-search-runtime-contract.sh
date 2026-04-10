#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LMS_PRODUCTION="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS_PRODUCTION="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"
SECRETS_FILE="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
CRONJOB_FILE="$REPO_ROOT/deploy/k8s/base/monitoring/cronjob-course-reindex.yaml"

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

require_pattern "$LMS_PRODUCTION" 'MEILISEARCH_API_KEY = \(os\.environ\.get\("MEILISEARCH_API_KEY", ""\) or ""\)\.rstrip\("\\r\\n"\)' \
  "LMS trims trailing newlines from MEILISEARCH_API_KEY"
require_pattern "$CMS_PRODUCTION" 'MEILISEARCH_API_KEY = \(os\.environ\.get\("MEILISEARCH_API_KEY", ""\) or ""\)\.rstrip\("\\r\\n"\)' \
  "CMS trims trailing newlines from MEILISEARCH_API_KEY"
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

printf '\nSummary: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -ne 0 ]]; then
  exit 1
fi
