# Security Exceptions Register

> Machine-readable register of accepted security risk exceptions with expiry enforcement.
> CI script: `scripts/qa/verify-security-exceptions.sh`
> CI workflow: `.github/workflows/security-exceptions.yml`

## Register

| ID | Description | Risk Level | Justification | Owner | Accepted Date | Expiry Date | Status |
|----|-------------|------------|---------------|-------|---------------|-------------|--------|
| SEC-001 | Tutor 18.x Redwood past community support window | Medium | RESOLVED: Upgraded to Tutor 21.0.x (Ulmo) in 2026-03/04; current pin is 21.0.4. Full image rebuild and smoke-test cycle completed for the Ulmo migration. | Platform Team | 2025-12-01 | 2026-06-30 | Revoked |
| SEC-002 | MongoDB Atlas shared cluster — no dedicated customer-managed encryption key (CMEK) | Low | Atlas shared tier does not support CMEK. Data at rest is encrypted by Atlas default keys. CMEK migration is gated on cluster tier upgrade in H2 2026. | Platform Team | 2025-12-01 | 2026-12-31 | Active |
| SEC-003 | `.trivyignore` suppressed CVEs in base images | Low | A set of CVEs in upstream OS base images have no available upstream fix. Each entry was reviewed and determined unexploitable in our deployment context. Reviewed quarterly. | Platform Team | 2026-01-15 | 2026-04-30 | Active |

## Process

### Adding a new exception

1. Open a PR that adds a new row to the Register table above.
2. Required fields: all columns must be populated — no blanks.
3. Risk levels: `Critical` / `High` / `Medium` / `Low`.
4. Status values: `Active` / `Expired` / `Revoked`.
5. Expiry must not exceed 12 months from Accepted Date without explicit CISO sign-off (note in Justification).
6. PR must be approved by a second team member before merge.

### Reviewing / renewing an exception

- Before expiry: open a PR updating the Expiry Date and Justification with current review evidence.
- The CI workflow runs weekly and on every push that touches this file; expired `Active` rows will fail the build.
- If an exception no longer applies, change Status to `Revoked` and add a revocation note in Justification.

### Expiry enforcement

`scripts/qa/verify-security-exceptions.sh` parses this table and:

- **Fails (exit 1)** if any `Active` exception's Expiry Date is in the past.
- **Warns** (exit 0) if any `Active` exception expires within 30 days.

The `.github/workflows/security-exceptions.yml` workflow runs this check on:
- Every push to `main` that modifies this file.
- A weekly Monday schedule (catches drift without code changes).
- Manual `workflow_dispatch`.
