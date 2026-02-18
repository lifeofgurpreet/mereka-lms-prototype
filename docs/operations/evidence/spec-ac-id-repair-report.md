# Spec AC-ID Repair Evidence Report

**Bead**: 23ry.1
**Date**: 2026-02-18
**Covers**: AC-SPEC-201, AC-SPEC-202, AC-SPEC-203
**Scope**: Top-tier spec coverage audit — CI/CD, K8s deployment, analytics, ecommerce

---

## 1. Coverage Dashboard Output

Run with: `python3 scripts/qa/spec-tools/spec_coverage_dashboard.py --testmaps-dir specs/testmaps --specs-dir specs`

```
=== Spec Coverage Dashboard ===
38 specs | 976 ACs | 771 automated | 17 manual | 0 monitoring | 188 unmapped

Overall coverage: 80.7%

Tier | Spec                                    | ACs | Auto | Man | Mon | Unmapped | Coverage
-----|----------------------------------------|-----|------|-----|-----|----------|----------
   3 | analytics-pipeline                     |   8 |    8 |   0 |   0 |        0 |   100.0%
   2 | auth-sso-enterprise                    |  45 |   45 |   0 |   0 |        0 |   100.0%
   3 | branding-system                        |  13 |   13 |   0 |   0 |        0 |   100.0%
   3 | content-libraries-v2                   |  33 |   33 |   0 |   0 |        0 |   100.0%
   0 | cross-cutting-requirements             |  12 |   12 |   0 |   0 |        0 |   100.0%
   3 | data-migrations-kajabi-mct             |  44 |   41 |   3 |   0 |        0 |   100.0%
   1 | design-tokens-system                   |  12 |   12 |   0 |   0 |        0 |   100.0%
   3 | external-registration-hubspot          |  26 |   26 |   0 |   0 |        0 |   100.0%
   3 | mobile-apps-secrets-management         |  25 |   25 |   0 |   0 |        0 |   100.0%
   3 | mongodb-atlas-integration              |   9 |    9 |   0 |   0 |        0 |   100.0%
   3 | multi-site-domains                     |   9 |    9 |   0 |   0 |        0 |   100.0%
   7 | multi-tenancy-architecture             |  33 |   33 |   0 |   0 |        0 |   100.0%
   3 | observability-stack                    |  16 |   16 |   0 |   0 |        0 |   100.0%
   4 | observability-validation-requirements  |  31 |   31 |   0 |   0 |        0 |   100.0%
   3 | platform-middleware-custom-apps        |  20 |   20 |   0 |   0 |        0 |   100.0%
   3 | proctoring-integration                 |  38 |   31 |   7 |   0 |        0 |   100.0%
   0 | repository-structure                   |  12 |   12 |   0 |   0 |        0 |   100.0%
   1 | secrets-management                     |  18 |   18 |   0 |   0 |        0 |   100.0%
   1 | slo-sla-service-level-management       |  53 |   49 |   4 |   0 |        0 |   100.0%
   2 | tutor-configuration-resilience         |  12 |   12 |   0 |   0 |        0 |   100.0%
   1 | tutor-configuration                    |  10 |   10 |   0 |   0 |        0 |   100.0%
   2 | verifiable-credentials-issuance        |   8 |    8 |   0 |   0 |        0 |   100.0%
   2 | verifiable-credentials-issuer          |   6 |    6 |   0 |   0 |        0 |   100.0%
   4 | verifiable-credentials-ops             |   9 |    9 |   0 |   0 |        0 |   100.0%
   2 | verifiable-credentials-types           |   8 |    8 |   0 |   0 |        0 |   100.0%
   3 | verifiable-credentials-verification    |   8 |    8 |   0 |   0 |        0 |   100.0%
   3 | video-pipeline-delivery                |  38 |   37 |   0 |   0 |        1 |    97.4%
   4 | enterprise-microservices               |  37 |   36 |   0 |   0 |        1 |    97.3%
   4 | ecommerce-purchase-gateway             |  34 |   33 |   0 |   0 |        1 |    97.1%
   3 | disaster-recovery-business-continuity  |  26 |   23 |   0 |   0 |        3 |    88.5%
   3 | forum-service-migration                |  25 |   22 |   0 |   0 |        3 |    88.0%
   3 | k8s-deployment                         |  37 |   32 |   0 |   0 |        5 |    86.5%
   3 | ci-cd-pipeline                         |  43 |   37 |   0 |   0 |        6 |    86.0%
   4 | email-notifications-pipeline           |  45 |   18 |   0 |   0 |       27 |    40.0%
   8 | data-privacy-gdpr-compliance           |  92 |   24 |   0 |   0 |       68 |    26.1%
   3 | advanced-assessment-xqueue             |  44 |    5 |   0 |   0 |       39 |    11.4%
   3 | mobile-apps-enterprise                 |  37 |    0 |   3 |   0 |       34 |     8.1%
   1 | github-actions-cost-monitoring         |   0 |    0 |   0 |   0 |        0 |     0.0%

Coverage tiers:
  GREEN  (>=80%): 33 specs
  YELLOW (50-79%): 0 specs
  RED    (<50%): 5 specs
```

