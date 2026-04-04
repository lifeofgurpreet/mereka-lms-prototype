---
name: docs-governance
description: Enforce documentation authority, supersession, and deprecation discipline. Use when creating, moving, or classifying docs in Mereka LMS. Prevents doc sprawl and conflicting authority claims.
---

# Documentation Governance

## Doc Separation Rule

| Location | Contains | Lifespan |
|---|---|---|
| `docs/architecture/` | Stable system model | Long-lived canonical |
| `docs/status/active/` | Current operational state | Short-lived status-only |
| `docs/reference/contracts/` | Verifier, identity, deprecation contracts | Long-lived canonical |
| `docs/reference/operations/` | Detailed operating procedures | Long-lived reference |
| `docs/ops/runbooks/` | Deterministic operator procedures | Long-lived reference |
| `docs/ops/playbooks/` | Surface-specific change playbooks | Long-lived reference |
| `docs/adr/` | Decision records | Permanent |
| `specs/` | Machine-checkable intended behavior | Long-lived |

## Classification Labels

- **canonical**: current authority owner
- **detailed-reference**: useful detail, not authority owner
- **status-only**: operational snapshot, not stable model
- **superseded**: replaced by canonical successor
- **deprecated in source truth**: explicitly marked deprecated by source authority

## Rules

1. **Never duplicate architecture in status docs.** Link instead.
2. **Status-only docs must never claim canonical status** in their header.
3. **Superseded docs must have a redirect banner** pointing to their successor.
4. **No `/home/gurpreet/` absolute paths** in active docs. Use relative paths or `$(git rev-parse --show-toplevel)`.
5. **New canonical content goes in `docs/architecture/`** (stable model) or `docs/reference/contracts/`** (contracts), not both.
6. **Deprecation uses evidence-backed labels only**, not speculative waves or dates.

## When Creating a New Doc

1. Determine classification (canonical, reference, status-only)
2. Place in correct root per table above
3. Add status header: `_Status: canonical_` or `_Status: status-only_`
4. Check DEPRECATION_LEDGER.md for overlap with existing docs
5. If replacing an existing doc, add supersession banner to the old doc
6. Update `docs/reference/governance/DEPRECATION_LEDGER.md` canonical/superseded map

## When a Doc Overlaps Another

1. Determine which is authority owner (canonical)
2. Add redirect banner to the non-canonical doc
3. Update DEPRECATION_LEDGER.md
4. Do NOT delete the old doc until all references are cleared

## CI Enforcement

`scripts/qa/verify-docs-authority-invariants.sh` enforces:
- AGENTS.md pointer integrity
- Supersession banners on non-canonical architecture docs
- No hardcoded user paths in active docs
- No forbidden authority claims in contract docs
- Required canonical doc existence

## Never Do

- Create canonical content under `docs/concepts/` (that root is detailed-reference)
- Claim canonical status in status-only docs
- Remove a superseded doc without checking all inbound links
- Use speculative deprecation dates without source evidence

## References

- [DEPRECATION_LEDGER.md](docs/reference/governance/DEPRECATION_LEDGER.md)
- [DOCUMENTATION_AUTHORITY_RESOLVER.md](docs/concepts/architecture/DOCUMENTATION_AUTHORITY_RESOLVER.md)
