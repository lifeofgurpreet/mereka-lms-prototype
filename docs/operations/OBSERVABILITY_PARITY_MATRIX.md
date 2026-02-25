# Observability Parity Matrix (Mereka LMS)

Date: 2026-02-25

## Metadata

- last_updated: 2026-02-25
- owner: Mereka LMS platform team
- canonical_runtime_gate: `scripts/qa/run-observability-first-class.sh`
- canonical_workflow: `.github/workflows/observability-compliance.yml`

## Purpose

Define required observability parity across environments so runtime checks are deterministic and evidence artifacts are comparable.

## Canonical Runtime Identity Contract

`evidence_identity` must follow:

`env=<label>;profile=<dispatch_profile>;context=<k8s_context>;project=<gcp_project>`

## Environment Matrix

| Environment | Canonical command | Required identity labels | Required runtime dependencies | Required evidence artifacts |
|---|---|---|---|---|
| `dev` | `OBSERVABILITY_ENV_LABEL=dev OBSERVABILITY_DISPATCH_PROFILE=nonprod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_DEV_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict` | `env=dev`, `profile=nonprod` | `OBS_PARITY_DEV_K8S_CONTEXT` + kubectl context + gcloud auth | `observability-compliance-runtime.json`, `observability-runtime-verify-runtime.md`, `observability-first-class-runtime-evidence-index.json` |
| `nonprod` | `OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_NONPROD_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict` | `env=nonprod`, `profile=nonprod` | `OBS_PARITY_NONPROD_K8S_CONTEXT` + kubectl context + gcloud auth | `observability-compliance-runtime.json`, `observability-runtime-verify-runtime.md`, `observability-first-class-runtime-evidence-index.json` |
| `prod` | `OBSERVABILITY_ENV_LABEL=prod OBSERVABILITY_DISPATCH_PROFILE=prod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_PROD_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict` | `env=prod`, `profile=prod` | `OBS_PARITY_PROD_K8S_CONTEXT` + kubeconfig current-context match + kubectl context + gcloud auth | `observability-compliance-runtime.json`, `observability-runtime-verify-runtime.md`, `observability-first-class-runtime-evidence-index.json` |

## Baseline Coverage Requirements (All Environments)

1. Runtime observability compliance script emits valid JSON.
2. LMS and CMS `/metrics` return `HTTP 200`.
3. ServiceMonitor/PrometheusRule runtime objects are queryable.
4. High-severity alert policies/channels remain enabled.
5. Evidence identity is internally consistent across:
   - preflight (if present)
   - compliance markdown/json
   - runtime verifier markdown
   - evidence index

## Allowed Temporary Differences

Allowed only when explicitly documented in release notes/runbooks:

1. Infrastructure constraints may limit dedicated staging cluster availability.
2. Some synthetic checks can be prod-only while dev/nonprod are being hardened.
3. Dashboard panel depth may differ temporarily if service rollout is incomplete.

Any temporary difference must include:
1. reason
2. owner
3. target resolution date

## Parity Verification Procedure

Run for each environment:

```bash
OBSERVABILITY_ENV_LABEL=<dev|nonprod|prod> \
OBSERVABILITY_DISPATCH_PROFILE=<nonprod|prod> \
OBSERVABILITY_K8S_CONTEXT=<context> \
OBSERVABILITY_GCP_PROJECT=<project> \
./scripts/qa/run-observability-first-class.sh --mode runtime --strict
```

Verify:
1. runtime command exits zero.
2. evidence files are generated.
3. `identity` in evidence index matches markdown `evidence_identity`.
4. profile/label values match this matrix.
5. for prod, the target context is active as the kubeconfig current context.

## Current Gap Tracking Template

Use this template when a parity gap is found:

```text
Environment: <dev|nonprod|prod>
Gap: <what is missing or inconsistent>
Impact: <operator blind spot or false signal>
Owner: <team/person>
Target fix date: <YYYY-MM-DD>
Evidence: <artifact path or workflow link>
```
