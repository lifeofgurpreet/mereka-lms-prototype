# Operations Evidence Packs
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

This directory is the active evidence surface for operational proof packs. Start here when the question is “what proof do we have?” about a deployment, recovery, runtime validation, or operator-facing gate.

## Start here

| If you need to... | Read this first | Then go deeper in |
|---|---|---|
| Verify a runtime or deployment claim | The relevant proof pack in this root | [`../../status/readiness/README.md`](../../status/readiness/README.md) if you need the corresponding readiness judgment |
| Find the canonical evidence location rules | [`../INDEX.md`](../INDEX.md) | [`../../guides/standards/EVIDENCE_PACK_STANDARD.md`](../../guides/standards/EVIDENCE_PACK_STANDARD.md) |
| Understand whether something belongs in evidence or status | [`../../README.md`](../../README.md) | The relevant winning root |

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

| Pack | Use it when... |
|---|---|
| [Analytics key elimination evidence](ANALYTICS_KEY_ELIMINATION_EVIDENCE.md) | You need proof for analytics-key remediation and validation. |
| [Assessment XQueue evidence](ASSESSMENT_XQUEUE_EVIDENCE.md) | You need proof for assessment/XQueue behavior or recovery. |
| [Wave 2B-Final closeout evidence pack](2026-03-wave-2b-final-closeout/README.md) | You need the durable proof bundle for the completed documentation convergence wave. |
| [GKE workload triage evidence](GKE_WORKLOAD_TRIAGE_EVIDENCE.md) | You need workload-level triage proof from the live cluster. |
| [Kind cluster recovery evidence](KIND_CLUSTER_RECOVERY_EVIDENCE.md) | You need proof for local cluster recovery and validation. |
| [Tenant isolation evidence](TENANT_ISOLATION_EVIDENCE.md) | You need evidence for tenant-boundary and isolation claims. |
| [Token integrity routing evidence](TOKEN_INTEGRITY_ROUTING.md) | You need proof for token-integrity routing or frontend/runtime parity claims. |

## What this root is not

- Not the place for a judgment about whether something is ready. That belongs in `docs/status/readiness/**`.
- Not the place for long-term retired proof. That belongs in `docs/archive/evidence/**`.
- Not the place for rules about evidence writing. That belongs in `docs/guides/standards/EVIDENCE_PACK_STANDARD.md`.
