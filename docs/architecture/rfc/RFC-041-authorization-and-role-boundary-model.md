# RFC-041 Authorization And Role-Boundary Model

Status: proposed
Source record: `docs/adr/041-authorization-and-role-boundary-model.md`

## Intent

Define explicit role scopes across platform-admin, tenant-admin, staff, and learner boundaries.

## Why This Is Still An RFC

Authorization should likely become a living constitution topic, but it is still best treated as active architecture work until the boundary model is fully settled.

## Candidate Invariants

- No tenant role implicitly escalates to platform-admin.
- Cross-tenant admin actions are auditable.
- Role boundaries are explicit and reviewable.
