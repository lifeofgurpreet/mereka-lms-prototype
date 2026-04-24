# Enterprise Frontend Delivery Contract

This contract hardens the repo-owned seam for enterprise learner/admin delivery.
It is intentionally narrow: route ownership, config-consumption mode, and
bundle-patch ownership for the enterprise MFEs.

Canonical machine-readable sources:

- `docs/programs/frontend/enterprise-frontend-route-owner.v1.yaml`
- `docs/programs/frontend/enterprise-frontend-config-consumption.v1.yaml`

Enforced by:

- `scripts/qa/verify-enterprise-frontend-route-contract.sh`
- `scripts/qa/verify-enterprise-frontend-config-contract.sh`
- `scripts/qa/test-enterprise-mfe-patch-contract.sh`

What is now enforced:

- enterprise learner/admin route families declare their semantic owner and the
  repo routing/config surfaces that must remain aligned
- enterprise config keys declare whether they are consumed from runtime
  `window.ENV_CONFIG`, patched into built bundles, or supplied by plugin/runtime
  theme wiring
- `patch-missing-env.sh` is role-aware and treats learner-only product patches
  as required signatures instead of silent best-effort rewrites
- learner/admin parity guardrails require both portals to share theme, env, and
  patch invocation inputs

What is still runtime/browser only:

- live proxy ownership after deploy
- browser-visible learner/admin success
- cross-origin/runtime behavior after infra changes land

Future owners must update the YAML contracts and verifier expectations whenever:

- enterprise route ownership changes
- enterprise MFE env keys are added, renamed, or made inert
- `patch-missing-env.sh` gains or drops a product patch

## Live Convergence Status

Lane M2 verified live dev contract parity against deployed artifacts, not just repo
intent.

Proven live matches:

- learner live `env.config.js` provides `INTEGRATION_WARNING_DISMISSED_COOKIE_NAME`
  and same-origin enterprise base URLs
- learner and admin live `window.PARAGON_THEME` configuration is present
- learner live Caddy routes `academies`, `enterprise-curations`, and
  `highlight-sets` to `enterprise-catalog`
- learner live Caddy routes `/api/v1/*` to `enterprise-access` and LMS auth
  paths to `lms`
- main live Caddy routes admin-host `/api/enterprise-catalog/*` to
  `enterprise-catalog` and `/api/enterprise-access/*` to `enterprise-access`
- learner live shipped JS contains the optional ecommerce 404 fallback and the
  Algolia null-guard patch markers
- admin live shipped JS correctly omits learner-only patch markers

Residual note:

- the currently live learner/admin image tags in dev still predate the merge SHAs
  for PRs `#885` and `#890`, but image provenance alone is not the governing
  truth for live parity

Lane M3 resolved that ambiguity from first principles:

- route ownership is `RUNTIME_MOUNTED` via the live Caddy ConfigMaps mounted at
  `/etc/caddy/Caddyfile`
- runtime env keys and `window.PARAGON_THEME` are `RUNTIME_MOUNTED` via the
  live `enterprise-mfe-env` ConfigMap mounted at `/openedx/dist/env.config.js`
- learner optional-404 hardening and the Algolia null guard are `IMAGE_BUILT`
  because the live learner bundle contains those markers while the live startup
  command does not inject them and no runtime volume overlays the JS bundle
- domain rewrites, empty-string cookie repair, and broad `MISSING_ENV_VAR`
  sentinel fixes are `STARTUP_PATCHED` because the live learner/admin deployment
  commands still run `sed` rewrites over `/openedx/dist/*.js` before `caddy`
  starts

The live enterprise frontend provenance in dev is therefore `MIXED`, not pure
image provenance. Image tags are insufficient for closure because they do not
capture runtime-mounted files or startup JS mutation.

Runtime guardrail:

- `scripts/qa/verify-enterprise-frontend-live-contract.sh` now checks the live
  learner/admin env, Caddy routing, startup-patch provenance markers, and
  bundle patch markers directly against the contract
- Lane M3 hardened that verifier so missing `--namespace` / `--context` values
  fail cleanly and single-quote patterns are passed safely to `kubectl exec`
  instead of being interpolated into a fragile remote shell

Lane M3 verdict:

- `CONDITIONALLY_CLOSED` until the verifier hardening lands on `main`
- after that merge, the remaining ambiguity is removed: future investigation can
  re-check live parity and provenance directly instead of inferring from image
  tags
