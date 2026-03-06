#!/usr/bin/env bash
# verify-openedx-audit-tracker-sync.sh
#
# Keeps Open edX architecture audit docs synchronized so implementors can rely
# on a single actionable tracker/board pair.
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required" >&2
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# Check both canonical and legacy paths (docs were reorganized)
if [[ -f "$REPO_ROOT/docs/concepts/architecture/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md" ]]; then
  TRACKER="$REPO_ROOT/docs/concepts/architecture/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md"
elif [[ -f "$REPO_ROOT/docs/architecture/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md" ]]; then
  TRACKER="$REPO_ROOT/docs/architecture/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md"
else
  TRACKER="$REPO_ROOT/docs/concepts/architecture/OPENEDX_REPO_ARCH_HYGIENE_AUDIT_TRACKER.md"
fi

if [[ -f "$REPO_ROOT/docs/concepts/architecture/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md" ]]; then
  BOARD="$REPO_ROOT/docs/concepts/architecture/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md"
elif [[ -f "$REPO_ROOT/docs/architecture/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md" ]]; then
  BOARD="$REPO_ROOT/docs/architecture/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md"
else
  BOARD="$REPO_ROOT/docs/concepts/architecture/OPENEDX_REPO_AUDIT_EXECUTION_BOARD.md"
fi

echo "=== Open edX Audit Tracker Sync Verification ==="
echo "Repo: $REPO_ROOT"
echo ""

if [[ ! -f "$TRACKER" ]]; then
  echo "FAIL: Missing tracker doc: $TRACKER" >&2
  exit 1
fi
if [[ ! -f "$BOARD" ]]; then
  echo "FAIL: Missing execution board doc: $BOARD" >&2
  exit 1
fi

python3 - "$TRACKER" "$BOARD" <<'PY'
import re
import sys
from pathlib import Path

tracker_path = Path(sys.argv[1])
board_path = Path(sys.argv[2])


PR_REF_PATTERNS = (
    re.compile(r"#(\d+)"),
    re.compile(r"/pull/(\d+)"),
)


def extract_pr_refs(value: str) -> set[int]:
    refs: set[int] = set()
    for pattern in PR_REF_PATTERNS:
        for match in pattern.findall(value):
            refs.add(int(match))
    return refs


def has_heading(path: Path, heading_prefix: str) -> bool:
    return any(
        line.startswith(heading_prefix)
        for line in path.read_text(encoding="utf-8").splitlines()
    )


def extract_table_prs(path: Path, heading_prefix: str) -> set[int]:
    lines = path.read_text(encoding="utf-8").splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith(heading_prefix):
            start = i + 1
            break
    if start is None:
        raise SystemExit(f"FAIL: heading not found in {path}: {heading_prefix}")

    prs: set[int] = set()
    in_table = False
    for line in lines[start:]:
        if not line.strip():
            if in_table:
                break
            continue
        if line.startswith("|"):
            in_table = True
            if "---" in line:
                continue
            prs |= extract_pr_refs(line)
            continue
        if in_table:
            break
    return prs


if has_heading(tracker_path, "### Post-Audit Implementation Status") and has_heading(
    board_path, "## Post-Merge Hardening Follow-ups"
):
    tracker_prs = extract_table_prs(
        tracker_path,
        "### Post-Audit Implementation Status",
    )
    board_prs = extract_table_prs(
        board_path,
        "## Post-Merge Hardening Follow-ups",
    )

    if not tracker_prs:
        raise SystemExit("FAIL: no PR references found in tracker post-audit status table")
    if not board_prs:
        raise SystemExit("FAIL: no PR references found in execution board follow-up table")

    missing_in_board = sorted(tracker_prs - board_prs)
    missing_in_tracker = sorted(board_prs - tracker_prs)

    print("Mode: post_audit_pr_sync")
    print(f"Tracker PR count: {len(tracker_prs)}")
    print(f"Board PR count  : {len(board_prs)}")
    print(f"Intersection    : {len(tracker_prs & board_prs)}")

    if missing_in_board:
        print(
            "FAIL: PRs in tracker but missing in execution board:",
            ", ".join(f"#{n}" for n in missing_in_board),
            file=sys.stderr,
        )
    if missing_in_tracker:
        print(
            "FAIL: PRs in execution board but missing in tracker:",
            ", ".join(f"#{n}" for n in missing_in_tracker),
            file=sys.stderr,
        )

    if missing_in_board or missing_in_tracker:
        raise SystemExit(1)

    print("PASS: Open edX audit tracker and execution board PR sets are synchronized.")
    raise SystemExit(0)


def extract_tracker_live_issue_refs(path: Path) -> set[int]:
    lines = path.read_text(encoding="utf-8").splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith("### Live PR Board"):
            start = i + 1
            break
    if start is None:
        raise SystemExit("FAIL: tracker missing '### Live PR Board' section")

    issues: set[int] = set()
    for line in lines[start:]:
        if line.startswith("### ") or line.startswith("## "):
            break
        m = re.search(r"-\s+#(\d+)\s+→", line)
        if m:
            issues.add(int(m.group(1)))
    return issues


def extract_board_current_issue_refs(path: Path) -> set[int]:
    lines = path.read_text(encoding="utf-8").splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.startswith("## Current Implementation Status (Live)"):
            start = i + 1
            break
    if start is None:
        raise SystemExit("FAIL: execution board missing current implementation status section")

    issues: set[int] = set()
    in_table = False
    for line in lines[start:]:
        if not line.strip():
            if in_table:
                break
            continue
        if line.startswith("|"):
            in_table = True
            if "---" in line:
                continue
            m = re.search(r"\|\s*#(\d+)\s*\|", line)
            if m:
                issues.add(int(m.group(1)))
            continue
        if in_table:
            break
    return issues


tracker_issues = extract_tracker_live_issue_refs(tracker_path)
board_issues = extract_board_current_issue_refs(board_path)

if not tracker_issues:
    raise SystemExit("FAIL: no issue refs found in tracker live PR board")
if not board_issues:
    raise SystemExit("FAIL: no issue refs found in execution board current table")

missing_in_board = sorted(tracker_issues - board_issues)
missing_in_tracker = sorted(board_issues - tracker_issues)

print("Mode: legacy_issue_sync")
print(f"Tracker issue count: {len(tracker_issues)}")
print(f"Board issue count  : {len(board_issues)}")
print(f"Intersection       : {len(tracker_issues & board_issues)}")

if missing_in_board:
    print(
        "FAIL: issue refs in tracker but missing in execution board:",
        ", ".join(f"#{n}" for n in missing_in_board),
        file=sys.stderr,
    )
if missing_in_tracker:
    print(
        "FAIL: issue refs in execution board but missing in tracker:",
        ", ".join(f"#{n}" for n in missing_in_tracker),
        file=sys.stderr,
    )

if missing_in_board or missing_in_tracker:
    raise SystemExit(1)

print("PASS: Open edX audit tracker and execution board issue refs are synchronized.")
PY
