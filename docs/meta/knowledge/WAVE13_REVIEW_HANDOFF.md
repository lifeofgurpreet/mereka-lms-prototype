# Wave 13 Review Handoff

## Review Order
1. [EXECUTION_PROOF_RUNTIME_MODEL.md](/home/gurpreet/projects/k8s/mereka-lms-wt-wave13-execution-proof-runtime/docs/meta/knowledge/EXECUTION_PROOF_RUNTIME_MODEL.md)
2. [RECEIPT_CLASSES.yaml](/home/gurpreet/projects/k8s/mereka-lms-wt-wave13-execution-proof-runtime/docs/meta/knowledge/RECEIPT_CLASSES.yaml)
3. [execution-receipt.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave13-execution-proof-runtime/generated/knowledge/execution-receipt.json)
4. [approval-receipt.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave13-execution-proof-runtime/generated/knowledge/approval-receipt.json)
5. [evidence-receipt.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave13-execution-proof-runtime/generated/knowledge/evidence-receipt.json)
6. [release-decision-receipt.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave13-execution-proof-runtime/generated/knowledge/release-decision-receipt.json)
7. [runtime-proof-receipt.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave13-execution-proof-runtime/generated/knowledge/runtime-proof-receipt.json)
8. [proof-bundle-manifest.json](/home/gurpreet/projects/k8s/mereka-lms-wt-wave13-execution-proof-runtime/generated/knowledge/proof-bundle-manifest.json)
9. [WAVE13_CLOSEOUT.md](/home/gurpreet/projects/k8s/mereka-lms-wt-wave13-execution-proof-runtime/docs/meta/knowledge/WAVE13_CLOSEOUT.md)

## Exact Validation Order
1. `bash scripts/qa/run-decision-runtime-gates.sh`
2. `python3 tools/knowledge/build_execution_receipt.py --check --repo-root . --range origin/main...HEAD`
3. `python3 tools/knowledge/build_approval_receipt.py --check --repo-root . --range origin/main...HEAD`
4. `python3 tools/knowledge/build_evidence_receipt.py --check --repo-root . --range origin/main...HEAD`
5. `python3 tools/knowledge/build_release_decision_receipt.py --check --repo-root . --range origin/main...HEAD`
6. `python3 tools/knowledge/build_runtime_proof_receipt.py --check --repo-root . --range origin/main...HEAD`
7. `python3 tools/knowledge/verify_execution_proof_runtime.py --repo-root . --range origin/main...HEAD`
8. `bash scripts/qa/run-execution-proof-runtime-gates.sh`
9. `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`

## Reviewer Guidance
- Treat all receipt JSON outputs as canonical.
- Use the proof bundle manifest as the authoritative inventory of the current proof chain.
- If an approval receipt shows unresolved live inputs, treat the release as still awaiting human approval state.
- If the runtime-proof receipt shows warnings, treat them as explicit follow-up items, not silent pass conditions.

## Remaining Manual Judgment
- live reviewer approval state
- live cluster/runtime proof attachment
- any cross-repo fact not proven from current local repos and canonical generated surfaces
