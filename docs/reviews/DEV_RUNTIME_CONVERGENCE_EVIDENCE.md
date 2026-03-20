# Dev Runtime Convergence Evidence Bundle

> Environment: mereka-lms-dev (rke2-nonprod)
> Bundle version: v1
> Generated: 2026-03-12
> Owner: Lane I (convergence evidence)
> Status: BLOCKED — Stabilization → Convergence gate not yet satisfied

## Executive Classification

The dev runtime environment is **partially stabilized but not convergence-ready**.

**What works**: Admin portal SSO and basic rendering, learner portal primary path (dashboard BFF, search), enterprise MFE build pipeline (explicit source tags, immutable output).

**What is still open**: Learner portal secondary endpoints have temporary routing mitigations (not semantic fixes), one infrastructure PR pending merge (enterprise_worker init container), synthetic fixture creation is now scripted but password setting requires manual env var injection.

**What was contradicted**: Multiple earlier claims were corrected by later investigation — these contradictions are recorded below, not summarized away.

## Claim Lineage Table

### Admin Portal

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| A1 | Admin portal renders without error boundary | var/proofs/LANE-A3-RUNTIME-BUNDLE.md | CONFIRMED | DURABLE | — | Yes |
| A2 | Admin SSO authentication works | var/proofs/runtime-stabilization-verdict.md, assets/screenshots-of-issues/enterprise-auth-proof/ | CONFIRMED | DURABLE | — | Yes |
| A3 | Admin portal shows enterprise data | assets/screenshots-of-issues/lane-a-phase2-proof/ | PROVISIONAL | MANUAL_STATE | Admin portal may show "No results" (open question from Lane A3) | No — needs fresh browser verification |

### Learner Portal — Primary Path

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| L1 | Learner dashboard renders without error boundary | var/proofs/LANE-A3-RUNTIME-BUNDLE.md | CONFIRMED | DURABLE | — | Yes |
| L2 | Learner SSO authentication works | var/proofs/phase6-final-verdict.md, assets/screenshots-of-issues/lane-a-phase3-bff-closure/ | CONFIRMED | DURABLE | — | Yes |
| L3 | Dashboard BFF returns 200 | var/proofs/learner-secondary-request-matrix.md | CONFIRMED | DURABLE | Earlier claim of "401 auth failure" was WRONG — it was HTML 404 from wrong service | Yes |
| L4 | Search page renders | var/proofs/LANE-A3-RUNTIME-BUNDLE.md | CONFIRMED | DURABLE | Search shows "Search Unavailable" (graceful degradation, not error) | Yes (with caveat) |

