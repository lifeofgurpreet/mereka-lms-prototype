#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004
# @spec: disaster-recovery-business-continuity_spec.md
# End-to-end Velero backup posture audit (read-only).
#
# Goals:
# - Remove tribal knowledge around "are backups actually happening?"
# - Catch silent failure modes (no snapshots, BSL unavailable, broken restore drill job).
# - Surface app-level data-risk signals (e.g., DBs on emptyDir) that Velero cannot protect.
#
# Usage:
#   ./scripts/qa/audit-velero.sh
#   ./scripts/qa/audit-velero.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
#   ./scripts/qa/audit-velero.sh --json
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}"
VELERO_NS="${VELERO_NS:-velero}"
APP_NS="${APP_NS:-${K8S_NAMESPACE_PROD:-${K8S_NAMESPACE:-mereka-lms}}}"
JSON_OUT=0

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/audit-velero.sh [--context CONTEXT] [--velero-namespace NS] [--app-namespace NS] [--json]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) K8S_CONTEXT="${2:-}"; shift 2 ;;
    --velero-namespace) VELERO_NS="${2:-}"; shift 2 ;;
    --app-namespace) APP_NS="${2:-}"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[SKIP] kubectl not available — skipping cluster checks"
  exit 0
fi

kubectl_json() {
  kubectl --context "$K8S_CONTEXT" -n "$1" get "$2" -o json 2>/dev/null || echo '{"items":[]}'
}

kubectl_json_cluster() {
  kubectl --context "$K8S_CONTEXT" get "$1" -o json 2>/dev/null || echo '{"items":[]}'
}

warn() { printf "WARN: %s\n" "$*" >&2; }
fail() { printf "FAIL: %s\n" "$*" >&2; }
ok() { printf "OK: %s\n" "$*"; }

tmpdir="$(mktemp -d -t audit-velero.XXXXXX)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT
export tmpdir APP_NS

bsls_json="$tmpdir/bsls.json"
vsls_json="$tmpdir/vsls.json"
vscs_json="$tmpdir/volumesnapshotclasses.json"
schedules_json="$tmpdir/schedules.json"
backups_json="$tmpdir/backups.json"
cronjobs_json="$tmpdir/cronjobs.json"
jobs_json="$tmpdir/jobs.json"
app_pvcs_json="$tmpdir/app_pvcs.json"
app_mongodb_json="$tmpdir/app_mongodb.json"
app_mongodb_svc_json="$tmpdir/app_mongodb_svc.json"
app_mongodb_ep_json="$tmpdir/app_mongodb_ep.json"
app_lms_json="$tmpdir/app_lms.json"
app_cms_json="$tmpdir/app_cms.json"
openedx_secrets_json="$tmpdir/openedx_secrets.json"

kubectl_json "$VELERO_NS" backupstoragelocations.velero.io >"$bsls_json"
kubectl_json "$VELERO_NS" volumesnapshotlocations.velero.io >"$vsls_json"
kubectl_json_cluster volumesnapshotclasses.snapshot.storage.k8s.io >"$vscs_json" || echo '{"items":[]}' >"$vscs_json"
kubectl_json "$VELERO_NS" schedules.velero.io >"$schedules_json"
kubectl_json "$VELERO_NS" backups.velero.io >"$backups_json"
kubectl_json "$VELERO_NS" cronjobs.batch >"$cronjobs_json"
kubectl_json "$VELERO_NS" jobs.batch >"$jobs_json"

kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get pvc -o json 2>/dev/null >"$app_pvcs_json" || echo '{"items":[]}' >"$app_pvcs_json"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy mongodb -o json 2>/dev/null >"$app_mongodb_json" || echo '{}' >"$app_mongodb_json"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get svc mongodb -o json 2>/dev/null >"$app_mongodb_svc_json" || echo '{}' >"$app_mongodb_svc_json"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get endpoints mongodb -o json 2>/dev/null >"$app_mongodb_ep_json" || echo '{}' >"$app_mongodb_ep_json"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy lms -o json 2>/dev/null >"$app_lms_json" || echo '{}' >"$app_lms_json"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy cms -o json 2>/dev/null >"$app_cms_json" || echo '{}' >"$app_cms_json"
kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get secret openedx-secrets -o json 2>/dev/null >"$openedx_secrets_json" || echo '{}' >"$openedx_secrets_json"

