# Verification Scripts - Mereka LMS

Quick guide to automated verification and testing in Mereka LMS.

---

## Directory Structure

```
scripts/
├── qa/                          # Quality assurance & verification
│   ├── verify-*.sh              # Verification scripts (see generated catalog for exact count)
│   ├── spec-tools/              # Spec coverage tools
│   │   ├── spec_coverage_dashboard.py  # Compact coverage dashboard
│   │   ├── spec_coverage_report.py     # Generate coverage report
│   │   ├── check_test_coverage.py      # Check AC coverage
│   │   └── mereka_spec_lint.py         # Lint specs
│   └── smoke-tests/             # Smoke test scripts
├── infra/                       # Infrastructure scripts
│   ├── verify-tutor-config.sh   # Verify Tutor patches applied
│   ├── fix-service-selectors.sh # Fix K8s service selectors
│   └── tutor-config-save.sh     # Safe config wrapper
└── shared/
    └── config.sh                # Shared configuration
```

---

## Running Verification Scripts

### Quick Checks

```bash
# Verify Tutor config (patches applied)
./scripts/infra/verify-tutor-config.sh

# Verify K8s images (no :latest tags)
./scripts/qa/verify-k8s-images.sh

# Verify ExternalSecret config
./scripts/qa/verify-externalsecret-config.sh

# Verify enterprise SSO setup
./scripts/qa/verify-enterprise-sso.sh

# Verify multi-tenancy setup
./scripts/qa/verify-multi-tenancy.sh
```

### Full Suite

```bash
# Release-blocking static suite
./scripts/qa/run-release-verification-gates.sh

# Catalog and ownership metadata
python3 scripts/qa/generate-verification-catalog.py
./scripts/qa/verify-verification-catalog.sh
```

Catalog outputs:
- `../../operations/verification/verification_catalog.json`
- `../../operations/verification/VERIFICATION_CATALOG.md`
- `../../operations/verification/VERIFICATION_GOVERNANCE.md`

---

## Spec Coverage System (V3)

### Key Concepts

**@covers Annotation**: Maps code/tests to Acceptance Criteria (ACs)

```bash
# Example: Shell script
# @covers AC-001, AC-002
# @spec: k8s-deployment_spec.md

# Example: Python test
def test_something():
    """@covers AC-003"""
    pass
```

**@spec Annotation**: Scopes ACs to correct spec (prevents AC-001 collision across 28 specs)

**CRITICAL**: One `@spec` per file. Tool captures LAST `@spec` in file.

### Coverage Metrics

As of 2026-02-11:
- **769 ACs** across 31 specs
- **371 automated** (48.2%)
- **83 manual** (in `specs/manual_verifications.yaml`)
- **4 monitoring** (in `specs/manual_verifications.yaml`)
- **311 unmapped** (59.6% overall coverage)

### Coverage Dashboard (Quick View)

```bash
cd scripts/qa/spec-tools

# Compact dashboard (text format)
python spec_coverage_dashboard.py --testmaps-dir ../../specs/_generated/testmaps/ --specs-dir ../../specs/

# Output:
# - Overall coverage rate
# - Per-spec coverage (sorted by rate)
# - Color-coded tiers (GREEN ≥80%, YELLOW 50-79%, RED <50%)

# JSON format (for CI/tooling)
python spec_coverage_dashboard.py --testmaps-dir ../../specs/_generated/testmaps/ --format json

# Markdown format (for GitHub issues/PRs)
python spec_coverage_dashboard.py --testmaps-dir ../../specs/_generated/testmaps/ --format markdown
```

### Generate Coverage Report (Detailed)

```bash
cd scripts/qa/spec-tools

# Full report
python spec_coverage_report.py

# Output:
# - Coverage by spec
# - Unmapped ACs
# - Manual/monitoring ACs
# - Summary metrics

# Filter specific spec
python spec_coverage_report.py --spec k8s-deployment_spec.md
```

### Check Test Coverage

