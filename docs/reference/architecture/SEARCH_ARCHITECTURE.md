# Search / Catalog / Discovery Runtime Contract
_Audience: platform operators and agents · Owner: Platform Team · Status: canonical · Last runtime verified: 2026-04-11T12:11Z (production)_

This document records the currently proved search/catalog/discovery contract for
`mereka-lms` and separates repo intent from overlay truth and runtime truth.
Runtime claims are lane-specific. The strongest current proof now includes the
production edx-platform search and learner browse lanes. Discovery remains a
separate legacy compatibility lane and must not be conflated with platform
Meilisearch success.

## External Direction

These upstream references were re-checked on 2026-04-10:

- `External-doc-verified`: Ulmo is the latest supported Open edX release, and
  the latest release is the only supported release.
- `External-doc-verified`: the new Catalog MFE is available in Ulmo, is not
  enabled by default there, and becomes default in Verawood.
- `External-doc-verified`: Design Tokens do not overlap with the old theming
  system.
- `External-doc-verified`: Meilisearch master keys are for API key management;
  API keys should be used for regular operations.

Sources:

- <https://docs.openedx.org/en/latest/community/release_notes/named_release_branches_and_tags.html>
- <https://docs.openedx.org/en/latest/community/release_notes/ulmo/ulmo_catalog.html>
- <https://docs.openedx.org/en/latest/community/release_notes/ulmo/design_tokens.html>
- <https://www.meilisearch.com/docs/resources/self_hosting/security/master_api_keys>

## Three Planes

| Plane | Repo intent | Overlay/runtime truth | Status |
|---|---|---|---|
| Discovery service | Discovery plugin settings point to Elasticsearch via `ELASTICSEARCH_DSL` | Discovery remains compatibility plumbing and must be proved separately per lane | `Runtime-verified` |
| edx-platform search | Base LMS uses Meilisearch; CMS explicitly sets Meilisearch plus runtime bootstrap repair | Production LMS and CMS now both resolve Meilisearch and the production reindex succeeds into Meilisearch | `Runtime-verified` |
| Learner browse UX | Legacy `/courses` still exists; Catalog MFE not yet wired here | Production `/courses`, `/courses/<key>/about`, and `/api/courses/v1/courses/` now return live course data after the Meilisearch repair | `Runtime-verified` |

## Current-State Matrix

Verification tags:

- `Repo-verified`
- `Overlay-verified`
- `Runtime-verified`
- `External-doc-verified`
- `Hypothesis`

