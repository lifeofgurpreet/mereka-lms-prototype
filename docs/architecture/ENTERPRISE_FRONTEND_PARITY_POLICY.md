# Enterprise Frontend Parity Policy
_Audience: Platform Engineering, Frontend Engineering, Release Reviewers • Owner: Platform Team • Last updated: 2026-03-11 • Status: canonical_

## Purpose

Define what counts as an enterprise frontend parity surface, what proof level is required for each surface, and what evidence is sufficient before calling an enterprise-facing frontend surface truly validated.

This policy is intentionally stricter than "page returns HTTP 200". Enterprise parity is only meaningful when route ownership, tenant identity, runtime config, and the real browser experience all line up.

## Scope

This policy governs repo-owned review and release decisions for:

- enterprise learner portal
- enterprise admin portal
- enterprise-linked auth surfaces
- enterprise-linked learner/account/profile/dashboard surfaces
- non-core adjacent routes when they participate in the enterprise journey

This policy does **not** claim live runtime proof from `mereka-lms` alone when the relevant truth is infra-owned or runtime-only.

## Proof Levels

| Level | Meaning | Typical evidence |
|---|---|---|
| `REPO_PROOF_ONLY` | Repo sources prove structure, ownership, and declared intent only | docs, manifests, scripts, contracts |
| `INFRA_PROOF_REQUIRED` | Final truth depends on lane overlays or ingress/GitOps realization outside this repo | `bbi-infrastructure`, overlay render, ingress realization |
| `RUNTIME_PROOF_REQUIRED` | Final truth depends on live runtime config/state | live `/api/mfe_config/v1`, live `SiteConfiguration`, live health |
| `BROWSER_PROOF_REQUIRED` | A browser must render and navigate the surface successfully | screenshots, browser test evidence, DOM assertions |
| `AUTHENTICATED_BROWSER_PROOF_REQUIRED` | The browser proof must include authenticated user state and one meaningful post-login path | session-aware browser evidence, protected-route navigation |

## Enterprise Frontend Parity Surfaces

| Surface | Why it is parity-sensitive | Minimum proof required | Release implication |
|---|---|---|---|
| Enterprise learner portal shell (`learner.*`) | Learner-facing enterprise entrypoint; branding, auth continuity, runtime config, and tenant isolation all converge here | `INFRA_PROOF_REQUIRED` + `RUNTIME_PROOF_REQUIRED` + `BROWSER_PROOF_REQUIRED` | Cannot be called `runtime_validated` without this |
| Enterprise learner deep route | Root shell success is not enough; tenant-linked content, loading/error handling, and authenticated navigation must work | `AUTHENTICATED_BROWSER_PROOF_REQUIRED` | Required before claiming enterprise learner parity |
| Enterprise admin portal shell (`admin.*`) | Admin route ownership and service API fan-out differ from the main MFE gateway | `INFRA_PROOF_REQUIRED` + `RUNTIME_PROOF_REQUIRED` + `BROWSER_PROOF_REQUIRED` | Cannot be called `runtime_validated` without this |
| Enterprise admin deep route | Admin flows depend on protected APIs, table states, permissions, and backend routing | `AUTHENTICATED_BROWSER_PROOF_REQUIRED` | Required before claiming enterprise admin parity |
| Enterprise-linked login / redirect / refresh surfaces | Enterprise journeys still depend on `/login`, `/oauth2`, `/csrf`, and `/login_refresh` behaving correctly from the enterprise domains | `INFRA_PROOF_REQUIRED` + `RUNTIME_PROOF_REQUIRED` + `BROWSER_PROOF_REQUIRED` | Required whenever enterprise auth continuity is in scope |
| Enterprise-linked account / profile / learner-dashboard surfaces on `apps.*` | These are not enterprise-hosted, but they are enterprise-relevant when redirects land here after enterprise auth or deep links | `RUNTIME_PROOF_REQUIRED` + `AUTHENTICATED_BROWSER_PROOF_REQUIRED` | Required when enterprise sign-in lands on shared MFE surfaces |
| Non-core enterprise-adjacent routes (`/orders*`, `/payment*`, credentials root/admin) | These can break the user journey even when core LMS/MFE paths look healthy | `REPO_PROOF_ONLY` by default, escalate to `BROWSER_PROOF_REQUIRED` if the route is part of the current enterprise release path | Not blocking by default, unless explicitly in the release path |

## What Counts as Parity

Parity means all of the following are true for the surface under review:

1. The route exists and resolves to the intended owner.
2. The tenant/domain identity is correct for the host being tested.
3. The surface does not show broken branding placeholders, wrong-domain links, or malformed runtime URLs.
4. Tenant-specific values do not bleed across hosts.
5. Required API calls for that surface resolve through the intended path.
6. The shell does not merely render; at least one meaningful navigation path works.
7. For authenticated surfaces, the protected route works after login or session restoration.
8. Key negative states are handled at least at a basic release-review level:
   - loading
   - empty
   - error
   - unauthorized / redirect

## What Does **Not** Count as Parity

The following are explicitly insufficient:

- HTTP `200` alone
- shell render alone
- unauthenticated login page alone
- repo-local defaults when truth is infra-owned
- repo-local defaults when truth is runtime-only
- one enterprise portal working while the other still breaks
- proof from `apps.*` alone while `admin.*` or `learner.*` remains unproven
- source-only checks for routes that require live browser behavior

## Release Decision Rules

### `repo_complete`

`repo_complete` is allowed when:

- repo contracts are internally consistent
- route ownership is documented
- verifier semantics are fail-closed / indeterminate where appropriate
- no repo-local contradiction remains

`repo_complete` is **not** the same as enterprise parity.

### `runtime_validated`

Enterprise frontend parity may only be called `runtime_validated` when all of the following are present:

1. enterprise learner portal shell proof
2. enterprise admin portal shell proof
3. one authenticated learner deep-route proof
4. one authenticated admin deep-route proof
5. live runtime config proof for the domain under test
6. no cross-tenant bleed in the tested route family

If any one of these is missing, the correct state is weaker than `runtime_validated`.

## Exception Handling

An enterprise exception is only valid if all of the following are documented:

- exact surface under exception
- owner
- reason
- expiry or retirement trigger
- downgrade effect on release verdicts

Open-ended warning-only exceptions are not valid policy.

## Current Policy Position

The current repo position is:

- enterprise learner and enterprise admin portals are parity-sensitive surfaces
- they are **not** "just another themed MFE"
- repo-only proof is useful for truth boundaries, but insufficient for final parity
- enterprise parity cannot be claimed from `mereka-lms` alone when lane overlays and runtime config are authoritative elsewhere

## Decision Points Still Requiring Explicit Owner Confirmation

These are the remaining policy decisions that require owner sign-off rather than silent assumption:

1. Whether enterprise learner and admin deep-route browser proof is required on every release, or only on releases that touch enterprise-owned surfaces.
2. Whether non-core routes (`/orders*`, `/payment*`, credentials) are release-blocking parity surfaces when enterprise programs rely on them.
3. Whether enterprise footer parity is a hard blocker for `runtime_validated`, or an explicitly time-bounded exception.

Until those decisions are formally resolved, reviewers should choose the stricter interpretation.

## Reviewer Shortcut

Use this decision shortcut:

- If the evidence is repo-only: at most `repo_complete`.
- If the evidence includes infra realization but no live browser proof: not parity-complete.
- If one enterprise portal is proven and the other is not: parity not achieved.
- If live runtime config is missing: parity not achieved.
- If authenticated deep-route evidence is missing: parity not achieved.
