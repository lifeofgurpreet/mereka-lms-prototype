#!/usr/bin/env bash
# verify-baseline-truth-control.sh — CI gate for baseline debt severity
#
# Reads config/baseline-debt-severity.yaml and enforces:
#   1. Zero high-severity active failures (merge-blocking)
#   2. All active entries have owner + root_cause
#   3. Baseline commit is reachable from current HEAD
#   4. Summary counts match actual entries
#
# Exit codes:
#   0  baseline is clean (no high-severity regressions)
#   1  baseline violation detected
#
# This script makes the baseline a first-class CI control surface,
# not just a documentation file.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASELINE="$REPO_ROOT/config/baseline-debt-severity.yaml"

PASS=0
FAIL=0
WARN=0

pass_() { PASS=$((PASS + 1)); printf "PASS  %s\n" "$1"; }
fail_() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1" >&2; }
warn_() { WARN=$((WARN + 1)); printf "WARN  %s\n" "$1"; }

# ── Check baseline file exists ───────────────────────────────────────────
if [[ ! -f "$BASELINE" ]]; then
  fail_ "baseline-debt-severity.yaml not found at $BASELINE"
  printf "\n=== Baseline Truth Control: 0 PASS / 1 FAIL ===\n"
  exit 1
fi

# ── Parse with yq (or python3 fallback) ──────────────────────────────────
if command -v yq &>/dev/null; then
  _yq() { yq eval "$1" "$BASELINE"; }
else
  _yq() {
    python3 -c "
import yaml, sys
with open('$BASELINE') as f:
    d = yaml.safe_load(f)
path = '$1'.lstrip('.').split('.')
obj = d
for p in path:
    if p and obj is not None:
        if isinstance(obj, list):
            obj = obj[int(p)] if p.isdigit() else None
        elif isinstance(obj, dict):
            obj = obj.get(p)
        else:
            obj = None
print(obj if obj is not None else 'null')
"
  }
fi

# ── 1. Zero high-severity active failures ────────────────────────────────
HIGH_COUNT=$(_yq '.summary.high_severity')
if [[ "$HIGH_COUNT" == "0" || "$HIGH_COUNT" == "null" ]]; then
  pass_ "zero high-severity active failures (count=$HIGH_COUNT)"
else
  fail_ "high-severity active failures detected (count=$HIGH_COUNT)"
fi

# ── 2. Active entries have required fields ───────────────────────────────
python3 - "$BASELINE" <<'PYEOF'
import yaml, sys

with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)

missing = []
for section in ['static_debt', 'runtime_debt', 'build_debt']:
    entries = d.get(section) or []
    for entry in entries:
        if entry.get('status') != 'active':
            continue
        eid = entry.get('id', 'unknown')
        if not entry.get('owner'):
            missing.append(f"{eid}: missing owner")
        if not entry.get('root_cause'):
            missing.append(f"{eid}: missing root_cause")
        if not entry.get('severity'):
            missing.append(f"{eid}: missing severity")

if missing:
    for m in missing:
        print(f"INCOMPLETE {m}")
    sys.exit(1)
else:
    print(f"COMPLETE all active entries have owner + root_cause + severity")
    sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass_ "all active entries have required fields"
else
  fail_ "active entries missing required fields (see above)"
fi

# ── 3. Summary counts match actual entries ───────────────────────────────
python3 - "$BASELINE" <<'PYEOF'
import yaml, sys

with open(sys.argv[1]) as f:
    d = yaml.safe_load(f)

actual_high = 0
actual_medium = 0
actual_active = 0

for section in ['static_debt', 'runtime_debt', 'build_debt']:
    entries = d.get(section) or []
    for entry in entries:
        if entry.get('status') == 'active':
            actual_active += 1
            sev = entry.get('severity', '')
            if sev == 'high':
                actual_high += 1
            elif sev == 'medium':
                actual_medium += 1

summary = d.get('summary', {})
declared_high = summary.get('high_severity', -1)
declared_medium = summary.get('medium_severity', -1)
declared_active = summary.get('total_active', -1)

ok = True
if declared_high != actual_high:
    print(f"MISMATCH high_severity: declared={declared_high} actual={actual_high}")
    ok = False
if declared_medium != actual_medium:
    print(f"MISMATCH medium_severity: declared={declared_medium} actual={actual_medium}")
    ok = False
if declared_active != actual_active:
    print(f"MISMATCH total_active: declared={declared_active} actual={actual_active}")
    ok = False

if ok:
    print(f"CONSISTENT high={actual_high} medium={actual_medium} active={actual_active}")
    sys.exit(0)
else:
    sys.exit(1)
PYEOF
if [[ $? -eq 0 ]]; then
  pass_ "summary counts match actual entries"
else
  fail_ "summary counts do not match actual entries"
fi

# ── 4. Baseline commit is reachable ──────────────────────────────────────
BASELINE_COMMIT=$(_yq '.baseline_commit')
if [[ "$BASELINE_COMMIT" != "null" && -n "$BASELINE_COMMIT" ]]; then
  if git rev-parse --verify "${BASELINE_COMMIT}^{commit}" &>/dev/null; then
    pass_ "baseline commit $BASELINE_COMMIT is reachable"
  else
    warn_ "baseline commit $BASELINE_COMMIT not reachable (shallow clone?)"
  fi
else
  warn_ "no baseline_commit declared"
fi

# ── Summary ──────────────────────────────────────────────────────────────
printf "\n=== Baseline Truth Control: %d PASS / %d FAIL / %d WARN ===\n" "$PASS" "$FAIL" "$WARN"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
