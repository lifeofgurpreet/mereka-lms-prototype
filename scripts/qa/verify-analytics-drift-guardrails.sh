#!/usr/bin/env bash
# @covers AC-ADRIFT-001, AC-ADRIFT-002, AC-ADRIFT-003
# @spec: analytics-pipeline_spec.md

set -euo pipefail

GUARDRAILS_DOC="docs/concepts/architecture/ANALYTICS_DRIFT_GUARDRAILS.md"
ADR_PATH="docs/programs/analytics/ANALYTICS_DEPLOYMENT_POLICY.md"
SPEC_PATH="specs/analytics-pipeline_spec.md"
PROD_KUSTOMIZATION="deploy/k8s/overlays/production/kustomization.yaml"
ASPECTS_VOLUMES="deploy/k8s/base/plugins/aspects/volumes.yml"

PASS=0
FAIL=0
WARN=0

echo "=== Analytics Drift Guardrails Verification ==="
echo ""

# AC-ADRIFT-003: Decision closure procedure documented
if [[ -f "$GUARDRAILS_DOC" ]]; then
    echo "✓ PASS: Guardrails doc exists at $GUARDRAILS_DOC"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Guardrails doc not found at $GUARDRAILS_DOC"
    FAIL=$((FAIL + 1))
    exit 1
fi

# Check for decision closure section
if grep -q "^## Decision Closure Procedure" "$GUARDRAILS_DOC"; then
    echo "✓ PASS: Decision closure procedure documented"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Decision closure procedure section missing"
    FAIL=$((FAIL + 1))
fi

# Check for guardrail rules section
if grep -q "^## Guardrail Rules" "$GUARDRAILS_DOC"; then
    echo "✓ PASS: Guardrail rules section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Guardrail rules section missing"
    FAIL=$((FAIL + 1))
fi

# Check for drift detection section
if grep -q "^## Drift Detection" "$GUARDRAILS_DOC"; then
    echo "✓ PASS: Drift detection section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Drift detection section missing"
    FAIL=$((FAIL + 1))
fi

# AC-ADRIFT-001: Guardrails prevent accidental analytics deployment

# Pre-read ADR and spec status for conditional checks
_ADR_STATUS="UNKNOWN"
if [[ -f "$ADR_PATH" ]]; then
    _ADR_STATUS=$(grep "^\*\*Status\*\*:" "$ADR_PATH" | sed 's/\*\*Status\*\*:[[:space:]]*//' || echo "UNKNOWN")
fi
_SPEC_STATUS="UNKNOWN"
if [[ -f "$SPEC_PATH" ]]; then
    _SPEC_STATUS=$(grep "^status:" "$SPEC_PATH" | sed 's/status:[[:space:]]*//' | tr -d '"' || echo "UNKNOWN")
fi

# Rule 1: Analytics images in production kustomization
# If ADR is Accepted + spec is approved/production, images are expected
echo ""
echo "--- Checking production kustomization for analytics images ---"

if [[ -f "$PROD_KUSTOMIZATION" ]]; then
    ANALYTICS_IMAGES=$(grep -E "aspects|clickhouse|superset" "$PROD_KUSTOMIZATION" || true)

    if [[ -z "$ANALYTICS_IMAGES" ]]; then
        echo "✓ PASS: No aspects images in production kustomization"
        PASS=$((PASS + 1))
    elif [[ "$_ADR_STATUS" == "Accepted" ]] && [[ "$_SPEC_STATUS" == "approved" || "$_SPEC_STATUS" == "production" ]]; then
        echo "✓ PASS: Analytics images present in production kustomization (ADR-017 Accepted + spec $_SPEC_STATUS)"
        PASS=$((PASS + 1))
    else
        echo "✗ FAIL: Analytics images found in production kustomization but ADR-017 is $_ADR_STATUS:"
        echo "$ANALYTICS_IMAGES"
        FAIL=$((FAIL + 1))
    fi
else
    echo "⚠ WARN: Production kustomization not found at $PROD_KUSTOMIZATION"
    WARN=$((WARN + 1))
fi

