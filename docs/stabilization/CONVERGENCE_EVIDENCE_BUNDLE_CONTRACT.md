# Convergence Evidence Bundle Contract

> Canonical contract for promoting runtime/browser evidence into merged repo truth.
> This document defines the evidence classification system, promotion rules,
> and required evidence for closing the Stabilization → Convergence gate.

## Purpose

This contract bridges local proof artifacts and canonical repo truth. The problem it solves is
that runtime evidence is scattered, contradictory, and not systematically classified. Without a
shared classification system, teams promote local observations as if they were durable closures,
contradictions go unresolved, and phase gates get claimed prematurely. This contract defines
exactly what counts as evidence, what can be promoted, and what must remain provisional.

## Evidence Classification

### Claim Status Classes

| Class | Definition | Can Promote? |
|-------|-----------|-------------|
| `CONFIRMED` | Claim backed by merged repo truth, non-contradicted by later evidence, survives actor/session change | Yes |
| `PROVISIONAL` | Claim backed by local proof or partial evidence, not yet contradicted but not yet durable | Not yet — requires promotion path |
| `CONTRADICTED` | Claim disagreed with by later evidence from same or higher-authority source | No — must stay open until resolved |
| `EXTERNAL_BLOCKER` | Claim blocked by dependency outside this repo's control (e.g., upstream service, external team) | No — record and park |
| `PARKED` | Claim intentionally deferred; not blocking current phase gate | No — not evaluated |

### State Durability Classes

| Class | Definition | Examples |
|-------|-----------|---------|
| `DURABLE` | State that survives pod restart, actor change, session loss, and cluster reprovisioning | Merged PR, pinned image digest, GitOps overlay, ExternalSecret |
| `MANUAL_STATE` | State created by operator action, not codified in repo or automation | kubectl exec, manual DB write, browser-set cookie |
| `TEMPORARY_RUNTIME_MITIGATION` | Workaround that unblocks progress but is not semantic closure | Caddy handle_response rewrite, pod-local sed patch, hot-fix Job |

## Promotion Rules

### What CAN be promoted to canonical repo truth

1. **Merged PR fixing a root cause** — the PR itself is durable evidence
2. **Pinned image digest** — immutable, verifiable, survives redeployment
3. **GitOps overlay change** — declarative desired state, ArgoCD-synced
4. **Browser proof backed by merged fix** — screenshot + merged PR = CONFIRMED
5. **CI verification script** — machine-checkable, runs on every commit

### What CANNOT be promoted

