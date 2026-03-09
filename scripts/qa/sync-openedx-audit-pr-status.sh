#!/usr/bin/env bash
# sync-openedx-audit-pr-status.sh
#
# Synchronize Open edX audit tracker/board PR status cells with live GitHub PR
# state so the implementation board remains operationally accurate.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/qa/sync-openedx-audit-pr-status.sh [--check]

Options:
  --check   Verify only (non-zero exit when drift is detected).
  -h, --help  Show this help.
EOF
}

MODE="write"
case "${1:-}" in
  "")
    ;;
  --check)
    MODE="check"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: unknown argument: $1" >&2
    usage >&2
    exit 2
    ;;
esac

for cmd in git gh python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 2
  fi
done

if [[ -z "${REPO_ROOT_OVERRIDE:-}" ]] && ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required" >&2
  exit 2
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "ERROR: gh is not authenticated for github.com" >&2
  exit 2
fi

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

resolve_doc_path() {
  local canonical="$1"
  local legacy="$2"

  if [[ -f "$canonical" ]]; then
    printf '%s\n' "$canonical"
  elif [[ -f "$legacy" ]]; then
    printf '%s\n' "$legacy"
  else
    printf '%s\n' "$canonical"
  fi
}

TRACKER="$(resolve_doc_path \
  "$REPO_ROOT/docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md" \
  "$REPO_ROOT/docs/architecture/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md")"
BOARD="$(resolve_doc_path \
  "$REPO_ROOT/docs/meta/docs-program/openedx-repo-audit/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md" \
  "$REPO_ROOT/docs/architecture/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md")"

