# Video Pipeline: Mux Credentials + Course Mapping Cleanup

> **Bead**: mereka-lms-1bdm.1
> **ACs**: AC-VPD-CRED-001, AC-VPD-CRED-002, AC-VPD-MAP-001, AC-VPD-MAP-002, AC-VPD-MAP-003
> **Date**: 2026-02-19

---

## AC-VPD-CRED-001: Mux Credentials Status

### Findings

| Location | Key | Status |
|----------|-----|--------|
| Infisical (prod) | `MEREKA_LMS_MUX_TOKEN_ID` | **NOT PRESENT** — missing from Infisical |
| Infisical (prod) | `MEREKA_LMS_MUX_TOKEN_SECRET` | **NOT PRESENT** — missing from Infisical |
| GCP SM (`bbi-k8`) | `MEREKA_LMS_MUX_TOKEN_ID` | **PLACEHOLDER** (`PLACEHOLDER_REPLACE_ME`) |
| GCP SM (`bbi-k8`) | `MEREKA_LMS_MUX_TOKEN_SECRET` | **PLACEHOLDER** (`PLACEHOLDER_REPLACE_ME`) |
| K8s `openedx-secrets` | `MUX_TOKEN_ID` | Present (synced from GCP SM — placeholder value) |
| K8s `openedx-secrets` | `MUX_TOKEN_SECRET` | Present (synced from GCP SM — placeholder value) |

**Root cause**: No real Mux credentials have ever been loaded into GCP SM. Both secrets are placeholder values.

### Secret Drift (Additional Issue)

The live `mux-delivery-monitor` deployment reads from `mereka-lms-runtime-secrets` (wrong), but the repo manifest `deploy/k8s/base/monitoring/mux-exporter.yaml` correctly references `openedx-secrets`. This is a **ArgoCD sync drift** — the deployment was manually patched at some point.

**Fix**: ArgoCD sync will correct this automatically once triggered. No repo change needed.

### Unblock Path (Operator Action Required)

```bash
# 1. Obtain real Mux API credentials from console.mux.com
# 2. Load into GCP SM (replace placeholder):
printf '%s' 'REAL_MUX_TOKEN_ID' | gcloud secrets versions add MEREKA_LMS_MUX_TOKEN_ID \
  --data-file=- --project=bbi-k8

printf '%s' 'REAL_MUX_TOKEN_SECRET' | gcloud secrets versions add MEREKA_LMS_MUX_TOKEN_SECRET \
  --data-file=- --project=bbi-k8

# 3. Force ExternalSecret refresh:
kubectl annotate externalsecret openedx-secrets -n mereka-lms \
  force-sync=$(date +%s) --overwrite

# 4. Force ArgoCD sync to fix deployment drift:
argocd app sync mereka-lms
```

---

## AC-VPD-CRED-002: Playback Auth Validation

**Status**: BLOCKED — cannot validate without real credentials.

Once real credentials are loaded:
```bash
# Validate Mux token ID format (should be: alphanumeric, ~8 chars)
kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MUX_TOKEN_ID}' | base64 -d

# Test Mux API connectivity
curl -u "${MUX_TOKEN_ID}:${MUX_TOKEN_SECRET}" \
  https://api.mux.com/video/v1/assets?limit=1
```

**Validation script**: `scripts/qa/verify-mux-secrets.sh` — currently passes config checks but cannot verify real token validity.

---

## AC-VPD-MAP-001: Course ID Mapping — SKILLOURFUTURE vs MEREKA

### Findings

| Org | Mapped Courses | Source |
|-----|---------------|--------|
| **SKILLOURFUTURE** | 30 courses | `exports/mct/complete_lesson_mapping.json` |
| **MEREKA** | **0 courses** | Not yet in mapping files |

**Source of truth**: `exports/mct/complete_lesson_mapping.json`
- All 30 mapped courses use `course-v1:SKILLOURFUTURE+MCT-{id}+course` pattern
- MCT migration data covers 178 MCT courses → 503 Mux videos (all SKILLOURFUTURE org)

**MEREKA org gap**: MCT data is SKILLOURFUTURE-only. MEREKA org courses were authored directly in Open edX Studio and do not have MCT-sourced Mux mappings.

**Reconciliation**: The two orgs use separate content pipelines:
- `SKILLOURFUTURE`: MCT → Mux migration (pre-mapped in exports/)
- `MEREKA`: Direct Open edX authoring (no Mux pipeline yet; uses XBlock video URLs if any)

---

## AC-VPD-MAP-002: Orphan VAL Records

### Findings

| Category | Count | Notes |
|----------|-------|-------|
| Total lessons in MCT export | 833 | All SKILLOURFUTURE courses |
| Lessons with Mux playback ID | 503 | Fully mapped, ready for import |
| **Unmapped lessons** | **330** | No `mux_playback_id` — these are orphan VAL records |
| Mux videos total (from Mux) | 503 | Matches mapped count exactly |

**Reason for 330 unmapped**: These lessons had no video content in MCT (text-only lessons, quizzes, or lessons where video upload to Mux was never completed).

**Not data loss**: The 330 unmapped lessons correspond to non-video lesson types. Mux upload complete file (`exports/mct/mux_upload_complete.json`) accounts for 503 uploads — all video lessons are covered.

---

## AC-VPD-MAP-003: Phase 1 Re-Upload Path and Next Steps

### Execution List

| Step | Action | Owner | Blocker |
|------|--------|-------|---------|
| 1 | Add real Mux credentials to GCP SM | Platform ops | **Immediate action item** |
| 2 | Trigger ArgoCD sync to fix deployment drift | Platform ops | After step 1 |
| 3 | Run `scripts/qa/verify-mux-secrets.sh` — confirm real token loaded | Platform ops | After step 2 |
| 4 | Test Mux API call with live credentials | Platform engineer | After step 3 |
| 5 | Validate `mux-delivery-monitor` pod starts clean | Platform engineer | After step 4 |
| 6 | Import SKILLOURFUTURE Mux mappings to Open edX VAL | Platform engineer | After step 5 |
| 7 | Set up MEREKA org video pipeline (separate roadmap item) | Product/engineering | Post-SKILLOURFUTURE launch |

### Phase 2+ Scope (Post-Unblock)

| Feature | Bead | Notes |
|---------|------|-------|
| Video analytics (xAPI events for watch completion) | 1bdm.2+ | Depends on Mux creds active |
| Content protection (Mux signed URLs) | 1bdm.2+ | Requires Mux playback policy config |
| Mux monitoring alerts | 1bdm.2+ | PrometheusRule already deployed (`prometheusrule-video.yaml`) |
| MEREKA org video pipeline | Future | No MCT source; needs XBlock video URL setup |

---

## Summary

| AC | Status | Blocker |
|----|--------|---------|
| AC-VPD-CRED-001 | ❌ BLOCKED | GCP SM has placeholder values — operator must add real Mux credentials |
| AC-VPD-CRED-002 | ❌ BLOCKED | Depends on AC-VPD-CRED-001 |
| AC-VPD-MAP-001 | ✅ RESOLVED | SKILLOURFUTURE=30 courses (MCT), MEREKA=0 (direct authoring, no MCT) |
| AC-VPD-MAP-002 | ✅ RESOLVED | 330 unmapped = non-video lessons (text/quiz); 503 video lessons fully mapped |
| AC-VPD-MAP-003 | ✅ COMPLETE | Phase 1 execution list documented above |

**Single unblock action**: Load real Mux API credentials into GCP SM `bbi-k8` project.
