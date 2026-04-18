#!/usr/bin/env bash
# generate-current-operator-state.sh
# -----------------------------------------------------------------------------
# Updates the dynamic sections of docs/status/active/CURRENT-OPERATOR-STATE.md
# from LIVE sources:
#   - gh pr list                         (PR queue truth, both repos)
#   - kubectl --context rke2-nonprod     (cluster truth)
#   - br ready                           (tracker truth)
#   - git log / git status               (repo truth)
#
# Edits IN PLACE. The file's stable skeleton (Purpose, Operating Rules,
# Refresh Procedure, Standing Priorities, etc.) is preserved. Only the three
# dynamic sections are replaced:
#
#   - ## Current Live Truth
#   - ## Current Queue Truth
#   - ## Next Exact Move
#
# Hand-edits to the stable sections ARE authority. Hand-edits to the three
# dynamic sections are drafts — re-run this script to refresh from live
# sources.
#
# Usage:
#   scripts/governance/generate-current-operator-state.sh [--no-cluster] [--dry-run]
#
# Options:
#   --file PATH       File to edit in place (default: docs/status/active/CURRENT-OPERATOR-STATE.md)
#   --no-cluster      Skip kubectl live-cluster section (useful when cluster
#                     unreachable; other sections still update)
#   --dry-run         Print the updated file to stdout; do not modify disk
#   -h | --help       Show this help and exit
#
# Exit codes:
#   0  success (file updated or printed)
#   1  missing dependency (gh / kubectl / jq / br / python3 / git)
#   2  usage error or target file missing / malformed
#
# Related:
#   - Bead: mereka-lms-5dz5 (this generator)
#   - Bead: mereka-lms-y69t (Truth Repair Doctrine — Rule 1: canonical = generated)
#   - docs/status/active/HOURLY-OPERATOR-LOOP-PROMPT.md (the loop that calls this)
#   - docs/meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md (authority reference)
# -----------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${REPO_ROOT}/docs/status/active/CURRENT-OPERATOR-STATE.md"
NO_CLUSTER=0
DRY_RUN=0

APP_REPO="Biji-Biji-Initiative/mereka-lms"
INFRA_REPO="Biji-Biji-Initiative/bbi-infrastructure"
DEV_CONTEXT="rke2-nonprod"
DEV_NS="mereka-lms-dev"
DEV_APP="mereka-lms-dev"

die() { echo "error: $*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)       TARGET="${2:-}"; shift 2 ;;
    --no-cluster) NO_CLUSTER=1; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    -h|--help)    sed -n '1,40p' "$0"; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

for cmd in gh jq git br python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: required command not in PATH: $cmd" >&2; exit 1; }
done
if [[ $NO_CLUSTER -eq 0 ]]; then
  command -v kubectl >/dev/null 2>&1 || { echo "error: kubectl not in PATH (use --no-cluster to skip live-cluster section)" >&2; exit 1; }
fi

[[ -f "$TARGET" ]] || die "target file does not exist: $TARGET"
grep -q '^## Current Live Truth$'   "$TARGET" || die "$TARGET: missing '## Current Live Truth' section"
grep -q '^## Current Queue Truth$'  "$TARGET" || die "$TARGET: missing '## Current Queue Truth' section"
grep -q '^## Next Exact Move$'      "$TARGET" || die "$TARGET: missing '## Next Exact Move' section"

NOW_UTC="$(date -u +%Y-%m-%dT%H:%MZ)"

