#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_PATH=".github/workflows/docs-compliance.yml"

if [ ! -f "$WORKFLOW_PATH" ]; then
  echo "missing workflow: $WORKFLOW_PATH"
  exit 1
fi

# Verify base ref context resolution step exists
grep -q "name: Resolve docs base ref context" "$WORKFLOW_PATH"

# Verify DOCS_BASE_REF and DOCS_POLICY_RANGE are written to GITHUB_ENV
grep -qF 'DOCS_POLICY_RANGE=' "$WORKFLOW_PATH"
grep -qF 'DOCS_BASE_REF=' "$WORKFLOW_PATH"
grep -qF '>> "$GITHUB_ENV"' "$WORKFLOW_PATH"

# Verify PR event uses event payload SHAs (not origin/$base_ref)
grep -qF 'github.event.pull_request.base.sha' "$WORKFLOW_PATH"
grep -qF 'github.event.pull_request.head.sha' "$WORKFLOW_PATH"

# Verify policy range and base ref are consumed by downstream steps
grep -q -- '--range "$DOCS_POLICY_RANGE"' "$WORKFLOW_PATH"
grep -q -- '--policy-range "$DOCS_POLICY_RANGE"' "$WORKFLOW_PATH"
grep -q -- '--base-ref "$DOCS_BASE_REF"' "$WORKFLOW_PATH"
grep -q "build-doc-catalog.py --check" "$WORKFLOW_PATH"
grep -q 'verify-generated-doc-banners.py' "$WORKFLOW_PATH"
grep -q "name: Detect docs scorecard scope" "$WORKFLOW_PATH"
grep -q "DOCS_SCORECARD_RELEVANT=true" "$WORKFLOW_PATH"
grep -q 'verify-stub-only-transitional-dirs.py' "$WORKFLOW_PATH"
grep -q 'verify-archive-write-protection.py' "$WORKFLOW_PATH"
grep -q 'verify-evidence-status-root-policy.py' "$WORKFLOW_PATH"
grep -q 'verify-doc-catalog-governance.py' "$WORKFLOW_PATH"
grep -q 'scan-doc-catalog-residue.py' "$WORKFLOW_PATH"
grep -q 'scan-doc-orphans.py' "$WORKFLOW_PATH"
grep -q 'report-nonstub-transitional-files.py' "$WORKFLOW_PATH"
grep -q -- '--fail-on-nonstub' "$WORKFLOW_PATH"
grep -q 'verify-legacy-testmaps-frozen.py' "$WORKFLOW_PATH"
grep -q 'git diff --name-only "$DOCS_POLICY_RANGE"' "$WORKFLOW_PATH"
grep -q 'echo "- base_ref=${DOCS_BASE_REF}"' "$WORKFLOW_PATH"
grep -q 'echo "- policy_range=${DOCS_POLICY_RANGE}"' "$WORKFLOW_PATH"

echo "verify-docs-compliance-workflow-contract self-test: OK"
