# Auth Change Checklist
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

- [ ] Confirmed if this repo is source-of-truth or capability-only for auth config
- [ ] Updated canonical infra values (if environment behavior changed)
- [ ] Updated auth registry entry (if pattern/domain/provider changed)
- [ ] No new `auth.mereka.io` references in active files
- [ ] No auth secrets in plaintext values/config files
- [ ] Forward-auth annotations match canonical contract (if applicable)
- [ ] OIDC issuer/provider URL is canonical and trailing-slash safe (if applicable)
- [ ] Outpost ingress/service wiring verified (if forward-auth with outpost path)
- [ ] CI checks passed (contract, drift, forbidden patterns, secret checks)
- [ ] Rollout evidence captured for target environment(s)

## Evidence Links

- Infra PR:
- App PR:
- Validation logs:
- Rollout runbook entry:

