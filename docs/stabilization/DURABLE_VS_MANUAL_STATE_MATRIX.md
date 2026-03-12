# Durable vs Manual State Matrix

> Anti-false-closure reference for what kinds of evidence actually close a claim.

## Matrix

| State surface | What it can prove | Default class | Closure notes |
|---|---|---|---|
| Git truth | Repo contracts, docs, scripts, manifests, tracked evidence | `DURABLE` | Required for durable repo-side closure. |
| Image truth | Immutable image tags/digests and their provenance | `DURABLE` | Must be pinned; aliases are convenience only. |
| GitOps truth | Declared desired state in tracked manifests | `DURABLE` | Proves intent, not live uptake by itself. |
| Live runtime truth | What the running system currently does | `MANUAL_STATE` unless durably captured | Can confirm or contradict repo truth; does not replace durable evidence by itself. |
| Browser proof | User-visible success or failure on real rendered paths | `MANUAL_STATE` unless durably captured | Outranks curl for user-visible success, but still needs tracked evidence for closure. |
| Manual runtime state | Operator changes, hot-patches, ad hoc fixes | `MANUAL_STATE` | Must never be summarized as durable closure. |
| Infra mutation | Cluster, GitOps, or platform changes outside this repo | `TEMPORARY_RUNTIME_MITIGATION` unless codified durably | May unblock runtime, but not repo semantic closure on its own. |

## Hard Rules

- pod-local hot-patch != closure
- DB write != architecture closure
- admin merge != semantic proof
- browser proof outranks curl for user-visible success
- contradictory proof must remain open, not summarized away

## Interpretation Rules

### Git truth

Git truth is the baseline for durable repo closure. If a claim is not present in tracked repo
artifacts, it is not durable program truth.

### Image truth

Image truth requires immutable tags or digests. `latest` or other floating aliases are not
authoritative and cannot close release questions.

### GitOps truth

GitOps truth proves intended desired state. It does not prove the live system actually consumed
that state unless corresponding live/runtime evidence is durably captured.

### Live runtime truth

Live runtime observations can overturn optimistic repo assumptions. If live behavior contradicts
repo truth, the result is `CONTRADICTED`, not closure.

### Browser proof

For user-visible paths, browser proof outranks curl or low-level HTTP success. A path that curls
successfully but still fails in the browser remains open.

### Manual runtime state

Manual changes are valid observations but not durable closure. They must either be codified into
tracked truth or kept explicitly open as non-durable mitigation.

### Infra mutation

Infra mutation can be necessary, but it is not allowed to masquerade as app or release closure
without corresponding durable repo and evidence updates.
