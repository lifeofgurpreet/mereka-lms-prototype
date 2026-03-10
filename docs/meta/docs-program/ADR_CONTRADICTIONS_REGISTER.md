# ADR Contradictions Register (v2 Overlay)

_Last updated: 2026-03-07_

## Active Contradictions

1. ADR-003 vs ADR-023/ADR-026
- Conflict: pipeline narrative references Artifact Registry while active direction is GHCR-driven release flow.
- Action: align ADR-003 wording to GHCR control-plane contract in ADR-028.

2. ADR-019 vs ADR-021
- Conflict: tutor version source of truth split between `requirements-tutor.txt` and workflow pinning.
- Action: define single canonical pin policy under ADR-028 and amend both ADRs.

3. ADR-002 vs ADR-005/ADR-022
- Conflict: cookie and domain assumptions are inconsistent with multi-root-domain federation reality.
- Action: resolve through ADR-029 and amend affected ADRs.

4. ADR-017 internal decision-state contradiction
- Conflict: decision says proceed with Aspects while rationale/actions defer deployment.
- Action: split migration timing from decision policy and normalize status.

5. ADR-024 datastore and commerce language drift
- Conflict: tenant/data/commercial references conflict with current infra direction and purchase-gateway migration.
- Action: tighten tenant lifecycle in ADR-033 and update ADR-024 references.

6. ADR README drift
- Conflict: hand-maintained index has stale status coverage.
- Action: generate index from manifest and stop manual truth maintenance.

## Exception ADR Conversion Queue

- ADR-013 -> exception lifecycle metadata applied; enforce expiry checks.
- ADR-022 -> exception lifecycle metadata applied; enforce expiry checks.
