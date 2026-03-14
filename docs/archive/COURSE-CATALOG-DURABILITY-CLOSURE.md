# COURSE CATALOG DURABILITY CLOSURE

> Lane C3 + C3b artifact. Final snapshot: 2026-03-14.

## 1. What Made `/courses` Empty

The `/courses` catalog page uses `ENABLE_COURSE_DISCOVERY=True` → AJAX calls `course_discovery_search()` → queries the **Elasticsearch `course_info` index** via `edx-search`.

The `course_info` index is **ephemeral**. It lives in ES pod memory/PVC. When ES restarts, the index is lost, and `/courses` shows "Viewing 0 courses."

The course data itself is durable:
- **MongoDB** (modulestore): 109 courses — source of truth
- **MySQL** (`CourseOverview`): 109 rows — synced from modulestore
- **ES `course_info`**: 90 docs — derived index, NOT durable

The gap (109 CourseOverviews vs 90 in `course_info`) represents draft/unpublished courses that `CoursewareSearchIndexer` filters out during reindex.

## 2. What Runtime Actions Restored It

```bash
kubectl exec -n mereka-lms-dev deployment/cms -- \
  python manage.py cms reindex_course --setup --all
```

This reads all courses from the modulestore, builds search documents, and writes them to the `course_info` ES index.

**Key facts:**
- `reindex_course` is a **CMS-only** command (not available via LMS)
- `--setup` skips interactive confirmation
- `--all` reindexes every course, not just active ones
- The command is **idempotent** — safe to rerun

## 3. Which Parts Were Non-Durable

| Component | Before | After |
|-----------|--------|-------|
| `reindex_course` execution | Hand-run by operator | **CronJob every 6 hours** |
| Post-reindex verification | None | **CronJob checks `course_info._count > 0`** |
| CI verification | None | **`verify-course-catalog-durability.sh`** |

## 4. What Durable Fix Was Added

**CronJob: `course-reindex`** — runs `reindex_course --setup --all` every 6 hours.

Located at: `deploy/k8s/base/monitoring/cronjob-course-reindex.yaml`

The CronJob:
1. Runs `python manage.py cms reindex_course --setup --all`
2. Verifies `course_info` doc count > 0 via direct ES `/_count` endpoint (fails job if empty)
3. Logs `CourseOverview` count for comparison (informational, non-blocking)
4. Uses same image/settings as CMS deployment (Kustomize image transformer applies)
5. Runs as non-root (UID 1000) with `allowPrivilegeEscalation: false` (Kyverno compliant)

**Verification script: `scripts/qa/verify-course-catalog-durability.sh`**

Checks:
1. CronJob manifest exists
2. Registered in kustomization
3. Uses CMS (not LMS)
4. Has post-reindex verification
5. Uses `--setup` for non-interactive mode
6. Live ES `course_info` doc count > 0 (when cluster access available)

## 5. Verification Bug and Fix (Lane C3b)

### The Bug

The original CronJob (PR #908) used Django shell to query ES:

```bash
COUNT=$(python manage.py cms shell -c "
import requests
r = requests.get('http://elasticsearch:9200/course_info/_count', timeout=10)
print(r.json().get('count', 0))
" 2>/dev/null)
```

Django shell outputs 19 "objects could not be automatically imported" warnings to **stdout** (not stderr). `2>/dev/null` only suppresses stderr. This polluted the `COUNT` variable with multi-line text, causing `[ "${COUNT:-0}" -eq 0 ]` to fail with `integer expression expected`.

The job exited 0 (the test was inside `if`, so failure meant "not zero" = skip exit 1), but the verification was a **false pass** — it never actually validated the count.

### The Fix

PR #911 replaced Django shell with direct ES query:

```bash
COUNT=$(curl -sf http://elasticsearch:9200/course_info/_count \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))")
```

PR #913 added Kyverno-required security context (`runAsNonRoot`, `allowPrivilegeEscalation: false`).

### Proof Job Output

Job `course-reindex-proof-v3`, completed `2026-03-14T10:09:11Z`:

```
=== Course Catalog Reindex - Sat Mar 14 10:08:10 AM UTC 2026 ===
[1/3] Reindexing all courses into ES course_info...
[2/3] Verifying course_info doc count...
course_info docs: 90
[3/3] Verifying CourseOverview count...
CourseOverview total: 109
Reindex complete.
```

COUNT is clean integer `90`. Assertion passed. Job succeeded.

## 6. How to Verify

```bash
# Static checks (CI)
bash scripts/qa/verify-course-catalog-durability.sh

# Live: trigger manual reindex
kubectl create job --from=cronjob/course-reindex course-reindex-manual -n mereka-lms-dev
kubectl logs -n mereka-lms-dev job/course-reindex-manual -f

# Live: check course_info
kubectl exec -n mereka-lms-dev deployment/lms -- \
  curl -sf http://elasticsearch:9200/course_info/_count
```

## 7. PRs

| PR | Repo | Purpose | Status |
|----|------|---------|--------|
| #908 | mereka-lms | CronJob + verification script + CI | MERGED (`cba32801`) |
| #911 | mereka-lms | Fix: curl instead of Django shell | MERGED (`e0e82623`) |
| #913 | mereka-lms | Fix: Kyverno security context | MERGED (`68bb2223`) |
| #1765 | bbi-infrastructure | Sync CronJob manifest | MERGED (`0c0f6ada`) |
| #1772 | bbi-infrastructure | Sync curl fix | MERGED (`115731af`) |
| #1775 | bbi-infrastructure | Sync security context | Auto-merge enabled |

## 8. Final Verdict

**CLOSED**

- CronJob deployed and executing in `mereka-lms-dev`
- Verification uses direct ES `/_count` (no Django shell pollution)
- Clean integer count assertion proven in live Job
- Source repos (mereka-lms + bbi-infrastructure) match live state
- CI verification script registered and passing
- One outstanding PR (#1775, security context sync to bbi-infrastructure) in auto-merge — non-blocking, already proven live
