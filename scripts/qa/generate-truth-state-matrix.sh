#!/usr/bin/env bash
# @covers AC-GIS-003
# @spec: gitops-integrity-system_spec.md
#
# Generate truth-state-matrix entries from git log and acceptance results.
# Usage: ./scripts/qa/generate-truth-state-matrix.sh [--since DAYS] [--write]
#
# Without --write, outputs what WOULD be added (dry-run).
# With --write, appends new entries to config/truth-state-matrix.yaml.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
MATRIX="${REPO_ROOT}/config/truth-state-matrix.yaml"
SINCE_DAYS="${SINCE_DAYS:-7}"
WRITE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE_DAYS="$2"; shift 2 ;;
    --write) WRITE=true; shift ;;
    *) shift ;;
  esac
done

echo "=== Truth State Matrix Generator ==="
echo "Scanning last ${SINCE_DAYS} days of merged PRs..."
echo ""

# Find merged PRs in the last N days
MERGED_PRS=$(git log --since="${SINCE_DAYS} days ago" --oneline --grep='(#' | grep -oP '#\d+' | sort -u)

if [[ -z "$MERGED_PRS" ]]; then
  echo "No merged PRs found in last ${SINCE_DAYS} days."
  exit 0
fi

echo "Found PRs: ${MERGED_PRS}"
echo ""

# Build tab-delimited PR data file for Python
PR_DATA_FILE=$(mktemp)
trap 'rm -f "$PR_DATA_FILE"' EXIT

for PR in $MERGED_PRS; do
  PR_NUM="${PR#\#}"
  # Match on subject line only (not body) to avoid squash-merge body cross-matches.
  # git log --grep searches full message, so we filter subject with a post-check.
  COMMIT=""
  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    csha="${candidate%% *}"
    csubj=$(git log -1 --format='%s' "$csha" 2>/dev/null)
    if [[ "$csubj" == *"(${PR})"* ]]; then
      COMMIT="$csha"
      SUBJECT="$csubj"
      break
    fi
  done < <(git log --since="${SINCE_DAYS} days ago" --oneline --grep="(${PR})" --format='%H %s' 2>/dev/null)
  if [[ -z "$COMMIT" ]]; then
    continue
  fi
  printf '%s\t%s\t%s\n' "$PR_NUM" "$COMMIT" "$SUBJECT" >> "$PR_DATA_FILE"
done

if [[ ! -s "$PR_DATA_FILE" ]]; then
  echo "No valid commits found for any PR."
  exit 0
fi

# Use Python to handle YAML read/write and dedup
python3 - "$MATRIX" "$WRITE" "$PR_DATA_FILE" <<'PYEOF'
import sys
import yaml
from datetime import datetime, timezone

matrix_path = sys.argv[1]
write_mode = sys.argv[2] == "true"
pr_data_file = sys.argv[3]

with open(pr_data_file, "r") as f:
    pr_data_raw = f.read().strip()

if not pr_data_raw:
    print("No PR data to process.")
    sys.exit(0)

# Load existing matrix
with open(matrix_path, "r") as f:
    matrix = yaml.safe_load(f)

if matrix is None:
    print(f"ERROR: Could not parse {matrix_path}", file=sys.stderr)
    sys.exit(1)

existing_entries = matrix.get("entries") or []
archived_entries = matrix.get("archived") or []

# Collect existing PR numbers for dedup
existing_prs = set()
for entry in existing_entries:
    existing_prs.add(entry.get("pr"))
for entry in archived_entries:
    existing_prs.add(entry.get("pr"))

now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
new_entries = []

for line in pr_data_raw.split("\n"):
    if not line.strip():
        continue
    parts = line.split("\t", 2)
    if len(parts) < 3:
        continue
    pr_num_str, commit_sha, subject = parts
    pr_num = int(pr_num_str)

    if pr_num in existing_prs:
        print(f"  SKIP  PR #{pr_num} (already in matrix)")
        continue

    entry = {
        "pr": pr_num,
        "commit": commit_sha[:12],
        "subject": subject,
        "added_utc": now_utc,
        "levels": {
            "branch": True,
            "merged": True,
            "realized": None,
            "proved": None,
            "durable": None,
        },
    }
    new_entries.append(entry)

if not new_entries:
    print("No new entries to add (all PRs already in matrix).")
    sys.exit(0)

# Print what will be added
print(f"{'Writing' if write_mode else 'Would add'} {len(new_entries)} new entries:\n")
for entry in new_entries:
    print(f"  ADD   PR #{entry['pr']}: {entry['subject']}")
    print(f"        commit: {entry['commit']}")
    print(f"        levels: branch=true, merged=true, realized=null, proved=null, durable=null")
    print()

if write_mode:
    # Append new entries to existing list
    if matrix.get("entries") is None:
        matrix["entries"] = []
    matrix["entries"].extend(new_entries)

    # Custom dumper: explicit 'null', 2-space sequence indent, preserve key order
    class OrderedDumper(yaml.SafeDumper):
        # Force 2-space indent for sequence items (never indentless)
        def increase_indent(self, flow=False, indentless=False):
            return super().increase_indent(flow, False)

    def _represent_none(dumper, data):
        return dumper.represent_scalar("tag:yaml.org,2002:null", "null")

    OrderedDumper.add_representer(type(None), _represent_none)

    with open(matrix_path, "w") as f:
        # Preserve the header comment block
        f.write("# Truth State Matrix\n")
        f.write("# Tracks every active fix across the five truth levels.\n")
        f.write("# Producer: scripts/qa/generate-truth-state-matrix.sh\n")
        f.write("# Consumer: scripts/qa/verify-truth-state-matrix.sh (AC-GIS-003)\n")
        f.write("# Spec: specs/gitops-integrity-system_spec.md\n")
        f.write("---\n")
        yaml.dump(
            matrix,
            f,
            Dumper=OrderedDumper,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
            width=120,
        )

    print(f"Wrote {len(new_entries)} entries to {matrix_path}")
else:
    print("Dry-run complete. Use --write to append entries.")
PYEOF

# If we wrote entries, validate the result
if [[ "$WRITE" == "true" ]]; then
  echo ""
  echo "--- Validating matrix ---"
  "${REPO_ROOT}/scripts/qa/verify-truth-state-matrix.sh"
fi
