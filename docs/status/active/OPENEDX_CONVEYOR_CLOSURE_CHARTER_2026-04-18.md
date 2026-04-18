# OpenEdX Conveyor Closure Charter — 2026-04-18

## Task Header

Own release-conveyor closure for the repaired line (artifact `102a56a07d`) through
runtime and product-surface truth, run one full graduation cycle on `main`, and land
the first hardening tranche so the next dev promotion is boring.

## Mission

Turn the current `102a56a07d` line from "probably shipped" into **proven across
RC-02 through RC-06**, then run an **RC-07 graduation cycle** with a fresh change,
then land **OG-01/02/03** hardening. Stop there. Do not reopen broad
build-architecture work unless evidence forces it.

## Anchors

| Item | Value |
|---|---|
| Server | `ssh mereka` (hostname `vmi2994232`) |
| mereka-lms HEAD | `fe191d9f8` (commit `102a56a07d` = build SHA, merge `#1797`) |
| bbi-infrastructure HEAD | `41d3d414` |
| App build run | `24590743862` (success, 2026-04-17T23:14:15Z) |
| Promote run | `24591542962` (success, 2026-04-17T23:45:23Z) |
| Promotion PR / commit | `bbi-infrastructure#3169` / `506b9337` |
| openedx digest | `sha256:d17ae77f533be1690b969b220b3507c4d9780ef7f477ecd5c47e2b7777b54578` |
| mfe digest | `sha256:377923c0a2ce22c8e7bac7baf488c80f345a1445e2f7ac47b5c29e5b475b35e1` |
| Failed E2E gate (classify, don't patch) | run `24591547989` |
| Authority ambiguity candidate | `overlays/dev/kustomization.yaml` (stale `dfbe7ef31806`) vs `overlays/profiles/dev/` (live) |

## Phase Sequence

### Phase 1 — Baseline freeze
- Verify repo HEADs, Argo sync/health, deployment spec digests, live pod imageIDs.
- Close out cms-worker/lms-worker rollout (from PR #3166 readinessProbe).
- Exit: one baseline table + Argo `Synced:Healthy`.

### Phase 2 — RC-02 release-object evidence
- Download `release-bundle` artifact from build run `24590743862` (GitHub Actions).
- Run `scripts/release/generate_release_object.py`, `scripts/qa/verify-release-object.sh`, `scripts/qa/verify-build-workflow-contract.sh`.
- Store at `docs/status/active/evidence/rc02-102a56a07d/`.
- Exit: verifier outputs + pass/fail.

### Phase 3 — RC-03/RC-04 single-chain proof
- Build artifact → promotion input → infra merge → Argo desired → deployment spec → live pod — one table.
- Exit: continuous chain documented.

### Phase 4 — RC-05/RC-06 closure
- Classify failed E2E gate run `24591547989` as: RC-05 runtime / RC-06 product-surface / test-infra noise.
- Initial finding: GKE auth failure on a decommissioned target → test-infra obsolescence.
- Re-run 3-tenant runtime matrix on live digests.
- Exit: closure evidence OR one precise reopener.

### Phase 5 — RC-07 graduation cycle
- Pick one small, safe, intentional change on `main`.
- Observe end-to-end without intervention. Any babysitting = conveyor failure.
- Capture timing ledger.
- Exit: full cycle report.

### Phase 6 — OG-01/02/03 hardening
- OG-01: stale-Argo-op recovery (script + test-backed runbook).
- OG-02: timing scoreboard for build/bundle/promotion/Argo/runtime latencies (p50/p95).
- OG-03: automation-PR audit — cluster recent failed `promote-dev-image.yml` runs by class.
- Exit: three deliverables under `docs/status/active/evidence/og/`.

### Phase 7 — Authority cleanup (evidence-gated only)
- Only act if `overlays/dev` is proven on a real ship path.
- Surgical deletion/consolidation only.
- Exit: one authoritative dev image source.

## Guardrails

- Proof beats narrative. Merged PR ≠ closure. GitHub green ≠ runtime truth.
- One owner layer per diagnostic move.
- No `kubectl` mutation of ArgoCD-managed resources (Kyverno blocks).
- No direct ConfigMap edits in-cluster (hashed-name kustomize flow only).
- No tenant-runtime fixes unless E2E classification points there.
- No stale-digest cleanup before proving authority.
- No scope widening to Build Authority Phase 2, deterministic-build cleanup, MFE redesign, Indigo retirement, observability, or docs work until Phases 1–6 are materially complete.

## Decision Tree

- Phase 1 fails → deployment/GitOps truth owner. Stop.
- Phase 2 fails → promotion-contract truth owner. Stop.
- Phase 3 fails → promotion/deployment truth owner. Stop.
- Phase 4 shows runtime break → RC-05 live blocker.
- Phase 4 shows product-surface break → RC-06 live blocker.
- Phase 4 shows test-infra noise → record, continue.
- Phase 5 babysitting needed → conveyor not graduated; file exact improvisation points.
- Phase 7 stale config unconsumed → record as debt, do not fix this cycle.

## Deliverables

1. Baseline table
2. RC-02 evidence packet
3. RC-03/RC-04 single-chain proof
4. RC-05/RC-06 runtime + product-surface matrix
5. RC-07 graduation report (one full cycle, with timing)
6. OG-01/02/03 hardening report
7. Authority verdict memo
8. One next-move recommendation + explicit stay-away zone
