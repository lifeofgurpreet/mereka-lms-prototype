# Search / Catalog / Discovery Runtime Contract
_Audience: platform operators and agents · Owner: Platform Team · Status: canonical · Last runtime verified: 2026-04-10T10:25Z (staging)_

This document records the currently proved search/catalog/discovery contract for
`mereka-lms` and separates repo intent from overlay truth and runtime truth.
Runtime claims are lane-specific. The strongest current proof is in
`stg-mereka-lms`; production remains a separate lane and must not be inferred
from staging success.

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
| edx-platform search | Base LMS uses Meilisearch; CMS explicitly sets Meilisearch plus runtime bootstrap repair | Staging CMS now resolves Meilisearch, carries a valid routine API key, and reindexes successfully into Meilisearch | `Runtime-verified` |
| Learner browse UX | Legacy `/courses` still exists; Catalog MFE not yet wired here | Staging `/courses`, `/courses/<key>/about`, and `/api/courses/v1/courses/` now return live course data after the Meilisearch repair | `Runtime-verified` |

## Current-State Matrix

Verification tags:

- `Repo-verified`
- `Overlay-verified`
- `Runtime-verified`
- `External-doc-verified`
- `Hypothesis`

| Lane | Surface | Runtime owner | Backend | Index / store | Secret / auth | Proof | Source of truth | Verification | Notes |
|---|---|---|---|---|---|---|---|---|---|
| `staging` | LMS `/courses` | `lms` Deployment | Legacy LMS browse UI backed by course API | Meilisearch-backed course catalog path | none to render shell | `curl -I https://staging.academyv2.mereka.io/courses` | live staged LMS config + course API | `Runtime-verified` | Returns `200` HTML after the staging Meilisearch repair. |
| `staging` | LMS `/courses/<key>/about` | `lms` Deployment | Legacy LMS about page | CourseOverview + search-backed browse data | none for anon page | `curl -I https://staging.academyv2.mereka.io/courses/course-v1:MEREKA+MCT44-EN+course/about` | LMS runtime settings | `Runtime-verified` | Real course key now returns `200`. |
| `staging` | Course catalog API | `lms` Deployment | LMS REST API | Meilisearch-fed course catalog | none for anon page | `curl -s https://staging.academyv2.mereka.io/api/courses/v1/courses/` | LMS runtime + Meilisearch | `Runtime-verified` | Returns real course results after successful reindex. |
| `staging` | Studio content search | `cms` Deployment | Meilisearch backend | `tutor_course_info` / `tutor_courseware_content` | `MEILISEARCH_API_KEY` for routine writes; `MEILISEARCH_MASTER_KEY` only for `/keys` and admin inspection | `kubectl exec -n stg-mereka-lms deploy/cms -- python manage.py cms shell -c "from django.conf import settings; print(settings.SEARCH_ENGINE, settings.MEILISEARCH_URL)"` plus Meilisearch `/indexes/*/stats` | CMS configmap + runtime settings | `Runtime-verified` | Staging CMS now reindexes successfully into Meilisearch. |
| `staging` | Course reindex CronJob | `course-reindex` CronJob | `reindex_course` command | Meilisearch `tutor_course_info` / `tutor_courseware_content` | `MEILISEARCH_API_KEY` for routine writes; `MEILISEARCH_MASTER_KEY` only for admin inspection | `kubectl create job -n stg-mereka-lms --from=cronjob/course-reindex course-reindex-manual` plus job logs and `/indexes/*/stats` | `deploy/k8s/base/monitoring/cronjob-course-reindex.yaml` | `Runtime-verified` | Manual staging run succeeded: `39 of 39 courses reindexed succesfully.` |
| `staging` | Learner dashboard MFE | MFE + LMS APIs | MFE | LMS enrollment APIs | session auth | verify through apps domain and config API | staging overlay MFE config | `Hypothesis` | Not re-proved in this tranche. |
| `staging` | Catalog MFE route | none in current runtime | not enabled | n/a | n/a | route inspection pending | upstream feature docs + repo wiring | `Hypothesis` | Strategic candidate, not yet wired. |
| `production` | Discovery root | `discovery` Deployment | Django Discovery service | MySQL `discovery` DB | none for root | `curl -I https://discovery.academyv2.mereka.io/` | `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py` | `Runtime-verified` | Root behavior must be re-proved per lane before assuming anonymous access. |
| `production` | Discovery `/health/` | `discovery` Deployment | Django Discovery service | MySQL `discovery` DB | none | `curl https://discovery.academyv2.mereka.io/health/` | `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py` | `Runtime-verified` | Returns `{"overall_status":"OK"...}` in prod. |
| `production` | Discovery `/api/v1/courses/` | `discovery` Deployment | Discovery REST API | Discovery DB + Elasticsearch | JWT required | `curl -i https://discovery.academyv2.mereka.io/api/v1/courses/` | `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py` | `Runtime-verified` | Current prod response is `401`, not public `200`. |
| `production` | LMS `/courses` | `lms` Deployment | Legacy LMS discovery UI | Elasticsearch `course_info` | none to render shell | `curl -I https://academyv2.mereka.io/courses` plus ES `_cat/indices` | live patched LMS configmap | `Runtime-verified` | Prod LMS still resolves `search.elastic.ElasticSearchEngine`; this lane is not yet migrated. |
| `production` | LMS `/courses/<key>/about` | `lms` Deployment | Legacy LMS course about page | LMS models / CourseOverview | none for anon page | `curl -I https://academyv2.mereka.io/courses/<course-key>/about` | LMS runtime settings | `Hypothesis` | Valid-course proof still needs a real prod key. |
| `production` | Studio content search | `cms` Deployment | Meilisearch backend | `tutor_course_info` / `tutor_courseware_content` plus Studio-owned indexes | `MEILISEARCH_API_KEY` | `kubectl exec -n mereka-lms deploy/cms -- python manage.py cms shell ...` plus Meilisearch `/tasks` and `/indexes/*` | CMS configmap + runtime settings | `Runtime-verified` | Earlier prod tranche proved wrong-primary-key index creation; this lane still needs re-proof after the staging repair is promoted. |
| `production` | Forum search | `lms` Deployment | Elasticsearch backend | Elasticsearch | none | `kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell ...` | live patched LMS configmap | `Runtime-verified` | Live `FORUM_SEARCH_BACKEND` is still `forum.search.es.ElasticsearchBackend`. |
| `production` | Discovery sync CronJob | `discovery-sync` CronJob | Discovery management commands | Discovery DB + search index | secrets via `envFrom` | `kubectl get cronjob discovery-sync -n mereka-lms -o json` | `deploy/k8s/base/jobs/discovery-sync-cronjob.yaml` | `Runtime-verified` | Exists live after the Kyverno-compliant vendored fix was realized. |

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
7. `Runtime-verified`: production LMS mounts `openedx-settings-lms-patched-*`, not
   the base LMS settings configmap.