1. **Local proof file under var/proofs/** — input only, never canonical by default
2. **Screenshot alone** — evidence of observation, not evidence of durability
3. **curl-only proof** — does not prove user-visible success
4. **kubectl exec result** — proves current state, not durable state
5. **Manual DB write** — proves data exists now, not that it survives reprovisioning
6. **Admin merge without semantic evidence** — proves merge happened, not that the fix works
7. **Pod-local hot-patch** — proves runtime workaround, not architecture closure

### Promotion path for PROVISIONAL → CONFIRMED

A provisional claim becomes confirmed when ALL of:
1. The fix is merged to the appropriate repo (mereka-lms or bbi-infrastructure)
2. The fix is deployed via GitOps (ArgoCD sync verified)
3. Browser or API proof exists showing the fix works in the target environment
4. No later evidence contradicts the claim
5. The evidence is recorded in a tracked evidence bundle (this contract's format)

### Contradiction rules

- Later evidence from same or higher-authority source supersedes earlier evidence
- A contradiction does NOT erase the earlier claim — it marks it CONTRADICTED with a reference
- Resolution requires new evidence that addresses both the original claim and the contradiction
- A summary that smooths over contradictions is itself a contract violation

## Required Evidence for Phase Gate Closure

### Stabilization → Convergence gate requires:

#### Admin Portal
| Evidence | Required? | What counts |
|----------|----------|------------|
| Admin portal renders without 500/error boundary | Required | Browser proof + merged routing fix |
| Admin user can authenticate via SSO | Required | Browser proof of successful login |
| Admin portal shows enterprise data | Required | Screenshot showing non-empty enterprise view |

#### Learner Portal — Primary Path
| Evidence | Required? | What counts |
|----------|----------|------------|
| Learner dashboard renders | Required | Browser proof + merged fixes for all root causes |
| Learner can authenticate via SSO | Required | Browser proof of successful login flow |
| Dashboard BFF returns 200 | Required | Access log or API proof showing BFF success |
| Search page renders | Required | Browser proof showing search UI (content optional) |

#### Learner Portal — Secondary Path
| Evidence | Required? | What counts |
|----------|----------|------------|
| Secondary endpoints classified | Required | Request matrix with owner, route, status for each |
| Misrouted endpoints identified and fixed | Required | Routing fix merged, not just mitigated |
| Graceful degradation working | Required | Browser proof that failures don't trigger error boundary |
| Temporary mitigations labeled | Required | Each mitigation explicitly marked as TEMPORARY_RUNTIME_MITIGATION |

#### Build Truth
| Evidence | Required? | What counts |
|----------|----------|------------|
| MFE images built from explicit source tags | Required | Build contract verified, no :latest dependency |
| Image digests pinned | Required | Immutable refs in deployment manifests or evidence bundle |

#### GitOps Truth
| Evidence | Required? | What counts |
|----------|----------|------------|
| All runtime fixes deployed via ArgoCD | Required | ArgoCD sync status, not kubectl apply |
| No manual patches required for basic function | Required | Pod restart produces working state without intervention |

#### Image Truth
| Evidence | Required? | What counts |
|----------|----------|------------|
| All deployed images traceable to source | Required | Image ref → build workflow → source commit chain |
| No floating tags in deployment manifests | Required | Pinned SHA or SHA-timestamp tags only |

#### Data-Layer Truth
| Evidence | Required? | What counts |
|----------|----------|------------|
| Synthetic test fixtures documented | Required | Fixture manifest + bootstrap tooling |
| Fixture creation is reproducible | Required | Script-based, not manual kubectl exec |
| Enterprise catalog both-sides populated | Required | LMS + enterprise-catalog service records exist |

## What Counts as Contradiction

1. A later browser proof showing failure where earlier proof showed success
2. A root cause analysis that reclassifies an earlier diagnosis
3. A PR that was claimed sufficient but later found insufficient
4. A fix path that was claimed durable but requires manual intervention after pod restart
5. An endpoint that was claimed working but later found to be misrouted

## What Counts as Superseded Evidence

Evidence is superseded when a later artifact from the same investigation:
- Corrects a factual error in the earlier artifact
- Provides a more accurate root cause
- Identifies additional failure modes not covered by the earlier artifact

The superseded artifact is NOT deleted — it is marked as superseded with a reference to the superseding artifact.

## Local Proof Input Policy

Files under `var/proofs/**` are:
- Valid inputs for building evidence bundles
- NOT canonical truth by default
- NOT sufficient for closing any claim
- Subject to contradiction by later evidence
- Must be explicitly promoted through the rules above to become canonical

Screenshots under `assets/screenshots-of-issues/**` are:
- Observational evidence of a point-in-time state
- NOT durable closure by themselves
- Valuable when paired with a merged fix and deployment verification
- Must be referenced from a tracked evidence bundle to have canonical weight

## Cross-References

- Phase gate criteria: `docs/stabilization/STABILIZATION_PHASE_GATES.md`
- Durable vs manual classification: `docs/stabilization/DURABLE_VS_MANUAL_STATE_MATRIX.md`
- Release evidence format: `docs/stabilization/RELEASE_EVIDENCE_BUNDLE_CONTRACT.md`
- Control board: `docs/stabilization/STABILIZATION_CONTROL_BOARD.md`
