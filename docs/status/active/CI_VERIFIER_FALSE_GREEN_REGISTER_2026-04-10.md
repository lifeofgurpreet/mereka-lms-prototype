# CI / Verifier False-Green Register

_Owner: Agent 2 | Last verified: 2026-04-10T13:52:00Z | Status: active_

## Open Risks

| # | Risk | Severity | Evidence | Why it matters |
|---|---|---|---|---|
| 1 | Red app build can still mutate GitOps until the app-side gate lands on `main` | critical | push runs `24226842382` and `24227735786` failed overall at `SLSA Provenance & Attestation -> Install cosign`, yet `Generate Release Bundle` and `Dispatch dev promotion to infra repo` both succeeded; a source fix now gates dispatch on successful provenance, but it is not merged yet | overall workflow conclusion is not a trustworthy promotion gate until the source fix is realized |
| 2 | Green workflow_dispatch build can mean “no promotion candidate emitted” | high | run `24229142921` succeeded while `Build MFE Image`, `Generate Release Bundle`, and `Manual GitOps Bridge` were skipped | green does not imply release bundle / release object / dispatch existed |
| 3 | Release-bundle schema drift was masked by permissive verifier logic | high | generator emitted `1.1` + `release_bundle_schema` while JSON schema still declared `1.0.0` + `release-bundle` until this tranche | verifier was compensating for duplicate writers instead of eliminating them |
| 4 | Release-object authority is still multi-writer | high | YAML schema, JSON schema, generator, and infra workflow all define structure | “validated” does not mean one authority owns the contract |
| 5 | Dispatch contract is still implicit | medium | sender/receiver code matches, but no PCP contract exists | next drift can pass until runtime or receiver rejects |
| 6 | PCP contract ref governance is implicit | medium | core generators/proof scripts and directly related tests were updated locally from `platform-control-plane@5fffde1a` to `@194e6001...`, but ref selection is still hardcoded rather than governed | emitted evidence can still overstate authority if the chosen PCP ref drifts again |
| 7 | GitOps writer app migration is unproved in live use | medium | open PRs [#1529](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1529) and [#2636](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2636) | fallback PAT path remains live and the steady-state auth path is not cut over |

## Risks Downgraded This Tranche

| Concern | New status | Why |
|---|---|---|
| “repository_dispatch has never been received” | retired | infra repository-dispatch runs are now proved |
| “organic push-build dispatch is blocked by MFE instability” | retired | organic push runs already built both images and dispatched; the remaining failure is the provenance lane |

## Current Trust Read

- `repository_dispatch` works.
- organic push-build dispatch works.
- overall build status is not yet a trustworthy promotion gate.
- PCP is not yet the active contract authority for the live sender/receiver handoff.
