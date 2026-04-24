---
title: MFE Executable Frontier Queue
type: execution-queue
owner: platform-review
status: active
observed_at: 2026-04-18T15:20Z
---

# MFE Executable Frontier Queue

This document converts the broader MFE issue map into bounded implementation
lanes.

It is not a replacement for the MFE planning packet. It is the “what should the
implementer actually pick up next” layer.

## Lane 1 — Enterprise Admin Browser Proof

- issue class: enterprise admin data visibility is not browser-proven
- evidence:
  - `docs/reviews/STAGING_RUNTIME_CONVERGENCE_EVIDENCE.md`
  - `docs/policies/architecture/ENTERPRISE_FRONTEND_PARITY_POLICY.md`
  - `docs/reference/architecture/ENTERPRISE_BROWSER_PROOF_PLAN.md`
- goal:
  - prove enterprise admin authenticated session and real enterprise data
    visibility in browser, not just shell render
- closure bar:
  - authenticated browser proof on admin root and deep route
  - evidence of visible enterprise data state
  - failure mode documented if permissions/data contract blocks proof

## Lane 2 — Enterprise Learner Authenticated Path Proof

- issue class: enterprise learner authenticated path still not browser-proven
- evidence:
  - `docs/reviews/STAGING_RUNTIME_CONVERGENCE_EVIDENCE.md`
  - `docs/policies/architecture/ENTERPRISE_FRONTEND_PARITY_POLICY.md`
- goal:
  - prove enterprise learner authenticated route path end-to-end
- closure bar:
  - browser proof from login through authenticated enterprise learner surface
  - tenant identity and runtime config consistent on the tested host

## Lane 3 — Learner Secondary Endpoint Semantic Closure

- issue class: learner secondary endpoints still rely on routing mitigations
- evidence:
  - `docs/reviews/DEV_RUNTIME_CONVERGENCE_EVIDENCE.md`
- goal:
  - retire the “temporary routing mitigation” class or formally accept it as a
    durable contract
- closure bar:
  - mitigation removed and replaced by real fix
  - or explicit doctrine decision that the mitigation is now the intended
    design, with docs updated accordingly

## Lane 4 — Enterprise Customization-Surface Inventory

- issue class: enterprise MFEs do not cleanly inherit Tutor / plugin-slot paths
- evidence:
  - `docs/policies/architecture/footer-slot-exceptions.md`
  - `docs/reference/architecture/MFE_RUNTIME_CONFIG.md`
  - `docs/reference/architecture/ROUTE_TRUTH_RECONCILIATION.md`
- goal:
  - create a canonical map of which enterprise MFE customizations are:
    - plugin-slot capable
    - runtime-config capable
    - build-pipeline specific
    - currently impossible without deeper changes
- closure bar:
  - one canonical matrix instead of scattered caveats
  - at least one implementable burn slice derived from the matrix

## Lane 5 — Runtime-Config Consistency Verification

- issue class: runtime-config correctness is still a live risk area
- evidence:
  - `docs/reference/architecture/MFE_RUNTIME_CONFIG.md`
  - `docs/policies/architecture/MULTISITE_UX_CONSISTENCY.md`
  - `docs/reference/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md`
- goal:
  - convert runtime-config policy into stronger active verification
- closure bar:
  - deterministic verification for highest-risk domains/surfaces
  - documented owner for each critical runtime-config dimension

## Lane 6 — Selector Debt Burn

- issue class: selector debt is real, but the live risky set is narrower than
  old docs imply
- evidence:
  - `docs/reference/architecture/MFE_SELECTOR_AUDIT.md`
  - `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`
  - `docs/policies/architecture/MFE_SELECTOR_EXCEPTIONS.md`
  - `docs/policies/architecture/SELECTOR_HARDENING_POLICY.md`
- goal:
  - separate:
    - dead selector residue
    - intentional selector exceptions
    - live risky selectors that still deserve burn work
- closure bar:
  - no broad “selector debt” blob remains
  - next selector work is targeted only at live risky or policy-exception areas

## Lane 7 — Performance Enforcement

- issue class: performance budgets exist more in policy than in active closure
- evidence:
  - `docs/policies/architecture/PERFORMANCE_BUDGETS.md`
- goal:
  - convert at least one high-value route or bundle surface into an operational
    enforcement loop
- closure bar:
  - one measurable route/bundle budget tied to a real check or report
  - explicit backlog of next performance targets

## Lane 8 — Accessibility Baseline For MFEs

- issue class: accessibility is underrepresented in the active MFE queue
- evidence:
  - MFE planning packet lacks a strong active accessibility lane
  - broader platform ambition requires it
- goal:
  - define an MFE accessibility baseline review lane
- closure bar:
  - first accessibility queue exists with named surfaces and failure classes
  - not just a general statement of intent

## Best Next Three

If an implementer needed the highest-leverage next MFE work, the best first
three lanes are:

1. enterprise admin browser proof
2. learner secondary endpoint semantic closure
3. enterprise customization-surface inventory

That mix gives:

- one proof lane
- one semantic/runtime lane
- one architecture-to-execution lane

## Planner Rule

Do not leave these as prose-only forever.

Once tracker hygiene is restored, split this frontier queue into concrete beads
with:

- explicit owner repo
- proof artifact
- closure criteria
- dependency links back to the broader MFE planning packet
