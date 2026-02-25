#!/usr/bin/env bash
# verify-capacity-planning.sh — Verify capacity planning document and k8s resource configs
# Exit 0 = all checks PASS. Exit 1 = one or more FAILs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

_pass() { echo "PASS $*"; PASS=$((PASS + 1)); }
_fail() { echo "FAIL $*"; FAIL=$((FAIL + 1)); }

# ── Section 1: Document existence and required sections ──────────────────────

DOC="$REPO_ROOT/docs/operations/CAPACITY_PLANNING.md"
_check_doc_section() {
  local label="$1" pattern="$2"
  if grep -qiE "$pattern" "$DOC" 2>/dev/null; then
    _pass "CAPACITY_PLANNING.md contains: $label"
  else
    _fail "CAPACITY_PLANNING.md missing section: $label"
  fi
}

if [[ -f "$DOC" ]]; then
  _pass "CAPACITY_PLANNING.md exists"
else
  _fail "CAPACITY_PLANNING.md missing at docs/operations/CAPACITY_PLANNING.md"
fi

_check_doc_section "resource allocation table"  "CPU Request|CPU Limit|Mem"
_check_doc_section "HPA configuration table"    "HPA Configuration|minReplicas|maxReplicas"
_check_doc_section "cost model"                 "Cost Model|per.*learner|/learner"
_check_doc_section "load test baseline"         "Load Test|concurrent users"
_check_doc_section "scaling policy"             "Scaling Policy|When to Scale"
_check_doc_section "quarterly review"           "Quarterly Review"

# ── Section 2: HPA manifests for critical services exist ────────────────────

check_hpa_file() {
  local label="$1" path="$REPO_ROOT/$2"
  if [[ -f "$path" ]]; then
    if grep -q "HorizontalPodAutoscaler" "$path"; then
      _pass "HPA manifest exists for: $label ($2)"
    else
      _fail "File exists but contains no HPA resource: $2"
    fi
  else
    _fail "HPA manifest missing for: $label ($2)"
  fi
}

check_hpa_file "lms"         "deploy/k8s/base/apps/lms/hpa.yaml"
check_hpa_file "cms"         "deploy/k8s/base/apps/cms/hpa.yaml"
check_hpa_file "workers"     "deploy/k8s/base/operational/hpa-baselines.yaml"
check_hpa_file "enterprise"  "deploy/k8s/base/monitoring/hpa-enterprise.yaml"

# ── Section 3: Production resource-limits patch exists and is non-trivial ───

LIMITS_FILE="$REPO_ROOT/deploy/k8s/overlays/production/patches/resource-limits.yaml"
if [[ -f "$LIMITS_FILE" ]]; then
  _pass "production resource-limits patch exists"
  # Must define limits for lms and cms at minimum
  if grep -q "name: lms" "$LIMITS_FILE" && grep -q "name: cms" "$LIMITS_FILE"; then
    _pass "resource-limits covers lms and cms"
  else
    _fail "resource-limits patch does not cover both lms and cms"
  fi
else
  _fail "deploy/k8s/overlays/production/patches/resource-limits.yaml missing"
fi

# ── Section 4: Limits are not absurdly over-provisioned ─────────────────────
# Parse limits section per deployment; CPU limit must be <= 16 cores.
# Uses Python to walk YAML documents (avoids awk false-positives on requests values).

python3 - "$LIMITS_FILE" <<'PYEOF'
import sys, re

MAX_CPU_CORES = 16  # sanity ceiling — alert if any service exceeds this

with open(sys.argv[1]) as fh:
    content = fh.read()

docs = content.split("---")
failures = []

for doc in docs:
    name_m = re.search(r'name:\s+(\S+)', doc)
    if not name_m:
        continue
    name = name_m.group(1)

    # Find the limits block (text after "limits:" up to next same-indent sibling)
    limits_m = re.search(r'limits:\s*\n(.*?)(?=\n\s{0,12}\w|\Z)', doc, re.DOTALL)
    if not limits_m:
        continue
    limits_block = limits_m.group(1)

    # Match only whole-core limits (digits without trailing 'm')
    cpu_m = re.search(r'cpu:\s*["\']?(\d+)["\']?\s*(?!m)', limits_block)
    if not cpu_m:
        continue  # cpu limit in millicores — skip (reasonable by definition)
    # Confirm the captured value is not a millicore spec in the raw text
    raw_cpu_m = re.search(r'cpu:\s*["\']?(\d+)(m?)["\']?', limits_block)
    if raw_cpu_m and raw_cpu_m.group(2) == 'm':
        continue  # millicores, skip
    cpu_cores = int(cpu_m.group(1))
    if cpu_cores > MAX_CPU_CORES:
        failures.append(f"{name}: CPU limit {cpu_cores} > {MAX_CPU_CORES} cores")
    else:
        print(f"PASS {name} CPU limit is reasonable ({cpu_cores} cores <= {MAX_CPU_CORES})")

for f in failures:
    print(f"FAIL {f}")

sys.exit(len(failures))
PYEOF
# Capture python exit code without losing pipefail
py_rc=$?
if (( py_rc == 0 )); then
  PASS=$((PASS + 1))   # counted as group pass; individual lines printed above
else
  FAIL=$((FAIL + py_rc))
fi

# ── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "Results: ${PASS} PASS, ${FAIL} FAIL"

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
