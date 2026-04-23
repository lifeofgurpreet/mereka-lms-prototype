#!/usr/bin/env bash
# Prune stale buildx builder containers from the fastlane VPS runner.
#
# Behavior:
#   - Lists all buildx builders via `docker buildx ls`
#   - Identifies stale ones (containers older than MAX_AGE_HOURS hours)
#   - Defers destructive cleanup while Docker/BuildKit substrate work is active
#   - Removes them via `docker buildx rm` (for buildx-managed builders) or
#     `docker rm -f` (for orphaned buildkit containers not tracked by buildx)
#   - Reports counts: before / removed / after
#   - Never removes the `default` buildx builder
#   - Never touches non-buildx containers
#
# Exit codes:
#   0  all requested removals succeeded (or dry-run)
#   1  docker daemon is unavailable
#   2  partial failure (some builders removed, some failed)
#
# Usage:
#   buildx-cleanup.sh [--dry-run] [--max-keep N]
#
# Options:
#   --dry-run        List stale builders without removing them
#   --max-keep N     Keep the N newest builders (default: 2)
#
# Intended cadence: every 30 minutes via cron or post-job hook.
# See docs/ops/ci-cd/RUNNER_HYGIENE.md for installation instructions.

set -euo pipefail

# ── Constants ───────────────────────────────────────────────────────────────
readonly SCRIPT_NAME="buildx-cleanup"
readonly DEFAULT_MAX_KEEP=2
readonly DEFAULT_MAX_AGE_HOURS=1
readonly BUILDX_CONTAINER_PREFIX="buildx_buildkit"
readonly PROTECTED_BUILDER="default"

# ── Defaults ────────────────────────────────────────────────────────────────
DRY_RUN=0
MAX_KEEP="${MAX_KEEP:-${DEFAULT_MAX_KEEP}}"
MAX_AGE_HOURS="${MAX_AGE_HOURS:-${DEFAULT_MAX_AGE_HOURS}}"

# ── Helpers ─────────────────────────────────────────────────────────────────
log() {
  printf "[%s] [%s] %s\n" "$(date '+%Y-%m-%dT%H:%M:%SZ')" "${SCRIPT_NAME}" "$*"
}

die() {
  log "ERROR: $*" >&2
  exit 1
}

usage() {
  printf 'Usage: %s [--dry-run] [--max-keep N]\n' "$(basename "$0")"
  printf '\n'
  printf 'Options:\n'
  printf '  --dry-run        List stale builders without removing them\n'
  printf '  --max-keep N     Keep the N newest builders (default: %d)\n' "${DEFAULT_MAX_KEEP}"
  printf '\n'
  printf 'Environment:\n'
  printf '  MAX_KEEP         Same as --max-keep (overridden by flag)\n'
  printf '  MAX_AGE_HOURS    Age threshold for stale detection (default: %d)\n' "${DEFAULT_MAX_AGE_HOURS}"
}

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --max-keep)
      if [[ -z "${2:-}" ]] || ! [[ "${2}" =~ ^[0-9]+$ ]]; then
        die "--max-keep requires a non-negative integer"
      fi
      MAX_KEEP="$2"
      shift 2
      ;;
    --max-keep=*)
      val="${1#--max-keep=}"
      if ! [[ "${val}" =~ ^[0-9]+$ ]]; then
        die "--max-keep requires a non-negative integer"
      fi
      MAX_KEEP="${val}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

# ── Docker availability check ────────────────────────────────────────────────
if ! docker info >/dev/null 2>&1; then
  log "ERROR: docker daemon is not reachable (socket unavailable or permission denied)" >&2
  exit 1
fi

# ── List buildx builders ─────────────────────────────────────────────────────
# `docker buildx ls --format '{{.Name}}'` is supported from Docker 23+.
# Fall back to text parsing for older daemons.
list_buildx_builders() {
  if docker buildx ls --format '{{.Name}}' >/dev/null 2>&1; then
    docker buildx ls --format '{{.Name}}' 2>/dev/null | grep -v '^$' || true
  else
    # Fallback: parse the tabular output, first column is the builder name.
    # Strip the trailing * that marks the active builder.
    docker buildx ls 2>/dev/null \
      | tail -n +2 \
      | awk '{print $1}' \
      | sed 's/\*$//' \
      | grep -v '^$' \
      || true
  fi
}