ns_list="$(
  python3 - "$schedules_json" <<'PY'
import json, sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
namespaces = set()
for item in data.get("items", []):
    tpl = (item.get("spec") or {}).get("template") or {}
    for ns in (tpl.get("includedNamespaces") or []):
        if isinstance(ns, str) and ns.strip():
            namespaces.add(ns.strip())
print(" ".join(sorted(namespaces)))
PY
)"

for ns in $ns_list; do
  kubectl --context "$K8S_CONTEXT" -n "$ns" get pvc -o json 2>/dev/null \
    >"$tmpdir/pvc_${ns}.json" || echo '{"items":[]}' >"$tmpdir/pvc_${ns}.json"

  kubectl --context "$K8S_CONTEXT" -n "$ns" get volumesnapshots.snapshot.storage.k8s.io -o json 2>/dev/null \
    >"$tmpdir/vs_${ns}.json" || echo '{"items":[]}' >"$tmpdir/vs_${ns}.json"
done

report_json="$(python3 - <<'PY'
import json, os, sys
from datetime import datetime, timezone
from pathlib import Path

tmpdir = os.environ.get("tmpdir") or ""

def load(path, default):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return default

def iso_to_dt(s):
    if not s:
        return None
    try:
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        return datetime.fromisoformat(s).astimezone(timezone.utc)
    except Exception:
        return None

def now():
    return datetime.now(timezone.utc)

paths = {
    "bsls": os.path.join(tmpdir, "bsls.json"),
    "vsls": os.path.join(tmpdir, "vsls.json"),
    "vscs": os.path.join(tmpdir, "volumesnapshotclasses.json"),
    "schedules": os.path.join(tmpdir, "schedules.json"),
    "backups": os.path.join(tmpdir, "backups.json"),
    "cronjobs": os.path.join(tmpdir, "cronjobs.json"),
    "jobs": os.path.join(tmpdir, "jobs.json"),
    "app_pvcs": os.path.join(tmpdir, "app_pvcs.json"),
    "app_mongodb": os.path.join(tmpdir, "app_mongodb.json"),
    "app_mongodb_svc": os.path.join(tmpdir, "app_mongodb_svc.json"),
    "app_mongodb_ep": os.path.join(tmpdir, "app_mongodb_ep.json"),
    "app_lms": os.path.join(tmpdir, "app_lms.json"),
    "app_cms": os.path.join(tmpdir, "app_cms.json"),
    "openedx_secrets": os.path.join(tmpdir, "openedx_secrets.json"),
}

bsls = load(paths["bsls"], {"items": []})
vsls = load(paths["vsls"], {"items": []})
vscs = load(paths["vscs"], {"items": []})
schedules = load(paths["schedules"], {"items": []})
backups = load(paths["backups"], {"items": []})
cronjobs = load(paths["cronjobs"], {"items": []})
jobs = load(paths["jobs"], {"items": []})
app_pvcs = load(paths["app_pvcs"], {"items": []})
app_mongodb = load(paths["app_mongodb"], {})
app_mongodb_svc = load(paths["app_mongodb_svc"], {})
app_mongodb_ep = load(paths["app_mongodb_ep"], {})
app_lms = load(paths["app_lms"], {})
app_cms = load(paths["app_cms"], {})
openedx_secrets = load(paths["openedx_secrets"], {})

def load_prefixed(prefix: str):
    out = {}
    for child in Path(tmpdir).glob(prefix + "*.json"):
        try:
            key = child.stem[len(prefix):]
            out[key] = json.loads(child.read_text(encoding="utf-8"))
        except Exception:
            continue
    return out

