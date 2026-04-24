#!/usr/bin/env bash
# Seed a dev MongoDB Atlas cluster with fixtures for local development.
#
# NEVER run this against production. The --obliterate flag will drop collections.
#
# Usage:
#   export MONGODB_CONNECTION_STRING="mongodb+srv://user:pass@cluster.mongodb.net"
#   ./scripts/infra/seed-mongo-dev.sh [--dry-run] [--obliterate]
#
# @covers T045
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# ----------------------------------------------------------------------------
# Color helpers (matches existing infra script convention)
# ----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

fail()  { echo -e "${RED}ERROR${NC}: $1" >&2; exit 1; }
warn()  { echo -e "${YELLOW}WARN${NC}: $1"; }
ok()    { echo -e "${GREEN}OK${NC}: $1"; }
info()  { echo -e "${BLUE}INFO${NC}: $1"; }
step()  { echo -e "\n${BLUE}==>${NC} $1"; }

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------
DRY_RUN=false
OBLITERATE=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Seed a dev MongoDB Atlas cluster with Open edX and forum fixtures.

Options:
  --dry-run     Print what would be done without executing any writes.
  --obliterate  Drop seeded collections before inserting (destructive!).
                Requires interactive confirmation unless FORCE_OBLITERATE=1.
  -h, --help    Show this help message.

Required environment:
  MONGODB_CONNECTION_STRING   Atlas connection string (mongodb+srv://...)

Example:
  export MONGODB_CONNECTION_STRING="mongodb+srv://${MONGODB_DEV_USER}:${MONGODB_DEV_PASSWORD}@cluster-dev.abc.mongodb.net"
  $(basename "$0") --dry-run
  $(basename "$0")
  $(basename "$0") --obliterate
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=true ;;
    --obliterate) OBLITERATE=true ;;
    -h|--help)    usage; exit 0 ;;
    *) fail "Unknown argument: $arg. Use --help for usage." ;;
  esac
done

# ----------------------------------------------------------------------------
# Guards
# ----------------------------------------------------------------------------
if [[ -z "${MONGODB_CONNECTION_STRING:-}" ]]; then
  fail "MONGODB_CONNECTION_STRING is not set. Export your dev Atlas connection string first."
fi

# Reject obvious production strings to reduce risk of accidental prod writes.
if echo "$MONGODB_CONNECTION_STRING" | grep -qiE 'cluster-mereka-lms\.2pjex4s'; then
  fail "MONGODB_CONNECTION_STRING appears to point at the PRODUCTION Atlas cluster. Refusing to seed."
fi

# Detect available Mongo tooling
MONGO_CMD=""
if command -v mongosh >/dev/null 2>&1; then
  MONGO_CMD="mongosh"
elif command -v mongo >/dev/null 2>&1; then
  MONGO_CMD="mongo"
fi

MONGOIMPORT_CMD=""
if command -v mongoimport >/dev/null 2>&1; then
  MONGOIMPORT_CMD="mongoimport"
fi

