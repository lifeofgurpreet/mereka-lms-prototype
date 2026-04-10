# Control-Plane Authority / Migration Map

_Owner: Agent 2 | Last verified: 2026-04-10 | Status: active_

## PCP Already Contains (Do Not Duplicate)

| Artifact | PCP Path | Notes |
|----------|----------|-------|
| Release-bundle schema | `contracts/release-bundle-schema.yaml` (v1.1) | Canonical; mereka-lms generator still writes v1.0.0 (see register #8) |
| Release-object authority | `contracts/release-object-authority-contract.yaml` | Lists mereka-lms as producer, bbi-infra as consumer |
| Service identity | `contracts/service-identity-contract.yaml` | Canonical service IDs |
| Lane identity (service) | `contracts/lane-identity-contract.yaml` | Maps canonical SERVICE lanes (mereka-lms, authentik, etc.) |
| Release contracts | `contracts/release-contracts.yaml` | Lane registry with evidence requirements |
| Promotion record schema | `contracts/promotion-record-schema.yaml` | Cross-repo promotion record format |
| Proof artifact policy | `contracts/proof-artifact-policy.yaml` | What proof is required for promotion |
| Evidence pack schema | `contracts/evidence-pack-schema.yaml` | Evidence pack structure |
| Secret contracts | `contracts/secrets-contract.yaml` | Secret management authority |
| Workload identity | `contracts/workload-identity-bindings.yaml` | GCP workload identity bindings |

## In mereka-lms (App-Scoped — Should Stay Here)

| Artifact | Path | Notes |
|----------|------|-------|
| Lane identity (env) | `config/lane-identity.yaml` | Maps LMS deployment environments (dev/staging/prod), not services — app-owned |
| Lane normalize script | `scripts/lib/lane-normalize.sh` | Derived from lane-identity.yaml; app runtime utility |
| Release bundle generator | `scripts/infra/generate-release-bundle.sh` | Produces bundles that PCP schema validates |
| Release object generator | `scripts/release/generate_release_object.py` | App-scoped proof object |
| Truth ledger generator | `scripts/release/generate_truth_ledger.py` | App-scoped ledger |
| CI inventory | `scripts/governance/script-registry.yaml` | App-owned CI gate definitions |

## Should Move to PCP (Candidates for Migration)

| Item | Current Location | PCP Target | Priority | Blocker |
|------|-----------------|------------|----------|---------|
| Dispatch payload contract | Implicit in workflow step code | `contracts/dispatch-contract.yaml` — defines exact fields sender/receiver must agree on | HIGH | Define contract first, then validate in both workflows |
| Release-bundle schema version | `generate-release-bundle.sh` writes v1.0.0, contract_family "release-bundle" | Align with PCP v1.1 and contract_family "release_bundle_schema" | MEDIUM | Non-breaking; receiver doesn't validate today |
| Proof gate contract | `config/proof-gate-contract.yaml` | Merge into `contracts/proof-artifact-policy.yaml` | LOW | Requires alignment between two teams |

## Already Aligned (No Migration Needed)

| Item | State |
|------|-------|
| Release-object schema_version | `"release-object/v1"` — fixed in PR #1489 |
| Dispatch payload format | Aligned sender+receiver — fixed in PR #1484 |
| Service ID (`mereka-lms`) | Matches PCP `lane-identity-contract.yaml` |
| Contract ref (`5fffde1a`) | Valid PCP commit SHA, verified |

## PCP Frozen Baseline

```
Biji-Biji-Initiative/platform-control-plane@5fffde1a
```

Verified: `git cat-file -t 5fffde1a` → `commit` in PCP repo.
This is referenced in all mereka-lms release bundles as `contract_ref`.

## Next Migration Step

1. Define `contracts/dispatch-contract.yaml` in PCP
2. Import it in both `build-tutor-images.yml` (sender) and `promote-dev-image.yml` (receiver)
3. Both workflows validate their payloads against the contract (fail on mismatch)
4. This eliminates the current "trust-by-convention" between sender and receiver

This is blocked on: no active failing scenario (the current payload IS aligned after #1484).
Priority: schedule for next control-plane sprint, not urgent.