pvc_by_ns = load_prefixed("pvc_")
vs_by_ns = load_prefixed("vs_")

def emit(obj):
    print(json.dumps(obj, indent=2, sort_keys=True))

def summarize():
    out = {
        "velero": {
            "backup_storage_locations": [],
            "volume_snapshot_locations": [],
            "volume_snapshot_classes": [],
            "schedules": [],
            "restore_drill": {},
            "backup_verification": {},
        },
        "coverage": {
            "pvc_by_namespace": {},
            "modulestore_runtime": {},
        },
        "app_data_risks": [],
        "checks": {"failures": 0, "warnings": 0},
    }

    def is_atlas_host(value):
        host = (value or "").strip().lower()
        return host.startswith("mongodb+srv://") or ".mongodb.net" in host

    def resolve_env_var(deploy_obj, name):
        env = ((((deploy_obj.get("spec") or {}).get("template") or {}).get("spec") or {}).get("containers") or [{}])[0].get("env") or []
        for item in env:
            if (item or {}).get("name") != name:
                continue
            if "value" in (item or {}):
                return item.get("value")
            ref = ((item.get("valueFrom") or {}).get("secretKeyRef") or {})
            key = ref.get("key")
            if key:
                data = (openedx_secrets.get("data") or {}).get(key)
                if data:
                    try:
                        import base64
                        return base64.b64decode(data).decode("utf-8")
                    except Exception:
                        return None
        return None

    # BSLs
    for b in bsls.get("items", []):
        st = (b.get("status") or {})
        out["velero"]["backup_storage_locations"].append({
            "name": b.get("metadata", {}).get("name"),
            "phase": st.get("phase"),
            "last_validation_time": st.get("lastValidationTime"),
            "is_default": bool(b.get("spec", {}).get("default")),
        })

    if not out["velero"]["backup_storage_locations"]:
        out["checks"]["failures"] += 1
        out["app_data_risks"].append({
            "severity": "critical",
            "risk": "Velero has no BackupStorageLocation. Backups cannot be stored.",
        })
    else:
        bad = [x for x in out["velero"]["backup_storage_locations"] if x.get("phase") != "Available"]
        if bad:
            out["checks"]["failures"] += 1
            out["app_data_risks"].append({
                "severity": "critical",
                "risk": f"BackupStorageLocation(s) not Available: {[x.get('name') for x in bad]}",
            })

    # VSLs
    for v in vsls.get("items", []):
        out["velero"]["volume_snapshot_locations"].append({
            "name": v.get("metadata", {}).get("name"),
        })

    if not out["velero"]["volume_snapshot_locations"]:
        out["checks"]["warnings"] += 1
        out["app_data_risks"].append({
            "severity": "warning",
            "risk": "No VolumeSnapshotLocation found. PV snapshots may not be configured.",
        })

    # VolumeSnapshotClasses (CSI snapshot plumbing)
    for c in vscs.get("items", []):
        out["velero"]["volume_snapshot_classes"].append({
            "name": c.get("metadata", {}).get("name"),
            "driver": (c.get("driver") or (c.get("spec") or {}).get("driver")),
            "deletion_policy": (c.get("deletionPolicy") or (c.get("spec") or {}).get("deletionPolicy")),
        })
    # Note: VolumeSnapshotClass is relevant only for CSI-based snapshotting. Velero can also
    # take snapshots via provider plugins without CSI VolumeSnapshot resources, so we do not
    # treat this as a failure or warning by itself.

    # Coverage inventory: Bound/Pending PVC counts by namespace (rough expected snapshot coverage)
    for ns, data in pvc_by_ns.items():
        bound = 0
        pending = 0
        for pvc in data.get("items", []):
            phase = (pvc.get("status") or {}).get("phase") or ""
            if phase == "Bound":
                bound += 1
            elif phase == "Pending":
                pending += 1
        out["coverage"]["pvc_by_namespace"][ns] = {"bound": bound, "pending": pending}

    # Schedules and their latest backup
    backups_items = backups.get("items", [])
    by_schedule = {}
    for b in backups_items:
        labels = (b.get("metadata") or {}).get("labels") or {}
        sched = labels.get("velero.io/schedule-name") or ""
        if not sched:
            continue
        by_schedule.setdefault(sched, []).append(b)

    def latest_completed(backup_list):
        completed = []
        for b in backup_list:
            st = (b.get("status") or {})
            if st.get("phase") != "Completed":
                continue
            dt = iso_to_dt(st.get("completionTimestamp")) or iso_to_dt((b.get("metadata") or {}).get("creationTimestamp"))
            if not dt:
                continue
            completed.append((dt, b))
        if not completed:
            return None
        completed.sort(key=lambda x: x[0], reverse=True)
        return completed[0][1]

    for s in schedules.get("items", []):
        name = s.get("metadata", {}).get("name")
        spec = s.get("spec") or {}
        tpl = spec.get("template") or {}
        included_ns = tpl.get("includedNamespaces") or []

        latest = latest_completed(by_schedule.get(name, []))
        latest_summary = None
        if latest:
            st = latest.get("status") or {}
            completed_at = st.get("completionTimestamp")
            completed_dt = iso_to_dt(completed_at)
            age_hours = None
            if completed_dt:
                age_hours = (now() - completed_dt).total_seconds() / 3600.0
            latest_summary = {
                "name": latest.get("metadata", {}).get("name"),
                "completed_at": completed_at,
                "age_hours": age_hours,
                "volume_snapshots_attempted": st.get("volumeSnapshotsAttempted"),
                "volume_snapshots_completed": st.get("volumeSnapshotsCompleted"),
            }

            # Critical: schedule targets "critical-databases" but snapshots are 0
            if "critical" in (name or ""):
                attempted = st.get("volumeSnapshotsAttempted") or 0
                if attempted == 0:
                    out["checks"]["failures"] += 1
                    out["app_data_risks"].append({
                        "severity": "critical",
                        "risk": f"Backup {latest_summary['name']} completed with 0 volume snapshots attempted. This is a manifest-only backup.",
                    })

            # Coverage sanity: compare snapshots completed to bound PVC count across included namespaces.
            expected_bound = 0
            for ns in included_ns:
                if not isinstance(ns, str) or not ns.strip():
                    continue
                expected_bound += out["coverage"]["pvc_by_namespace"].get(ns.strip(), {}).get("bound", 0)

            completed = st.get("volumeSnapshotsCompleted")
            if isinstance(completed, int) and expected_bound > 0 and completed < expected_bound:
                msg = (
                    f"Backup {latest_summary['name']} snapshots_completed={completed} but expected_bound_pvcs={expected_bound} "
                    f"(included_namespaces={included_ns})."
                )
                if "hourly" in (name or "") or "critical" in (name or ""):
                    out["checks"]["failures"] += 1
                    out["app_data_risks"].append({"severity": "critical", "risk": msg})
                else:
                    out["checks"]["warnings"] += 1
                    out["app_data_risks"].append({"severity": "warning", "risk": msg})

            # Recency sanity: a "working" backup program must also be recent.
            if age_hours is not None:
                # Heuristics by schedule name.
                if "hourly" in (name or "") and age_hours > 2.5:
                    out["checks"]["failures"] += 1
                    out["app_data_risks"].append({
                        "severity": "critical",
                        "risk": f"Hourly schedule {name} latest completed backup is stale ({age_hours:.1f}h old).",
                    })
                elif "daily" in (name or "") and age_hours > 30:
                    out["checks"]["warnings"] += 1
                    out["app_data_risks"].append({
                        "severity": "warning",
                        "risk": f"Daily schedule {name} latest completed backup is stale ({age_hours:.1f}h old).",
                    })
                elif "weekly" in (name or "") and age_hours > 24 * 8:
                    out["checks"]["warnings"] += 1
                    out["app_data_risks"].append({
                        "severity": "warning",
                        "risk": f"Weekly schedule {name} latest completed backup is stale ({age_hours:.1f}h old).",
                    })

        out["velero"]["schedules"].append({
            "name": name,
            "schedule": spec.get("schedule"),
            "paused": bool(spec.get("paused", False)),
            "ttl": tpl.get("ttl"),
            "include_cluster_resources": bool(tpl.get("includeClusterResources", False)),
            "included_namespaces": included_ns,
            "excluded_namespaces": tpl.get("excludedNamespaces") or [],
            "volume_snapshot_locations": tpl.get("volumeSnapshotLocations") or [],
            "latest_completed_backup": latest_summary,
        })

    # Restore drill posture (CronJob: restore-test)
    restore_cj = next((c for c in cronjobs.get("items", []) if c.get("metadata", {}).get("name") == "restore-test"), None)
    restore_status = {"exists": bool(restore_cj)}
    if restore_cj:
        spec = (((restore_cj.get("spec") or {}).get("jobTemplate") or {}).get("spec") or {}).get("template", {}).get("spec", {})
        containers = spec.get("containers") or []
        c0 = containers[0] if containers else {}
        image = c0.get("image") or ""
        cmd = c0.get("command") or []
        env_items = c0.get("env") or []
        env_map = {}
        for it in env_items:
            name = (it or {}).get("name")
            val = (it or {}).get("value")
            if isinstance(name, str) and name:
                env_map[name] = val
        restore_status.update({
            "schedule": (restore_cj.get("spec") or {}).get("schedule"),
            "last_schedule_time": (restore_cj.get("status") or {}).get("lastScheduleTime"),
            "container_image": image,
            "container_command": cmd,
            "config": {
                "preferred_schedule": env_map.get("PREFERRED_SCHEDULE"),
                "restore_persistent_resources": env_map.get("RESTORE_PERSISTENT_RESOURCES"),
                "require_pvc_restore": env_map.get("REQUIRE_PVC_RESTORE"),
                "verify_restored_mysql": env_map.get("VERIFY_RESTORED_MYSQL"),
            },
        })

        # Known-bad: velero image does not ship /bin/bash, but CronJob uses it.
        if any(x.endswith("/bin/bash") or x == "/bin/bash" for x in cmd) and ("velero/velero:" in image or image.startswith("velero/velero")):
            out["checks"]["failures"] += 1
            out["app_data_risks"].append({
                "severity": "critical",
                "risk": "Velero restore drill CronJob is misconfigured: image is velero/velero but command uses /bin/bash. The job will StartError and drills will silently fail.",
                "fix_hint": "Patch the restore-test CronJob to use an image that actually includes a shell + tooling, or rewrite it to not require bash/jq.",
            })

        restore_persistent = str(env_map.get("RESTORE_PERSISTENT_RESOURCES") or "").lower() in {"1", "true", "yes"}
        require_pvc = str(env_map.get("REQUIRE_PVC_RESTORE") or "").lower() in {"1", "true", "yes"}
        verify_mysql = str(env_map.get("VERIFY_RESTORED_MYSQL") or "").lower() in {"1", "true", "yes"}
        if not restore_persistent:
            out["checks"]["failures"] += 1
            out["app_data_risks"].append({
                "severity": "critical",
                "risk": "restore-test is configured without persistent resource restore validation (RESTORE_PERSISTENT_RESOURCES!=true).",
                "fix_hint": "Set RESTORE_PERSISTENT_RESOURCES=true on velero/restore-test CronJob.",
            })
        if not require_pvc:
            out["checks"]["failures"] += 1
            out["app_data_risks"].append({
                "severity": "critical",
                "risk": "restore-test does not require restored PVCs to bind (REQUIRE_PVC_RESTORE!=true).",
                "fix_hint": "Set REQUIRE_PVC_RESTORE=true on velero/restore-test CronJob.",
            })
        if not verify_mysql:
            out["checks"]["warnings"] += 1
            out["app_data_risks"].append({
                "severity": "warning",
                "risk": "restore-test is not probing restored MySQL with a read-only query (VERIFY_RESTORED_MYSQL!=true).",
                "fix_hint": "Set VERIFY_RESTORED_MYSQL=true on velero/restore-test CronJob.",
            })

        # Last restore job status (best-effort)
        restore_jobs = [j for j in jobs.get("items", []) if j.get("metadata", {}).get("labels", {}).get("component") == "restore-test"]
        if restore_jobs:
            restore_jobs.sort(key=lambda j: iso_to_dt(j.get("metadata", {}).get("creationTimestamp")) or datetime(1970,1,1,tzinfo=timezone.utc), reverse=True)
            j0 = restore_jobs[0]
            st = j0.get("status") or {}
            restore_status["last_job"] = {
                "name": j0.get("metadata", {}).get("name"),
                "created_at": j0.get("metadata", {}).get("creationTimestamp"),
                "succeeded": st.get("succeeded", 0),
                "failed": st.get("failed", 0),
            }

    out["velero"]["restore_drill"] = restore_status

    # Backup verification CronJob posture (CronJob: backup-verification)
    verify_cj = next((c for c in cronjobs.get("items", []) if c.get("metadata", {}).get("name") == "backup-verification"), None)
    verify_status = {"exists": bool(verify_cj)}
    if verify_cj:
        verify_status.update({
            "schedule": (verify_cj.get("spec") or {}).get("schedule"),
            "last_schedule_time": (verify_cj.get("status") or {}).get("lastScheduleTime"),
            "last_successful_time": (verify_cj.get("status") or {}).get("lastSuccessfulTime"),
        })
        last_ok = iso_to_dt(verify_status.get("last_successful_time"))
        if not last_ok:
            out["checks"]["warnings"] += 1
            out["app_data_risks"].append({
                "severity": "warning",
                "risk": "backup-verification CronJob has no lastSuccessfulTime; verification may not be running.",
            })
        else:
            age_hours = (now() - last_ok).total_seconds() / 3600.0
            if age_hours > 30:
                out["checks"]["warnings"] += 1
                out["app_data_risks"].append({
                    "severity": "warning",
                    "risk": f"backup-verification lastSuccessfulTime is stale ({age_hours:.1f}h ago).",
                })

    out["velero"]["backup_verification"] = verify_status

    # App-level data risk signals (mereka-lms)
    lms_mongodb_host = resolve_env_var(app_lms, "MONGODB_HOST")
    cms_mongodb_host = resolve_env_var(app_cms, "MONGODB_HOST")
    lms_is_atlas = is_atlas_host(lms_mongodb_host)
    cms_is_atlas = is_atlas_host(cms_mongodb_host)
    out["coverage"]["modulestore_runtime"] = {
        "lms_mongodb_host_is_atlas": lms_is_atlas,
        "cms_mongodb_host_is_atlas": cms_is_atlas,
    }

    # 1) PVCs pending
    pending = []
    for pvc in app_pvcs.get("items", []):
        if (pvc.get("status") or {}).get("phase") == "Pending":
            pending.append(pvc.get("metadata", {}).get("name"))
    if pending:
        out["checks"]["warnings"] += 1
        out["app_data_risks"].append({
            "severity": "warning",
            "risk": f"PVC(s) Pending in {os.environ.get('APP_NS', 'mereka-lms')}: {pending}",
        })

    # 2) MongoDB Deployment using emptyDir (ephemeral)
    try:
        vols = (((app_mongodb.get("spec") or {}).get("template") or {}).get("spec") or {}).get("volumes") or []
        if any("emptyDir" in (v or {}) for v in vols):
            if lms_is_atlas and cms_is_atlas:
                out["checks"]["warnings"] += 1
                out["app_data_risks"].append({
                    "severity": "warning",
                    "risk": "mereka-lms/mongodb Deployment uses emptyDir, but LMS/CMS modulestore is currently configured to Atlas. Keep this deployment out of the production data path or migrate it to PVC-backed storage before reuse.",
                    "fix_hint": "Preferred: remove legacy in-cluster MongoDB after cutover verification. Interim: add PVC-backed storage if it must remain active.",
                })
            else:
                out["checks"]["failures"] += 1
                out["app_data_risks"].append({
                    "severity": "critical",
                    "risk": "mereka-lms/mongodb Deployment uses emptyDir for /data/db (ephemeral). If modulestore is pointed at in-cluster MongoDB, course content will be lost on pod reschedule/restart.",
                    "fix_hint": "Move modulestore to Atlas OR add a PVC-backed volume to MongoDB before importing any courses.",
                })
    except Exception:
        pass

    # 3) Legacy mongodb Service drift
    try:
        svc_exists = bool((app_mongodb_svc.get("metadata") or {}).get("name"))
        deploy_exists = bool((app_mongodb.get("metadata") or {}).get("name"))
        has_endpoints = bool((app_mongodb_ep.get("subsets") or []))
        if svc_exists and not deploy_exists:
            out["checks"]["warnings"] += 1
            out["app_data_risks"].append({
                "severity": "warning",
                "risk": "legacy Service/mongodb exists without a deployment; remove the orphan service via production overlay GitOps patch.",
                "fix_hint": "Keep deploy/k8s/overlays/production/patches/remove-legacy-mongodb-service.yaml applied and synced.",
            })
        elif svc_exists and has_endpoints and not (lms_is_atlas and cms_is_atlas):
            out["checks"]["failures"] += 1
            out["app_data_risks"].append({
                "severity": "critical",
                "risk": "legacy Service/mongodb has active endpoints while modulestore is not fully Atlas-backed.",
                "fix_hint": "Complete Atlas cutover before relying on in-cluster MongoDB paths.",
            })
    except Exception:
        pass

    return out