| Lane | Surface | Runtime owner | Backend | Index / store | Secret / auth | Proof | Source of truth | Verification | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `dev` | LMS `/courses` | `lms` Deployment | Legacy LMS browse UI backed by course API | Meilisearch-backed course catalog path | none to render shell | `curl -I https://academyv2.mereka.dev/courses` | live dev LMS config + course API | `Runtime-verified` | Returns `200` HTML after the dev CMS Meilisearch realization and successful reindex. |
| `dev` | LMS `/courses/<key>/about` | `lms` Deployment | Legacy LMS about page | CourseOverview + search-backed browse data | none for anon page | `curl -I https://academyv2.mereka.dev/courses/course-v1:MEREKA+MCT33-ID+course/about` | LMS runtime settings | `Runtime-verified` | Real course key now returns `200`. |
| `dev` | Course catalog API | `lms` Deployment | LMS REST API | Meilisearch-fed course catalog | none for anon page | `curl -s https://academyv2.mereka.dev/api/courses/v1/courses/?page_size=1` | LMS runtime + Meilisearch | `Runtime-verified` | Returns real course results and `count=41` after successful reindex. |
| `dev` | Studio content search | `cms` Deployment | Meilisearch backend | `tutor_course_info` / `tutor_courseware_content` | `MEILISEARCH_API_KEY` for routine writes; `MEILISEARCH_MASTER_KEY` only for `/keys` and admin inspection | `kubectl exec -n mereka-lms-dev deploy/cms -- python manage.py cms shell -c "from django.conf import settings; print(settings.SEARCH_ENGINE, settings.MEILISEARCH_URL, settings.ELASTIC_SEARCH_CONFIG)"` plus Meilisearch `/indexes/*/stats` | dev CMS overlay + runtime settings | `Runtime-verified` | Dev CMS now resolves the explicit Meilisearch engine and writes to Meilisearch successfully. |
| `dev` | Course reindex CronJob | `course-reindex` CronJob | `reindex_course` command | Meilisearch `tutor_course_info` / `tutor_courseware_content` | `MEILISEARCH_API_KEY` for routine writes; `MEILISEARCH_MASTER_KEY` only for admin inspection | `kubectl create job -n mereka-lms-dev --from=cronjob/course-reindex course-reindex-manual` plus job logs and `/indexes/*/stats` | `deploy/k8s/base/monitoring/cronjob-course-reindex.yaml` | `Runtime-verified` | Manual dev run succeeded: `41 of 41 courses reindexed succesfully.` |
| `staging` | LMS `/courses` | `lms` Deployment | Legacy LMS browse UI backed by course API | Meilisearch-backed course catalog path | none to render shell | `curl -I https://staging.academyv2.mereka.io/courses` | live staged LMS config + course API | `Runtime-verified` | Returns `200` HTML after the staging Meilisearch repair. |
| `staging` | LMS `/courses/<key>/about` | `lms` Deployment | Legacy LMS about page | CourseOverview + search-backed browse data | none for anon page | `curl -I https://staging.academyv2.mereka.io/courses/course-v1:MEREKA+MCT44-EN+course/about` | LMS runtime settings | `Runtime-verified` | Real course key now returns `200`. |
| `staging` | Course catalog API | `lms` Deployment | LMS REST API | Meilisearch-fed course catalog | none for anon page | `curl -s https://staging.academyv2.mereka.io/api/courses/v1/courses/` | LMS runtime + Meilisearch | `Runtime-verified` | Returns real course results after successful reindex. |
| `staging` | Studio content search | `cms` Deployment | Meilisearch backend | `tutor_course_info` / `tutor_courseware_content` | `MEILISEARCH_API_KEY` for routine writes; `MEILISEARCH_MASTER_KEY` only for `/keys` and admin inspection | `kubectl exec -n stg-mereka-lms deploy/cms -- python manage.py cms shell -c "from django.conf import settings; print(settings.SEARCH_ENGINE, settings.MEILISEARCH_URL)"` plus Meilisearch `/indexes/*/stats` | CMS configmap + runtime settings | `Runtime-verified` | Staging CMS now reindexes successfully into Meilisearch. |
| `staging` | Course reindex CronJob | `course-reindex` CronJob | `reindex_course` command | Meilisearch `tutor_course_info` / `tutor_courseware_content` | `MEILISEARCH_API_KEY` for routine writes; `MEILISEARCH_MASTER_KEY` only for admin inspection | `kubectl create job -n stg-mereka-lms --from=cronjob/course-reindex course-reindex-manual` plus job logs and `/indexes/*/stats` | `deploy/k8s/base/monitoring/cronjob-course-reindex.yaml` | `Runtime-verified` | Manual staging run succeeded: `39 of 39 courses reindexed succesfully.` |
| `staging` | Learner dashboard MFE | MFE + LMS APIs | MFE | LMS enrollment APIs | session auth | verify through apps domain and config API | staging overlay MFE config | `Hypothesis` | Not re-proved in this tranche. |
| `staging` | Catalog MFE route | none in current runtime | not enabled | n/a | n/a | route inspection pending | upstream feature docs + repo wiring | `Hypothesis` | Strategic candidate, not yet wired. |
| `production` | Discovery root | `caddy` -> `discovery` Deployment | Redirected compatibility landing | none for root redirect | none for root | `curl -I https://discovery.academyv2.mereka.io/` | `deploy/k8s/base/apps/caddy/Caddyfile` + prod overlay Caddy config | `Runtime-verified` | Returns `302 Location: /health/`; the legacy Query Preview UI is no longer a supported public surface. |
| `production` | Discovery `/health/` | `discovery` Deployment | Django Discovery service | MySQL `discovery` DB | none | `curl https://discovery.academyv2.mereka.io/health/` | `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py` | `Runtime-verified` | Returns `{"overall_status":"OK"...}` in prod. |
| `production` | Discovery `/api/v1/courses/` | `discovery` Deployment | Discovery REST API | Discovery DB + Elasticsearch | JWT required | `curl -i https://discovery.academyv2.mereka.io/api/v1/courses/` | `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py` | `Runtime-verified` | Current prod response is `401`, not public `200`. |
| `production` | LMS `/courses` | `lms` Deployment | Legacy LMS browse UI backed by course API | Meilisearch-fed course catalog path | none for anon page | `curl -I https://academyv2.mereka.io/courses` plus `kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell ...` | live patched LMS configmap | `Runtime-verified` | Returns `200` after the prod LMS Meilisearch overlay fix is realized. |
| `production` | LMS `/courses/<key>/about` | `lms` Deployment | Legacy LMS course about page | CourseOverview + Meilisearch-fed browse data | none for anon page | `curl -I https://academyv2.mereka.io/courses/course-v1:MEREKA+F101-MS+course/about` | LMS runtime settings | `Runtime-verified` | Real course key now returns `200`. |
| `production` | Course catalog API | `lms` Deployment | LMS REST API | Meilisearch-fed course catalog | none for anon page | `curl -s https://academyv2.mereka.io/api/courses/v1/courses/?page_size=1` | LMS runtime + Meilisearch | `Runtime-verified` | Returns real course JSON after the production reindex settles. |
| `production` | Studio content search | `cms` Deployment | Meilisearch backend | `tutor_course_info` / `tutor_courseware_content` plus Studio-owned indexes | `MEILISEARCH_API_KEY` | `kubectl exec -n mereka-lms deploy/cms -- python manage.py cms shell ...` plus Meilisearch `/indexes/*/stats` | CMS configmap + runtime settings | `Runtime-verified` | Production CMS reindex now succeeds into Meilisearch with settled counts `39 / 2815`. |
| `production` | Forum search | `lms` Deployment | Meilisearch backend | `tutor_*` Meilisearch indexes | `MEILISEARCH_API_KEY` | `kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell ...` | live patched LMS configmap | `Runtime-verified` | Live `FORUM_SEARCH_BACKEND` now resolves `forum.search.meilisearch.MeilisearchBackend`. |
| `production` | Course reindex CronJob | `course-reindex` CronJob | `reindex_course` command | Meilisearch `tutor_course_info` / `tutor_courseware_content` | `MEILISEARCH_API_KEY` for routine writes; `MEILISEARCH_MASTER_KEY` only for admin inspection | `kubectl create job -n mereka-lms --from=cronjob/course-reindex course-reindex-manual` plus job logs and `/indexes/*/stats` | `deploy/k8s/base/monitoring/cronjob-course-reindex.yaml` | `Runtime-verified` | Manual production run succeeded: `39 of 39 courses reindexed succesfully.` |
| `production` | Discovery sync CronJob | `discovery-sync` CronJob | Discovery management commands | Discovery DB + Elasticsearch indexes | secrets via `envFrom` | `kubectl get cronjob discovery-sync -n mereka-lms -o json` plus `kubectl logs -n mereka-lms job/discovery-sync-manual-*` | `deploy/k8s/base/jobs/discovery-sync-cronjob.yaml` | `Runtime-verified` | Manual production run completed successfully at `2026-04-11T12:09:01Z` and populated Discovery with `39` courses / `39` course runs. |