8. `Runtime-verified`: after a manual full sync, production CMS and
   `course-reindex` now also mount `openedx-settings-cms-patched-*`.
9. `Runtime-verified`: production LMS still reports:
   - `SEARCH_ENGINE = "search.elastic.ElasticSearchEngine"`
   - `FORUM_SEARCH_BACKEND = "forum.search.es.ElasticsearchBackend"`
   - `COURSE_CATALOG_URL_ROOT = "http://localhost:8008"`
10. `Runtime-verified`: Discovery is live in production but currently has `0`
    `Course`, `0` `CourseRun`, and `0` `Program` rows.
11. `Repo-verified`: the repo now includes a static contract guard at
    `scripts/qa/verify-search-runtime-contract.sh`
    to catch newline-polluted Meilisearch keys, wrong CMS engine drift, missing
    bootstrap repair, SRV-host Mongo misconfiguration, and regression of the
    current non-interactive reindex contract.
12. `Runtime-verified`: the earlier `invalid_document_id` failure mode was real
    and came from wrong-primary-key Meilisearch indexes; staging is now past
    that blocker after key-authority repair and successful reindex.
13. `Repo-verified`: prod app auto-sync is disabled in source, so realization
    currently depends on an explicit manual sync instead of normal Argo
    convergence.
14. `Runtime-verified`: after the vendored CronJob security-context fix was
    merged and a new full sync completed, prod is now `Synced` on infra revision
    `0aebdace...`.
