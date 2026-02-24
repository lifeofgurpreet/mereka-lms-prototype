# UI Readiness Matrix — wrsl.1 Evidence Bundle

> **Bead**: mereka-lms-wrsl.1 (AC-UI-101..105)
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize
> **Operator**: WhiteCliff

---

## AC-UI-101: Route Status Snapshot

| Route | URL | Status | Notes |
|-------|-----|--------|-------|
| LMS home | https://academyv2.mereka.io/ | **200 PASS** | Mereka branding present (566 refs) |
| LMS courses | https://academyv2.mereka.io/courses | **200 PASS** | |
| Studio | https://studio.academyv2.mereka.io/ | **200 PASS** | 13 Mereka refs, Studio markers ✓ |
| Authn MFE | https://apps.academyv2.mereka.io/authn/login | **200 PASS** | Title: "Authentication" |
| Enterprise admin portal | https://admin.academyv2.mereka.io/ | **200 PASS** | nreum-clean-202602190645 ✓ |
| Enterprise learner portal | https://enterprise.academyv2.mereka.io/ | **200 PASS** | nreum-clean-202602190645 ✓ |
| Django admin | https://academyv2.mereka.io/admin/ | **200 PASS** | Auth redirect working |
| Credentials root | https://academyv2.mereka.io/credentials/ | **404 WARN** | Credentials MFE not deployed |

**Commands used:**
```bash
for url in <urls>; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 "$url")
  echo "$STATUS  $url"
done
```

---

## AC-UI-102: DOM Markers — Branding + NREUM Regression Guard

### Branding tokens (via MFE config endpoint)

Both enterprise portal config endpoints return valid JSON with full Mereka branding:
```bash
curl -s https://admin.academyv2.mereka.io/api/mfe_config/v1
curl -s https://enterprise.academyv2.mereka.io/api/mfe_config/v1
```

Key tokens confirmed:
| Token | Value |
|-------|-------|
| `SITE_NAME` | `"Mereka Academy"` |
| `LOGO_URL` | `https://academyv2.mereka.io/theming/asset/mereka/images/logo-horizontal.png` |
| `LOGO_WHITE_URL` | `https://academyv2.mereka.io/theming/asset/mereka/images/logo-horizontal-white.png` |
| `FAVICON_URL` | `https://academyv2.mereka.io/theming/asset/mereka/images/favicon.ico` |
| `LMS_BASE_URL` | `https://academyv2.mereka.io` |
| `STUDIO_BASE_URL` | `https://studio.academyv2.mereka.io` |
| `INFO_EMAIL` | `contact@mereka.io` |

### LMS DOM markers
- Mereka refs in HTML: **566** (logo, footer, branding assets)
- Footer plugin slot: **10** matches (footer/Footer)
- Logo: `logo.b6c374d66d57.png` alt="Mereka" — **PASS**
- Segment analytics: **1** reference — **PASS**

### NREUM / undefined_license_key regression guard

| Surface | NREUM count | undefined_license_key count | Result |
|---------|-------------|----------------------------|--------|
| LMS home | 0 | 0 | **PASS** |
| Authn MFE | 0 | 0 | **PASS** |
| Admin portal | 0 | 0 | **PASS** |
| Learner portal | 0 | 0 | **PASS** |

Running images:
- `enterprise-admin-portal`: `nreum-clean-202602190645`
- `enterprise-learner-portal`: `nreum-clean-202602190645`

QA script result:
```
bash scripts/qa/verify-enterprise-mfe-nreum-clean.sh
PASS: 6 | FAIL: 0 | SKIP: 2
RESULT: PASS
```
(2 SKIPs = script-internal curl logic skipping HTML body check; manual verification confirms 0 NREUM.)

---

## AC-UI-103: Ranked Gap List

