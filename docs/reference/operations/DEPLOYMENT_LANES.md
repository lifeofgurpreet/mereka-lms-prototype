# Deployment Lanes

**Audience**: Platform engineers and on-call operators.

This document is the canonical environment-truth reference for Mereka LMS.
Except for `local`, **ArgoCD does not deploy from `deploy/k8s/overlays/*` in this
repo**. Non-local deployment is realized in
`bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/`.

---

## Current Truth

| Lane | Domains | Cluster now | App repo overlay artifact | GitOps source of truth | Status |
|------|---------|-------------|---------------------------|------------------------|--------|
| **local** | `localhost` | Kind / Minikube | `deploy/k8s/overlays/local` | N/A | Active |
| **dev** | `*.academyv2.mereka.dev` | shared `rke2-nonprod` | `deploy/k8s/overlays/rke2-nonprod` | `bbi-infrastructure/apps/mereka-lms/overlays/dev/` | Active |
| **staging** | `staging.*.mereka.io` | shared `rke2-nonprod` | `deploy/k8s/overlays/staging` | `bbi-infrastructure/apps/mereka-lms/overlays/staging/` | Active on shared cluster; split-ready for a dedicated RKE2 staging cluster later |
| **prod** | `*.academyv2.mereka.io` | GKE `bbi-k8-cluster` | `deploy/k8s/overlays/production` | `bbi-infrastructure/apps/mereka-lms/overlays/prod/` | Parked / explicit promotion only; keep zero replicas until dev + staging are green and leadership signs off |

---

## Promotion Path

```text
local
  -> dev      (shared rke2-nonprod)
  -> staging  (shared rke2-nonprod, separate domains / namespaces / secrets)
  -> prod     (GKE, parked, explicit promotion only)
```

`dev` and `staging` are different environment truths even though they currently
share the same cluster. Do not collapse environment truth into current cluster
placement.

---

## Overlay Roles

### local

`deploy/k8s/overlays/local` is the only permanently app-owned overlay in this
repo. Use it for local development and smoke checks.

### rke2-nonprod

`deploy/k8s/overlays/rke2-nonprod` is a **reference overlay artifact** for the
current dev lane. It remains in this repo so the base/exported manifest shape,
image-tag contract, and nonprod patch structure are visible alongside the app.
ArgoCD does **not** deploy from it directly.

### staging

`deploy/k8s/overlays/staging` is a **reference overlay artifact** for the
current staging lane. It models staging domains and secrets while explicitly
documenting that staging currently shares `rke2-nonprod` with dev. It is not a
deprecated fake lane, and it is not a dedicated staging cluster today.

### production

`deploy/k8s/overlays/production` is a **reference overlay artifact** for the
parked GKE prod lane. Keep it structurally aligned with nonprod, but do not
present it as the default validation target or a live learner-serving lane.

---

## Future Topology

- `staging` will move to its own RKE2 cluster when the shared nonprod lane is stable.
- `prod` remains on GKE for now.
- The long-term target is RKE2 for all lanes, but that future migration does not
  change the current dev/staging/prod environment truth.

---

## Operator Rules

- Do not treat `deploy/k8s/overlays/{rke2-nonprod,staging,production}` as live
  ArgoCD sources.
- Do not describe staging as “deprecated” or “never activated”.
- Do not describe prod as the default validation lane while it is intentionally parked.
- If a script needs a live non-local deployment target, it should point operators
  at the matching `bbi-infrastructure` overlay or cluster runbook, not this repo’s
  frozen overlay artifact.

---

## Related Documentation

- [deploy/k8s/overlays/README.md](../../../deploy/k8s/overlays/README.md)
- [deploy/DEPLOYMENT.md](../../../deploy/DEPLOYMENT.md)
- [DEPLOYMENT_CONTRACT.md](../architecture/DEPLOYMENT_CONTRACT.md)
- `bbi-infrastructure/ENVIRONMENTS.md`
