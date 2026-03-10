---
title: Data Governance
owner: Platform Security
status: canonical
last_reviewed: 2026-03-09
canonical_root: docs/concepts/architecture
doc_class: architecture-standard
audience:
  - Engineering Team
summary: Defines governance rules for data classification, retention, deletion, and handling across the platform.
tags:
  - architecture
  - data.pii
  - data.retention
governs:
  - data.pii
  - data.retention
  - data.deletion
---
# Data Governance

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
