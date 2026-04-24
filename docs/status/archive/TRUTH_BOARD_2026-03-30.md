# Platform Truth Board — 2026-03-30

> Every claim uses exactly one of four states:
> **stabilized** | **codified** | **reconciled** | **verified**
>
> No vague language. No "should be fine." No "pretty much done."

## Studio CMS

| State | Evidence |
|-------|----------|
| **Codified** | #1229 merged (widgets/footer.html), #1230 merged (footer.html + Mako verifier), #1231 merged (CI registration) |
| **Reconciled** | PENDING — image build in progress (run 23722747954). Once built, ArgoCD/infra promotion needed. |
| **Verified** | NOT YET — need post-deploy pod source verification |

**Root cause**: PR #1119 introduced `${_('LMS')}` in CMS Mako footer templates without importing `gettext`. Every Django-rendered CMS page crashed with `TypeError: 'Undefined' object is not callable`.

**Temporary stabilization**: Mako cache patched in running pod. Reverts on pod restart. Not durable.

**Permanent fix**: Two footer templates fixed (literal `LMS`). Mako syntax verifier added to CI static inventory (release-blocking). Catches this class of bug before merge.

**What remains**: Image rebuild → deploy → verify pod source matches git → confirm no Mako cache dependency.

---

## Staging Parity

| State | Evidence |
|-------|----------|
| **Codified** | mereka-lms #1227 merged, bbi-infrastructure #2175 merged |
| **Reconciled** | ArgoCD synced revision `defb96cd` (bbi-infrastructure main HEAD). LMS pods rolled. |
| **Verified** | **YES** — all 10 staging hosts verified at 2026-03-30T00:39Z |

### Host Verification Results

| Host | HTTP | Status |
|------|------|--------|
| staging.academyv2.mereka.io | 200 | PASS |
| staging.academy.biji-biji.com | 200 | PASS |
| staging.skillourfuture.academy.mereka.io | 200 | PASS |
| staging.studio.academyv2.mereka.io | 302 → /login/ | PASS |
| staging.apps.academyv2.mereka.io | 200 | PASS |
| staging.discovery.academyv2.mereka.io | 200 | PASS |
| staging.notes.academyv2.mereka.io | 200 | PASS |
| staging.credentials.academyv2.mereka.io | 404 (root) / 302 (/records/) | PASS (expected) |
| staging.admin.academyv2.mereka.io | 200 | PASS |
| staging.learner.academyv2.mereka.io | 200 | PASS |

### Tenant Config Verification

| Host | SITE_NAME | PRIMARY | URLs correct? |
|------|-----------|---------|--------------|
| staging.academyv2.mereka.io | Mereka Academy (Staging) | #ab3b78 | Yes |
| staging.academy.biji-biji.com | Biji-Biji Academy | #2d6a4f | Yes |
| staging.skillourfuture.academy.mereka.io | Skill Our Future | #1a3c6e | Yes |

**Minor issue**: 4 orphaned ConfigMaps causing cosmetic OutOfSync in ArgoCD. Non-blocking. Fix: `argocd app sync mereka-lms-staging --prune`.

---

## Footer Architecture

| State | Evidence |
|-------|----------|
| **Diagnosed** | Architecture analysis complete. Decision: TWO systems (MFE canonical + Django fallback) |
| **Codified** | IN PROGRESS — footer-rewrite agent working on Django LMS footer rewrite + parity verifier |
| **Reconciled** | NOT YET |
| **Verified** | NOT YET |

**Decision**: One canonical content contract, two renderers maximum.
- MFE footer (React): canonical brand expression with social icons, WhatsApp, app badges, 4 link columns
- Django footer (Mako): server-rendered equivalent for non-MFE pages, must visually match MFE

**Current state**: Django LMS footer is completely different design (white, academy-only). Rewrite in progress to match MFE dark v2.

---

## Test Coverage

| State | Evidence |
|-------|----------|
| **Codified** | All 21/21 custom apps have tests. PRs #1225, #1226, #1228 merged. |
| **Reconciled** | Yes — tests run in CI |
| **Verified** | 1,102 tests total: 856 pass, 224 skip (DB-dependent), 11 skip (FK str) |

**Honest description**: This is **baseline** protection, not comprehensive coverage. The 224 skipped tests need pytest-django DB fixtures to run. They are marked with `@unittest.skip("DB migration required")` — not hidden, not claimed as passing.

---

## SCSS Split

| State | Evidence |
|-------|----------|
| **Codified** | PR #1224 — rebased on latest main, force-pushed, catalog regenerated |
| **Reconciled** | PENDING — CI running after rebase |
| **Verified** | Local verifiers pass (branding-health, css-overhead, a11y-regression) |

**What it does**: Splits `mereka.scss` (935 lines) into 7 surface partials. Updates all downstream verifiers to be partial-aware.

---

## Mako Template Verifier

| State | Evidence |
|-------|----------|
| **Codified** | #1230 merged (verifier script), #1231 merged (CI registration) |
| **Reconciled** | Yes — in CI static inventory, release-blocking |
| **Verified** | 15/15 pass across all 11 theme templates |

**What it catches**: `${_()}` without gettext import, unbalanced Mako tags, undefined built-in references. The exact class of bug that crashed Studio.

---

## Open Items

| Item | State | Next action |
|------|-------|-------------|
| Studio image deploy | Codified | Wait for build → verify pod source |
| Footer convergence PR | In progress | Agent completing rewrite |
| SCSS #1224 | Codified | Wait for CI → merge |
| ArgoCD ConfigMap prune | Cosmetic | `argocd app sync mereka-lms-staging --prune` |
| DB-dependent test fixtures | Baseline only | Future: add pytest-django fixtures |

---

*Generated 2026-03-30. Source truth: git. Deploy truth: ArgoCD + pod inspection. Runtime truth: public HTTP proofs.*
