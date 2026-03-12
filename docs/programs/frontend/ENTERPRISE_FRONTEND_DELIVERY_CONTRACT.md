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
