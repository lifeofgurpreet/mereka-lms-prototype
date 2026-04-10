# Duplicate Writer Retirement Register

_Owner: Agent 2 | Last verified: 2026-04-10T00:00:00Z | Status: active_

## Agent 2 Lane — Promotion / Proof / Control-Plane Duplicates

| # | Duplicate | Canonical | Shadow | Temporary? | Status | Exit Plan | Risk if Left |
|---|-----------|-----------|--------|------------|--------|-----------|--------------|
| 1 | Release-object schema version | `generate_release_object.py` → `"release-object/v1"` | `config/release-object-schema.yaml` → was `"1.0"` | Accidental | **RETIRED** (PR #1489 aligned) | Monitor for drift | Low now |
| 2 | Dispatch payload contract | `promote-dev-image.yml` receiver | `build-tutor-images.yml` sender → was flat keys | Accidental | **RETIRED** (PR #1484 aligned) | Create PCP contract for both to validate against | Low now |
| 3 | Lane normalize | PCP `lane-identity-contract.yaml` | `scripts/lib/lane-normalize.sh` + `config/lane-identity.yaml` | Accidental | NOT RETIRED | Replace bash script with PCP-generated projection | Medium — can silently diverge |
| 4 | Image tag writers (manual vs auto) | Automated dispatch → `promote-dev-image.yml` | Manual `update-gitops` job in `build-tutor-images.yml` | By design (manual bridge) | NOT RETIRED | Retire manual bridge after automated chain proven over 5+ builds | Low — manual only fires on `workflow_dispatch` with `update_gitops=true` |
| 5 | CI static inventory | `script-registry.yaml` | `.github/ci-scripts-static.txt` (derivative) | By design | CONTROLLED | Freshness gate active, auto-regen hooks (PR #1465) | Low |
| 6 | Release-object schema (PCP vs app) | PCP `release-object-authority-contract.yaml` | `config/release-object-schema.yaml` (app repo) | Accidental | PARTIALLY RETIRED | Delete app-repo schema, validate against PCP | Medium — different field structures |
| 7 | Proof gate contract | `config/proof-gate-contract.yaml` | Inline workflow steps | Accidental | NOT RETIRED | Add `@proof-gate-contract` decorator to workflow steps | Low — declarative only, no enforcement |
| 8 | Release-bundle schema version | PCP `release-bundle-schema.yaml` → `schema_version: "1.1"`, `contract_version: "1.1"` | `generate-release-bundle.sh` → was `"schema_version": "1.0.0"`, `"contract_version": "1.0"`, `"contract_family": "release-bundle"` vs PCP const `"release_bundle_schema"` | Accidental | **RETIRED** (PR #1507 aligns generator to v1.1) | Monitor for future PCP schema bumps | Low now |

## Summary

- **3 RETIRED** (schema version, dispatch payload, release-bundle schema version) — all fixed this session
- **1 CONTROLLED** (CI inventory) — has freshness gate
- **4 NOT YET RETIRED** — lane normalize, manual bridge, PCP schema authority, proof gate enforcement
- **Priority for next fix**: #6 (release-object schema authority) — move to PCP
- Next retirement target: manual GitOps bridge (#4) after automated chain proven
- Next migration target: release-object schema authority (#6) and release-bundle schema version (#8) to PCP
