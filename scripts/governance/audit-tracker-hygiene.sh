#!/usr/bin/env bash
set -euo pipefail

# audit-tracker-hygiene.sh
# Read-only health check for a repo's .beads tracker surface.
#
# Usage:
#   bash audit-tracker-hygiene.sh /path/to/repo
#
# Exit codes:
#   0 = healthy enough for normal use
#   1 = degraded; read-only mode recommended
#   2 = hard failure (missing files / unreadable tracker)

REPO_ROOT="${1:-}"
if [[ -z "${REPO_ROOT}" ]]; then
  echo "usage: bash audit-tracker-hygiene.sh /path/to/repo" >&2
  exit 2
fi

BEADS_DIR="${REPO_ROOT%/}/.beads"
JSONL="${BEADS_DIR}/issues.jsonl"
DB="${BEADS_DIR}/beads.db"

if [[ ! -d "${BEADS_DIR}" ]]; then
  echo "[FAIL] missing tracker directory: ${BEADS_DIR}" >&2
  exit 2
fi
if [[ ! -f "${JSONL}" ]]; then
  echo "[FAIL] missing issues.jsonl: ${JSONL}" >&2
  exit 2
fi

echo "=== Tracker Hygiene Audit ==="
echo "repo:        ${REPO_ROOT}"
echo "beads_dir:   ${BEADS_DIR}"

degraded=0

echo
echo "--- JSONL parse / legacy ID audit ---"
set +e
python3 - "${JSONL}" <<'PY'
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
bad = []
count = 0
for line in path.read_text().splitlines():
    if not line.strip():
        continue
    count += 1
    try:
        obj = json.loads(line)
    except Exception as exc:
        print(f"[FAIL] parse error at record {count}: {exc}")
        sys.exit(2)
    iid = obj.get("id", "")
    if iid.startswith("bd-") or (iid.startswith("mereka-") and not iid.startswith("mereka-lms")):
        bad.append((iid, obj.get("status", "?"), obj.get("title", "")[:90]))

print(f"[OK] parsed records: {count}")
print(f"[INFO] non-conforming IDs: {len(bad)}")
for iid, status, title in bad[:25]:
    print(f"  - {iid} [{status}] {title}")
sys.exit(1 if bad else 0)
PY
jsonl_status=$?
set -e
if [[ "${jsonl_status}" -eq 2 ]]; then
  exit 2
fi
if [[ "${jsonl_status}" -ne 0 ]]; then
  degraded=1
fi

echo
echo "--- br doctor ---"
if command -v br >/dev/null 2>&1; then
  set +e
  doctor_out="$(cd "${REPO_ROOT}" && br doctor 2>&1)"
  doctor_rc=$?
  set -e
  printf '%s\n' "${doctor_out}"
  if grep -q 'ERROR schema.tables' <<<"${doctor_out}"; then
    degraded=1
  fi
  if [[ "${doctor_rc}" -ne 0 ]]; then
    degraded=1
  fi
else
  echo "[WARN] br not installed in PATH"
  degraded=1
fi

echo
echo "--- storage artifacts ---"
find "${BEADS_DIR}" -maxdepth 1 -type f \
  \( -name 'beads.db*' -o -name 'issues.jsonl*' \) | sort | sed 's#^#  - #'

artifact_count="$(find "${BEADS_DIR}" -maxdepth 1 -type f \
  \( -name '*.corrupt*' -o -name '*.broken*' -o -name '*.malformed*' -o -name '*.recovered*' -o -name '*partial*' \) | wc -l | tr -d ' ')"
echo "[INFO] recovery/corruption artifacts: ${artifact_count}"
if [[ "${artifact_count}" -gt 0 ]]; then
  degraded=1
fi

if [[ -f "${DB}" ]] && command -v sqlite3 >/dev/null 2>&1; then
  echo
  echo "--- sqlite quick_check ---"
  set +e
  quick_check="$(sqlite3 "${DB}" 'PRAGMA quick_check;' 2>&1)"
  qc_rc=$?
  set -e
  printf '%s\n' "${quick_check}"
  if [[ "${qc_rc}" -ne 0 ]] || [[ "${quick_check}" != "ok" ]]; then
    degraded=1
  fi
fi

echo
echo "--- summary ---"
if [[ "${degraded}" -eq 0 ]]; then
  echo "[PASS] tracker hygiene looks healthy enough for normal planner mutation"
  exit 0
fi

echo "[WARN] tracker hygiene is degraded; prefer read-only operations and follow TRACKER-HYGIENE-RECOVERY-PLAN.md"
exit 1