### Learner Portal — Secondary Path

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| S1 | 13 secondary requests classified by owner and route | var/proofs/learner-secondary-request-matrix.md | CONFIRMED | DURABLE | — | Yes (classification is repo truth) |
| S2 | 3 enterprise-catalog endpoints misrouted to enterprise-access | var/proofs/phase4-enterprise-learner-secondary-endpoint-verdict.md | CONFIRMED | DURABLE | — | Yes |
| S3 | Caddy routing fix for enterprise-catalog endpoints (PR #1643) | var/proofs/LANE-A2-FINAL.md | CONFIRMED | DURABLE | — | Yes (PR merged in bbi-infrastructure) |
| S4 | Cookie name sed patch (PR #1662) | var/proofs/LANE-A2-FINAL.md | PROVISIONAL | PENDING_MERGE | — | No — PR must merge and deploy first |
| S5 | enterprise_worker user creation is durable | var/proofs/LANE-A2-FINAL.md | CONTRADICTED | — | var/proofs/LANE-A3-RUNTIME-BUNDLE.md: Job not on render path; init container (PR #1673) is the real fix | No — A2 claim superseded by A3 |
| S6 | PR #1640 handle_response is semantic fix | var/proofs/lane-a-runtime-closure.md (Phase 3) | CONTRADICTED | TEMPORARY_RUNTIME_MITIGATION | var/proofs/phase4-enterprise-learner-secondary-endpoint-verdict.md: it masks routing error, not fixes it | No — labeled as temporary mitigation |
| S7 | Graceful degradation works for secondary failures | var/proofs/phase5-pr1643-sufficiency-verdict.md | CONFIRMED | DURABLE | — | Yes (MFE uses safeEnsureQueryData pattern) |
| S8 | Ecommerce endpoints return 404 | var/proofs/learner-secondary-request-matrix.md | CONFIRMED | EXTERNAL_BLOCKER | — | Parked — ecommerce not deployed to nonprod |

### Build Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| B1 | MFE images built from explicit source tags (not :latest) | var/proofs/enterprise-mfe-build-stabilization.md | CONFIRMED | DURABLE | — | Yes |
| B2 | Build contract verified (12 checks pass) | docs/stabilization/ENTERPRISE_MFE_BUILD_CONTRACT.md | CONFIRMED | DURABLE | — | Yes |
| B3 | Image digests: admin sha256:65681d7d, learner sha256:c394da77 | var/proofs/runtime-stabilization-verdict.md | CONFIRMED | DURABLE | — | Yes |

### GitOps Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| G1 | JS hot-patches baked into MFE images (not pod-local) | var/proofs/runtime-stabilization-verdict.md | CONFIRMED | DURABLE | — | Yes |
| G2 | ArgoCD syncs enterprise MFE deployments | var/proofs/LANE-A3-RUNTIME-BUNDLE.md (rev 59d8d3ac) | CONFIRMED | DURABLE | — | Yes |
| G3 | enterprise_worker init container on ArgoCD path | var/proofs/LANE-A3-RUNTIME-BUNDLE.md | PROVISIONAL | PENDING_MERGE | — | No — PR #1673 must merge |
| G4 | No manual patches required for basic portal function | var/proofs/runtime-drift-inventory.json | PROVISIONAL | — | Cookie name sed may still require manual intervention if PR #1662 not merged | No — pending PR merge |

### Image Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| I1 | enterprise-admin-portal image traceable to source | docs/stabilization/ENTERPRISE_MFE_BUILD_CONTRACT.md | CONFIRMED | DURABLE | — | Yes |
| I2 | enterprise-learner-portal image traceable to source | docs/stabilization/ENTERPRISE_MFE_BUILD_CONTRACT.md | CONFIRMED | DURABLE | — | Yes |
| I3 | No floating tags in deployment manifests | docs/stabilization/ENTERPRISE_MFE_BUILD_CONTRACT.md | CONFIRMED | DURABLE | — | Yes |

### Data-Layer Truth

| # | Claim | Source Artifact | Status | Durability | Contradicted By | Promotable? |
|---|-------|----------------|--------|-----------|----------------|-------------|
| D1 | 4 synthetic test identities exist in DB | var/proofs/runtime-test-identities.md, config/runtime-proof/LIVE_FIXTURE_STATE.md | CONFIRMED | DURABLE | — | Yes |
| D2 | Enterprise customer + catalog both-sides populated | config/runtime-proof/LIVE_FIXTURE_STATE.md | CONFIRMED | DURABLE | — | Yes |
| D3 | Fixture creation is scripted and reproducible | scripts/tenants/bootstrap-runtime-proof-fixtures.py | CONFIRMED | DURABLE | — | Yes |
| D4 | UUID drift detection implemented | scripts/tenants/validate-runtime-proof-fixtures.py | CONFIRMED | DURABLE | — | Yes |
| D5 | Waffle flags match manifest | config/runtime-proof/LIVE_FIXTURE_STATE.md | CONFIRMED | DURABLE | — | Yes |

## Durable Truths — Promotable Now

These claims have merged fixes, verified deployments, and no contradictions:

1. **Admin portal rendering** — SSO works, portal renders (A1, A2)
2. **Learner primary path** — dashboard BFF 200, search renders, SSO works (L1–L4)
3. **Build pipeline** — explicit source tags, immutable output, 12-check contract (B1–B3)
4. **JS hot-patches baked in images** — no more pod-local patches (G1)
5. **ArgoCD deployment** — enterprise MFE images deployed via GitOps (G2)
6. **Image traceability** — all images traceable, no floating tags (I1–I3)
7. **Secondary endpoint classification** — 13 requests mapped, owners identified (S1, S2)
8. **Caddy routing fix** — enterprise-catalog endpoints routed correctly (S3)
9. **Graceful degradation** — MFE safeEnsureQueryData handles secondary failures (S7)
10. **Synthetic fixtures** — scripted, reproducible, UUID-drift-checked (D1–D5)

## Provisional Truths — Awaiting Promotion

These claims need additional evidence or PR merges:

1. **S4 — Cookie name sed patch**: PR #1662 pending merge in bbi-infrastructure
2. **G3 — enterprise_worker init container**: PR #1673 pending merge in bbi-infrastructure
3. **G4 — No manual patches for basic function**: Depends on S4 and G3 merging
4. **A3 — Admin portal enterprise data visibility**: Needs fresh browser verification

## Contradicted Truths — Must Stay Open

These earlier claims were corrected by later evidence:

| Earlier Claim | Source | Contradicted By | Correction |
|--------------|--------|----------------|-----------|
| LMS BFF 401 is JWT auth failure | Phase 2 proofs | Phase 3: lane-a-runtime-closure.md | Actually HTML 404 from enterprise-access (wrong service routing) |
| PR #1640 handle_response is semantic fix | Phase 3 proofs | Phase 4: phase4-enterprise-learner-secondary-endpoint-verdict.md | It's TEMPORARY_RUNTIME_MITIGATION — masks routing error |
| PR #1664 (Job) creates enterprise_worker durably | LANE-A2-FINAL.md | LANE-A3-RUNTIME-BUNDLE.md | Job not on render path; init container (PR #1673) required |
| window.ENV_CONFIG provides config to getConfig() | PR #1643 analysis | LANE-A3-RUNTIME-BUNDLE.md | Webpack reads build-time config; sed patch required |
| Cookie name fix via ConfigMap env.config.js | PR #1643 analysis | phase5-pr1643-sufficiency-verdict.md | getConfig() doesn't read runtime ConfigMap; needs sed |

## Exact Blockers: Stabilization → Convergence

| # | Blocker | Owner | What Unblocks It |
|---|---------|-------|-----------------|
| BLK-1 | PR #1662 (cookie name sed) not yet merged | bbi-infrastructure / Lane A | Merge PR, verify ArgoCD sync, browser re-proof |
| BLK-2 | PR #1673 (enterprise_worker init container) not yet merged | bbi-infrastructure / Lane A | Merge PR, verify init container fires on pod restart |
| BLK-3 | Admin portal enterprise data visibility unverified | Lane A | Fresh browser proof showing non-empty enterprise view |
| BLK-4 | Post-merge browser re-proof not yet done | Lane A | Full browser proof after BLK-1 and BLK-2 are merged and deployed |

## Exact Evidence Lane A Must Produce Next

1. Confirm PRs #1662 and #1673 are merged in bbi-infrastructure
2. Verify ArgoCD has synced the changes to mereka-lms-dev
3. Perform a pod-restart test: delete the LMS and enterprise MFE pods, wait for restart, verify portals work WITHOUT manual intervention
4. Browser proof all three portals: admin, learner dashboard, learner search
5. Capture evidence that enterprise_worker user exists after pod restart (init container proof)
6. Capture admin portal showing enterprise data (not "No results")
7. Submit evidence as a tracked, promotable artifact (not var/proofs/ local file)

## What NOT to Claim Yet

- Do NOT claim learner secondary path is fully fixed (routing mitigation is temporary)
- Do NOT claim ecommerce integration works (service not deployed)
- Do NOT claim admin portal enterprise data visibility (unverified)
- Do NOT claim zero manual intervention required (pending PR merges)
- Do NOT claim convergence readiness from this bundle (it explicitly says BLOCKED)