## Proved Runtime Facts

1. `Runtime-verified`: staging CMS reports:
   - `SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine"`
   - `MEILISEARCH_URL = "http://meilisearch:7700"`
2. `Runtime-verified`: staging Meilisearch now accepts the repaired routine API
   key and the authoritative master key.
3. `Runtime-verified`: staging `openedx-secrets` originally carried a stale
   `MEILISEARCH_API_KEY` that matched neither built-in Meilisearch key; that
   stale authority was repaired at Infisical source and then realized through ESO.
4. `Runtime-verified`: after the Infisical repair, ESO refresh, and CMS/CMS-worker
   restart, staging consumers now carry the current live Default Admin API Key for
   routine writes.
5. `Runtime-verified`: staging one-off `course-reindex` now succeeds end-to-end:
   - `39 of 39 courses reindexed succesfully.`
   - `tutor_course_info = 39`
   - `tutor_courseware_content = 2815`
6. `Runtime-verified`: staging learner browse now works with real data:
   - `/courses` returns `200`
   - `/courses/course-v1:MEREKA+MCT44-EN+course/about` returns `200`
   - `/api/courses/v1/courses/` returns course JSON
7. `Runtime-verified`: dev CMS now reports:
   - `SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine"`
   - `MEILISEARCH_URL = "http://meilisearch:7700"`
   - `ELASTIC_SEARCH_CONFIG = [{"host": "meilisearch", "port": 7700}]`