```bash
cd scripts/qa/spec-tools

# Check if AC is covered
python check_test_coverage.py AC-001

# Check multiple ACs
python check_test_coverage.py AC-001 AC-002 AC-003

# Check spec-scoped AC
python check_test_coverage.py AC-TCR-001
```

### Lint Specs

```bash
cd scripts/qa/spec-tools

# Lint single spec
python mereka_spec_lint.py specs/k8s-deployment_spec.md

# Lint all specs
for spec in specs/*_spec.md; do
  python mereka_spec_lint.py "$spec"
done
```

---

## Adding New Verification Scripts

### File Location

```bash
# Domain-specific verifications
scripts/qa/verify-<feature>.sh

# Infrastructure verifications
scripts/infra/verify-<component>.sh

# Analytics verifications
scripts/analytics/verify-<feature>.sh
```

### Script Template

```bash
#!/usr/bin/env bash
# @covers AC-001, AC-002
# @spec: feature-name_spec.md
set -euo pipefail

# Feature verification script
# Usage: scripts/qa/verify-feature.sh [options]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/scripts/shared/config.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Check functions
check_something() {
  echo "Checking something..."

  if [[ condition ]]; then
    pass "Check passed"
  else
    fail "Check failed: reason"
  fi
}

# Main execution
main() {
  echo "=== Feature Verification ==="
  echo

  check_something

  # Summary
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS"
  echo -e "${RED}FAIL:${NC} $FAIL"

  if [[ $FAIL -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"
```

### Common Patterns

**K8s Resource Checks**:
```bash
# Check deployment exists
kubectl get deployment lms -n mereka-lms >/dev/null 2>&1

# Check pod is running
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms \
  --field-selector=status.phase=Running | grep -q lms

# Check service has endpoints
ENDPOINTS=$(kubectl get endpoints lms -n mereka-lms -o jsonpath='{.subsets[*].addresses[*].ip}')
[[ -n "$ENDPOINTS" ]]
```

**Config Checks**:
```bash
# Check config key exists
grep -q "KEY_NAME" tutor_env/config.yml

# Check config value
VALUE=$(grep "KEY_NAME" tutor_env/config.yml | awk '{print $2}')
[[ "$VALUE" == "expected" ]]
```

**HTTP Checks**:
```bash
# Check HTTP 200
curl -sf https://academyv2.mereka.io >/dev/null

# Check HTTP status code
STATUS=$(curl -so /dev/null -w "%{http_code}" https://academyv2.mereka.io)
[[ "$STATUS" == "200" ]]

# Check response body
curl -s https://academyv2.mereka.io | grep -q "expected text"
```

---

## Live Cluster Validation

### Run Verification Against Production

```bash
# Set namespace
export NAMESPACE=mereka-lms

# Run K8s-specific verifications
./scripts/qa/verify-k8s-images.sh
./scripts/qa/verify-externalsecret-config.sh
./scripts/infra/verify-tutor-config.sh

# Run service verifications
./scripts/qa/public-health-check.sh prod
./scripts/qa/verify-auth-surfaces.sh prod
./scripts/qa/verify-credentials-readiness.sh --cluster
```

### Validation Results (2026-02-11)

Out of 121 scripts tested against live cluster:
- **76 PASS** (62.8%)
- **29 FAIL** (mostly undeployed features)
- **8 TIMEOUT**
- **8 NEED-ARGS**

Adjusted (excluding timeouts + need-args): **76/105 = 72.4%**

Common failures:
- HubSpot webhook (not deployed)
- Mux video (not configured)
- Missing test data
- Config drift (fixed after run)

---

## @covers Annotation Syntax

### Basic Format

```bash
# Single AC
# @covers AC-001

# Multiple ACs (comma-separated)
# @covers AC-001, AC-002, AC-003

# WRONG: Space-separated (only captures AC-001)
# @covers AC-001 AC-002
```

### Spec Scoping

