# DEV Convergence Resume
_Audience: Operators and reviewers • Owner: Platform Team • Last verified: 2026-03-20 • Status: active_

This is the single canonical resume and handoff doc for the current DEV convergence lane.

## Read First

1. `docs/status/active/DEV_CONVERGENCE_LEDGER.md`
2. `docs/status/active/DEV_CONVERGENCE_PARKED_ISSUES.md`
3. `deploy/k8s/RUNTIME_AUTHORITY_MAP.md`
4. `docs/ops/runbooks/DEV_CONVERGENCE_PROOF_CHECKLIST.md`

## Canonical Operator Front Door

- App-owned operational concerns: `bin/lms-ops`
- Domain and tenant truth: `deploy/k8s/tenancy/tenant-registry.yaml`
- Static domain drift gate: `scripts/qa/verify-domain-url-invariants.sh`
- Repeatable Site/SiteConfiguration apply path: `scripts/tenants/seed-siteconfigs.sh`
- Live DEV GitOps consumer: `bbi-infrastructure/apps/mereka-lms/overlays/profiles/dev`
- DEV Notes host-domain correction path: `bbi-infrastructure/apps/mereka-lms/overlays/dev/patches/satellite-services-domain.yaml`
- Live DEV drift-suppression policy: `kubectl get application mereka-lms-dev -n argocd -o yaml`

## DEV Re-Verification Commands

```bash
kubectl config current-context
kubectl get applications.argoproj.io -A | rg 'mereka-lms-dev'
kubectl get application mereka-lms-dev -n argocd -o yaml
kubectl get deploy,pods,svc,ingress -n mereka-lms-dev
kubectl get deploy caddy,lms,cms -n mereka-lms-dev -o json
kubectl get deploy notes -n mereka-lms-dev -o yaml | rg 'MEREKA_LMS_DOMAIN|NOTES_DOMAIN|value:'
kubectl logs deploy/caddy -n mereka-lms-dev --tail=120 | rg 'notes\.academyv2\.mereka\.dev|status\":400'
kubectl logs deploy/notes -n mereka-lms-dev --tail=400 | rg 'Invalid HTTP_HOST|DisallowedHost'
python3 - <<'PY'
import ssl, urllib.request
for host in [
    "academyv2.mereka.dev",
    "studio.academyv2.mereka.dev",
    "apps.academyv2.mereka.dev",
    "biji-biji.academyv2.mereka.dev",
    "studio.biji-biji.academyv2.mereka.dev",
    "apps.biji-biji.academyv2.mereka.dev",
    "skillourfuture.academyv2.mereka.dev",
    "studio.skillourfuture.academyv2.mereka.dev",
    "apps.skillourfuture.academyv2.mereka.dev",
]:
    with urllib.request.urlopen(
        urllib.request.Request(f"https://{host}/", headers={"User-Agent": "codex-resume"}),
        context=ssl._create_unverified_context(),
        timeout=15,
    ) as resp:
        print(host, resp.status, resp.getheader("Content-Type"))
PY
```

## Lane Guardrails

- DEV only.
- Do not treat runtime-only DB state as durable truth.
- Do not treat app-repo `deploy/k8s/overlays/rke2-nonprod` as the live DEV source unless ArgoCD source proves it.
- Do not treat ArgoCD `Synced` / `Healthy` as ConfigMap proof when the live Application ignores ConfigMap `/data` and keeps `Prune=false`.
- Do not call a host-level `400` an ingress problem until ingress, proxy logs, pod logs, and effective deployment env agree on the owner layer.
- Do not call a repo-only consumer patch a live fix until ArgoCD has applied it and the public host has been reprobed.
- Do not treat local untracked notes as canonical handoff.
- Do not widen scope into staging, prod, or UI polish unless the parked ledger explicitly moves an item back into scope.
- Do not claim browser correctness from `curl` alone when auth behavior matters.