8. `Runtime-verified`: dev one-off `course-reindex` now succeeds end-to-end:
   - `41 of 41 courses reindexed succesfully.`
   - `tutor_course_info = 41`
   - `tutor_courseware_content = 2827`
9. `Runtime-verified`: dev learner browse now works with real data:
   - `/courses` returns `200`
   - `/courses/course-v1:MEREKA+MCT33-ID+course/about` returns `200`
   - `/api/courses/v1/courses/?page_size=1` returns course JSON with `count = 41`
10. `Runtime-verified`: dev Argo required a one-time hard refresh before it
    realized the merged overlay revision; the source fix alone was not enough.
11. `Runtime-verified`: production LMS mounts `openedx-settings-lms-patched-*`, not
   the base LMS settings configmap.
12. `Runtime-verified`: after a manual full sync, production CMS and
   `course-reindex` now also mount `openedx-settings-cms-patched-*`.
13. `Runtime-verified`: after the prod LMS overlay alignment, production LMS now reports:
   - `SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine"`
   - `FORUM_SEARCH_BACKEND = "forum.search.meilisearch.MeilisearchBackend"`
   - `MEILISEARCH_URL = "http://meilisearch:7700"`
14. `Runtime-verified`: production one-off `course-reindex` now succeeds end-to-end:
   - `39 of 39 courses reindexed succesfully.`
   - `tutor_course_info = 39`
   - `tutor_courseware_content = 2815`
15. `Runtime-verified`: production learner browse now works with real data:
   - `/courses` returns `200`
   - `/courses/course-v1:MEREKA+F101-MS+course/about` returns `200`
   - `/api/courses/v1/courses/?page_size=1` returns course JSON
16. `Runtime-verified`: production Elasticsearch remains live but now has `0`
   `course_info` and `0` `courseware_content` docs after the platform cutover.
17. `Runtime-verified`: Discovery is live in production but currently has `0`
    `Course`, `0` `CourseRun`, and `0` `Program` rows.
18. `Repo-verified`: the repo now includes a static contract guard at
    `scripts/qa/verify-search-runtime-contract.sh`
    to catch newline-polluted Meilisearch keys, wrong CMS engine drift, missing
    bootstrap repair, SRV-host Mongo misconfiguration, and regression of the
    current non-interactive reindex contract.
19. `Runtime-verified`: the earlier `invalid_document_id` failure mode was real
    and came from wrong-primary-key Meilisearch indexes; staging is now past
    that blocker after key-authority repair and successful reindex.
20. `Repo-verified`: prod app auto-sync is disabled in source, so realization
    currently depends on an explicit manual sync instead of normal Argo
    convergence.
21. `Runtime-verified`: after the search-fix syncs completed, prod is now
    `Synced` on infra revision `3c9713bd...`.
22. `Runtime-verified`: `discovery-sync` and `clickhouse-data-sync-daily` now
    exist live with Kyverno-compliant security contexts.