```bash
# WITHOUT @spec: AC-001 could be from any spec
# @covers AC-001

# WITH @spec: AC-001 scoped to k8s-deployment_spec.md
# @spec: k8s-deployment_spec.md
# @covers AC-001
```

**CRITICAL**: Use `@spec` annotation for all non-prefixed ACs (AC-001, AC-002, etc.)

### Prefixed ACs

Some specs use prefixed ACs:
- `AC-TCR-001` (tenant-config-registry)
- `AC-PG-001` (purchase-gateway)
- `AC-SSO-001` (enterprise-sso)

These don't need `@spec` annotation (prefix makes them unique).

---

## Manual Verifications

For ACs that can't be automated (UI checks, manual processes):

**File**: `specs/manual_verifications.yaml`

```yaml
- ac_id: AC-001
  spec: feature-name_spec.md
  verification_type: manual
  reason: "Requires visual inspection of UI"
  verification_steps:
    - "Log in to LMS"
    - "Navigate to feature"
    - "Verify visual element"

- ac_id: AC-002
  spec: feature-name_spec.md
  verification_type: monitoring
  reason: "Verified via Prometheus alerts"
  prometheus_query: "rate(http_requests_total[5m])"
```

Types:
- `manual` - Human verification required
- `monitoring` - Verified via observability (Prometheus, Grafana, Sentry)

---

## Common Verification Patterns

### Service Selector Fix

```bash
# Most common production issue: empty endpoints after pod restart
./scripts/infra/fix-service-selectors.sh

# What it does:
# 1. Check each service selector
# 2. Compare to current pod labels
# 3. Update selector if mismatch
# 4. Verify endpoints populated
```

### Tutor Config Verification

```bash
# After tutor config save, verify patches applied
./scripts/infra/verify-tutor-config.sh

# Checks:
# - MySQL auth plugin
# - MFE Node version
# - Extra domains
# - Webpack memory limit
# - MongoDB Atlas SRV support
```

### K8s Image Tag Verification

```bash
# Ensure no :latest tags in production
./scripts/qa/verify-k8s-images.sh --check no-latest

# Ensure correct registry and tag format
./scripts/qa/verify-k8s-images.sh --check registry-path

# Expected tag format: YYYYMMDD-*-HASH
# Example: 20240212-ulmo-abc1234
```

---

## Integration with CI/CD

```yaml
# .github/workflows/verify.yml
name: Verify

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run verification scripts
        run: |
          make qa-smoke

      - name: Check spec coverage
        run: |
          cd scripts/qa/spec-tools
          python spec_coverage_report.py
```

---

## Troubleshooting

### AC Not Found by Coverage Tool

**Problem**: Added `@covers AC-001` but coverage report shows "unmapped"

**Checks**:
1. Is `@spec` annotation present? (Required for non-prefixed ACs)
2. Is AC ID formatted correctly? (Comma-separated, no spaces after comma OK)
3. Does AC exist in spec? (Check spec frontmatter or body)
4. Is file in correct location? (Tool scans from repo root)

### Multiple Specs in One File

**Problem**: File covers ACs from multiple specs

**Solution**: Create separate verification scripts per spec, or use prefixed ACs

```bash
# BAD: One file, two specs
# @spec: spec-a.md
# @covers AC-001
# ... (code for spec A)
# @spec: spec-b.md  # Only this @spec captured!
# @covers AC-002
# ... (code for spec B)

# GOOD: Two files
# File: verify-spec-a.sh
# @spec: spec-a.md
# @covers AC-001

# File: verify-spec-b.sh
# @spec: spec-b.md
# @covers AC-002
```

---

## See Also

- [Kubectl Cheatsheet](./kubectl-cheatsheet.md) - K8s operations
- [Tutor Commands](./tutor-commands.md) - Tutor operations
- [Common Troubleshooting](./common-troubleshooting.md) - 1-page debug guide
- [Verification Report](../../operations/VERIFICATION_REPORT.md) - Latest validation results
