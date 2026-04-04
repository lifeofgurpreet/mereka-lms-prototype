# VERIFIER_CONTRACT_CATALOG
_Audience: Operators and agents · Owner: Platform Team · Status: canonical_

> This is the contract owner for proof lanes.
> Detailed per-script implementation notes belong in
> [../operations/VERIFIER_CONTRACT_CATALOG.md](../operations/VERIFIER_CONTRACT_CATALOG.md).

## Proof-lane-to-verifier/artifact table

| Proof lane | Verifier(s) | Allowed to prove | Target surfaces | Inputs | Produced artifact | False-green trap | False-red trap | Owner | Successor if deprecated |
|---|---|---|---|---|---|---|---|---|---|
| runtime-routing | `verify-rke2-tenant-routes.sh`, runtime-proof scripts | route reachability and response class | active host/route surfaces | tenant registry + live URLs | runtime probe output | offline-only checks can miss live breakage | transient DNS/network failures | platform | n/a |
| authenticated learner canary | `verify-authenticated-sso-canary.sh` | login/session/dashboard journey | authn + learner dashboard | smoke creds + env scope | browser run artifact | session pass with blank page | slow redirect timeout | platform | n/a |
| Studio canary | `verify-authenticated-sso-canary.sh` (studio path) | staff Studio login/home | Studio authenticated surface | studio smoke creds | browser run artifact | non-blocking mode can skip silently | callback timeout/5xx | platform | n/a |
| forum smoke | `verify-forum-smoke.sh` + runtime proofs | forum endpoint health semantics | forum alias + in-process endpoint | forum URL + probe config | forum probe output | alias empty 200 can look healthy | alias DNS drift | platform | n/a |
| credentials/notes smoke | credentials/notes smoke checks | auth-required API behavior | credentials/notes services | service endpoints + expected status | service smoke output | health-only checks can miss function breakage | readiness lag | platform | n/a |
| generated surfaces | `verify-domain-generated-surfaces.sh`, `verify-domain-authority-chain.sh` | generated outputs match source contracts | generated DNS/domain/caddy surfaces | source contracts + generated outputs | generated-surface check output | generated output matches stale source | stale generated files | governance | n/a |
| release object / truth ledger | `release-gate.sh`, bundle verification, proof emit commands | release-chain integrity | release bundle + proof envelopes | build metadata + release object | release/proof envelope artifacts | structural pass without runtime validity | missing required metadata | release/platform | n/a |
| tenant isolation | isolation verifier + scheduled checks | cross-tenant separation proof | tenant boundaries | tenant config + runtime checks | isolation report/metrics | alert pipeline may be inert without full plumbing | strict assumptions | platform/security | n/a |

## Smoke identity authority/consumer mapping table

| Identity class | Identity authority | Secret authority | Consumer lanes |
|---|---|---|---|
| tenant learner smoke | Authentik + Open edX account | Infisical (consumer mirrors allowed) | learner canary, authenticated smoke |
| tenant operator/staff smoke | Authentik + Open edX staff | Infisical (consumer mirrors allowed) | Studio canary, operator journeys |
| enterprise admin smoke | enterprise identity authority | Infisical | enterprise admin proof |
| analytics/support smoke | analytics identity authority | Infisical | analytics/operator proof |

## Contract rules

1. Verifiers may only prove what is in their contract lane.
2. A green verifier outside its lane is not launch proof.
3. If runtime red + verifier green, the verifier contract must be corrected.
4. Deprecated verifiers must declare successor lane or be retired.

## Related

- [AGENT_EXECUTION_WORKFLOW.md](../operations/AGENT_EXECUTION_WORKFLOW.md)
- [SMOKE_ACCOUNT_REGISTRY_2026-04-04.md](../../status/active/SMOKE_ACCOUNT_REGISTRY_2026-04-04.md)
- [AUTHENTICATED_SMOKE_CREDENTIALS.md](../operations/AUTHENTICATED_SMOKE_CREDENTIALS.md)
