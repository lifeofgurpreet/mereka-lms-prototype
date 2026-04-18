# OG-03 Audit — `promote-dev-image.yml` Recent Failure Cluster

**Date:** 2026-04-18
**Workflow:** `Biji-Biji-Initiative/bbi-infrastructure/.github/workflows/promote-dev-image.yml`
**Sample:** last 20 runs on `main` (2026-04-10 → 2026-04-17)

## Headline

9 successes / 11 failures in last 20 runs = **45% success rate**.

## Failure Table

| Run | Timestamp | Short SHA | Failed step | Class | Root Cause Evidence |
|---|---|---|---|---|---|
| 24541644435 | 2026-04-17T00:41 | 74168e2e | Create promotion PR | empty-log (class D) | logs empty via `--log-failed`; needs deep job-step log fetch |
| 24540832207 | 2026-04-17T00:14 | 8643c87a | Create promotion PR | empty-log (class D) | same as above |
| 24480350838 | 2026-04-15T21:53 | b8b0faa2 | Dispatch required PR validations | **auth-403 (class B)** | `curl: (22) The requested URL returned error: 403` dispatching `policy-guards.yml` |
| 24437205954 | 2026-04-15T04:57 | d9828183 | Dispatch required PR validations | **transient-panic (class C)** | `panic: runtime error: invalid memory address or nil pointer dereference` — binary tool crash |
| 24428546215 | 2026-04-14T23:43 | 576b2d33 | Validate emitted objects | **control-plane-fetch (class A.1)** | `Failed to fetch ... from CONTROL_PLANE_REPO HTTP {status}` — intermittent network/ratelimit |
| 24422640222 | 2026-04-14T20:59 | 4c3325a9 | Validate emitted objects | **schema-validation (class A.2)** | `FAIL: release_object_projection validation` |
| 24419163558 | 2026-04-14T19:39 | 4124a4d2 | Validate emitted objects | empty-log (class D) | logs empty |
| 24403124280 | 2026-04-14T13:57 | 1392e857 | multiple | cascade | dispatch+evidence+validate all failed |
| 24389934670 | 2026-04-14T08:51 | 413b049d | Validate emitted objects | **schema-field-missing (class A.2)** | `release_object_projection missing canonical identity field 'lane'` |
| 24389488823 | 2026-04-14T08:40 | 413b049d | Generate evidence pack record + Validate emitted | **evidence-pack-missing (class A.3)** | `structured evidence is required for non-dry-run promotions` + `promotion_record validation` fail |
| 24253492957 | 2026-04-10T16:38 | e1d3cd8a | multiple | cascade | dispatch+evidence+validate all failed |

## Failure Class Summary

| Class | Count | Description | Fix Effort |
|---|---|---|---|
| A.1 control-plane fetch | 1 | Transient HTTP to control-plane repo (rate limit or network) | Low — add retry-with-backoff |
| A.2 schema validation / field-missing | 3 | Release-object payload missing required field added to control-plane schema | **Medium — coordination fix; producer (mereka-lms) must add field before consumer (bbi-infra promote) expects it. Appears to self-correct over time.** |
| A.3 evidence-pack missing | 1 | Evidence pack requires fields that aren't in the release bundle | Medium — either relax contract or update producer |
| B auth-dispatch-403 | 1 | GitHub App lacks `actions:write` to dispatch `policy-guards.yml` | **Low — permission fix on the GitHub App installation** |
| C transient-panic | 1 | Binary tool nil-pointer crash in dispatch step | Medium — identify tool, upgrade/fix |
| D empty-log (needs investigation) | 3 | `gh run view --log-failed` returns empty; likely the `Create promotion PR` step logs are trimmed | Low — either upload-artifact of logs, or use step-level API to retrieve |
| cascade | 2 | Multiple steps failed in same run, root cause = earliest failure | — |

## Recommendations (Ranked by Impact)

1. **Fix the GitHub App permission** (1 failure × high recurrence risk). The
   dispatch step uses a workflow-dispatch call. If the App lacks `actions:write`
   on the target repo, every dispatch will 403. This is a one-time config change
   in the App's installation settings. Highest ROI.

2. **Investigate the "Create promotion PR" empty-log failures** (3 failures ×
   real impact). Could be `pull_requests:write` permission on the App, or a
   race between the branch push and the PR-create call. Start with adding
   verbose logging and retry logic to the `Create promotion PR` step.

3. **Add retry-with-backoff to control-plane contract fetch** (1 failure ×
   medium recurrence). Any `curl --fail` against the control-plane repo should
   retry 3× with exponential backoff. Handles GitHub API throttling +
   transient network.

4. **Binary tool panic in dispatch step** (1 failure × unknown recurrence).
   Identify the tool (presumably a Go CLI used for workflow_dispatch), pin to
   a known-good version or replace with `gh api --method POST`.

5. **Schema evolution is not a pipeline defect**, it's a producer/consumer
   coordination issue. Document the convention: when the control-plane repo
   adds a required field to `release-object-projection-schema.yaml`, the
   producing repo (mereka-lms) must ship the emitter change first; otherwise
   in-flight builds fail until a new build rolls through. Not a fix target;
   a governance note.

## Non-Action Items

Do not attempt to retry/patch any of these runs — they are historical. The
current artifact (`102a56a07d`) was promoted via a GREEN run (`24591542962`),
so today's conveyor health is sound for this line. This audit is governance
input for the OG-03 hardening tranche, not an incident response.