# ── List buildkit orphan containers ─────────────────────────────────────────
# Containers named buildx_buildkit_* that are NOT backed by a live buildx
# builder entry.  These arise when `docker buildx rm` is interrupted.
list_orphan_buildkit_containers() {
  docker ps -a \
    --filter "name=${BUILDX_CONTAINER_PREFIX}" \
    --format '{{.Names}}' 2>/dev/null \
    | grep -v '^$' \
    || true
}

# ── Determine container age in seconds ───────────────────────────────────────
# Returns the age of the underlying buildkit container for a builder, or
# empty string if the container doesn't exist.
builder_container_age_seconds() {
  local builder="$1"
  local container_name="${BUILDX_CONTAINER_PREFIX}_${builder}"
  local created_at
  created_at="$(docker inspect --format '{{.Created}}' "${container_name}" 2>/dev/null || true)"
  if [[ -z "${created_at}" ]]; then
    echo ""
    return 0
  fi
  local created_epoch now_epoch
  # `date -d` works on Linux (GNU coreutils); fall back gracefully if unavailable.
  created_epoch="$(date -d "${created_at}" +%s 2>/dev/null || date -j -f '%Y-%m-%dT%H:%M:%S' "${created_at%%.*}" +%s 2>/dev/null || echo 0)"
  now_epoch="$(date +%s)"
  echo $((now_epoch - created_epoch))
}

# ── Check for active Docker/BuildKit commands before destructive cleanup ─────
# BuildKit containers are long-running daemons, so container state alone cannot
# distinguish an idle stale builder from a live build.  The post-job/cron path
# must therefore defer destructive cleanup when active build, bake, pull, or
# buildctl work is still present on the shared runner.
active_build_processes() {
  if ! command -v pgrep >/dev/null 2>&1; then
    return 1
  fi

  local proc_line
  while IFS= read -r proc_line; do
    [[ -n "${proc_line}" ]] || continue
    [[ "${proc_line}" == *"${SCRIPT_NAME}"* ]] && continue

    if [[ "${proc_line}" =~ (^|[[:space:]/])docker[[:space:]]+buildx[[:space:]]+(build|bake)([[:space:]]|$) ]] \
      || [[ "${proc_line}" =~ (^|[[:space:]/])docker[[:space:]]+build([[:space:]]|$) ]] \
      || [[ "${proc_line}" =~ (^|[[:space:]/])docker[[:space:]]+pull([[:space:]]|$) ]] \
      || [[ "${proc_line}" =~ (^|[[:space:]/])buildctl[[:space:]]+build([[:space:]]|$) ]]; then
      printf '%s\n' "${proc_line}"
    fi
  done < <(pgrep -af '(^|[[:space:]/])(docker|buildctl)([[:space:]]|$)' 2>/dev/null || true)
}

# ── Main logic ───────────────────────────────────────────────────────────────
log "Starting buildx cleanup (dry_run=${DRY_RUN}, max_keep=${MAX_KEEP}, max_age_hours=${MAX_AGE_HOURS})"

all_builders=()
while IFS= read -r name; do
  [[ -n "${name}" ]] || continue
  all_builders+=("${name}")
done < <(list_buildx_builders)

count_before="${#all_builders[@]}"
log "Found ${count_before} buildx builder(s): ${all_builders[*]:-<none>}"

# Separate protected and candidate builders.
protected=()
candidates=()
for b in "${all_builders[@]}"; do
  if [[ "${b}" == "${PROTECTED_BUILDER}" ]]; then
    protected+=("${b}")
  else
    candidates+=("${b}")
  fi
done

if [[ "${#protected[@]}" -gt 0 ]]; then
  log "Protected (never removed): ${protected[*]}"
fi

# Apply max-keep: sort candidates by container creation time (newest first),
# then retain the N newest.
declare -a sorted_candidates
if [[ "${#candidates[@]}" -gt 0 ]]; then
  # Build a list of "timestamp builder" pairs, then sort descending.
  declare -a timestamped
  for b in "${candidates[@]}"; do
    container_name="${BUILDX_CONTAINER_PREFIX}_${b}"
    ts="$(docker inspect --format '{{.Created}}' "${container_name}" 2>/dev/null || echo '1970-01-01T00:00:00Z')"
    timestamped+=("${ts} ${b}")
  done
  # Sort descending (newest first).
  while IFS= read -r line; do
    sorted_candidates+=("${line#* }")
  done < <(printf '%s\n' "${timestamped[@]}" | sort -r)
fi

to_keep=()
to_remove=()
max_age_seconds=$((MAX_AGE_HOURS * 3600))

