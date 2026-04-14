# Spec Coverage
_Audience: Operators and implementers • Owner: Platform Team • Last verified: 2026-04-14 • Status: canonical_

## What spec coverage means in this repo

Every spec file in `specs/` encodes machine-checkable intent as *acceptance criteria* (ACs).
An AC is considered **covered** when at least one of the following is true:

| Evidence type | Where stored |
|---|---|
| A generated `testmap.yml` entry with a `file:` path or `type: automated` | `specs/_generated/testmaps/<spec>.testmap.yml` |
| A reference to the spec basename in `tests/` | `tests/` |
| An entry in `specs/plans/manual_verifications.yaml` | `specs/plans/manual_verifications.yaml` |

**Coverage percentage** = (ACs with at least one evidence entry / total ACs in spec) × 100.

The floor is a gate, not a vanity metric. An AC with no test reference is
unverified intent.

## How the script works

`scripts/qa/verify-spec-coverage.sh` runs these steps:

1. **Discover spec files** — finds all `*_spec.md` and other Markdown files directly under
   `specs/`, skipping the template and index files.
2. **Count ACs per spec** — applies heuristics in priority order:
   - Checkbox lines (`- [ ]` / `- [x]`)
   - Lines explicitly labelled `AC-…` at the start
   - Lines containing `MUST` or `SHALL` as whole words
3. **Count covered ACs per spec**:
   - If `specs/_generated/testmaps/<spec>.testmap.yml` exists, a Python snippet counts AC
     blocks that contain either `type: automated` or a `file:` reference.
   - Otherwise, a grep over `tests/` and `specs/plans/manual_verifications.yaml`
     checks whether the spec is referenced at all.
4. **Print a summary table** with per-file and overall totals.
5. **Enforce the floor** — exits 0 if `overall_pct >= SPEC_COVERAGE_FLOOR`, else exits 1.

## Running locally

```bash
# Default floor (40%)
./scripts/qa/verify-spec-coverage.sh

# Custom floor
SPEC_COVERAGE_FLOOR=60 ./scripts/qa/verify-spec-coverage.sh

# Against a non-standard repo root
REPO_ROOT=/path/to/checkout ./scripts/qa/verify-spec-coverage.sh
```

## Example output

```text
=== Spec Coverage Report ===
Repo:  /home/gurpreet/projects/k8s/mereka-lms
Floor: 40%  (override with SPEC_COVERAGE_FLOOR=N)

Spec File                                            Total ACs  Covered Coverage
-------------------------------------------------------------------------------
advanced-assessment-xqueue_spec.md                         44       44     100%
analytics-pipeline_spec.md                                  8        8     100%
auth-sso-enterprise_spec.md                                45       45     100%
branding-system_spec.md                                    13       13     100%
ci-cd-pipeline_spec.md                                     43       40      93%
data-privacy-gdpr-compliance_spec.md                       93       24      25% <FLOOR
github-actions-cost-monitoring_spec.md                     14        0       0% <FLOOR
proposals/mobile-apps-enterprise_spec.md                   37        3       8% <FLOOR
...

-------------------------------------------------------------------------------
TOTAL                                                     991      844      85%

PASS  Overall coverage 85% >= floor 40%
```

Lines marked `<FLOOR` are highlighted for remediation work. Only the overall
aggregate is enforced by the gate.

## Ratcheting the floor upward each sprint

The floor is intentionally low at 40% to let the codebase onboard without
immediately failing CI. Each sprint, raise it by 5–10 percentage points as
testmap entries are wired:

| Sprint | Recommended floor |
|--------|-------------------|
| Current baseline | 40% |
| Sprint +1 | 50% |
| Sprint +2 | 60% |
| Sprint +3 | 70% |
| Long-term target | 80% |

To raise the floor, update the `SPEC_COVERAGE_FLOOR` value in the CI workflow
or invoking target and keep this table in sync.

**Never lower the floor** to make CI green.

## Adding coverage for an uncovered AC

1. Open the relevant `specs/_generated/testmaps/<spec>.testmap.yml`.
2. Find the AC entry.
3. Add a `verify` block referencing a real test file:

```yaml
- id: AC-042
  description: "..."
  verify:
  - type: automated
    test_type: shell_verification
    file: scripts/qa/verify-my-feature.sh
    command: scripts/qa/verify-my-feature.sh
```

4. Ensure the referenced file exists and exits 0 on success.
5. Re-run `./scripts/qa/verify-spec-coverage.sh`.

## Integration with CI

Add the following step to any CI workflow that gates merges:

```yaml
- name: Spec coverage floor
  run: |
    SPEC_COVERAGE_FLOOR=40 ./scripts/qa/verify-spec-coverage.sh
```

The script exits 1 when coverage is below the floor, which fails the job.
