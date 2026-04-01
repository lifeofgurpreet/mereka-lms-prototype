# Aspects Analytics Activation Tracker

_Last updated: 2026-04-01_

## Architecture Decision

Aspects uses **Authentik-brokered OIDC** for Superset authentication, NOT the default
Aspects LMS-direct-SSO pattern. This is a custom design — LMS users authenticate
through Authentik, which brokers the OIDC flow to Superset. The standard Aspects
LMS JWT → Superset path is not used.

## Status by Environment

### Dev (academyv2.mereka.dev)

| Surface | Status | Evidence |
|---------|--------|----------|
| Pods running (4/4) | DONE | clickhouse, superset, superset-worker, ralph |
| DNS resolves | DONE | analytics.academyv2.mereka.dev |
| TLS valid | DONE | Let's Encrypt |
| OAuth redirect | DONE | 302 → auth0.mereka.dev |
| Batch sync (MySQL→CH) | DONE | CronJob daily 2 AM, enrollments/courses populated |
| xAPI pipeline (LMS→Ralph→CH) | DONE | 1+ event verified in xapi.xapi_events_all |
| Browser E2E auth | **PENDING** | Requires agent-browser or manual login test |
| LMS user role mapping | **PENDING** | Need to verify Gamma role auto-assignment |

### Staging (stg-mereka-lms)

| Surface | Status | Evidence |
|---------|--------|----------|
| Pods running (4/4) | DONE | All pods Running 7h+ |
| DNS resolves | DONE | analytics.staging.academyv2.mereka.io |
| TLS valid | DONE | Let's Encrypt, valid until 2026-06-28 |
| OAuth redirect | DONE | 302 → staging.auth0.mereka.io |
| Batch sync (MySQL→CH) | DONE | 146K+ enrollments, 109 courses |
| xAPI pipeline | **PENDING** | Not yet verified on staging |
| Browser E2E auth | **PENDING** | Requires browser test through Authentik |
| LMS user role mapping | **PENDING** | Need to verify Gamma role auto-assignment |

### Production

**DORMANT** — All replicas at 0. ADR-017 defers activation until:
1. Core platform stable 3+ consecutive months
2. Course creators request analytics features
3. Team has capacity for CH/Superset ops (3-5 hrs/month)

## Honest Assessment

### What is proven
- Transport layer: pods run, DNS resolves, TLS works, OAuth redirects correctly
- Data pipeline: batch sync populates ClickHouse, xAPI events reach Ralph
- Init codification: `scripts/aspects/bootstrap-aspects-env.sh` replaces manual steps

### What is NOT proven
- **No browser E2E**: nobody has signed into Superset as a real user through Authentik
- **No role mapping proof**: Authentik → Superset Gamma role auto-assignment untested
- **No report visibility**: no human has viewed a dashboard or report in Superset
- **Init Jobs**: ArgoCD PostSync hooks work but MySQL DB creation still requires bootstrap script

### Verification Scripts
- `scripts/aspects/bootstrap-aspects-env.sh --env dev --check` — verify env health
- `scripts/aspects/verify-aspects-auth-flow.sh --env dev` — verify OAuth flow
- `scripts/aspects/verify-aspects-data-pipeline.sh --env dev` — verify ClickHouse data
- `scripts/qa/verify-aspects-wiring.sh` — manifest structure verification

## What Closure Actually Requires

1. `bootstrap-aspects-env.sh` succeeds on a fresh namespace (init is repeatable)
2. Browser access works without `curl --resolve` (real DNS, real TLS)
3. A real LMS-linked user signs into Superset with correct role
4. At least one report/dashboard shows real enrollment or course data
