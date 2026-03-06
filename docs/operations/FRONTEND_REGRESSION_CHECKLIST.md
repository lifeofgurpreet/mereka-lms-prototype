# Frontend Regression Migration Checklist

**Status**: Active
**Last Updated**: 2026-02-18
**AC**: AC-UI-003

> Checklist and rollback path for resolving frontend regressions during
> plugin-native migration. Use this when a UI/branding change causes
> 403/405 errors, blank pages, or visual regressions.

## Common Frontend Regressions

### 1. 403 Forbidden on MFE Routes

**Cause**: CSRF trusted origins missing for new domain, or `SESSION_COOKIE_SAMESITE` too strict.

**Fix checklist**:
- [ ] Verify domain in `CSRF_TRUSTED_ORIGINS` (both `apply-patches.sh` and `mereka_lms.py`)
- [ ] Verify `SESSION_COOKIE_SAMESITE = "None"` (not "Lax")
- [ ] Verify `SESSION_COOKIE_DOMAIN = None` (host-only, not wildcard)
- [ ] Check browser console for `SameSite` warnings
- [ ] Run: `curl -I https://<domain>/api/mfe_config/v1` — should return 200

**Rollback**: Revert CSRF change, redeploy.

### 2. 405 Method Not Allowed on Login/Register

**Cause**: MFE authn hitting wrong endpoint, or Caddy routing misconfigured.

**Fix checklist**:
- [ ] Check Caddy logs: `kubectl logs -n mereka-lms deploy/caddy --tail=20`
- [ ] Verify MFE `LMS_BASE_URL` in SiteConfiguration matches actual LMS URL
- [ ] Verify authn MFE route exists: `curl -I https://apps.academyv2.mereka.io/authn/login`
- [ ] Check if `mfe_oauth_fix` middleware is in INSTALLED_APPS

**Rollback**: Revert Caddy config change, restart Caddy pod.

### 3. Blank MFE Page (White Screen)

**Cause**: MFE bundle not loading, stale cache, or missing `env.config.jsx`.

**Fix checklist**:
- [ ] Check browser Network tab for 404 on JS bundles
- [ ] Verify `Cache-Control: no-cache` header on HTML responses
- [ ] Verify `env.config.jsx` exists in MFE build output
- [ ] Check if MFE image is correct: `kubectl get deploy mfe -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].image}'`
- [ ] Hard refresh: Ctrl+Shift+R

**Rollback**: Revert to previous MFE image tag in `kustomization.yaml`, push to main.

### 4. Segment/Analytics Key Not Loading

**Cause**: `SEGMENT_KEY` missing from SiteConfiguration or MFE config.

**Fix checklist**:
- [ ] Check MFE config: `curl -s https://<domain>/api/mfe_config/v1 | python3 -c "import json,sys; print(json.load(sys.stdin).get('SEGMENT_KEY','MISSING'))"`
- [ ] Verify `SEGMENT_KEY` in ExternalSecret mapping
- [ ] Verify key is set in GCP Secret Manager (project `bbi-k8`)

**Rollback**: Analytics is non-critical. Can proceed without key; add key later.

### 5. Visual Regression (Wrong Colors/Fonts)

**Cause**: Design tokens not synced, SASS not recompiled, or stale CSS cache.

**Fix checklist**:
- [ ] Run: `./scripts/branding/verify-branding-health.sh`
- [ ] Verify `mereka-overrides.css` loaded: check `<head>` for `head-extra.html` link
- [ ] Verify `--mereka-branding-rev` CSS variable matches source
- [ ] Run: `./scripts/branding/sync-brand-assets.sh` then rebuild

**Rollback**: Revert theme changes, rebuild OpenedX image.

### 6. Footer Variant Missing/Wrong

**Cause**: `SITE_VARIANTS` map in `mereka_lms.py` missing the domain, or plugin slot fallback not triggered.

**Fix checklist**:
- [ ] Check `MerekaFooter` renders: view page source, search for `mereka-footer`
- [ ] Verify domain in `SITE_VARIANTS` mapping in `mereka_lms.py`
- [ ] Verify `apply-patches.sh` RenderWidget replacement ran (dual-path)
- [ ] Run: `./scripts/qa/verify-footer-variant-matrix.sh`

**Rollback**: Footer is cosmetic. Revert variant map, redeploy.

## Regression Triage Decision Tree

```
Frontend issue reported
  │
  ├── HTTP 403/405? → Check CSRF/cookies (#1, #2)
  │
  ├── Blank page? → Check JS bundle loading (#3)
  │
  ├── Wrong branding? → Check theme/tokens (#5, #6)
  │
  ├── Analytics not tracking? → Check Segment key (#4)
  │
  └── Other → Check browser console + Caddy logs
```

## Rollback Priority

| Regression | Severity | Rollback Speed | Method |
|-----------|----------|----------------|--------|
| 403/405 on login | P0 (site down) | < 5 min | Revert CSRF/cookie config, push to main |
| Blank MFE page | P0 (site down) | < 5 min | Revert MFE image tag in kustomization.yaml |
| Wrong footer | P2 (cosmetic) | Next deploy | Fix SITE_VARIANTS mapping |
| Wrong colors/fonts | P2 (cosmetic) | Next deploy | Sync brand assets, rebuild |
| Missing analytics | P3 (non-user-facing) | Scheduled | Add Segment key to config |

## Evidence Capture

After fixing any regression, capture evidence:

```bash
# Run the plugin surface matrix
./scripts/qa/verify-plugin-surface-matrix.sh \
  --evidence-dir var/evidence/regression-fix-$(date +%Y%m%d)

# Run post-deploy smoke
./scripts/qa/verify-post-deploy-smoke.sh --env prod \
  --evidence-dir var/evidence/regression-fix-$(date +%Y%m%d)
```

## Related

- `docs/guides/branding/PLUGIN_MIGRATION_SURVEY.md` — Full override inventory
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` — Exception policy
- `docs/operations/MERGE_FIRST_DEPLOYMENT_PROTOCOL.md` — Deploy protocol
- `docs/operations/TROUBLESHOOTING.md` — Request-path diagnostics
