# Operations Evidence Packs
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory is the active evidence surface for operational proof packs.

## Use this directory for

- gate proof bundles
- runtime verification captures
- deployment or recovery evidence
- operator validation artifacts that prove a claim or outcome

## Do not use this directory for

- active status reporting that belongs in `docs/status/**`
- cold historical evidence that belongs in `docs/archive/evidence/**`
- generated summaries that should be regenerated rather than stored as proof

## Pack shape

Preferred shape:

- `docs/evidence/operations/<YYYY-MM-DD>-<slug>/README.md`

Short-form compatibility files may still exist while older packs are being normalized, but new active evidence should follow the pack shape documented in the index.

## Authority rule

Files here are part of the winning active evidence root under `docs/evidence/**`.

Do not create new active proof under top-level `evidence/**` or archive paths.

## Active packs

- [Analytics key elimination evidence](ANALYTICS_KEY_ELIMINATION_EVIDENCE.md)
- [Assessment XQueue evidence](ASSESSMENT_XQUEUE_EVIDENCE.md)
- [GKE workload triage evidence](GKE_WORKLOAD_TRIAGE_EVIDENCE.md)
- [Kind cluster recovery evidence](KIND_CLUSTER_RECOVERY_EVIDENCE.md)
- [Tenant isolation evidence](TENANT_ISOLATION_EVIDENCE.md)
- [Token integrity routing evidence](TOKEN_INTEGRITY_ROUTING.md)