15. `Runtime-verified`: `discovery-sync` and `clickhouse-data-sync-daily` now
    exist live with Kyverno-compliant security contexts.
16. `Runtime-verified`: the active production split-brain is now narrower: live LMS still
    reports Elasticsearch, while live CMS and the shipped `course-reindex`
    manifest now target Meilisearch.
17. `Runtime-verified`: running `search.meilisearch.create_indexes()` repairs
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

## Why `/courses` Is Still On Elasticsearch In Production

What is actually proved today:

- `Runtime-verified`: staging is now healthy on Meilisearch and proves the path
  can work end-to-end once key authority and bootstrap order are correct.
- `Runtime-verified`: production LMS is still on
  `search.elastic.ElasticSearchEngine`.
- `Runtime-verified`: production Elasticsearch `course_info` exists but was
  previously empty at last proof time.
- `Runtime-verified`: the earlier production Meilisearch failure mode was
  `invalid_document_id` on indexes created without `_pk` as the primary key.

What is not yet proved:

- whether the now-proved staging fix promotes cleanly into production without
  an additional lane-specific secret or realization defect
- whether production learner browse can be moved off Elasticsearch immediately
  after promotion, or whether a short hybrid period is still safer

Current conclusion:

- Keep production LMS `/courses` on Elasticsearch until the staging repair is
  promoted and a production full reindex populates the learner-facing index.
- The previously sharp blockers have been retired in staging:
  - interactive prompt failure
  - stale API-key authority
  - wrong-primary-key index creation
- The next production question is promotion proof, not root-cause discovery.
- The repo still carries secret-model debt because `FORUM_MONGODB_HOST` is the
  effective runtime source for modulestore Atlas connectivity in prod.
- The old blanket “colon-id bug” story is still too loose. The proved issue is
  narrower: Meilisearch rejects raw Open edX ids when the index was created
  without `_pk` and therefore never applies edx-search’s id hashing path.
- `Repo-verified`: source-side fixes now exist to make the app repo SRV-safe and
  to make the GitOps prod overlay mount a patched CMS settings configmap for
  `cms`, `cms-worker`, and the CMS-based cronjobs.

## Discovery Strategy

- `Runtime-verified`: Discovery is still an Elasticsearch-backed compatibility
  service in this estate.
- `Runtime-verified`: its production courses API is auth-protected and currently
  empty.
- `Runtime-verified`: staging learner browse success does not currently depend
  on Discovery content being populated.
- `Runtime-verified`: Discovery sync CronJob is now deployed in prod, but
  Discovery content remains empty and auth-protected there.

Current strategy:

- contain Discovery as compatibility plumbing
- do not expand product dependence on it
- prove whether Catalog MFE enablement can replace browse-path dependence before
  investing heavily in more legacy Discovery behavior

## Forward Path

1. Promote the staging-proved Meilisearch repair into production:
   - keep course reindex non-interactive
   - keep CMS on the explicit Meilisearch engine
   - keep the repaired API-key authority and bootstrap order intact
2. Re-prove production after promotion:
   - valid `/courses/<key>/about`
   - actual course card population
   - final `tutor_course_info` / `tutor_courseware_content` counts
   - actual forum search backend behavior
3. Clean remaining secret-model debt:
   - keep master-key authority in Infisical newline-safe
   - keep `MEILISEARCH_API_KEY` aligned to a valid routine admin key, not the master key
   - split modulestore authority from `FORUM_MONGODB_HOST`
4. Decide whether `mereka-lms-prod` should remain on explicit manual sync or
   return to normal auto-sync after stabilization.
5. Evaluate Catalog MFE in a dev/canary lane against Ulmo guidance:
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