origin_url="$(git config --get remote.origin.url || true)"
repo_slug=""
if [[ "$origin_url" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
  repo_slug="${BASH_REMATCH[1]}"
fi
if [[ -z "$repo_slug" ]]; then
  repo_slug="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

python3 - "$MODE" "$repo_slug" "$TRACKER" "$BOARD" <<'PY'
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

mode = sys.argv[1]
repo_slug = sys.argv[2]
tracker_path = Path(sys.argv[3])
board_path = Path(sys.argv[4])

if mode not in {"write", "check"}:
    raise SystemExit(f"ERROR: unsupported mode {mode}")


@dataclass
class Section:
    path: Path
    heading: str


TARGET_SECTIONS = [
    Section(
        path=tracker_path,
        heading="### Post-Audit Implementation Status",
    ),
    Section(
        path=board_path,
        heading="## Post-Merge Hardening Follow-ups",
    ),
]

PR_HASH_RE = re.compile(r"#(\d+)")
PR_URL_RE = re.compile(r"/pull/(\d+)")


def split_cells(row: str) -> list[str]:
    row = row.strip()
    if not row.startswith("|") or not row.endswith("|"):
        raise ValueError(f"not a markdown table row: {row}")
    return [cell.strip() for cell in row.strip("|").split("|")]


def extract_pr_number(value: str) -> int | None:
    hash_match = PR_HASH_RE.search(value)
    if hash_match:
        return int(hash_match.group(1))
    url_match = PR_URL_RE.search(value)
    if url_match:
        return int(url_match.group(1))
    return None


def find_table(lines: list[str], heading: str) -> tuple[int, int]:
    start = None
    for i, line in enumerate(lines):
        if line.startswith(heading):
            start = i + 1
            break
    if start is None:
        raise SystemExit(f"FAIL: heading not found: {heading}")

    table_start = None
    table_end = None
    for i in range(start, len(lines)):
        line = lines[i].strip()
        if not line:
            if table_start is not None:
                table_end = i
                break
            continue
        if line.startswith("|"):
            if table_start is None:
                table_start = i
            continue
        if table_start is not None:
            table_end = i
            break

    if table_start is None:
        raise SystemExit(f"FAIL: table not found after heading: {heading}")
    if table_end is None:
        table_end = len(lines)
    return table_start, table_end


def fetch_pr_status(number: int) -> str:
    out = subprocess.check_output(
        ["gh", "api", f"repos/{repo_slug}/pulls/{number}"],
        text=True,
    )
    payload = json.loads(out)
    if payload.get("merged_at"):
        return "Merged"
    if payload.get("state") == "open":
        return "Open"
    return "Closed"


def fetch_pr_status_bulk(required_prs: set[int]) -> tuple[dict[int, str], int]:
    if not required_prs:
        return {}, 0

    out = subprocess.check_output(
        [
            "gh",
            "pr",
            "list",
            "--repo",
            repo_slug,
            "--state",
            "all",
            "--limit",
            "1000",
            "--json",
            "number,state,mergedAt",
        ],
        text=True,
    )
    payload = json.loads(out)
    status_by_pr: dict[int, str] = {}
    for item in payload:
        number = item.get("number")
        if not isinstance(number, int):
            continue
        if item.get("mergedAt"):
            status_by_pr[number] = "Merged"
        elif item.get("state") == "OPEN":
            status_by_pr[number] = "Open"
        else:
            status_by_pr[number] = "Closed"

    fallback_calls = 0
    missing = sorted(required_prs - set(status_by_pr))
    for number in missing:
        status_by_pr[number] = fetch_pr_status(number)
        fallback_calls += 1

    return status_by_pr, fallback_calls


def collect_pr_numbers(path: Path, heading: str) -> set[int]:
    lines = path.read_text(encoding="utf-8").splitlines()
    table_start, table_end = find_table(lines, heading)
    header = split_cells(lines[table_start])
    try:
        pr_idx = header.index("PR")
    except ValueError as exc:
        raise SystemExit(f"FAIL: missing PR column in {path} ({heading})") from exc

    prs: set[int] = set()
    for line in lines[table_start + 2 : table_end]:
        if not line.strip().startswith("|"):
            continue
        cells = split_cells(line)
        if len(cells) <= pr_idx:
            continue
        pr_number = extract_pr_number(cells[pr_idx])
        if pr_number is not None:
            prs.add(pr_number)
    return prs


def apply_status_sync(
    path: Path,
    heading: str,
    status_by_pr: dict[int, str],
    check_only: bool,
) -> tuple[int, list[str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    table_start, table_end = find_table(lines, heading)
    header = split_cells(lines[table_start])

    try:
        status_idx = header.index("Status")
        pr_idx = header.index("PR")
    except ValueError as exc:
        raise SystemExit(f"FAIL: missing Status/PR column in {path} ({heading})") from exc

    diffs: list[str] = []
    updated = 0
    for i in range(table_start + 2, table_end):
        line = lines[i]
        if not line.strip().startswith("|"):
            continue
        cells = split_cells(line)
        if len(cells) <= max(status_idx, pr_idx):
            continue
        pr_number = extract_pr_number(cells[pr_idx])
        if pr_number is None:
            continue

        expected = status_by_pr.get(pr_number)
        if not expected:
            continue
        current = cells[status_idx]
        if current == expected:
            continue

        diffs.append(
            f"{path.name} ({heading}) PR #{pr_number}: {current!r} -> {expected!r}"
        )
        if not check_only:
            cells[status_idx] = expected
            lines[i] = "| " + " | ".join(cells) + " |"
            updated += 1

    if not check_only and updated:
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return updated, diffs


all_prs: set[int] = set()
for section in TARGET_SECTIONS:
    if not section.path.exists():
        raise SystemExit(f"FAIL: missing file: {section.path}")
    all_prs |= collect_pr_numbers(section.path, section.heading)

if not all_prs:
    raise SystemExit("FAIL: no PR references found in target sections")

status_by_pr, fallback_calls = fetch_pr_status_bulk(all_prs)

total_updates = 0
all_diffs: list[str] = []
for section in TARGET_SECTIONS:
    updates, diffs = apply_status_sync(
        section.path,
        section.heading,
        status_by_pr,
        check_only=(mode == "check"),
    )
    total_updates += updates
    all_diffs.extend(diffs)

print(f"Repo: {repo_slug}")
print(f"Tracked PRs: {len(all_prs)}")
print(f"Fallback PR API calls: {fallback_calls}")
if all_diffs:
    print("Detected status drift:")
    for diff in all_diffs:
        print(f"  - {diff}")
else:
    print("No status drift detected.")

if mode == "check":
    if all_diffs:
        raise SystemExit(1)
    print("PASS: audit docs PR statuses match live GitHub state.")
    raise SystemExit(0)

print(f"Updated rows: {total_updates}")
PY
