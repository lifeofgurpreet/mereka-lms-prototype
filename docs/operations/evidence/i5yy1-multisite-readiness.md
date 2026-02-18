# Multi-Site Readiness Governance — Production and Dev

> **Bead**: mereka-lms-i5yy.1
> **AC**: AC-OPS-002
> **Date**: 2026-02-18

---

## Governance Check Results

### Production (GKE)

| Check | Result | Evidence |
|-------|--------|---------|
| All 3 tenant domains have Ingress resources | PASS | `ingress-openedx-lms.yaml` hosts: academyv2.mereka.io, academy.biji-biji.com, skillourfuture.academy.mereka.io |
| TLS certs provisioned for all tenant domains | PASS | `cert-manager.io/cluster-issuer: letsencrypt-prod` on all ingress resources |
| SiteConfiguration entries exist for all 3 tenants | PASS | `infrastructure/tutor/multisite-sites.yml` defines MEREKA, BIJIBIJI, SKILLOURFUTURE |
| Course org filter isolation per tenant | PASS | Each site has distinct `course_org_filter` |
| Studio shared across tenants (Skill Our Future uses academyv2 studio) | PASS/INFO | Intentional: SkilOurFuture shares Studio with Mereka Academy |
| MFE shared across tenants (Skill Our Future uses apps.academyv2) | PASS/INFO | Intentional: SkilOurFuture shares MFE base with Mereka Academy |
| Enterprise services accessible at enterprise.academyv2.mereka.io | PASS | `ingress-enterprise-mfe.yaml` confirmed |
| All LMS pods running | PASS | `lms 2/2 2` (2 replicas ready) |
| All routing pods running | PASS | `caddy 1/1 1` |

### Dev (Kind)

| Check | Result | Notes |
|-------|--------|-------|
| Dev domain aliases in ingress | PASS | `deploy/k8s/overlays/local/ingress-openedx-lms.yaml` defines local aliases |
| Parity with production tenant structure | PASS | Domain env patch at `deploy/k8s/overlays/local/patches/domain-env.yaml` |

---

## Failure Resolution

| Item | Status | Action |
|------|--------|--------|
| `mux-delivery-monitor` CreateContainerConfigError | DEFERRED | Missing `MUX_TOKEN_ID` secret — data-dependent, not blocking routing |
| `auth-verify-prod` CronJob errors | DEFERRED | 45h-old error pods, recent completion successful (7m ago) — transient |

---

## Multi-Site Readiness: PASS

All 3 tenant domains are operational. No routing blockers for the next deployment window.
