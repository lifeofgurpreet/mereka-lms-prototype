# FROZEN — Do Not Apply

> **Date**: 2026-03-31
> **Reason**: Authority migration to `platform-control-plane` (SPEC-PLATFORM-001)
> **ADR**: bbi-infrastructure ADR-021 (GKE→RKE2 prod migration)

## Status

This Terraform configuration is **frozen**. Do not run `terraform apply` from this directory.

All GCP infrastructure management is transitioning to the `platform-control-plane` repository, which is the canonical IaC authority per SPEC-PLATFORM-001.

## What This Contains

Legacy Terraform modules for:
- GKE cluster configuration
- CloudSQL instances
- Artifact Registry
- Memorystore (Redis)
- Network/VPC
- Secret Manager
- Cloud Storage
- Budget alerts

## What To Do Instead

- For GCP resource changes: use `platform-control-plane` repo
- For Kubernetes changes: use `bbi-infrastructure` repo
- For questions: see `platform-control-plane/docs/EXECUTION-ROADMAP.md`

## Migration Plan

These modules will be imported into `platform-control-plane` and this directory will be archived. See `bbi-infrastructure/docs/status/2026-03-31-AUTHORITY-BOUNDARY-CONTAINMENT-PLAN.md` Tranche 2.