# ── build Current Live Truth section body ────────────────────────────────────
build_live_truth() {
  local ambient="—" sync="—" health="—" rev="—" auto_heal="0"
  local deploy_summary="—"
  if [[ $NO_CLUSTER -eq 0 ]]; then
    ambient="$(kubectl config current-context 2>/dev/null || echo '?')"
    local argo_json
    argo_json="$(kubectl --context "$DEV_CONTEXT" -n argocd get application "$DEV_APP" -o json 2>/dev/null || echo '{}')"
    sync="$(echo "$argo_json" | jq -r '.status.sync.status // "—"')"
    health="$(echo "$argo_json" | jq -r '.status.health.status // "—"')"
    rev="$(echo "$argo_json" | jq -r '.status.sync.revision // "—"')"
    auto_heal="$(echo "$argo_json" | jq -r '.status.operationState.operation.sync.autoHealAttemptsCount // "0"')"
    local deploy_json
    deploy_json="$(kubectl --context "$DEV_CONTEXT" -n "$DEV_NS" get deploy -o json 2>/dev/null || echo '{"items":[]}')"
    deploy_summary="$(echo "$deploy_json" | jq -r '[.items[] | "\(.metadata.name):\((.status.readyReplicas // 0))/\(.spec.replicas)"] | join(", ")')"
    [[ -z "$deploy_summary" ]] && deploy_summary="—"
  fi
  cat <<EOF
_Observed at \`${NOW_UTC}\` (UTC). Every kubectl command below pins \`--context ${DEV_CONTEXT}\` because ambient context on \`ssh mereka\` drifts to \`rke2-prod\` between sessions._

- Dev cluster: \`${DEV_CONTEXT}\`
  - Argo app state: \`sync=${sync} health=${health}\`
  - revision: \`${rev}\`
  - auto-heal count: \`${auto_heal}\`
  - deployment readiness summary: ${deploy_summary}
  - ambient kubectl context at generation: \`${ambient}\`
- Notable runtime observations: (machine output: none. Add manually if you observed something the dashboard would miss.)

Re-prove command:
\`\`\`bash
kubectl --context ${DEV_CONTEXT} -n argocd get application ${DEV_APP} \\
  -o jsonpath='sync={.status.sync.status} health={.status.health.status} rev={.status.sync.revision}{"\\n"}'
\`\`\`
If the output of that command disagrees with the table above, trust the command, not this file.

EOF
}

# ── build Current Queue Truth section body ───────────────────────────────────
build_queue_truth() {
  local app_open infra_open app_merged infra_merged ready_list
  app_open="$(gh pr list --repo "$APP_REPO" --state open --limit 20 --json number,title,mergeStateStatus 2>/dev/null || echo '[]')"
  infra_open="$(gh pr list --repo "$INFRA_REPO" --state open --limit 20 --json number,title,mergeStateStatus 2>/dev/null || echo '[]')"
  app_merged="$(gh pr list --repo "$APP_REPO" --state merged --base main --limit 6 --json number,title,mergedAt,mergeCommit 2>/dev/null || echo '[]')"
  infra_merged="$(gh pr list --repo "$INFRA_REPO" --state merged --base main --limit 6 --json number,title,mergedAt,mergeCommit 2>/dev/null || echo '[]')"
  ready_list="$(br ready --limit 8 2>&1 | sed -n '/^[0-9]\./p' | head -8)"
  [[ -z "$ready_list" ]] && ready_list="(br ready returned no rows)"

  {
    echo "_Queue snapshot at \`${NOW_UTC}\`._"
    echo ""
    echo "### Open PRs — \`${APP_REPO}\`"
    echo ""
    local open_count
    open_count="$(echo "$app_open" | jq 'length')"
    if [[ "$open_count" -eq 0 ]]; then
      echo "_No open PRs._"
    else
      echo "$app_open" | jq -r '.[] | "- [#\(.number)](https://github.com/'"${APP_REPO}"'/pull/\(.number)) \(.mergeStateStatus) — \(.title | gsub("\\|"; "/"))"'
    fi
    echo ""
    echo "### Open PRs — \`${INFRA_REPO}\`"
    echo ""
    open_count="$(echo "$infra_open" | jq 'length')"
    if [[ "$open_count" -eq 0 ]]; then
      echo "_No open PRs._"
    else
      echo "$infra_open" | jq -r '.[] | "- [#\(.number)](https://github.com/'"${INFRA_REPO}"'/pull/\(.number)) \(.mergeStateStatus) — \(.title | gsub("\\|"; "/"))"'
    fi
    echo ""
    echo "### Last merges to \`main\` — \`${APP_REPO}\`"
    echo ""
    echo "$app_merged" | jq -r '.[] | "- [#\(.number)](https://github.com/'"${APP_REPO}"'/pull/\(.number)) \((.mergeCommit.oid // "")[0:12]) — \(.title | gsub("\\|"; "/"))"'
    echo ""
    echo "### Last merges to \`main\` — \`${INFRA_REPO}\`"
    echo ""
    echo "$infra_merged" | jq -r '.[] | "- [#\(.number)](https://github.com/'"${INFRA_REPO}"'/pull/\(.number)) \((.mergeCommit.oid // "")[0:12]) — \(.title | gsub("\\|"; "/"))"'
    echo ""
    echo "### Ready work from \`br ready\` (top 8)"
    echo ""
    echo '```'
    echo "$ready_list"
    echo '```'
    echo ""
  }
}

# ── build Next Exact Move section body ───────────────────────────────────────
build_next_move() {
  local branch head_sha head_subject
  branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  head_sha="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
  head_subject="$(git -C "$REPO_ROOT" log -1 --format='%s' 2>/dev/null || echo '?')"
  cat <<EOF
_Computed at \`${NOW_UTC}\`. Replace this with a specific action for the next loop iteration._

Current checkout: branch \`${branch}\`, HEAD \`${head_sha}\` — _${head_subject}_.

Default next move if nothing else is obviously higher-leverage:

1. Re-prove live truth (see re-prove command in Current Live Truth).
2. Inspect BLOCKED / BEHIND PRs above; rebase or fix CI failures for the top of the queue.
3. Claim the top \`br ready\` item that retires a named failure class (P0/P1 beats P2 housekeeping).
4. Regenerate this file at end of slice with \`bash scripts/governance/generate-current-operator-state.sh\`.

Before ending a loop, write the next concrete action here so the next iteration can start without oral context. Canonical authority here is the last human-authored sentence on this line — the default text above is a floor, not a plan.

### Authority

This file is regenerated from live state by
\`scripts/governance/generate-current-operator-state.sh\`. That mechanism
is the enforcement of [Truth Repair Doctrine](../meta/standing-orders/TRUTH_REPAIR_DOCTRINE.md)
Rule 1 — *canonical state is generated, not written*. The three dynamic
sections above (Current Live Truth, Current Queue Truth, Next Exact Move)
are rewritten on every run; the stable skeleton (Purpose, Operating Rules,
Refresh Procedure, Standing Priorities) is preserved verbatim. Hand-edits
to the dynamic sections are drafts, not authority.

If the doctrine itself needs to change, update the doctrine file first,
then the generator, then this file — in that order, in one tranche, per
the doctrine's own Rule 5 on coordinated verifier-affecting changes.

EOF
}

LIVE_BODY="$(build_live_truth)"
QUEUE_BODY="$(build_queue_truth)"
NEXT_BODY="$(build_next_move)"

# ── in-place update via Python ───────────────────────────────────────────────
OUTPUT="$(python3 - "$TARGET" <<PYEOF
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

live_body  = """$LIVE_BODY"""
queue_body = """$QUEUE_BODY"""
next_body  = """$NEXT_BODY"""

def replace_section(text, heading, body):
    # Match from the heading line to the next top-level ## heading or EOF.
    pattern = re.compile(
        r"(^## " + re.escape(heading) + r"\s*\n)(.*?)(?=^## |\Z)",
        re.MULTILINE | re.DOTALL,
    )
    if not pattern.search(text):
        print(f"error: section not found: {heading}", file=sys.stderr)
        sys.exit(2)
    return pattern.sub(lambda m: m.group(1) + "\n" + body.rstrip() + "\n\n", text, count=1)

text = replace_section(text, "Current Live Truth",  live_body)
text = replace_section(text, "Current Queue Truth", queue_body)
text = replace_section(text, "Next Exact Move",     next_body)

sys.stdout.write(text)
PYEOF
)"

if [[ $DRY_RUN -eq 1 ]]; then
  printf '%s' "$OUTPUT"
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
printf '%s' "$OUTPUT" > "$tmp"
mv "$tmp" "$TARGET"
echo "updated $TARGET at $NOW_UTC" >&2
