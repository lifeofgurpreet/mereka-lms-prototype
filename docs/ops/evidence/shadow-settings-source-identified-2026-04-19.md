---
title: "Shadow settings file defect — runtime configmap source IDENTIFIED (closes slice-67 open question)"
type: evidence-bundle
status: active
observed_at: 2026-04-19T14:00Z
owner: platform-release
bead: mereka-lms-mefk
supersedes_question_in: docs/ops/evidence/shadow-settings-correction-addendum-2026-04-19.md
---

# Shadow settings file defect — runtime configmap source IDENTIFIED

The slice-67 correction addendum (PR #1885,
`docs/ops/evidence/shadow-settings-correction-addendum-2026-04-19.md`)
established that a K8s configmap (`openedx-settings-lms-patched-*`)
overwrites the Tutor-rendered LMS settings at mount time, and left open
the question: **what source renders the configmap?**

## Answer

The configmap is produced by kustomize `configMapGenerator` in the
bbi-infrastructure overlay. Per environment:

| Env     | Authoritative source path                                                                         |
|---------|---------------------------------------------------------------------------------------------------|
| dev     | `bbi-infrastructure/apps/mereka-lms/overlays/dev/patches/production-dev.py`                       |
| staging | `bbi-infrastructure/apps/mereka-lms/overlays/staging/patches/production-staging.py`               |
| prod    | `bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py`                     |

Plus sibling module files (all in
`bbi-infrastructure/apps/mereka-lms/overlays/<env>/`):
- `__init__.py`
- `mereka_multisite.py`
- `mereka_footer.py`
- `mereka_xblock_iframe.py`
- `mereka_jwt_session.py`
- `mereka_platform_admin.py`
- `mereka_forwarded_headers.py`
- `mereka_enterprise_channels.py`

## Chain of surfaces (CLOSED)

```
bbi-infrastructure/apps/mereka-lms/overlays/<env>/patches/production-<env>.py  ← AUTHORITATIVE
    + bbi-infrastructure/apps/mereka-lms/overlays/<env>/<sibling modules>.py
        ↓ (kustomize configMapGenerator, content-hashed)
ConfigMap openedx-settings-lms-patched-<hash>       (Argo-managed)
        ↓ (volumeMount at /openedx/edx-platform/lms/envs/tutor/)
/openedx/edx-platform/lms/envs/tutor/production.py  (live in pod)
        ↓ (Python import)
Django settings
        ↓ (readable via manage.py lms shell)
settings.FEATURES / settings.MFE_CONFIG / ...
```

## Evidence — dev env verification

```bash
# Kustomize generator points at the authoritative path
cd bbi-infrastructure
grep -A 12 "configMapGenerator" apps/mereka-lms/overlays/dev/kustomization.yaml
# → - name: openedx-settings-lms-patched
#     files:
#       - production.py=patches/production-dev.py
#       - __init__.py
#       - mereka_multisite.py
#       - ...

# Authoritative file has LEARNING_MICROFRONTEND_URL at line 1318
grep -n "LEARNING_MICROFRONTEND_URL" apps/mereka-lms/overlays/dev/patches/production-dev.py
# → 1318:LEARNING_MICROFRONTEND_URL = "https://apps.academyv2.mereka.dev/learning"

# Runtime pod has the same line at the same position
kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/lms \
  -- grep -n 'LEARNING_MICROFRONTEND_URL' /openedx/edx-platform/lms/envs/tutor/production.py
# → 1318:LEARNING_MICROFRONTEND_URL = "https://apps.academyv2.mereka.dev/learning"
```

Same line, same value, same line number → authoritative source confirmed.

Recent changes to the authoritative dev file:
- `d38ae3fd fix(mereka-lms): restore nonprod module helper (#2732)`
- `64ef659c fix(mereka-lms): mount custom video api routes (#2716)`
  — this is the bbi-infra companion of app-repo #1559. Proves the
  "dual-ship" pattern exists: some changes landed in both app-repo
  shadow AND bbi-infra overlay, keeping them in partial sync. Others
  landed in only one side (causing the no-op PRs caught in slices 63-64).

## Implications

### Definitive "correct path" guidance

