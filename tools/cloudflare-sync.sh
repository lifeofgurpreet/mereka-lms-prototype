#!/usr/bin/env bash
# Sync Cloudflare DNS records with the canonical definition in ops/cloudflare/records.json.
# Requires: CLOUDFLARE_ZONE_ID and either CLOUDFLARE_API_TOKEN or
#            CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY, plus jq & curl
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECORDS_FILE=${1:-"$REPO_ROOT/ops/cloudflare/records.json"}
API_BASE="https://api.cloudflare.com/client/v4"
ZONE_ID=${CLOUDFLARE_ZONE_ID:?"Set CLOUDFLARE_ZONE_ID"}
DRY_RUN=${DRY_RUN:-false}

declare -a AUTH_HEADERS
if [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  AUTH_HEADERS=("-H" "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")
elif [[ -n "${CLOUDFLARE_EMAIL:-}" && -n "${CLOUDFLARE_API_KEY:-}" ]]; then
  AUTH_HEADERS=("-H" "X-Auth-Email: ${CLOUDFLARE_EMAIL}" "-H" "X-Auth-Key: ${CLOUDFLARE_API_KEY}")
else
  echo "Provide CLOUDFLARE_API_TOKEN or CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed" >&2
  exit 1
fi

if [[ ! -f "$RECORDS_FILE" ]]; then
  echo "Records file not found: $RECORDS_FILE" >&2
  exit 1
fi

echo "Syncing DNS records defined in $RECORDS_FILE"

status=0

jq -c '.[]' "$RECORDS_FILE" | while read -r record; do
  type=$(echo "$record" | jq -r '.type')
  name=$(echo "$record" | jq -r '.name')
  content=$(echo "$record" | jq -r '.content')
  ttl=$(echo "$record" | jq -r '.ttl')
  proxied=$(echo "$record" | jq -r '.proxied')
  description=$(echo "$record" | jq -r '.description // ""')

  existing=$(curl -fsSL "${AUTH_HEADERS[@]}" \
    -H "Content-Type: application/json" \
    "$API_BASE/zones/$ZONE_ID/dns_records?type=$type&name=$name") || {
      echo "Failed to query record $name" >&2
      status=1
      continue
    }

  record_id=$(echo "$existing" | jq -r '.result[0].id // empty')
  current_content=$(echo "$existing" | jq -r '.result[0].content // empty')
  current_ttl=$(echo "$existing" | jq -r '.result[0].ttl // empty')
  current_proxied=$(echo "$existing" | jq -r '.result[0].proxied // false')

  payload=$(jq -n --arg type "$type" --arg name "$name" --arg content "$content" \
    --argjson ttl "$ttl" --argjson proxied "$proxied" \
    --arg comment "$description" '{type:$type,name:$name,content:$content,ttl:$ttl,proxied:$proxied} + ( $comment | select(length>0) | {comment:$comment} )')

  if [[ -z "$record_id" ]]; then
    echo "[CREATE] $name -> $content"
    if [[ "$DRY_RUN" == "true" ]]; then
      continue
    fi
    curl -fsSL -X POST "$API_BASE/zones/$ZONE_ID/dns_records" \
      "${AUTH_HEADERS[@]}" \
      -H "Content-Type: application/json" \
      --data "$payload" >/dev/null || {
        echo "  ! Failed to create $name" >&2
        status=1
      }
    continue
  fi

  if [[ "$current_content" == "$content" && "$current_ttl" == "$ttl" && "$current_proxied" == "$proxied" ]]; then
    echo "[OK] $name already up to date"
    continue
  fi

  echo "[UPDATE] $name (content $current_content -> $content)"
  if [[ "$DRY_RUN" == "true" ]]; then
    continue
  fi
  curl -fsSL -X PUT "$API_BASE/zones/$ZONE_ID/dns_records/$record_id" \
    "${AUTH_HEADERS[@]}" \
    -H "Content-Type: application/json" \
    --data "$payload" >/dev/null || {
      echo "  ! Failed to update $name" >&2
      status=1
    }

done

exit $status
