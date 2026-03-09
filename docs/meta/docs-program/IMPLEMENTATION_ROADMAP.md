# Mereka LMS Implementation Roadmap

_Last updated: 2026-02-27_

**Status**: ~70% mapped as of 2026-02-12 (Sprint 1+2 complete)
**Goal**: 100% coverage across all 31 specifications

This document provides the systematic implementation order for all Mereka Academy features based on dependency analysis and current progress.

---

## Progress Overview

| Category | Count | Coverage |
|----------|-------|----------|
| **Complete** (100% mapped) | 20 specs | 438 ACs ✅ |
| **In Progress** (1-99%) | 11 specs | 331 ACs 🚧 |
| **Total** | 31 specs | 769 ACs |

**Automated**: 371 (48.2%)
**Manual**: 83
**Monitoring**: 4
**Unmapped**: 311 (features to build)

---

## Implementation Tiers

Based on `specs/plans/IMPLEMENTATION_ORDER.md` (computed from `depends_on` frontmatter):

### Tier 0: Foundation (100% ✅)
- `repository-structure_spec.md` - 12 ACs ✅
- `cross-cutting-requirements_spec.md` - 12 ACs ✅

### Tier 1: Core Infrastructure (100% ✅)
- `secrets-management_spec.md` - 18 ACs ✅
- `tutor-configuration_spec.md` - 10 ACs ✅

### Tier 2: Deployment & Data (97-100%)
- `k8s-deployment_spec.md` - 32 ACs (97%) - 1 unmapped
- `mongodb-atlas-integration_spec.md` - 9 ACs ✅
- `multi-site-domains_spec.md` - 9 ACs ✅
- `tutor-configuration-resilience_spec.md` - 12 ACs (67%) - 4 unmapped

### Tier 3: Services & Operations (55-100%)
- `branding-system_spec.md` - 10 ACs ✅
- `observability-stack_spec.md` - 8 ACs ✅
- `forum-service-migration_spec.md` - 22 ACs (73%)
- `analytics-pipeline_spec.md` - 8 ACs (88%)
- `data-migrations-kajabi-mct_spec.md` - 44 ACs (98%)
- `disaster-recovery-business-continuity_spec.md` - 22 ACs (55%)
- `video-pipeline-delivery_spec.md` - 25 ACs (24%) - 19 unmapped
- `platform-middleware-custom-apps_spec.md` - 20 ACs (5%) - 19 unmapped
- `ci-cd-pipeline_spec.md` - 39 ACs (56%)

### Tier 4: Multi-Tenancy & SLOs (54-83%)
- `design-tokens-system_spec.md` - 12 ACs (75%)
- `multi-tenancy-architecture_spec.md` - 28 ACs (57%)
- `slo-sla-service-level-management_spec.md` - 23 ACs (83%)

### Tier 5: Enterprise SSO (13%)
- `auth-sso-enterprise_spec.md` - 45 ACs (13%) - **38 unmapped**

### Tier 6: Enterprise Services (100% ✅)
- `enterprise-microservices_spec.md` - 36 ACs ✅

### Tier 7: Advanced Features (0-52%)
- `ecommerce-purchase-gateway_spec.md` - 33 ACs (52%)
- `advanced-assessment-xqueue_spec.md` - 39 ACs (0%) - all unmapped
- `badges-credentials-enterprise_spec.md` - 32 ACs (9%) - 28 unmapped
- `content-libraries-v2_spec.md` - 33 ACs (0%) - all unmapped
- `email-notifications-pipeline_spec.md` - 45 ACs (4%) - 43 unmapped
- `mobile-apps-enterprise_spec.md` - 37 ACs (8%) - 34 unmapped

### Tier 8: External Integrations (19-26%)
- `external-registration-hubspot_spec.md` - 26 ACs (19%) - 21 unmapped
- `proctoring-integration_spec.md` - 38 ACs (26%) - 28 unmapped

### Tier 9: Compliance (0%)
- `data-privacy-gdpr-compliance_spec.md` - 30 ACs (0%) - all unmapped

---

## Sprint Planning

### Sprint Status

| Sprint | Status | Focus | Coverage |
|--------|--------|-------|----------|
| **Sprint 1** | ✅ COMPLETE | Close Tier 2-3 gaps | 60% → 65% |
| **Sprint 2** | ✅ COMPLETE | SLI/SLO, gap fixes, multi-tenancy | 65% → 70% |
| **Sprint 3** | 🚧 IN PROGRESS | Auth SSO verification, forum moderation, purchase gateway | 70% → 78% |

See `reports/2026/sprints/` for detailed sprint plans.

---

## Critical Path: Auth SSO

**Biggest gap**: `auth-sso-enterprise_spec.md` - 38 unmapped ACs (13% coverage)

This is a **Tier 5 blocker** for advanced enterprise features. Phases:

1. **Phase 0** (Complete ✅): SAML foundation, cert injection, middleware
2. **Phase 1** (Next): Tenant SSO configuration (10 ACs)
3. **Phase 2**: SAML flows + user provisioning (15 ACs)
4. **Phase 3**: JIT account creation + attribute mapping (13 ACs)

---

## Specs Ready for Docs Work

These specs are **100% mapped** and need comprehensive documentation:

| Spec | Docs Needed |
|------|-------------|
| `repository-structure` | Onboarding guide, directory structure |
| `secrets-management` | Infisical setup, ExternalSecrets workflow |
| `tutor-configuration` | Patch workflow, config lifecycle |
| `k8s-deployment` | Deployment runbook, troubleshooting |
| `mongodb-atlas` | Atlas setup, migration guide |
| `multi-site-domains` | Domain config, DNS setup |
| `branding-system` | Branding guide, asset pipeline |
| `observability-stack` | Dashboards, alert runbooks |
| `enterprise-microservices` | Service deployment, integration guide |

---

## Development Workflow

When implementing a new AC:

1. **Read the spec** - Understand acceptance criteria
2. **Check dependencies** - Use `IMPLEMENTATION_ORDER.md`
3. **Write test first** with `@covers`:
   ```python
   # @covers AC-XXX, AC-YYY
   # @spec: my-feature_spec.md
   def test_feature():
       ...
   ```
4. **Implement feature** to pass test
5. **Run verification**:
   ```bash
   python3 scripts/qa/spec-tools/spec_verify.py specs/ \
     --scan-dirs scripts/ tests/ deploy/ infrastructure/ services/ .github/workflows/
   ```
6. **Check coverage**:
   ```bash
   python3 scripts/qa/spec-tools/spec_coverage_report.py
   ```

---

## Tracking Progress

### Daily
```bash
# Quick coverage check
python3 scripts/qa/spec-tools/spec_coverage_report.py --format text
```

### Weekly
```bash
# Full report with unmapped ACs
python3 scripts/qa/spec-tools/spec_coverage_report.py \
  --format markdown > docs/archive/reports/coverage-$(date +%Y-%m-%d).md
```

### Per Sprint
```bash
# Verify all gates pass
./scripts/qa/run-spec-integrity-gates.sh
```

---

## Resources

- **Dependency graph**: `specs/plans/IMPLEMENTATION_ORDER.md`
- **Coverage reports**: `docs/archive/reports/`
- **Sprint plans**: `reports/2026/sprints/`
- **Manual verifications**: `specs/manual_verifications.yaml`
- **ADR**: `docs/adr/011-convention-based-spec-verification.md`

---

## Getting Help

- **Tools**: Run with `--help` flag
- **Skill**: Use `/spec-write`, `/spec-plan` for new specs
- **Team**: Check `AGENTS.md` for agent assignments
