#!/usr/bin/env bash
# cleanup-stale-branches.sh — Remove merged branches and stale worktrees
#
# Usage:
#   ./scripts/infra/cleanup-stale-branches.sh [--dry-run] [--remote]
#
# Flags:
#   --dry-run   Show what would be deleted without deleting
#   --remote    Also prune merged remote branches (requires push access)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=false
PRUNE_REMOTE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --remote) PRUNE_REMOTE=true ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Stale Branch & Worktree Cleanup ==="
echo "Repo: $REPO_ROOT"
echo "Dry run: $DRY_RUN"
echo

# ─── Section 1: Stale local branches (merged to main) ───
echo "=== Local branches merged to main ==="
MERGED_LOCAL=$(git branch --merged main | grep -v '^\*' | grep -v 'main' | grep -v 'worktree-' | sed 's/^[ +]*//' || true)

if [[ -z "$MERGED_LOCAL" ]]; then
  echo -e "${GREEN}No stale local branches found${NC}"
else
  COUNT=$(echo "$MERGED_LOCAL" | wc -l)
  echo -e "${YELLOW}Found $COUNT merged local branches:${NC}"
  echo "$MERGED_LOCAL" | while read -r branch; do
    echo "  - $branch"
  done
  echo
  if [[ "$DRY_RUN" == "false" ]]; then
    echo "$MERGED_LOCAL" | while read -r branch; do
      git branch -d "$branch" 2>/dev/null && echo -e "${GREEN}Deleted${NC} $branch" || echo -e "${RED}Failed${NC} $branch (may be checked out in worktree)"
    done
  else
    echo "(dry run — no deletions)"
  fi
fi
echo

# ─── Section 2: Stale remote branches (merged to main) ───
if [[ "$PRUNE_REMOTE" == "true" ]]; then
  echo "=== Remote branches merged to main ==="
  git fetch --prune origin 2>/dev/null
  MERGED_REMOTE=$(git branch -r --merged main | grep -v 'origin/main' | grep -v 'origin/HEAD' | sed 's/^[ ]*//' || true)

  if [[ -z "$MERGED_REMOTE" ]]; then
    echo -e "${GREEN}No stale remote branches found${NC}"
  else
    COUNT=$(echo "$MERGED_REMOTE" | wc -l)
    echo -e "${YELLOW}Found $COUNT merged remote branches:${NC}"
    echo "$MERGED_REMOTE" | while read -r branch; do
      echo "  - $branch"
    done
    echo
    if [[ "$DRY_RUN" == "false" ]]; then
      echo "$MERGED_REMOTE" | while read -r branch; do
        REMOTE_NAME=$(echo "$branch" | sed 's|origin/||')
        git push origin --delete "$REMOTE_NAME" 2>/dev/null && echo -e "${GREEN}Deleted remote${NC} $REMOTE_NAME" || echo -e "${RED}Failed${NC} $REMOTE_NAME"
      done
    else
      echo "(dry run — no deletions)"
    fi
  fi
  echo
fi

# ─── Section 3: Stale worktrees ───
echo "=== Git worktrees ==="
WORKTREE_LIST=$(git worktree list --porcelain)

STALE_COUNT=0
while IFS= read -r line; do
  if [[ "$line" == worktree\ * ]]; then
    WT_PATH="${line#worktree }"
    # Skip the main worktree
    if [[ "$WT_PATH" == "$REPO_ROOT" ]]; then
      continue
    fi
    # Check if the worktree has uncommitted changes
    if [[ -d "$WT_PATH" ]]; then
      LAST_COMMIT_AGE=$(git -C "$WT_PATH" log -1 --format="%cr" 2>/dev/null || echo "unknown")
      BRANCH=$(git -C "$WT_PATH" branch --show-current 2>/dev/null || echo "detached")
      echo -e "  ${YELLOW}$WT_PATH${NC}"
      echo "    Branch: $BRANCH | Last commit: $LAST_COMMIT_AGE"
      STALE_COUNT=$((STALE_COUNT + 1))
    fi
  fi
done <<< "$WORKTREE_LIST"

if [[ "$STALE_COUNT" -eq 0 ]]; then
  echo -e "${GREEN}No extra worktrees found${NC}"
else
  echo
  echo -e "${YELLOW}Found $STALE_COUNT extra worktrees${NC}"
  echo "To remove a stale worktree:"
  echo "  git worktree remove <path>"
  echo "  git branch -d <branch>"
fi
echo

# ─── Summary ───
echo "=== Summary ==="
LOCAL_COUNT=$(echo "$MERGED_LOCAL" | grep -c '.' 2>/dev/null || echo "0")
echo "Local merged branches: $LOCAL_COUNT"
if [[ "$PRUNE_REMOTE" == "true" ]]; then
  REMOTE_COUNT=$(echo "$MERGED_REMOTE" | grep -c '.' 2>/dev/null || echo "0")
  echo "Remote merged branches: $REMOTE_COUNT"
fi
echo "Extra worktrees: $STALE_COUNT"

if [[ "$DRY_RUN" == "true" ]]; then
  echo
  echo "Re-run without --dry-run to clean up."
fi
