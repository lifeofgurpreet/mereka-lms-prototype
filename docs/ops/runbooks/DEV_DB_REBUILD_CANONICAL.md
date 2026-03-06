# Dev Open edX DB Rebuild (Canonical, Guarded)

_Audience: Platform Operators / SRE • Owner: Infra Team • Last updated: 2026-03-06_

Audience: platform operators, SRE

## Purpose

Use this runbook when the non-production Open edX MySQL schema state is unrecoverable (for example, `django_migrations` diverged from actual schema after manual migration-table edits) and a clean rebuild is required.

This procedure is intentionally aligned with the repository data-protection rules:
- dry-run first
- pre-op Velero backup before destructive steps
- explicit destructive confirmation token
- no ad-hoc `kubectl exec ... manage.py migrate --fake` recovery

## Scope and Constraints

- Target environment: non-production (`rke2-nonprod` by default)
- Namespace: `mereka-lms`
- Canonical entrypoint script: `scripts/infra/rebuild-dev-openedx-db.sh`
- Production-like contexts are blocked by default in the script

## 1. Preflight (Dry-run)

```bash
./scripts/infra/rebuild-dev-openedx-db.sh
```

Expected behavior:
- no cluster changes
- prints targeted MySQL PVCs
- prints exact guarded destructive command

## 2. Execute Guarded Rebuild

```bash
RUN_DESTRUCTIVE=1 \
CONFIRM_REBUILD_DEV_DB=REBUILD_DEV_DB \
./scripts/infra/rebuild-dev-openedx-db.sh
```

What the script does in destructive mode:
1. Creates Velero pre-op backup (`pre-op-<namespace>-dev-db-rebuild-<timestamp>`) unless explicitly disabled.
2. Scales MySQL deployment to 0.
3. Deletes MySQL PVC(s) in the namespace.
4. Scales MySQL deployment back to 1 and waits for rollout.
5. Restarts Open edX service deployments so init/migration paths run through deployment graph.

## 3. Post-Rebuild Verification

```bash
KUBE_CONTEXT=rke2-nonprod ./scripts/qa/verify-rke2-dev-readiness.sh --online
kubectl --context rke2-nonprod -n mereka-lms get pods
kubectl --context rke2-nonprod -n mereka-lms get jobs
```

Minimum success conditions:
- MySQL deployment is `Available`
- LMS/CMS and enterprise services are `Running`
- no migration init-container crash loops

## 4. Rollback

If the rebuild does not converge, restore the pre-op backup created in step 2.

Reference commands:

```bash
# List recent backups
velero backup get

# Restore from the pre-op backup created by rebuild script
velero restore create --from-backup <pre-op-backup-name>
```

Then re-run the verification commands in section 3.

## Notes

- Keep this flow operator-driven and auditable.
- Do not bypass script guardrails with manual migration-table editing.
- If production recovery is required, follow the production DR runbook and explicit approval flow.
