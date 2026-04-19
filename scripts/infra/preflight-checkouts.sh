#!/usr/bin/env bash
# preflight-checkouts.sh — Print the live state of the operator's canonical
# checkouts so any agent or human can immediately see "what truth am I looking
# at" at the start of a session.
#
# Bead: mereka-lms-p74m (VPS checkouts are not canonical)
#
# Reports for each checkout:
#   - branch name
#   - local HEAD (short sha + one-line subject)
#   - origin/main tip
#   - ahead/behind counts vs origin/main
#   - dirty state (modified / untracked count)
#   - last fetch time (relative)
#
# Exits 0 unconditionally. Observability only — never blocks operator flow.
#
# Usage:
#   preflight-checkouts.sh                # default CHECKOUT_ROOT=$HOME/projects/k8s
#   CHECKOUT_ROOT=/some/other/path preflight-checkouts.sh
#   preflight-checkouts.sh --quiet        # skip the header banner

set -euo pipefail

CHECKOUT_ROOT="${CHECKOUT_ROOT:-${HOME}/projects/k8s}"
CHECKOUTS=("mereka-lms" "bbi-infrastructure")

QUIET=0
for arg in "$@"; do
  case "$arg" in
    --quiet|-q) QUIET=1 ;;
    --help|-h)
      sed -n '3,20p' "${BASH_SOURCE[0]}" >&2
      exit 0
      ;;
  esac
done

fmt_relative_time() {
  local epoch="$1"
  if [[ -z "$epoch" || "$epoch" == "0" ]]; then
    printf 'never'
    return
  fi
  local now
  now="$(date -u +%s)"
  local delta=$(( now - epoch ))
  if (( delta < 60 )); then printf '%ds ago' "$delta"
  elif (( delta < 3600 )); then printf '%dm ago' $(( delta / 60 ))
  elif (( delta < 86400 )); then printf '%dh ago' $(( delta / 3600 ))
  else printf '%dd ago' $(( delta / 86400 ))
  fi
}

report_checkout() {
  local name="$1"
  local path="${CHECKOUT_ROOT}/${name}"

  if [[ ! -d "${path}/.git" ]]; then
    printf '%-22s MISSING (%s)\n' "$name" "$path"
    return
  fi

  local branch head_sha head_subject origin_main ahead behind dirty_mods dirty_untracked fetch_epoch fetch_rel

  branch="$(git -C "$path" branch --show-current 2>/dev/null || echo 'DETACHED')"
  [[ -z "$branch" ]] && branch="DETACHED"
  head_sha="$(git -C "$path" rev-parse --short HEAD 2>/dev/null || echo '???????')"
  head_subject="$(git -C "$path" log -1 --pretty=format:'%s' 2>/dev/null || echo 'unknown')"

  if git -C "$path" rev-parse --verify origin/main >/dev/null 2>&1; then
    origin_main="$(git -C "$path" rev-parse --short origin/main)"
    ahead="$(git -C "$path" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)"
    behind="$(git -C "$path" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"
  else
    origin_main="NO_ORIGIN_MAIN"
    ahead=0
    behind=0
  fi

  dirty_mods="$(git -C "$path" diff --name-only 2>/dev/null | wc -l)"
  dirty_untracked="$(git -C "$path" ls-files --others --exclude-standard 2>/dev/null | wc -l)"

  fetch_epoch=0
  if [[ -f "$path/.git/FETCH_HEAD" ]]; then
    fetch_epoch="$(stat -c %Y "$path/.git/FETCH_HEAD" 2>/dev/null || echo 0)"
  fi
  fetch_rel="$(fmt_relative_time "$fetch_epoch")"

  # One compact line per checkout
  printf '%-22s branch=%-40s HEAD=%s (%.60s)\n' \
    "$name" "$branch" "$head_sha" "$head_subject"
  printf '%-22s origin/main=%s ahead=%s behind=%s mods=%s untracked=%s fetched=%s\n' \
    '' "$origin_main" "$ahead" "$behind" "$dirty_mods" "$dirty_untracked" "$fetch_rel"
}

if [[ $QUIET -eq 0 ]]; then
  echo "=== VPS Checkout Preflight ==="
  echo "CHECKOUT_ROOT=${CHECKOUT_ROOT}"
  echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "---"
fi

for name in "${CHECKOUTS[@]}"; do
  report_checkout "$name"
done

exit 0