For LMS Django settings that must take effect at runtime:

- **Authoritative surface**: edit the corresponding file under
  `bbi-infrastructure/apps/mereka-lms/overlays/<env>/patches/production-<env>.py`
  (and sibling modules in `overlays/<env>/`) in the bbi-infrastructure repo.
- **Test**: after merge to bbi-infra main, Argo rolls the LMS pod with a
  new configmap hash; verify via
  `kubectl exec deploy/lms -- manage.py lms shell -c "..."`.
- **Waffle flags** (DB-backed): still applicable via
  `manage.py lms waffle_flag <name> --activate` + seed migration.
- **Tutor plugin** (`infrastructure/tutor/plugins/mereka_lms.py`):
  applicable ONLY for settings the configmap does NOT overwrite, OR
  for image-baked artifacts (packages, themes, entrypoint) that the
  configmap volume mount does not replace.
- **App-repo shadow** (`deploy/k8s/base/apps/openedx/settings/lms/*.py`):
  **NEVER THE CORRECT PATH** for runtime changes. Shadow files only
  serve as reference copies; the warning headers added in #1883
  correctly warn against treating them as authoritative.

### Warning headers need updating (out of scope this PR)

The headers added in #1883 point to "Tutor plugin / patches / waffle
flag" as correct paths. Per slice 67+68 findings, the primary correct
path for Django settings is actually the bbi-infra overlay. Follow-up
PR should update the header text to match. Tracked in bead
`mereka-lms-mefk`.

### Dual-ship drift risk

The app-repo shadow files and the bbi-infra overlay files are clearly
maintained in partial parallel. Some commits landed in both (e.g.
custom-video-api-routes landed as both app-repo #1559 and bbi-infra
#2716); others landed only in app-repo (silent no-op) or only in
bbi-infra (runtime-only fix, invisible in app-repo). The historical
audit bead (`mereka-lms-mefk`) now has a concrete methodology:

1. Enumerate all PRs touching `deploy/k8s/base/apps/openedx/settings/lms/*.py`
   in the app-repo.
2. For each, check whether there is a companion PR in bbi-infra that
   made the equivalent change to
   `apps/mereka-lms/overlays/<env>/patches/production-<env>.py` or
   sibling modules.
3. Classify:
   - (a) Both sides changed → correctly dual-shipped, no issue
   - (b) App-repo only → silent no-op at runtime
   - (c) bbi-infra only → runtime-applied but app-repo "reference copy"
     is out of sync (also a problem — misleads future agents reading
     app-repo)

## Updated bead guidance

- **`mereka-lms-mefk`** (P1 bug, shadow-settings audit): methodology
  now concrete. Execute the 3-way classification against `git log`
  from both repos. Deliverable: table of PRs in each class.
- **`mereka-lms-vfd5`** (P2 task, expose LEARNING_MICROFRONTEND_URL):
  correct surface identified. For prod, edit
  `bbi-infrastructure/apps/mereka-lms/overlays/prod/patches/production-prod.py`
  (and matching dev/staging). Gated on confirming MFE consumption.
- **New follow-up**: update `#1883` warning headers with corrected
  pointer list. Small, well-scoped PR against app-repo.

## Doctrine implications

Runtime-settings chain-of-surfaces invariant (filed slice 67) now has
complete worked example. The chain terminates at
`bbi-infrastructure/apps/mereka-lms/overlays/<env>/patches/` for LMS
Django settings in this deployment.

## Related

- PR #1875 (slice 60, original no-op attempt — both parts retracted)
- PR #1881 (slice 63, retracted FEATURES portion)
- PR #1882 (slice 64, original evidence — still correct about app-repo shadow being dead)
- PR #1883 (slice 65, retracted setdefault + added warning headers — headers need pointer update)
- PR #1885 (slice 67, correction addendum identifying the configmap layer)
- Beads: `mereka-lms-mefk` (audit), `mereka-lms-vfd5` (MFE_CONFIG exposure)
- bbi-infra PR #2716 (mount custom video api routes) — example of correctly dual-shipped change
- bbi-infra PR #2852 (sync openedx probe contract) — last touched the now-confirmed-non-authoritative `apps/mereka-lms/base/` vendored copy