# Rule 2: No aspects volumes in production kustomization
echo ""
echo "--- Checking production kustomization for aspects volumes ---"

if [[ -f "$PROD_KUSTOMIZATION" ]]; then
    # Capture output to variable first to avoid SIGPIPE
    KUSTOMIZATION_RESOURCES=$(cat "$PROD_KUSTOMIZATION")
    ASPECTS_VOL_REF=$(echo "$KUSTOMIZATION_RESOURCES" | grep -i "aspects.*volumes\|plugins/aspects/volumes" || true)

    if [[ -z "$ASPECTS_VOL_REF" ]]; then
        echo "✓ PASS: No aspects volumes in production kustomization"
        PASS=$((PASS + 1))
    else
        echo "✗ FAIL: Aspects volumes referenced in production kustomization:"
        echo "$ASPECTS_VOL_REF"
        FAIL=$((FAIL + 1))
    fi
else
    echo "⚠ WARN: Production kustomization not found"
    WARN=$((WARN + 1))
fi

# AC-ADRIFT-002: Verifier detects any analytics drift

# Rule 3: Check for live aspects pods (if kubectl available)
echo ""
echo "--- Checking for live aspects pods (requires kubectl) ---"

if command -v kubectl &> /dev/null; then
    ASPECTS_PODS=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/part-of=aspects 2>/dev/null || echo "NO_ACCESS")

    if [[ "$ASPECTS_PODS" == "NO_ACCESS" ]]; then
        echo "⚠ WARN: Cannot access cluster (kubectl not configured or namespace doesn't exist)"
        WARN=$((WARN + 1))
    elif echo "$ASPECTS_PODS" | grep -q "No resources found"; then
        echo "✓ PASS: No aspects pods in production cluster"
        PASS=$((PASS + 1))
    elif [[ -z "$ASPECTS_PODS" ]]; then
        echo "✓ PASS: No aspects pods in production cluster (empty output)"
        PASS=$((PASS + 1))
    else
        echo "✗ FAIL: Aspects pods found in production cluster:"
        echo "$ASPECTS_PODS"
        FAIL=$((FAIL + 1))
    fi
else
    echo "⚠ WARN: kubectl not available, skipping live cluster check"
    WARN=$((WARN + 1))
fi

# Rule 4: Check Caddyfile for Superset routes
echo ""
echo "--- Checking Caddyfile for Superset routes ---"

CADDYFILE_PATH="tutor_env/env/apps/caddy/Caddyfile"

if [[ -f "$CADDYFILE_PATH" ]]; then
    # Capture content to variable to avoid SIGPIPE
    CADDYFILE_CONTENT=$(cat "$CADDYFILE_PATH")

    # Check for uncommented Superset reverse_proxy directives
    SUPERSET_ROUTES=$(echo "$CADDYFILE_CONTENT" | grep -v "^#" | grep -i "analytics.*mereka\|superset:8088" || true)

    if [[ -z "$SUPERSET_ROUTES" ]]; then
        echo "✓ PASS: No active Superset routes in Caddyfile"
        PASS=$((PASS + 1))
    else
        echo "✗ FAIL: Active Superset routes found in Caddyfile:"
        echo "$SUPERSET_ROUTES"
        FAIL=$((FAIL + 1))
    fi
else
    echo "⚠ WARN: Caddyfile not found at $CADDYFILE_PATH (Tutor env may not be initialized)"
    WARN=$((WARN + 1))
fi

# Rule 5: ADR-017 decision gate status
echo ""
echo "--- Checking ADR-017 status ---"

if [[ -f "$ADR_PATH" ]]; then
    # Extract status field (looks for **Status**: pattern)
    ADR_STATUS=$(grep "^\*\*Status\*\*:" "$ADR_PATH" | sed 's/\*\*Status\*\*:[[:space:]]*//' || echo "UNKNOWN")

    if [[ "$ADR_STATUS" == "Deferred" ]] || [[ "$ADR_STATUS" == "Accepted" ]]; then
        echo "✓ PASS: ADR-017 status is $ADR_STATUS (valid state)"
        PASS=$((PASS + 1))
    else
        echo "✗ FAIL: ADR-017 status is '$ADR_STATUS' (expected 'Deferred' or 'Accepted')"
        FAIL=$((FAIL + 1))
    fi
