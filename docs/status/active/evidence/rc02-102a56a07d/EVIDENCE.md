# RC-02 Evidence — Artifact 102a56a07d

**Date:** 2026-04-18
**Commit SHA:** `102a56a07d3270bb61d7c95b28d6ed0d67919360`
**Build run:** [24590743862](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24590743862) (success)
**Promote run:** [24591542962](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/actions/runs/24591542962) (success)
**Promotion PR / commit:** `bbi-infrastructure#3169` / `506b9337`

## Artifacts (downloaded from build run 24590743862)

| File | Bytes | Description |
|---|---|---|
| `release-bundle.json` | 1354 | Build provenance + image digests + contract refs |
| `release-object.json` | 1958 | Canonical release-object/v1 projection |
| `release-gate-envelope.json` | 1736 | Gate identity envelope |
| `truth-ledger.json` | 3517 | Truth-ledger assertion set |
| `build-provenance.json` | 825 | SLSA-ish provenance |
| `promotion-dispatch-envelope.json` | 7538 | Dispatch envelope payload |
| `control-plane-release-bundle-projection.json` | 2938 | Control-plane projection |

Signature material (`release-bundle.sig`, `release-bundle.pem`) is available on the
upstream GitHub Actions artifact (build run `24590743862`, artifact `release-bundle`)
and is intentionally not committed here (`.pem` is globally gitignored; `.sig` without
`.pem` is unverifiable in isolation).

## Verifier Outputs

### scripts/qa/verify-release-object.sh
```
PASS: release object contract valid
Release ID: ro-rb-102a56a0-20260417T232409Z
Contract ref: Biji-Biji-Initiative/platform-control-plane@fa5065b9b083f569278ab80c67fc1dfa25c82b3c
```
EXIT: 0

### scripts/qa/verify-build-workflow-contract.sh
```
=== Results: 127 PASS / 0 FAIL ===
```
EXIT: 0

## Digest Agreement (release-bundle.json)

| Image | Digest |
|---|---|
| openedx | `sha256:d17ae77f533be1690b969b220b3507c4d9780ef7f477ecd5c47e2b7777b54578` |
| mfe | `sha256:377923c0a2ce22c8e7bac7baf488c80f345a1445e2f7ac47b5c29e5b475b35e1` |
| commit_sha | `102a56a07d3270bb61d7c95b28d6ed0d67919360` |

These digests are bit-identical in:
1. `release-bundle.json` (this packet)
2. `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml` (bbi-infrastructure@506b9337)
3. Deployment specs in `mereka-lms-dev` namespace
4. Live pod `imageID`s

## Verdict

**RC-02: CLOSED.**
Release-object contract verified against `platform-control-plane@fa5065b` schema `release-object/v1`.
Build-workflow contract: 127/127 PASS.
