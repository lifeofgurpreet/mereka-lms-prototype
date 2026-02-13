# Spec → Test Plan

> Convert an approved spec into a comprehensive test plan with testmap YAML.

## Input

An approved spec file from `specs/<name>_spec.md` with acceptance criteria.

## Output

1. **Test plan document** (`specs/plans/<name>_testplan.md`)
2. **Testmap YAML** (`specs/testmaps/<name>.testmap.yml`)

## Test Method Selection

| AC characteristic | Test method | Priority |
|-------------------|-------------|----------|
| File/config existence check | static | P0 |
| API response format | contract | P0 |
| Business logic correctness | unit | P0 |
| Cross-service interaction | integration | P1 |
| User workflow end-to-end | e2e | P1 |
| Performance threshold | load | P2 |
| Failure recovery | resilience | P1 |
| Alert fires correctly | monitoring | P2 |
| Visual appearance | visual-regression | P3 |
| Requires human judgment | manual | P3 |

## Testmap YAML Format

```yaml
# specs/testmaps/<name>.testmap.yml
spec: "<name>_spec.md"
version: "1.0.0"
last_updated: "YYYY-MM-DD"

acceptance_criteria:
  AC-PREFIX-001:
    description: "Brief AC description"
    method: unit          # unit|integration|e2e|static|contract|monitoring|manual
    automation: automated # automated|semi-automated|manual
    test_file: "tests/test_<module>.py::test_ac_001"
    priority: P0
    covers_spec_section: "Requirements > Functional"

  AC-PREFIX-002:
    description: "Brief AC description"
    method: integration
    automation: automated
    test_file: "tests/integration/test_<service>.py::test_ac_002"
    priority: P1

coverage:
  total_acs: N
  automated: M
  manual: K
  coverage_percent: (M/N * 100)
```

## Test Plan Structure

```markdown
# <Spec Name> Test Plan

## Test Strategy
- Approach and tooling decisions

## Test Matrix
| AC ID | Description | Method | Priority | Automation |
|-------|-------------|--------|----------|------------|

## Unit Tests
- Scenario list with expected inputs/outputs

## Integration Tests
- Cross-service scenarios

## E2E Tests
- User workflow scenarios

## Manual Verification
- Human-judgment checks

## Monitoring Verification
- Alert and metric checks
```

## Annotation Convention

Test files MUST include spec annotations:
```python
# @spec: <name>_spec.md
# @covers AC-PREFIX-001, AC-PREFIX-002

def test_ac_001_description():
    """AC-PREFIX-001: Given X, when Y, then Z."""
    ...
```

## Quality Rules

- Every AC MUST appear in the testmap
- Every AC MUST have a defined test method
- P0 ACs MUST be automated
- P1 ACs SHOULD be automated
- Test files MUST include `@covers` annotations
- Testmap `coverage_percent` MUST be calculated correctly
