# MFE Branding Revision Parity — 2qpt Evidence

> **Bead**: mereka-lms-2qpt (AC-BRD-106..109)
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize
> **Operator**: WhiteCliff

---

## Summary

| AC | Result | Notes |
|----|--------|-------|
| AC-BRD-106 | **PASS** | All non-MFE surfaces have correct branding revision marker |
| AC-BRD-107 | **CONTROLLED GAP** | MFE authn CSS revision mismatch: image build-time gap, not a config error |
| AC-BRD-108 | **PASS** | Audit script now shows deployed vs expected revision deterministically |
| AC-BRD-109 | **PASS** | Runbook note added; resolution path documented |

**Overall**: Branding gates pass (exit 0, strict=0). MFE revision gap is a build-time artifact, not a
runtime misconfiguration. Audit script improved to show deployed revision in gap message.

---

## Root Cause Analysis

### Why only MFE authn surfaces show revision mismatch

The platform has two classes of deployed CSS:

| CSS Class | Deployment Mechanism | Can be updated without image rebuild? |
|-----------|---------------------|---------------------------------------|
| LMS/microsite override CSS (`mereka-overrides.css`) | Injected via ConfigMap → collectstatic | **YES** — update ConfigMap, roll LMS pod |
| Studio themed CSS (`studio-main-v1.*.css`) | Built into openedx Docker image | No — needs image rebuild |
| MFE authn CSS (`/authn/app.*.css`) | Built into MFE Docker image | No — needs image rebuild |

The LMS and microsite `--mereka-branding-rev` marker lives in the override CSS file, which is
deployed via ConfigMap. When the source was updated (2026-02-10-pass1), it was picked up
automatically on the next rollout.

The MFE `--mereka-mfe-branding-rev` marker lives INSIDE the compiled MFE Docker image. The MFE
image was built on 2026-02-10 (tag `b732a7d-20260210161437`) — **before** the source revision was
bumped to `2026-02-18-us7`. So the deployed image has:

```
--mereka-mfe-branding-rev:"2026-02-08-pass4"   # embedded in image at build time
```

While the current source declares:

```scss
--mereka-mfe-branding-rev: "2026-02-18-us7";   // in infrastructure/tutor/themes/mereka/mfe/mereka.scss
```

### Verification

```bash
# Confirm deployed MFE CSS revision
css_url=$(curl -sL --max-time 15 https://apps.academyv2.mereka.io/authn/login | \
  grep -o '/authn/app\.[^"]*\.css' | head -1)
curl -sL --max-time 30 "https://apps.academyv2.mereka.io${css_url}" | \
  sed -nE 's/.*--mereka-mfe-branding-rev:"([^"]+)".*/\1/p' | head -1
# Output: 2026-02-08-pass4

# Confirm source revision
sed -nE 's/.*--mereka-mfe-branding-rev:[[:space:]]*"([^"]+)".*/\1/p' \
  infrastructure/tutor/themes/mereka/mfe/mereka.scss | head -1
# Output: 2026-02-18-us7
```

---

## Why This Is a Controlled Gap (Not a Bug)

1. **All branding gates pass** (exit 0) — the MFE is functionally branded with Mereka tokens,
   gradient, Poppins font, and authn card styling. The revision marker is a tracking signal only.

2. **The gap is expected** when the MFE image has not been rebuilt since a source revision bump.
   This is the normal lifecycle: bump revision → rebuild image → deploy.

3. **The strict=0 sentinel** in `audit-branding-surfaces.sh` is working correctly. The 4 gaps
   (2 direct MFE hosts + 2 proxy surfaces) are all the same underlying gap.

4. **No runtime workaround exists** for this gap without rebuilding the image. Patching the CSS
   dynamically would be unsafe and non-deterministic.

---

## Script Improvement (2qpt fix)

The audit script previously showed only what was **missing**:

```
✗ MFE authn (apps.academyv2.mereka.io): branding revision marker 2026-02-18-us7 missing
✗ Ecommerce dashboard: authn css branding revision differs from source (2026-02-18-us7)
```

After fix, the script now shows **both deployed and expected** revision:

```
✗ MFE authn (apps.academyv2.mereka.io): branding revision marker 2026-02-18-us7 missing
    (deployed: 2026-02-08-pass4; rebuild MFE image)
✗ Ecommerce dashboard: authn css branding revision differs from source
    (source=2026-02-18-us7, deployed=2026-02-08-pass4; rebuild MFE image)
```

**Files changed**: `scripts/qa/audit-branding-surfaces.sh` (lines 175-176, 312-313)
- `check_mfe_authn_surface`: extract `_deployed_rev` from CSS and include in gap message
- `check_authn_proxy_surface`: same pattern

This makes the output **deterministic**: operators can immediately see if the deployed revision has
changed (i.e., if an image rebuild has been deployed) without re-running `curl` manually.

---

## Resolution Path

To close the MFE revision gap completely:

```bash
# 1. Rebuild MFE image (picks up 2026-02-18-us7 from mereka.scss)
tutor images build mfe
docker tag openedx/mfe:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/mfe:<new-sha>
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/mfe:<new-sha>

# 2. Update image tag in deploy/k8s/overlays/production/kustomization.yaml
# 3. Commit, push → ArgoCD rolls out new MFE pod
# 4. Re-run audit → all 4 gaps close
```

The revision gap is tracked; a separate MFE image build task (outside this bead) will resolve it.

---

## Branding Gates Run (post-fix)

```
BRANDING_LEVEL=deep ./scripts/branding/run-branding-gates.sh prod
EXIT: 0
Branding surface audit: gaps=4 strict=0
```

All 4 gaps are MFE revision drift (image build-time, not config error). No blocking failures.

---

## Related files

| File | Change |
|------|--------|
| `scripts/qa/audit-branding-surfaces.sh` | Show deployed vs expected revision in gap messages |
| This file | Root cause analysis + resolution path |