emit(summarize())
PY
)"

if [[ "$JSON_OUT" -eq 1 ]]; then
  printf "%s\n" "$report_json"
  exit 0
fi

python3 -c '
import json, sys
d = json.loads(sys.stdin.read() or "{}")

checks = d.get("checks") or {}
failures = int(checks.get("failures") or 0)
warnings = int(checks.get("warnings") or 0)

print(f"Velero audit: failures={failures} warnings={warnings}")

velero = d.get("velero") or {}
bsls = velero.get("backup_storage_locations") or []
if bsls:
  for b in bsls:
    name = b.get("name")
    phase = b.get("phase")
    print(f"BSL {name}: {phase}")
else:
  print("BSL: <none>")

restore = velero.get("restore_drill") or {}
restore_exists = bool(restore.get("exists"))
print(f"Restore drill exists: {restore_exists}")
if restore.get("last_job"):
  lj = restore["last_job"]
  jn = lj.get("name")
  js = lj.get("succeeded")
  jf = lj.get("failed")
  print(f"Restore last job: {jn} succeeded={js} failed={jf}")

verify = velero.get("backup_verification") or {}
verify_exists = bool(verify.get("exists"))
print(f"Backup verification exists: {verify_exists}")
if verify.get("last_successful_time"):
  ts = verify.get("last_successful_time")
  print(f"Backup verification last OK: {ts}")

print("")
risks = d.get("app_data_risks") or []
if risks:
  print("Findings:")
  for r in risks:
    sev = (r.get("severity") or "").upper()
    risk = r.get("risk") or ""
    if sev and risk:
      print(f"- {sev}: {risk}")
else:
  print("Findings: none")

sys.exit(1 if failures else 0)
' <<<"$report_json"