23. `Runtime-verified`: running `search.meilisearch.create_indexes()` repairs
    filterable and sortable attributes but does not repair an already-created
    wrong-primary-key index, so bootstrap order matters.

## Key Model

| Purpose | Canonical variable | Current state | Decision |
|---|---|---|---|
| Meilisearch server bootstrap | `MEILI_MASTER_KEY` from `MEILISEARCH_MASTER_KEY` | present in Meilisearch Deployment and accepted by `/keys` | keep |
| Backend index/admin operations | `MEILISEARCH_API_KEY` | staging source authority now repaired to the live Default Admin API Key and accepted for routine index/settings writes | keep as routine index/admin key; do not fall back to master |
| Frontend search | separate search-only key | not wired | do not invent until Catalog MFE path is chosen |

Rules:

- Only use the master key for API key management.
- Use API keys for routine index, settings, and document operations.
- Strip trailing newlines from runtime-consumed search keys.
- One variable per purpose; no master-key fallback for routine operations.
- Enforce SRV-aware modulestore config in git so Atlas URIs do not get silently
  mixed with hardcoded `port: 27017` assumptions.

## Production Search Status

What is proved today:

- `Runtime-verified`: dev, staging, and production all now reindex
  successfully into Meilisearch and serve learner browse data from populated
  Meilisearch indexes.
- `Runtime-verified`: production LMS and CMS both resolve the Meilisearch
  engine after the final prod LMS overlay realization.
- `Runtime-verified`: production Elasticsearch remains present but the
  platform-search indexes `course_info` and `courseware_content` are both `0`.
- `Runtime-verified`: the earlier production Meilisearch failure mode was
  `invalid_document_id` on indexes created without `_pk` as the primary key,
  and that blocker is now retired by the runtime bootstrap repair.

Current conclusion:

- Production edx-platform search and learner browse are now on Meilisearch.
- Discovery is not part of that cutover. It remains separate legacy
  Elasticsearch-backed compatibility plumbing.
- Do not describe the estate as “fully decommissioned off Elasticsearch”
  unless Discovery is either removed, hidden, or migrated away from its
  Elasticsearch dependency.
- The remaining technical debt is no longer the platform search path itself.
  It is:
  - Discovery containment or retirement
  - secret-contract cleanup around `FORUM_MONGODB_HOST`
  - vendored overlay debt that still needs stronger sync/diff discipline

## Discovery Strategy

- `Runtime-verified`: Discovery is still an Elasticsearch-backed compatibility
  service in this estate.
- `Runtime-verified`: the public Discovery root contract is now
  `/ -> /health/`; the old Query Preview UI is no longer a supported public
  surface.
- `Runtime-verified`: its production courses API is auth-protected.
- `Runtime-verified`: staging learner browse success does not currently depend
  on Discovery content being populated.
- `Runtime-verified`: production Discovery sync now completes successfully and
  leaves Discovery with `39` `Course` rows, `39` `CourseRun` rows, `0`
  `Program` rows, and `0` `Organization` rows.
- `Runtime-verified`: production LMS still publishes
  `DISCOVERY_API_BASE_URL=https://discovery.academyv2.mereka.io` with
  `ENABLE_COURSE_DISCOVERY=True`, even though learner browse is now served from
  the Meilisearch-backed LMS course API.
- `Runtime-verified`: enterprise-catalog and enterprise-catalog-worker still
  inject `DISCOVERY_SERVICE_URL=http://discovery:8000` and
  `DISCOVERY_SERVICE_API_URL=http://discovery:8000/api/v1/` through their
  generated config.

Current strategy:

- contain Discovery as compatibility plumbing
- do not expand product dependence on it
- prove whether Catalog MFE enablement can replace browse-path dependence before
  investing heavily in more legacy Discovery behavior

### Remaining Discovery Consumers

The remaining proved production consumers are:

