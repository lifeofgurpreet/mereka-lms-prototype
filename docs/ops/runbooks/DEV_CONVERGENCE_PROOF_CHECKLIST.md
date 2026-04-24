# DEV Convergence Proof Checklist
_Audience: Operators • Owner: Platform Team • Last verified: 2026-03-20 • Status: canonical_

Use this checklist before claiming anything in the DEV convergence lane is fixed, verified, or durable.

## Claim Taxonomy

- `VERIFIED FACT`: proven from current source or current runtime in this lane
- `DISPROVED CLAIM`: contradicted by current source or runtime
- `WORKING HYPOTHESIS`: plausible, but not yet proven
- `PARKED ISSUE`: real and acknowledged, but intentionally out of the current batch

## Source Taxonomy

- `CANONICAL SOURCE`: the source that wins by repo policy
- `DERIVATIVE SOURCE`: generated or convenience projection
- `STALE / CONFLICTING SOURCE`: contradicted by a canonical source or current proof
- `TEMP BRIDGE`: intentionally temporary source-owned bridge with an owner and removal trigger
- `TEMP RUNTIME`: runtime-only state with no durable source guarantee

## Before Any Change

- [ ] Confirm the lane is DEV-only.
- [ ] Read `docs/status/active/DEV_CONVERGENCE_LEDGER.md`.
- [ ] Read `docs/status/active/DEV_CONVERGENCE_PARKED_ISSUES.md`.
- [ ] Confirm the owning source with `deploy/k8s/RUNTIME_AUTHORITY_MAP.md`.
- [ ] If the claim depends on live GitOps behavior, capture the active ArgoCD source path and drift-suppression settings before reasoning from repo files.
- [ ] Capture before-proof for every touched surface:
  - [ ] source state
  - [ ] runtime state
  - [ ] browser-visible state when relevant

## Required DEV Proof Commands

```bash
kubectl get applications.argoproj.io -A | rg 'mereka-lms-dev'
kubectl get application mereka-lms-dev -n argocd -o yaml
kubectl get deploy,pods,svc,ingress -n mereka-lms-dev
bash scripts/qa/verify-domain-url-invariants.sh
bash scripts/qa/verify-tenant-contract-alignment.sh
bash scripts/infra/apply-multisite-config.sh --namespace mereka-lms-dev --env dev --dry-run
```

## Browser and Runtime Rules

- [ ] Do not treat a successful `curl` as browser proof when auth, cookies, redirects, or MFE runtime config matter.
- [ ] When a public host is part of the claim, record the exact host and first-response shape (`200`, `302`, auth page, or error).
- [ ] When ConfigMaps or mounted settings are implicated, prove the live GitOps consumer render and the mounted runtime object names before calling anything durable.
- [ ] For a public-host `4xx` or `5xx`, trace ingress or service selection, proxy access logs, pod logs, and effective deployment env before naming the owner layer.
- [ ] Do not call a repo-only consumer patch a runtime fix until the live deployment env and the public host both re-verify after GitOps applies it.
- [ ] If a surface remains `TEMP_RUNTIME`, say so plainly and record the removal trigger.

## Required Output For Any Batch

- [ ] before proof
- [ ] after proof
- [ ] exact files changed
- [ ] exact runtime effect
- [ ] exact browser effect
- [ ] exact remaining drift
- [ ] exact removal trigger for anything temporary

## Stop Conditions

- Stop if the next step requires staging or prod.
- Stop if the only remaining path is an uncommitted local workaround.
- Stop if the evidence would force a repo-boundary violation.
