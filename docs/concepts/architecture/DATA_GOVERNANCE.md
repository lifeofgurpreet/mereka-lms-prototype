# Data Governance
_Audience: Engineering Team • Owner: Platform Security • Last verified: 2026-03-09 • Status: canonical_

## Governs

- data.pii
- data.retention
- data.deletion

## Non-goals

- analytics product questions
- content strategy

## Standard

- PII-bearing flows must define retention, redaction, and deletion boundaries.
- Evidence must not carry live secret, token, or cookie material.
- Deletion promises must map to actual operational procedures.

## Fitness Functions

- `scripts/qa/verify-evidence-redaction.sh`
- `scripts/qa/scan-secrets-fast.sh`

## Source ADRs

- `ADR-032`