1. LMS runtime configuration metadata:
   - `DISCOVERY_API_BASE_URL=https://discovery.academyv2.mereka.io`
   - `ENABLE_COURSE_DISCOVERY=True`
   - This is compatibility config, not proof that learner browse still depends
     on Discovery data.
2. Discovery maintenance:
   - `discovery-sync` CronJob still targets `http://discovery:8000`
   - the job now succeeds, so it is no longer a broken consumer, but it still
     keeps Discovery operationally in scope
3. Enterprise catalog services:
   - `enterprise-catalog`
   - `enterprise-catalog-worker`
   - `enterprise-catalog-migrate`
   - all still point at `DISCOVERY_SERVICE_URL` /
     `DISCOVERY_SERVICE_API_URL`

That means the safe next step is not deleting Discovery outright. The safe next
step is replacing or retiring these consumers deliberately, then removing the
service and its Elasticsearch dependency.

## Forward Path

1. Keep production edx-platform search on the now-proved Meilisearch path:
   - keep course reindex non-interactive
   - keep LMS and CMS on the explicit Meilisearch engine
   - keep the repaired API-key authority and bootstrap order intact
2. Clean remaining secret-model debt:
   - keep master-key authority in Infisical newline-safe
   - keep `MEILISEARCH_API_KEY` aligned to a valid routine admin key, not the master key
   - split modulestore authority from `FORUM_MONGODB_HOST`
3. Decide whether `mereka-lms-prod` should remain on explicit manual sync or
   return to normal auto-sync after stabilization.
4. Contain or retire Discovery:
   - remove or gate the public Discovery root if it is no longer needed
   - inventory and replace remaining runtime dependencies before keeping Elasticsearch alive
   - make Elasticsearch decommission explicitly contingent on Discovery removal
5. Discovery retirement criteria:
   - LMS no longer publishes `DISCOVERY_API_BASE_URL` as an active contract, or
     the remaining consumer is proven non-functional dead config
   - enterprise-catalog no longer requires `DISCOVERY_SERVICE_URL`
   - `discovery-sync` CronJob is removed or disabled because no authoritative
     consumer remains
   - public Discovery host is either removed or reduced to an explicitly owned
     internal/admin-only contract
   - only then is Elasticsearch eligible for full removal
6. Evaluate Catalog MFE in a dev/canary lane against Ulmo guidance:
   - route enablement
   - config API values
   - Design Tokens / plugin-slot readiness
   - enroll/browse smoke path

## Proof Commands

```bash
# LMS runtime search settings
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c \
  "from django.conf import settings; print(settings.SEARCH_ENGINE, settings.FORUM_SEARCH_BACKEND, settings.COURSE_CATALOG_URL_ROOT)"

# CMS runtime search settings
kubectl exec -n mereka-lms deploy/cms -- \
  python manage.py cms shell -c \
  "from django.conf import settings; print(settings.SEARCH_ENGINE, settings.MEILISEARCH_ENABLED, settings.MEILISEARCH_URL)"

# Discovery runtime backend
kubectl exec -n mereka-lms deploy/discovery -- \
  python manage.py shell -c \
  "from django.conf import settings; print(settings.ELASTICSEARCH_DSL)"

# CourseOverview count
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c \
  "from openedx.core.djangoapps.content.course_overviews.models import CourseOverview; print(CourseOverview.objects.count())"

# Discovery metadata counts
kubectl exec -n mereka-lms deploy/discovery -- \
  python manage.py shell -c \
  "from course_discovery.apps.course_metadata.models import Course, CourseRun, Program; print(Course.objects.count(), CourseRun.objects.count(), Program.objects.count())"

# Live route checks
curl -I https://academyv2.mereka.io/courses
curl -i https://discovery.academyv2.mereka.io/api/v1/courses/

# Elasticsearch state
kubectl port-forward -n mereka-lms svc/elasticsearch 19200:9200
curl http://127.0.0.1:19200/_cluster/health
curl 'http://127.0.0.1:19200/_cat/indices?v'

# Static contract guard
scripts/qa/verify-search-runtime-contract.sh
```