if [[ -z "$MONGO_CMD" && -z "$MONGOIMPORT_CMD" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    warn "Neither mongosh/mongo nor mongoimport found on PATH — dry-run only, no writes attempted."
  else
    fail "Neither mongosh/mongo nor mongoimport found on PATH. Install MongoDB Database Tools: https://www.mongodb.com/try/download/database-tools"
  fi
fi

info "Mongo shell : ${MONGO_CMD:-<not found>}"
info "mongoimport : ${MONGOIMPORT_CMD:-<not found>}"
info "Dry-run     : $DRY_RUN"
info "Obliterate  : $OBLITERATE"

# ----------------------------------------------------------------------------
# Connection validation
# ----------------------------------------------------------------------------
step "Validating connection to Atlas..."

if [[ "$DRY_RUN" == "true" ]]; then
  warn "[dry-run] Would run: mongosh \"<connection-string>\" --eval 'db.adminCommand({ping:1})'"
elif [[ -n "$MONGO_CMD" ]]; then
  if ! "$MONGO_CMD" "$MONGODB_CONNECTION_STRING" --quiet --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1; then
    fail "Connection to Atlas failed. Check MONGODB_CONNECTION_STRING and Atlas IP allowlist."
  fi
  ok "Atlas connection verified."
else
  # mongoimport can't ping; do a lightweight test via mongosh if available, else skip
  warn "mongosh not available — skipping ping. Connection errors will surface during import."
fi

# ----------------------------------------------------------------------------
# Obliterate collections (optional, destructive)
# ----------------------------------------------------------------------------
OPENEDX_COLLECTIONS=("modulestore.definitions" "modulestore.active_versions" "user.profiles")
FORUM_COLLECTIONS=("contents")

if [[ "$OBLITERATE" == "true" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    warn "[dry-run] Would drop collections:"
    for col in "${OPENEDX_COLLECTIONS[@]}"; do
      warn "  openedx.$col"
    done
    for col in "${FORUM_COLLECTIONS[@]}"; do
      warn "  cs_comments_service.$col"
    done
  else
    if [[ "${FORCE_OBLITERATE:-}" != "1" ]]; then
      echo -e "${RED}"
      echo "  !!  DESTRUCTIVE OPERATION  !!"
      echo "  This will DROP the following collections before seeding:"
      for col in "${OPENEDX_COLLECTIONS[@]}"; do
        echo "    openedx.$col"
      done
      for col in "${FORUM_COLLECTIONS[@]}"; do
        echo "    cs_comments_service.$col"
      done
      echo -e "${NC}"
      read -r -p "Type YES to confirm obliterate: " confirm_input
      [[ "$confirm_input" == "YES" ]] || fail "Obliterate cancelled."
    fi

    if [[ -n "$MONGO_CMD" ]]; then
      step "Dropping openedx collections..."
      for col in "${OPENEDX_COLLECTIONS[@]}"; do
        "$MONGO_CMD" "$MONGODB_CONNECTION_STRING/openedx" --quiet \
          --eval "db.getCollection('${col}').drop(); print('dropped ${col}');"
      done

      step "Dropping cs_comments_service collections..."
      for col in "${FORUM_COLLECTIONS[@]}"; do
        "$MONGO_CMD" "$MONGODB_CONNECTION_STRING/cs_comments_service" --quiet \
          --eval "db.getCollection('${col}').drop(); print('dropped ${col}');"
      done
      ok "Collections dropped."
    else
      warn "mongosh not available — cannot drop collections. Proceeding with upsert-only import."
    fi
  fi
fi

# ----------------------------------------------------------------------------
# Seed helper
# ----------------------------------------------------------------------------
SEEDED_COLLECTIONS=()
SEEDED_COUNTS=()

import_fixture() {
  local db="$1"
  local collection="$2"
  local fixture_file="$3"

  if [[ ! -f "$fixture_file" ]]; then
    fail "Fixture file not found: $fixture_file"
  fi

  local doc_count
  doc_count=$(python3 -c "import json,sys; data=json.load(open('$fixture_file')); print(len(data) if isinstance(data,list) else 1)" 2>/dev/null || echo "?")

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] Would import $doc_count document(s) from $(basename "$fixture_file") -> $db.$collection"
    SEEDED_COLLECTIONS+=("$db.$collection")
    SEEDED_COUNTS+=("$doc_count (dry-run)")
    return
  fi

  if [[ -n "$MONGOIMPORT_CMD" ]]; then
    "$MONGOIMPORT_CMD" \
      --uri "$MONGODB_CONNECTION_STRING" \
      --db "$db" \
      --collection "$collection" \
      --file "$fixture_file" \
      --jsonArray \
      --mode upsert \
      --quiet
  elif [[ -n "$MONGO_CMD" ]]; then
    # Fallback: load JSON in mongosh
    "$MONGO_CMD" "$MONGODB_CONNECTION_STRING/$db" --quiet --eval "
      const docs = $(cat "$fixture_file");
      const arr = Array.isArray(docs) ? docs : [docs];
      arr.forEach(doc => db.getCollection('${collection}').replaceOne(
        { _id: doc._id },
        doc,
        { upsert: true }
      ));
      print('upserted ' + arr.length + ' document(s) into ${collection}');
    "
  else
    fail "No import tool available. This should have been caught earlier."
  fi

  SEEDED_COLLECTIONS+=("$db.$collection")
  SEEDED_COUNTS+=("$doc_count")
}

# ----------------------------------------------------------------------------
# Seed: openedx database
# ----------------------------------------------------------------------------
step "Seeding openedx database..."

# Split the single fixture file by _type so each collection gets the right docs.
# We extract sub-arrays per type using Python and pipe to mongoimport/mongosh.
OPENEDX_FIXTURE="$FIXTURES_DIR/openedx-demo-course.json"

seed_openedx_collection() {
  local type_filter="$1"
  local collection="$2"
  local tmp_file
  tmp_file="$(mktemp /tmp/seed-mongo-XXXXXX.json)"

  python3 -c "
import json, sys
data = json.load(open('$OPENEDX_FIXTURE'))
subset = [d for d in data if d.get('_type', '') == '$type_filter']
json.dump(subset, sys.stdout, default=str)
" > "$tmp_file"

  local count
  count=$(python3 -c "import json; print(len(json.load(open('$tmp_file'))))" 2>/dev/null || echo "?")

  if [[ "$count" == "0" ]]; then
    warn "No documents matched _type='$type_filter' in $(basename "$OPENEDX_FIXTURE") — skipping $collection."
    rm -f "$tmp_file"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] Would import $count doc(s) matching _type='$type_filter' -> openedx.$collection"
    SEEDED_COLLECTIONS+=("openedx.$collection")
    SEEDED_COUNTS+=("$count (dry-run)")
    rm -f "$tmp_file"
    return
  fi

  import_fixture "openedx" "$collection" "$tmp_file"
  rm -f "$tmp_file"

  # Replace the last entry added by import_fixture with a more descriptive one
  local last_idx=$(( ${#SEEDED_COLLECTIONS[@]} - 1 ))
  SEEDED_COLLECTIONS[$last_idx]="openedx.$collection"
  SEEDED_COUNTS[$last_idx]="$count"
}

seed_openedx_collection "org"          "modulestore.active_versions"
seed_openedx_collection "definition"   "modulestore.definitions"
seed_openedx_collection "user.profile" "user.profiles"

# ----------------------------------------------------------------------------
# Seed: cs_comments_service database (forum)
# ----------------------------------------------------------------------------
step "Seeding cs_comments_service database (forum)..."
import_fixture "cs_comments_service" "contents" "$FIXTURES_DIR/forum-seed.json"

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
step "Seed summary"
echo ""
printf "  %-45s %s\n" "Collection" "Documents"
printf "  %-45s %s\n" "-----------------------------------------" "---------"
for i in "${!SEEDED_COLLECTIONS[@]}"; do
  printf "  %-45s %s\n" "${SEEDED_COLLECTIONS[$i]}" "${SEEDED_COUNTS[$i]}"
done
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  warn "Dry-run complete — no data was written."
else
  ok "Dev seed complete. To reset, re-run with --obliterate."
fi
