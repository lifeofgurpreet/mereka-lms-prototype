# Data Sources Explained
_Audience: Platform Eng + Data • Owner: Analytics Guild • Last verified: 2026-03-10 • Status: canonical_

This reference explains the migration-era data sources used in analytics reconciliation work.

## Kajabi source

- Legacy Kajabi exports provide enrollment and certificate-adjacent data for reconciliation.
- These exports are migration inputs, not steady-state application truth.

## MCT source

- Legacy MCT material provides enrollment and course source data for migration and parity checks.
- These inputs support reference and migration verification, not current platform analytics.

## Open edX source

- Open edX course, enrollment, and completion data is the current destination-system source.
- Built-in instructor reports remain the current operational reporting path.
