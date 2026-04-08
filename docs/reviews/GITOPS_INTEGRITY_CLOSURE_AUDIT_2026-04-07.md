<!-- markdownlint-disable MD032 -->
# GitOps Integrity System — Closure Audit

_Date: 2026-04-07_
_Auditor: Docs agent (Opus)_
_Branch audited: main (ca428e358)_
_PR branch with claimed artifacts: docs/phase1-guides-rewrite (2ed722fe6)_

---

## 1. What Is Real

These exist on main, are enforced, and block merges:

| Invariant | Enforcement | Blocking? |
|-----------|-------------|-----------|
| Feature branch only (INV-01) | GitHub branch protection | YES |
| shellcheck (INV-03) | CI static-validation shards | YES |
| yamllint (INV-04) | CI static-validation shards | YES |
| kubeconform (INV-05) | CI static-validation shards | YES |
| CI green on main (INV-08) | Branch protection required checks | YES |
| Never debug on main (INV-10) | Branch protection | YES |

AGENTS.md hard rules 9-11 (GitOps law, 3-state reporting, durability) exist on main.
EXECUTION_INVARIANTS.md Invariant 11-12 exist on main.
PROMOTION_REALIZATION five-truth model exists on main.

**These 3 documents are real and on main. They define the system in prose.**

## 2. What Is Partial

These have prose/docs on main but the machine-checkable layer is NOT on main:

| Item | Doc (main) | Script | CI wiring | Config | Status |
|------|-----------|--------|-----------|--------|--------|
| GitOps law (INV-11) | YES | PR only | NO | NO | PARTIAL |
| Guardrail extraction (INV-12) | YES | PR only | NO | NO | PARTIAL |
| Five-truth durability | YES | PR only | NO | NO | PARTIAL |

## 3. What Is Prose-Only

These exist as documentation but have NO automated detection or enforcement:

| Invariant | Why prose-only |
|-----------|---------------|
| Clean tree before mutation (INV-02) | No hook, no CI check |
| ARC runner gaps (INV-06) | Documented contract, no automated check |
| No tar.xz actions (INV-07) | No automated check |
| One hypothesis per PR (INV-09) | Relies on human review |
| AGENTS.md rules 9-11 | Relies on agent reading docs |

## 4. What Is False or Overstated

| Claim | Reality |
|-------|---------|
| "Machine-checkable invariants" | Scripts exist on PR branch, not main. Not invoked by any CI workflow. Not in script registry. |
| "5 verification scripts all pass" | Scripts fail when run — they can't find config files (wrong REPO_ROOT), and exit 0 on FAIL (should exit 1) |
| "config/invariant-enforcement-map.yaml maps 26 invariants" | File not on main. Nobody reads it. |
| "config/truth-state-matrix.yaml tracks fixes" | File not on main. Nobody writes to it. Nobody reads it. |
| "config/live-mutation-ledger.yaml with 48h TTL" | File not on main. No process writes to it. |
| "config/incidents/*.yaml pipeline" | One example file on PR branch. No process creates these. |
| "Complete system with knowledge graph" | 3 docs linked on main. 10 artifacts on unmerged PR. Zero CI enforcement. |

## 5. What I Fixed Now

Nothing yet. This audit is the first honest accounting. The artifacts exist in code but are not wired, not enforced, and not on main.

## 6. What Still Blocks the System From Being Truly Machine-Enforced

### Critical (false claim / broken linkage)
1. **Scripts exit 0 on FAIL** — all 5 scripts report failures but don't set exit code. CI would pass them even when they detect problems.
2. **REPO_ROOT resolution broken** — scripts resolve to `//config/` instead of actual repo root when run from certain contexts.
3. **No CI workflow invokes any of the 5 scripts** — they could pass perfectly and it wouldn't matter because nothing runs them.
4. **No script registry entries** — the scripts aren't registered in `scripts/governance/script-registry.yaml`, so governance checks don't know they exist.

### Major (detector exists but not wired)
5. **Scripts on PR branch, not main** — PR #1421 needs to merge first. Until then, the entire machine layer is aspirational.
6. **No CI static inventory entry** — even after merge, the scripts won't run in CI unless added to `ci_static_inventory` in script-registry.yaml.
7. **config/ files have no producer** — nobody writes to truth-state-matrix.yaml or live-mutation-ledger.yaml. They're empty schemas.

### Medium (wired but not evidenced)
8. **Kyverno protect-gitops-managed-resources** — exists in archive but NOT deployed on rke2-prod. INV-11 references it but it doesn't enforce anything.
9. **No ArgoCD OutOfSync alert** — INV-11 says alert when OutOfSync >10 minutes. No alerting rule exists.
10. **No incident → guardrail automation** — the incident YAML schema exists but there's no process or hook that creates incident records or verifies guardrail completeness.

### Low (documentation polish)
11. **Cross-reference index is incomplete** — invariant-enforcement-map.yaml maps invariants but some entries point to scripts that don't exist on main.
12. **AGENTS.md quick reference links to EXECUTION_INVARIANTS #11-12** — correct but agents have to follow 2 hops to find the enforcement details.

---

## Prioritized Gap Register

| # | Gap | Class | Fix |
|---|-----|-------|-----|
| 1 | Scripts exit 0 on FAIL | critical | Fix exit codes in all 5 scripts |
| 2 | REPO_ROOT broken | critical | Fix path resolution |
| 3 | No CI invocation | critical | Add to ci_static_inventory + script-registry |
| 4 | Not on main | major | Merge PR #1421 |
| 5 | No CI inventory entry | major | Register scripts after merge |
| 6 | Config files have no producer | major | Build a generator or manual process doc |
| 7 | Kyverno not deployed | medium | Deploy protect-gitops policy (infra repo) |
| 8 | No OutOfSync alert | medium | Add Prometheus alert rule |
| 9 | No incident automation | medium | Could be manual process with verification |
| 10 | Cross-ref incomplete | low | Update after scripts are on main |

---

## Phase D: Real Incident Walkthrough (added post-audit)

**Incident**: April 2026 Redis OOM → Prod CrashLoop

| Chain Node | Exists? | Path/Evidence |
|-----------|---------|---------------|
| Incident record | YES | `config/incidents/INC-2026-04-redis-oom.yaml` |
| Linked invariant | YES | INV-011 in `config/process-invariants.yaml` |
| Linked detector | YES | `scripts/qa/verify-gitops-sync-drift.sh` |
| Workflow/job | YES | CI static inventory (1 entry) |
| Evidence artifact | YES | Infra PRs #2500, #2502 (merged) |
| Closure criteria | YES | INV-011 + durability checklist |
| Guardrail added | YES | INV-012 + `verify-incident-guardrails.sh` |

**Missing edges**: Kyverno policy not deployed, no OutOfSync alert, incident automation is manual.

**Conclusion**: The chain is 7/7 complete for this incident. The system works for one real case. The missing edges are enforcement-level (runtime policy + alerting), not structural.
