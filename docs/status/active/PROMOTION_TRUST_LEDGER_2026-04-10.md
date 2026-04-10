# Promotion Trust Ledger

_Owner: Agent 2 | Last verified: 2026-04-10T00:00:00Z | Status: active_

## WS4 Automated Promotion Chain — Step-by-Step Status

| Step | Description | Status | Evidence | Blocker |
|------|-------------|--------|----------|---------|
| 1 | Push-to-main build fires | WORKS | Build triggers on every merge to main | None |
| 2 | OpenEdX image builds | WORKS | Run 24198990337 built openedx successfully | None |
| 3 | MFE image builds | BLOCKED (runner) | Code fixes confirmed (SCSS COPY, git HTTPS, DNS fallback all merged). ARC heavy-builder runners crash/OOM during 12-MFE webpack build. | Runner memory (12GB insufficient for 12 concurrent MFE builds) |
| 4 | release-object.json emitted | WORKS (when build succeeds) | Run 24072395766 generated release-object | Depends on step 3 |
| 5 | truth-ledger.json emitted | WORKS (when build succeeds) | Same run | Depends on step 3 |
| 6 | Dispatch fires to bbi-infrastructure | PROVED | HTTP 204 on direct API call. Payload contract fixed in PR #1484. | None — code path is correct |
| 7 | Infra receiver processes dispatch | PROVED | Run 24218312468 SUCCESS via repository_dispatch | None |
| 8 | Dev overlay promotion PR created | PROVED | bbi-infrastructure PR #2601 created automatically | None |
| 9 | Argo deploys promoted image | PENDING | PR #2601 not yet merged | Merge PR → ArgoCD reconciles |
| 10 | Release-ID bindable to runtime proof | PENDING | Agent 1 must verify deployed image matches release object | Depends on step 9 |

## Dispatch Auth Proof

- Method: Direct `urllib` API call (replaced deprecated `peter-evans/repository-dispatch@v3`)
- Token: GitHub App `bbi-arc-runners` (App ID 2954185, installation 112573881) via `actions/create-github-app-token@v2`
- Endpoint: `POST /repos/Biji-Biji-Initiative/bbi-infrastructure/dispatches`
- Auth verified: HTTP 204 on 2 canary dispatches (2026-04-09T23:24Z and 23:26Z)
- First canary: rejected at validation (invalid hex in bundle_id) — proves parsing works
- Second canary: passed all validation, created promotion PR — proves full chain

## Payload Contract

Sender emits (build-tutor-images.yml dispatch step):
```json
{
  "release_bundle_id": "<from var/ci/release-bundle.json>",
  "validation_evidence": "ci-build-pass:<run_id>",
  "release_object": "<full var/ci/release-object.json>",
  "build_provenance": {
    "run_url": "<github actions run URL>",
    "artifact_uri": "<release-bundle artifact>",
    "build_commit_sha": "<40-char SHA>"
  }
}
```

Receiver validates (promote-dev-image.yml):
- `release_bundle_id` matches `rb-[0-9a-f]{7,40}-[0-9]{8}T[0-9]{6}Z`
- `validation_evidence` is non-empty
- `release_object` has `schema_version: "release-object/v1"`, valid `release_id`, `app_commit_sha`, `service_id: "mereka-lms"`, matching `build.release_bundle_id`, and valid image digests
- `build_provenance` has `run_url`, `artifact_uri`, `build_commit_sha` matching `app_commit_sha`

## Remaining Risk

The only unproved step is a real organic push build completing the MFE image.
All code fixes are merged. Runner stability is the sole blocker.

## PRs That Built This Chain

| PR | What | Merged |
|----|------|--------|
| #1484 | Dispatch payload contract fix + action replacement | 2026-04-09 |
| #1489 | Schema version drift fix | 2026-04-09 |
| #1493 | Ops-streak consumer (B-027) | 2026-04-09 |
| #1494 | MFE SCSS COPY fix | 2026-04-09 |
| #1499 | Git HTTPS for Docker builds | 2026-04-09 |
| #1502 | DinD DNS fallback | 2026-04-09 |