---

## 2. Target Spec AC ID Counts (AC-SPEC-201)

| Spec | Total ACs | Checkbox Format (`- [ ] AC-`) | Lint (error) |
|------|-----------|-------------------------------|--------------|
| ci-cd-pipeline_spec.md | 43 | 43 | PASS |
| k8s-deployment_spec.md | 37 | 37 | PASS |
| ecommerce-purchase-gateway_spec.md | 34 | 34 | PASS |
| analytics-pipeline_spec.md | 8 | 8 | PASS |

All four top-tier specs pass lint at error severity and meet minimum AC ID thresholds.

---

## 3. Residual Unmapped ACs by Spec (AC-SPEC-203)

### ci-cd-pipeline_spec.md — 6 unmapped (86.0% coverage)

These ACs use a non-standard prefix (`AC-INT-*`) or are unmapped due to missing `@covers` annotations in verification scripts:

| AC ID | Description (summary) | Gap Reason |
|-------|----------------------|------------|
| AC-INT-001 | K8s manifest validation → Artifact Registry push integration | Cross-spec integration AC; no dedicated verify script |
| AC-INT-002 | ExternalSecrets reach SecretSynced before deployment success | Cross-spec integration AC; no dedicated verify script |
| AC-INT-003 | Infisical secret validation fails build on missing keys | Cross-spec integration AC; no dedicated verify script |
| AC-INT-004 | Branding preflight passes during openedx image build | Cross-spec integration AC; no dedicated verify script |
| AC-003 | Python ruff lint violations fail the job | Covered implicitly by `make lint`; no `@covers` annotation |
| AC-004 | YAML K8s manifest validation via kubeconform | Covered by kubeconform CI job; no `@covers` annotation in verify script |

### k8s-deployment_spec.md — 5 unmapped (86.5% coverage)

| AC ID | Description (summary) | Gap Reason |
|-------|----------------------|------------|
| AC-INT-001 | All pods reach Running with secrets from ExternalSecrets | Requires live cluster; no verify script with `@covers` |
| AC-INT-002 | OPENEDX_SECRET_KEY is non-empty via kubectl exec | Requires live cluster exec; not in any verify script |
| AC-INT-003 | Rotated secret propagates within 1h without manual edit | Operational/time-based; cannot be statically verified |
| AC-INT-004 | MySQL native password flag in LMS connection (from tutor patches) | Cross-spec AC; covered partially by tutor-config verify |
| AC-INT-005 | ALLOWED_HOSTS contains all three multi-site domains | Cross-spec AC; no dedicated `@covers` annotation |

### ecommerce-purchase-gateway_spec.md — 1 unmapped (97.1% coverage)

| AC ID | Description (summary) | Gap Reason |
|-------|----------------------|------------|
| AC-034 | Service domain MUST use DNS-only Cloudflare + Let's Encrypt SSL | Cross-cutting infrastructure AC; covered by global rule, no service-specific verify step |

### analytics-pipeline_spec.md — 0 unmapped (100.0% coverage)

No gaps. All 8 ACs are mapped to verification scripts.

---

## 4. Domain Ownership Map

| Spec | Domain | Owning Team |
|------|--------|-------------|
| ci-cd-pipeline | Platform Engineering | DevOps / SRE |
| k8s-deployment | Infrastructure | DevOps / SRE |
| ecommerce-purchase-gateway | Commerce | Backend Engineering |
| analytics-pipeline | Data | Data Engineering |

---

## 5. Before / After Comparison

This bead is documentation-only (no spec files modified). The coverage numbers reflect the current state of the codebase as-is.

| Metric | Value |
|--------|-------|
| Overall coverage | 80.7% |
| Specs at 100% | 26 of 38 |
| Specs in GREEN (>=80%) | 33 of 38 |
| Specs in RED (<50%) | 5 (email-pipeline, gdpr, xqueue, mobile-enterprise, github-cost) |
| Top-tier specs below 100% | ci-cd (86%), k8s (87%), ecommerce (97%) |
| Total unmapped ACs | 188 |

The 12 unmapped ACs across the four target specs are all either:
- Cross-spec integration ACs (`AC-INT-*`) requiring live cluster or CI runner
- ACs covered implicitly by CI jobs but lacking `@covers` annotations in scripts

No spec-level structural issues were found. All four target specs pass lint at error severity.

---

## 6. Spec Tool Output Evidence

### mereka_spec_lint.py results (error severity)

```
PASS specs/ci-cd-pipeline_spec.md
PASS specs/k8s-deployment_spec.md
PASS specs/ecommerce-purchase-gateway_spec.md
PASS specs/analytics-pipeline_spec.md
```

### spec_coverage_dashboard.py summary

```
Overall coverage: 80.7%
GREEN (>=80%): 33 specs
YELLOW (50-79%): 0 specs
RED (<50%): 5 specs
```
