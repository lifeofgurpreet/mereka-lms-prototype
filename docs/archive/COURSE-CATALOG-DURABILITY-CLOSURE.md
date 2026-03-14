# COURSE CATALOG DURABILITY CLOSURE

> Lane C3 artifact. Final snapshot: 2026-03-14.

## 1. What Made `/courses` Empty

The `/courses` catalog page uses `ENABLE_COURSE_DISCOVERY=True` → AJAX calls `course_discovery_search()` → queries the **Elasticsearch `course_info` index** via `edx-search`.

The `course_info` index is **ephemeral**. It lives in ES pod memory/PVC. When ES restarts, the index is lost, and `/courses` shows "Viewing 0 courses."

The course data itself is durable:
- **MongoDB** (modulestore): 109 courses — source of truth
- **MySQL** (`CourseOverview`): 109 rows — synced from modulestore
- **ES `course_info`**: 89 docs — derived index, NOT durable

The gap (109 CourseOverviews vs 89 in `course_info`) represents draft/unpublished courses that `CoursewareSearchIndexer` filters out during reindex.

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
2. Verifies `course_info` doc count > 0 after reindex (fails job if empty)
3. Logs `CourseOverview` count for comparison
4. Uses same image/settings as CMS deployment (Kustomize image transformer applies)

**Verification script: `scripts/qa/verify-course-catalog-durability.sh`**

Checks:
1. CronJob manifest exists
2. Registered in kustomization
3. Uses CMS (not LMS)
4. Has post-reindex verification
5. Uses `--setup` for non-interactive mode
6. Live ES `course_info` doc count > 0 (when cluster access available)

## 5. How to Verify

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

## 6. Final Verdict

**CONDITIONALLY_CLOSED**

- Durable fix implemented (CronJob + verification script)
- CI coverage added
- Current live state verified (89 docs in `course_info`)
- **Condition**: CronJob must be deployed to the cluster (requires PR merge → bbi-infrastructure sync → ArgoCD deploy). Until then, the current 89-doc state is runtime-only.