else
    echo "✗ FAIL: ADR-017 not found at $ADR_PATH"
    FAIL=$((FAIL + 1))
fi

# Rule 6: Analytics spec status
echo ""
echo "--- Checking analytics spec status ---"

if [[ -f "$SPEC_PATH" ]]; then
    # Extract status from frontmatter (YAML)
    SPEC_STATUS=$(grep "^status:" "$SPEC_PATH" | sed 's/status:[[:space:]]*//' | tr -d '"' || echo "UNKNOWN")

    if [[ "$SPEC_STATUS" == "in_progress" ]] || [[ "$SPEC_STATUS" == "approved" ]] || [[ "$SPEC_STATUS" == "production" ]]; then
        echo "✓ PASS: Analytics spec status is $SPEC_STATUS (valid state)"
        PASS=$((PASS + 1))
    else
        echo "✗ FAIL: Analytics spec status is '$SPEC_STATUS' (expected 'in_progress', 'approved', or 'production')"
        FAIL=$((FAIL + 1))
    fi
else
    echo "✗ FAIL: Analytics spec not found at $SPEC_PATH"
    FAIL=$((FAIL + 1))
fi

# AC-ADRIFT-002: Decision gate alignment check
echo ""
echo "--- Checking decision gate alignment ---"

# If ADR is Deferred, spec should be in_progress (deployment NOT happening)
# If ADR is Accepted, spec should be approved or production (deployment happening)

if [[ "$ADR_STATUS" == "Deferred" ]]; then
    if [[ "$SPEC_STATUS" == "in_progress" ]]; then
        echo "✓ PASS: Decision gate alignment verified (Deferred + in_progress = no deployment)"
        PASS=$((PASS + 1))
    elif [[ "$SPEC_STATUS" == "approved" ]]; then
        echo "✗ FAIL: Spec is approved but ADR-017 is still Deferred (inconsistent state)"
        FAIL=$((FAIL + 1))
    else
        echo "✓ PASS: Decision gate alignment acceptable (spec status: $SPEC_STATUS)"
        PASS=$((PASS + 1))
    fi
elif [[ "$ADR_STATUS" == "Accepted" ]]; then
    if [[ "$SPEC_STATUS" == "approved" ]] || [[ "$SPEC_STATUS" == "production" ]]; then
        echo "✓ PASS: Decision gate alignment verified (Accepted + approved/production = deployment approved)"
        PASS=$((PASS + 1))
    else
        echo "⚠ WARN: ADR is Accepted but spec is still '$SPEC_STATUS' (expected 'approved' or 'production')"
        WARN=$((WARN + 1))
    fi
else
    echo "⚠ WARN: ADR status '$ADR_STATUS' not recognized for alignment check"
    WARN=$((WARN + 1))
fi

# Check for verification commands section
echo ""
echo "--- Checking guardrails doc completeness ---"

if grep -q "^## Verification Commands" "$GUARDRAILS_DOC"; then
    echo "✓ PASS: Verification commands section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Verification commands section missing"
    FAIL=$((FAIL + 1))
fi

if grep -q "^## Failure Scenarios" "$GUARDRAILS_DOC"; then
    echo "✓ PASS: Failure scenarios section exists"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Failure scenarios section missing"
    FAIL=$((FAIL + 1))
fi

# Check that guardrails cover all 5 rules
RULE_COUNT=$(grep -c "^### Rule [0-9]:" "$GUARDRAILS_DOC" || true)
if [[ "$RULE_COUNT" -ge 5 ]]; then
    echo "✓ PASS: At least 5 guardrail rules documented ($RULE_COUNT found)"
    PASS=$((PASS + 1))
else
    echo "✗ FAIL: Expected at least 5 guardrail rules, found $RULE_COUNT"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "WARN: $WARN"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
    echo "✓ All analytics drift guardrail checks passed"
    exit 0
else
    echo "✗ Some analytics drift guardrail checks failed"
    exit 1
fi
