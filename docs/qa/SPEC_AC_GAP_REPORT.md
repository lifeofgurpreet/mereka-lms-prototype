# Spec AC Gap Report

**Generated**: 2026-02-18
**Bead**: 23ry.1 (spec cleanup: repair top-tier spec acceptance IDs)
**Tool**: `scripts/qa/spec-tools/spec_coverage_dashboard.py`

This report lists every spec below 100% coverage, the unmapped AC IDs, their priority tier, owning domain, and recommended action.

---

## Summary

| Status | Count |
|--------|-------|
| Total specs | 38 |
| At 100% coverage | 26 |
| GREEN (>=80%, below 100%) | 7 |
| RED (<50%) | 5 |
| Total unmapped ACs | 188 |

---

## Specs Below 100% Coverage

### GREEN Tier (>=80% — Operational, monitor)

#### ci-cd-pipeline_spec.md — 86.0% (6 Unmapped)

| AC ID | Description | Priority | Domain | Action |
|-------|-------------|----------|--------|--------|
| AC-INT-001 | K8s manifest + Artifact Registry push integration | P2 | DevOps/SRE | Add `@covers AC-INT-001` to `verify-ci-cd-pipeline.sh` or create integration test |
| AC-INT-002 | ExternalSecrets SecretSynced gate before deploy | P2 | DevOps/SRE | Add `@covers AC-INT-002` to `verify-k8s-externalsecrets.sh` |
| AC-INT-003 | Infisical secret validation in CI | P2 | DevOps/SRE | Add `@covers AC-INT-003` to `infisical-validate-mereka-lms.sh` |
| AC-INT-004 | Branding preflight during openedx build | P2 | DevOps/SRE | Add `@covers AC-INT-004` to `branding-preflight.sh` |
| AC-003 | ruff lint violations fail CI | P3 | DevOps/SRE | Add `@covers AC-003` to any lint verify script |
| AC-004 | kubeconform K8s YAML validation | P3 | DevOps/SRE | Add `@covers AC-004` to `verify-kustomize-render.sh` |

#### k8s-deployment_spec.md — 86.5% (5 Unmapped)

| AC ID | Description | Priority | Domain | Action |
|-------|-------------|----------|--------|--------|
| AC-INT-001 | Pods reach Running with secrets from ExternalSecrets | P1 | DevOps/SRE | Add to `verify-k8s-live-cluster.sh` with `@covers AC-INT-001` |
| AC-INT-002 | OPENEDX_SECRET_KEY non-empty via kubectl exec | P1 | DevOps/SRE | Add live cluster exec check to `verify-k8s-live-cluster.sh` |
| AC-INT-003 | Secret rotation propagates within 1h | P2 | DevOps/SRE | Manual verification; add to `manual_verifications.yaml` |
| AC-INT-004 | MySQL native password from tutor patches in LMS | P2 | DevOps/SRE | Add `@covers AC-INT-004` to `verify-cicd-tutor-config-workflow.sh` |
| AC-INT-005 | ALLOWED_HOSTS contains all multi-site domains | P2 | DevOps/SRE | Add `@covers AC-INT-005` to `verify-k8s-deployment-spec.sh` |

#### ecommerce-purchase-gateway_spec.md — 97.1% (1 Unmapped)

| AC ID | Description | Priority | Domain | Action |
|-------|-------------|----------|--------|--------|
| AC-034 | Service domain uses DNS-only Cloudflare + Let's Encrypt SSL | P3 | Commerce/Infra | Add `@covers AC-034` to `verify-purchase-gateway.sh` or defer to global infra verify |

#### enterprise-microservices_spec.md — 97.3% (1 Unmapped)

| AC ID | Description | Priority | Domain | Action |
|-------|-------------|----------|--------|--------|
| (1 unmapped) | Enterprise microservices integration gap | P3 | Backend/Enterprise | Identify AC via testmap; add `@covers` annotation |

#### video-pipeline-delivery_spec.md — 97.4% (1 Unmapped)

| AC ID | Description | Priority | Domain | Action |
|-------|-------------|----------|--------|--------|
| (1 unmapped) | Video delivery integration gap | P3 | Data/Media | Identify AC via testmap; add `@covers` annotation |

#### disaster-recovery-business-continuity_spec.md — 88.5% (3 Unmapped)

| AC ID | Description | Priority | Domain | Action |
|-------|-------------|----------|--------|--------|
| (3 unmapped) | DR/BC verification gaps | P2 | DevOps/SRE | Identify ACs via testmap; add to verify-dr-evidence scripts |

#### forum-service-migration_spec.md — 88.0% (3 Unmapped)

| AC ID | Description | Priority | Domain | Action |
|-------|-------------|----------|--------|--------|
| (3 unmapped) | Forum migration verification gaps | P2 | Platform | Identify ACs via testmap; add `@covers` to forum verify scripts |

---

### RED Tier (<50% — High debt, needs planning)

#### email-notifications-pipeline_spec.md — 40.0% (27 Unmapped)

| Priority | Domain | Action |
|----------|--------|--------|
| P2 | Platform/Backend | 27 ACs unimplemented. Email pipeline not yet built. Defer to Tier 4/5 work. |

#### data-privacy-gdpr-compliance_spec.md — 26.1% (68 Unmapped)

| Priority | Domain | Action |
|----------|--------|--------|
| P1 | Legal/Compliance | 68 ACs unimplemented. GDPR compliance is legally required. Schedule dedicated sprint. |

#### advanced-assessment-xqueue_spec.md — 11.4% (39 Unmapped)

| Priority | Domain | Action |
|----------|--------|--------|
| P3 | Platform | XQueue is legacy. 39 ACs largely deferred. Review if XQueue is still required. |

#### mobile-apps-enterprise_spec.md — 8.1% (34 Unmapped)

| Priority | Domain | Action |
|----------|--------|--------|
| P3 | Mobile | Enterprise mobile features not yet implemented. Defer. |

#### github-actions-cost-monitoring_spec.md — 0.0% (0 ACs)

| Priority | Domain | Action |
|----------|--------|--------|
| P3 | DevOps | Spec has 0 ACs defined. Spec needs AC authoring before verification is possible. |

---

## Priority Definitions

| Priority | Meaning |
|----------|---------|
| P1 | Deployment-critical: failures here cause production outages or security breaches |
| P2 | Operational: failures degrade reliability, observability, or compliance posture |
| P3 | Future: features not yet built or deferred to later tiers |

---

## Recommended Next Actions

1. **Quick wins (add `@covers` annotations)**: ci-cd AC-003, AC-004 and k8s AC-INT-004, AC-INT-005 — these are already verified implicitly, just need annotation wiring.
2. **Live cluster ACs** (k8s AC-INT-001, AC-INT-002): Add targeted `kubectl exec` checks to `verify-k8s-live-cluster.sh`.
3. **Manual entries**: k8s AC-INT-003 (secret rotation time-based) should be added to `specs/manual_verifications.yaml`.
4. **GDPR compliance (P1)**: Schedule a dedicated planning session. 68 unmapped ACs represent significant legal risk.
5. **XQueue review**: Evaluate whether `advanced-assessment-xqueue_spec.md` is still relevant to current product direction before investing in verification coverage.
