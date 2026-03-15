# Pre-Audit Readiness Decision

Date: 2026-03-15T10:52Z
Verdict: **READY_WITH_KNOWN_REDS**

## Proven Working Surfaces

| Surface | Status | Evidence |
|---------|--------|----------|
| `/authn/login` | PROVEN_WORKING | HTTP 200, login form renders, login completes |
| Learner course home | PROVEN_WORKING | 2 clean browser sessions, course tour shown |
| `/authoring/home` (Studio) | WORKING (runtime-patched) | 109 courses, authenticated admin, API 200 |
| `/courses` (catalog) | PROVEN_WORKING | 109 courses via API |
| Course-reindex CronJob | LIVE_AND_GOVERNED | Running on 6h schedule |
| CI main branch | GREEN | Static Validation + all 5 jobs pass |

## Runtime-Patched vs Governed Truth

Both LMS and CMS use patched ConfigMaps (`openedx-settings-lms-patched`,
`openedx-settings-cms-patched`), not the Argo-governed rendered ones.
This is the source of all durability caveats below.

| Fix | Live | App Repo | Infra Vendored |
|-----|------|----------|----------------|
| Enterprise catalog internal URL | Patched CM | PR #924 merged | NOT synced |
| CMS JWT public key derivation | Patched CM | PR #926 open | NOT synced |
| LMS JWT public key derivation | Patched CM | PR #926 open | NOT synced |
| MFE authn parse fix | New image | Merged | Promoted |
| Course-reindex CronJob | Deployed | Merged | N/A |

## Known Reds

1. **Patched ConfigMaps** — LMS/CMS settings run from manually
   patched ConfigMaps, not from the Argo-governed kustomize render.
   A full Argo sync without the patches would regress the JWT fix.
2. **PR #926 not merged** — JWT key derivation fix is live but not
   in the repo. Needs merge + vendor-sync to be durable.
3. **Enterprise catalog URL not vendor-synced** — Fix in app repo
   (PR #924) but not propagated to `bbi-infrastructure` vendored copy.
4. **Studio URL config mismatch** — MFE config advertises
   `/course-authoring` but MFE builds with basename `/authoring`.
   Studio works at `/authoring/home` only.
5. **Argo OutOfSync** — expected with patched ConfigMaps.

## Audit Contamination Assessment

None of the known reds will produce false "broken" findings in the
audit. All critical surfaces work on the live cluster. The audit
tests live behavior, and the live cluster is functional.

## Decision

The audit should start now. Known reds are governance/durability
items, not product failures. They should be documented as post-audit
follow-up work, not blockers.