| Priority | Surface | Gap | Owner | ETA |
|----------|---------|-----|-------|-----|
| P1 WARN | Credentials MFE | `/credentials/` returns 404 — Credentials service not deployed | Platform team | Next sprint |
| P2 WARN | Authn MFE | 0 Mereka branding refs in HTML (MFE config loads branding dynamically post-hydration, not in initial HTML) | Frontend | No action needed — correct SPA behavior |
| P2 WARN | verify-enterprise-mfe-nreum-clean.sh | 2 SKIP on NREUM HTML body check (script logic bug — uses empty-body check that fires after 200) | QA | Fix script to use `--output -` pattern |
| P3 INFO | Studio | No pinned image tag (uses base `:latest` — ArgoCD reverts manual patches) | Ops | Tracked separately |
| P3 INFO | bbi-infrastructure | Enterprise portal image pins were missing from ArgoCD overlay | **FIXED this session** (commit `3b6f95c`) | Done |

---

## AC-UI-104: Demo-Ready Artifact Bundle

### Quick demo smoke commands
```bash
# 1. Full route health check
for url in \
  "https://academyv2.mereka.io/" \
  "https://studio.academyv2.mereka.io/" \
  "https://apps.academyv2.mereka.io/authn/login" \
  "https://admin.academyv2.mereka.io/" \
  "https://enterprise.academyv2.mereka.io/"; do
  echo "$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 "$url")  $url"
done

# 2. NREUM regression guard
bash scripts/qa/verify-enterprise-mfe-nreum-clean.sh

# 3. Branding token verification
curl -s https://admin.academyv2.mereka.io/api/mfe_config/v1 | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('SITE_NAME'), d.get('LOGO_URL'))"

# 4. Pod image check
kubectl get deployment enterprise-admin-portal enterprise-learner-portal \
  -n mereka-lms \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}'
```

### Evidence locations
| Artifact | Path |
|----------|------|
| This file | `docs/operations/evidence/wrsl1-ui-readiness-matrix.md` |
| NREUM clean build evidence | `docs/operations/evidence/69qz-enterprise-mfe-clean-build.md` |
| NREUM verify script | `scripts/qa/verify-enterprise-mfe-nreum-clean.sh` |
| Enterprise MFE clean Dockerfiles | `infrastructure/docker/enterprise-mfe-clean/` |
| Build+push script | `scripts/infra/build-enterprise-mfe-clean.sh` |
| Deployment runbook Section 9 | `docs/operations/runbooks/DEPLOYMENT_RUNBOOK.md` |
| Build/cache pipeline runbook | `docs/operations/BUILD_CACHE_PIPELINE_RUNBOOK.md` |

---

## AC-UI-105: No Shell Fallback Patching

Post-deploy checks verified to NOT use shell fallback patching:
- `verify-enterprise-mfe-nreum-clean.sh` — pure `curl` + `grep` checks, no live patching
- `scripts/qa/verify-public-branding.sh` — read-only HTTP checks
- No `kubectl exec` patching, no runtime `sed`/`awk` transforms in production
- NREUM stripping moved to build time (`infrastructure/docker/enterprise-mfe-clean/strip-nreum.sh` runs at `docker build`, not at pod start)
- Previous init container workaround (`strip-nreum`, `copy-dist`) removed in commit `5d358d2`

**PASS** — zero shell fallback patching in post-deploy checks.

---

## Summary

| AC | Result | Evidence |
|----|--------|---------|
| AC-UI-101 | **PASS** (7/8 routes 200; credentials 404 known gap) | Route status table above |
| AC-UI-102 | **PASS** (MFE config tokens verified; NREUM=0 all surfaces) | DOM markers + mfe_config JSON |
| AC-UI-103 | **PASS** (Gap list produced, 1 P1 WARN, 2 P2 WARN) | Gap list table above |
| AC-UI-104 | **PASS** (Demo commands + evidence index) | This doc + evidence locations |
| AC-UI-105 | **PASS** (No shell fallback patching) | Build-time strip confirmed |

**Overall: PASS** — cluster is in clean, demo-ready state.
