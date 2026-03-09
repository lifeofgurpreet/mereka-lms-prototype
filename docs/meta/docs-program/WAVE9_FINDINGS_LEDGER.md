# Wave 9 Findings Ledger

> Generated file. Do not hand-edit. Regenerate with `python3 tools/knowledge/build_wave9_findings_ledger.py --repo-root .`.

## Summary

- Generated on: 2026-03-09
- Total findings: 10
- Status counts: {"FIXED": 3, "INVALIDATED": 3, "OPEN": 2, "PARTIAL": 2}

## Audit Breakdown

### infra_alignment_audit
- OPEN: 1
- PARTIAL: 1
- FIXED: 0
- INVALIDATED: 2

### repo_truth_audit
- OPEN: 1
- PARTIAL: 1
- FIXED: 3
- INVALIDATED: 1

## Findings

| ID | Audit | Status | Severity | Risk | Files | Recommended action |
|---|---|---|---|---|---|---|
| RTA-01 | repo_truth_audit | FIXED | blocker | high | docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md | Demote unverifiable future completion claims or update verification semantics mechanically. |
| RTA-02 | repo_truth_audit | FIXED | blocker | high | docs/archive/reports/docs-program-scorecard-20260313.md | Keep the dated artifact absent until it can be generated with a real verification date. |
| RTA-03 | repo_truth_audit | FIXED | major | high | generated/adr-bundles/*.md<br>scripts/qa/build_decision_graph.py | Fix the ADR bundle generator so generated links resolve into canonical docs/adr paths. |
| RTA-04 | repo_truth_audit | OPEN | major | high | specs/catalog.json<br>specs/_generated/graph.json<br>specs/_generated/indexes/spec-read-first.md | Land deterministic spec catalog, graph, and read-first surfaces with CI checks. |
| RTA-05 | repo_truth_audit | PARTIAL | medium | medium | docs/catalog.json<br>generated/catalogs/docs-catalog.json | Keep generated catalog primary and verify docs/catalog.json stays a mirror-only projection. |
| RTA-06 | repo_truth_audit | INVALIDATED | medium | medium | docs/archive/reports/docs-program-scorecard-20260306.md | Introduce explicit program prefixes in read-first and handoff surfaces so wave terms do not collide. |
| ICA-01 | infra_alignment_audit | INVALIDATED | major | medium | docs/guides/PROMOTION-WORKFLOW.md<br>docs/reference/operations/RELEASE_PROCESS.md<br>scripts/promote.sh<br>.github/workflows/promote-image.yml | Use the actual release process path and compare it against the real promote script/workflow contract. |
| ICA-02 | infra_alignment_audit | OPEN | major | high | CLAUDE.md<br>docs/adr/027-deployment-contract-ownership-lanes.md<br>docs/archive/LOGO_FIX_SUMMARY.md<br>docs/archive/PRODUCTION_INFRASTRUCTURE_PLAN_LEGACY.md<br>docs/archive/SESSION_SUMMARY_2026-02-03_AWS_SECRETS.md<br>docs/archive/root-cleanup-20260120/COST_OPTIMIZATION_SUMMARY.md<br>docs/archive/root-cleanup-20260203/COST_OPTIMIZATION_SUMMARY.md<br>docs/archive/root-cleanup-20260203/SETUP_STATUS.md<br>docs/guides/onboarding/DEVCONTAINER_GUIDE.md | Either compile CLAUDE from authoritative contracts or demote it from active read-first surfaces. |
| ICA-03 | infra_alignment_audit | PARTIAL | medium | medium | SECURITY.md<br>docs/archive/CLICKUP_TASK_LIST.md<br>docs/meta/docs-program/WAVE9_FINDINGS_LEDGER.md<br>docs/policies/operations/BRANCH_PROTECTION.md<br>docs/reference/operations/SECRET_SCANNING.md | Tie security summary claims to contract-backed sources or demote the summary surface. |
| ICA-04 | infra_alignment_audit | INVALIDATED | medium | medium | config/domain-registry.yaml<br>config/bootstrap-lane-topology.yaml<br>contracts/release-contracts.yaml<br>contracts/service-identity-contract.yaml | Use actual in-repo contract surfaces for alignment work and mark cross-repo-only sources explicitly. |

### RTA-01 — Tracker claims canonical proof while embedding later completion dates

- Audit: `repo_truth_audit`
- Status: `FIXED`
- Severity: `blocker`
- Owner: `platform-team`
- Files: `docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md`
- Proof command: `python3 - <<'PY'
from pathlib import Path; import re
text=Path('docs/DOCS_REMEDIATION_PLAN_AND_TRACKER.md').read_text().splitlines()
for i,line in enumerate(text, start=1):
  low=line.lower()
  if any(k in low for k in ('done','published','generated','verified','closure','scorecard')) and 'no earlier than' not in low and 'template' not in low:
    dates=re.findall(r'20\\d{2}-\\d{2}-\\d{2}', line)
    if dates: print(i, dates, line)
PY`
- Risk: `high`
- Notes: last_verified=2026-03-06, proof_like_later_dates=none

### RTA-02 — Archived scorecard presents future-dated proof with stale verification metadata

- Audit: `repo_truth_audit`
- Status: `FIXED`
- Severity: `blocker`
- Owner: `platform-team`
- Files: `docs/archive/reports/docs-program-scorecard-20260313.md`
- Proof command: `test -f docs/archive/reports/docs-program-scorecard-20260313.md`
- Risk: `high`
- Notes: future-dated scorecard artifact removed from active tree

### RTA-03 — Generated ADR bundles contain broken relative navigation

- Audit: `repo_truth_audit`
- Status: `FIXED`
- Severity: `major`
- Owner: `platform-team`
- Files: `generated/adr-bundles/*.md, scripts/qa/build_decision_graph.py`
- Proof command: `python3 - <<'PY'
from pathlib import Path; import re
link_re=re.compile(r'\[[^\]]+\]\(([^)]+)\)')
for bundle in Path('generated/adr-bundles').glob('*.md'):
  for target in link_re.findall(bundle.read_text()):
    p=(bundle.parent/target).resolve()
    if target and not target.startswith(('http://','https://','#','mailto:')) and not p.exists():
      print(f'{bundle}:{target}')
PY`
- Risk: `high`
- Notes: broken_links=0

### RTA-04 — Spec plane still lacks full machine-readable parity surfaces

- Audit: `repo_truth_audit`
- Status: `OPEN`
- Severity: `major`
- Owner: `platform-team`
- Files: `specs/catalog.json, specs/_generated/graph.json, specs/_generated/indexes/spec-read-first.md`
- Proof command: `test -f specs/catalog.json; test -f specs/_generated/graph.json; test -f specs/_generated/indexes/spec-read-first.md`
- Risk: `high`
- Notes: missing=specs/catalog.json, specs/_generated/graph.json, specs/_generated/indexes/spec-read-first.md

### RTA-05 — Two docs catalog surfaces still present an authority duplication risk

- Audit: `repo_truth_audit`
- Status: `PARTIAL`
- Severity: `medium`
- Owner: `platform-team`
- Files: `docs/catalog.json, generated/catalogs/docs-catalog.json`
- Proof command: `test -f docs/catalog.json && test -f generated/catalogs/docs-catalog.json`
- Risk: `medium`
- Notes: mirror_and_generated_catalogs_present

### RTA-06 — Wave numbering is overloaded across docs program and runtime programs

- Audit: `repo_truth_audit`
- Status: `INVALIDATED`
- Severity: `medium`
- Owner: `platform-team`
- Files: `docs/archive/reports/docs-program-scorecard-20260306.md`
- Proof command: `rg -n "Wave 2B|Wave 5|Wave 6" docs/meta docs/archive/reports`
- Risk: `medium`
- Notes: overlapping_wave_vocab=docs/archive/reports/docs-program-scorecard-20260306.md

### ICA-01 — Promotion workflow drift must be checked against real script and workflow semantics

- Audit: `infra_alignment_audit`
- Status: `INVALIDATED`
- Severity: `major`
- Owner: `platform-team`
- Files: `docs/guides/PROMOTION-WORKFLOW.md, docs/reference/operations/RELEASE_PROCESS.md, scripts/promote.sh, .github/workflows/promote-image.yml`
- Proof command: `test -f docs/guides/PROMOTION-WORKFLOW.md || test -f docs/reference/operations/RELEASE_PROCESS.md`
- Risk: `medium`
- Notes: audit_target_missing_but_release_process_exists_at_docs/reference/operations/RELEASE_PROCESS.md

### ICA-02 — CLAUDE.md remains an active front-door summary instead of a compiled or demoted helper

- Audit: `infra_alignment_audit`
- Status: `OPEN`
- Severity: `major`
- Owner: `platform-team`
- Files: `CLAUDE.md, docs/adr/027-deployment-contract-ownership-lanes.md, docs/archive/LOGO_FIX_SUMMARY.md, docs/archive/PRODUCTION_INFRASTRUCTURE_PLAN_LEGACY.md, docs/archive/SESSION_SUMMARY_2026-02-03_AWS_SECRETS.md, docs/archive/root-cleanup-20260120/COST_OPTIMIZATION_SUMMARY.md, docs/archive/root-cleanup-20260203/COST_OPTIMIZATION_SUMMARY.md, docs/archive/root-cleanup-20260203/SETUP_STATUS.md, docs/guides/onboarding/DEVCONTAINER_GUIDE.md`
- Proof command: `rg -n "CLAUDE\.md" docs docs/ops docs/guides docs/reference`
- Risk: `high`
- Notes: active_docs_referencing_CLAUDE=18

### ICA-03 — SECURITY.md is still an active policy front door without contract-derived sync proof

- Audit: `infra_alignment_audit`
- Status: `PARTIAL`
- Severity: `medium`
- Owner: `platform-team`
- Files: `SECURITY.md, docs/archive/CLICKUP_TASK_LIST.md, docs/meta/docs-program/WAVE9_FINDINGS_LEDGER.md, docs/policies/operations/BRANCH_PROTECTION.md, docs/reference/operations/SECRET_SCANNING.md`
- Proof command: `rg -n "SECURITY\.md" docs .github`
- Risk: `medium`
- Notes: active_docs_referencing_SECURITY=4

### ICA-04 — Audit-referenced contract source files are not all present in this repo root

- Audit: `infra_alignment_audit`
- Status: `INVALIDATED`
- Severity: `medium`
- Owner: `platform-team`
- Files: `config/domain-registry.yaml, config/bootstrap-lane-topology.yaml, contracts/release-contracts.yaml, contracts/service-identity-contract.yaml`
- Proof command: `rg --files | rg 'domain-registry|bootstrap-lane-topology|release-contracts|service-identity-contract'`
- Risk: `medium`
- Notes: present=none_in_this_repo