for i in "${!sorted_candidates[@]}"; do
  b="${sorted_candidates[$i]}"
  if [[ $i -lt ${MAX_KEEP} ]]; then
    to_keep+=("${b}")
    log "KEEP  ${b} (within max-keep=${MAX_KEEP}, rank=$((i + 1)))"
    continue
  fi
  # Candidate for removal — check age.
  age_seconds="$(builder_container_age_seconds "${b}")"
  if [[ -z "${age_seconds}" ]]; then
    # No underlying container found — always remove the dangling builder entry.
    to_remove+=("${b}")
    log "QUEUE ${b} for removal (no backing container)"
    continue
  fi
  if [[ "${age_seconds}" -lt "${max_age_seconds}" ]]; then
    to_keep+=("${b}")
    log "KEEP  ${b} (age=${age_seconds}s < threshold=${max_age_seconds}s)"
  else
    to_remove+=("${b}")
    log "QUEUE ${b} for removal (age=${age_seconds}s >= threshold=${max_age_seconds}s)"
  fi
done

# Also find orphan buildkit containers (not tracked by any buildx builder).
known_containers=()
for b in "${all_builders[@]}"; do
  known_containers+=("${BUILDX_CONTAINER_PREFIX}_${b}")
done

orphan_containers=()
while IFS= read -r cname; do
  [[ -n "${cname}" ]] || continue
  local_known=0
  for kc in "${known_containers[@]:-}"; do
    if [[ "${cname}" == "${kc}" ]]; then
      local_known=1
      break
    fi
  done
  if [[ "${local_known}" -eq 0 ]]; then
    orphan_containers+=("${cname}")
    log "QUEUE orphan container ${cname} for removal"
  fi
done < <(list_orphan_buildkit_containers)

total_to_remove=$(( ${#to_remove[@]} + ${#orphan_containers[@]} ))

if [[ "${total_to_remove}" -eq 0 ]]; then
  log "Nothing to remove. builders=${count_before}, kept=${#to_keep[@]}, orphans=0"
  exit 0
fi

active_processes="$(active_build_processes || true)"
if [[ -n "${active_processes}" ]]; then
  log "Active Docker/BuildKit substrate process detected; deferring destructive cleanup"
  while IFS= read -r proc_line; do
    [[ -n "${proc_line}" ]] || continue
    log "  active: ${proc_line}"
  done <<<"${active_processes}"
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    log "Deferred cleanup. candidates=${#to_remove[@]}, orphans=${#orphan_containers[@]}"
    exit 0
  fi
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  log "DRY RUN — would remove ${#to_remove[@]} builder(s) and ${#orphan_containers[@]} orphan container(s)"
  for b in "${to_remove[@]}"; do
    log "  would remove builder: ${b}"
  done
  for c in "${orphan_containers[@]}"; do
    log "  would remove orphan container: ${c}"
  done
  exit 0
fi

# ── Removal ──────────────────────────────────────────────────────────────────
removed_count=0
failed_count=0

for b in "${to_remove[@]}"; do
  log "Removing builder: ${b}"
  if docker buildx rm "${b}" 2>/dev/null; then
    log "  removed builder: ${b}"
    removed_count=$((removed_count + 1))
  else
    log "  WARN: failed to remove builder '${b}' via buildx rm; trying direct container removal"
    container_name="${BUILDX_CONTAINER_PREFIX}_${b}"
    if docker rm -f "${container_name}" 2>/dev/null; then
      log "  removed orphaned container: ${container_name}"
      removed_count=$((removed_count + 1))
    else
      log "  ERROR: could not remove builder '${b}' or its container" >&2
      failed_count=$((failed_count + 1))
    fi
  fi
done

for c in "${orphan_containers[@]}"; do
  log "Removing orphan container: ${c}"
  if docker rm -f "${c}" 2>/dev/null; then
    log "  removed orphan container: ${c}"
    removed_count=$((removed_count + 1))
  else
    log "  ERROR: could not remove orphan container '${c}'" >&2
    failed_count=$((failed_count + 1))
  fi
done

# Count remaining builders.
remaining=()
while IFS= read -r name; do
  [[ -n "${name}" ]] || continue
  remaining+=("${name}")
done < <(list_buildx_builders)
count_after="${#remaining[@]}"

log "Summary: before=${count_before} removed=${removed_count} failed=${failed_count} after=${count_after}"

if [[ "${failed_count}" -gt 0 ]]; then
  log "Partial failure: ${failed_count} builder(s) could not be removed" >&2
  exit 2
fi

exit 0
