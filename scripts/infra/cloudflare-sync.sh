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
  data=$(echo "$record" | jq -c '.data // null')
  priority=$(echo "$record" | jq -r '.priority // empty')

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
  current_data=$(echo "$existing" | jq -c '.result[0].data // null')

  base_payload=$(jq -n --arg type "$type" --arg name "$name" \
    --argjson ttl "$ttl" '{type:$type,name:$name,ttl:$ttl}')

  # include proxied flag only for record types that support it (A/AAAA/CNAME)
  case "$type" in
    A|AAAA|CNAME)
      base_payload=$(echo "$base_payload" | jq --argjson proxied "$proxied" '. + {proxied:$proxied}')
      ;;
  esac

  if [[ -n "$priority" ]]; then
    base_payload=$(echo "$base_payload" | jq --argjson priority "$priority" '. + {priority:$priority}')
  fi

  if [[ "$data" != "null" ]]; then
    payload=$(echo "$base_payload" | jq --argjson data "$data" '. + {data:$data}')
  else
    payload=$(echo "$base_payload" | jq --arg content "$content" '. + {content:$content}')
  fi

  if [[ -n "$description" ]]; then
    payload=$(echo "$payload" | jq --arg comment "$description" '. + {comment:$comment}')
  fi

  display_value=$content
  if [[ "$data" != "null" ]]; then
    display_value=$data
  fi

  if [[ -z "$record_id" ]]; then
    echo "[CREATE] $name -> $display_value"
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

  needs_update=false
  if [[ "$data" != "null" ]]; then
    desired_data=$(echo "$data" | jq -c '.')
    current_data_cmp=$current_data
    [[ "$current_data_cmp" == "null" ]] && current_data_cmp="null"
    if [[ "$current_data_cmp" == "$desired_data" && "$current_ttl" == "$ttl" ]]; then
      needs_update=false
    else
      needs_update=true
    fi
  else
    if [[ "$current_content" == "$content" && "$current_ttl" == "$ttl" && ( "$type" != "A" && "$type" != "AAAA" && "$type" != "CNAME" || "$current_proxied" == "$proxied" ) ]]; then
      needs_update=false
    else
      needs_update=true
    fi
  fi

  if [[ "$needs_update" == "false" ]]; then
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
