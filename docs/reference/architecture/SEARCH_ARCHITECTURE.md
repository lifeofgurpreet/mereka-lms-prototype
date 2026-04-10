# Search / Catalog / Discovery Runtime Contract
_Audience: platform operators and agents · Owner: Platform Team · Status: canonical_

This document records the currently proved search/catalog/discovery contract for
`mereka-lms` and separates repo intent from overlay truth and runtime truth.

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
| Discovery service | Discovery plugin settings point to Elasticsearch via `ELASTICSEARCH_DSL` | Runtime Discovery still uses Elasticsearch and has zero `Course` / `CourseRun` rows | `Runtime-verified` |
| edx-platform search | Base LMS uses Meilisearch; CMS now explicitly sets Meilisearch plus runtime bootstrap repair | Production LMS still resolves Elasticsearch, while production CMS now resolves Meilisearch and writes into Meilisearch indexes | `Runtime-verified` |
| Learner browse UX | Legacy `/courses` still exists; Catalog MFE not yet wired here | `/courses` returns a 200 HTML shell, but the learner browse index is still empty because CMS reindex fails on wrong-primary-key Meilisearch indexes | `Runtime-verified` |

## Current-State Matrix

Verification tags:

- `Repo-verified`
- `Overlay-verified`
- `Runtime-verified`
- `External-doc-verified`
- `Hypothesis`

| Surface | Runtime owner | Backend | Index / store | Secret / auth | Proof | Source of truth | Verification | Notes |
|---|---|---|---|---|---|---|---|---|
| Discovery root | `discovery` Deployment | Django Discovery service | MySQL `discovery` DB | none for root | `curl -I https://discovery.academyv2.mereka.io/` | `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py` | `Runtime-verified` | Root behavior must be re-proved per environment before assuming anonymous access. |
| Discovery `/health/` | `discovery` Deployment | Django Discovery service | MySQL `discovery` DB | none | `curl https://discovery.academyv2.mereka.io/health/` | `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py` | `Runtime-verified` | Returns `{"overall_status":"OK"...}` in prod. |
| Discovery `/api/v1/courses/` | `discovery` Deployment | Discovery REST API | Discovery DB + Elasticsearch | JWT required in prod | `curl -i https://discovery.academyv2.mereka.io/api/v1/courses/` | `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py` | `Runtime-verified` | Current prod response is `401`, not public `200`. |
| LMS `/courses` | `lms` Deployment | Legacy LMS discovery UI | Elasticsearch `course_info` | none to render shell | `curl -I https://academyv2.mereka.io/courses` plus ES `_cat/indices` | live patched LMS configmap | `Runtime-verified` | Live LMS still resolves `search.elastic.ElasticSearchEngine`; current ES `course_info` count is `0`. |
| LMS `/courses/<key>/about` | `lms` Deployment | Legacy LMS course about page | LMS models / CourseOverview | none for anon page | `curl -I https://academyv2.mereka.io/courses/<course-key>/about` | LMS runtime settings | `Runtime-verified` | Sample unknown course key returns `404`; valid-course proof still needed. |
| Learner dashboard MFE | MFE + LMS APIs | MFE | LMS enrollment APIs | session auth | verify through apps domain and config API | prod overlay MFE config | `Hypothesis` | Not yet re-proved in this pass. |
| Catalog MFE route | none in current runtime | not enabled | n/a | n/a | route inspection pending | upstream feature docs + repo wiring | `Hypothesis` | Strategic candidate, not currently proved live. |
| Studio content search | `cms` Deployment | Meilisearch backend | `tutor_course_info` / `tutor_courseware_content` plus Studio-owned indexes | `MEILISEARCH_API_KEY` | `kubectl exec deploy/cms -- python manage.py cms shell ...` plus Meilisearch `/tasks` and `/indexes/*` | CMS configmap + runtime settings | `Runtime-verified` | CMS now resolves `search.meilisearch.MeilisearchEngine`; writes fail on wrong-primary-key indexes auto-created without `_pk`. |
| Forum search | `lms` Deployment | Elasticsearch backend in prod | Elasticsearch | none | `kubectl exec deploy/lms -- python manage.py lms shell ...` | live patched LMS configmap | `Runtime-verified` | Live `FORUM_SEARCH_BACKEND` is `forum.search.es.ElasticsearchBackend`, contradicting base repo intent. |
| Course reindex CronJob | `course-reindex` CronJob | `reindex_course` command | Meilisearch `tutor_course_info` / `tutor_courseware_content` | `MEILISEARCH_API_KEY` for routine writes, `MEILISEARCH_MASTER_KEY` only for admin inspection | `kubectl get cronjob course-reindex -o json` plus one-off job logs and Meilisearch `/tasks` | `deploy/k8s/base/monitoring/cronjob-course-reindex.yaml` | `Runtime-verified` | Prompt blocker is gone. Current failure is `invalid_document_id` because indexes were created without `_pk` as primary key before bootstrap repair ran. |
| Discovery sync CronJob | `discovery-sync` CronJob | Discovery management commands | Discovery DB + search index | secrets via `envFrom` | `kubectl get cronjob discovery-sync -n mereka-lms -o json` | `deploy/k8s/base/jobs/discovery-sync-cronjob.yaml` | `Runtime-verified` | Live prod CronJob now exists after the Kyverno-compliant vendored fix was realized. |

## Proved Runtime Facts

1. `Runtime-verified`: production LMS mounts `openedx-settings-lms-patched-*`, not
   the base LMS settings configmap.
2. `Runtime-verified`: after a manual full sync, production CMS and
   `course-reindex` now also mount `openedx-settings-cms-patched-*`.
3. `Runtime-verified`: production LMS reports:
   - `SEARCH_ENGINE = "search.elastic.ElasticSearchEngine"`
   - `FORUM_SEARCH_BACKEND = "forum.search.es.ElasticsearchBackend"`
   - `COURSE_CATALOG_URL_ROOT = "http://localhost:8008"`
4. `Runtime-verified`: production CMS now reports:
   - `SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine"`
   - `MEILISEARCH_ENABLED = True`
   - `MEILISEARCH_URL = "http://meilisearch:7700"`
   - `ELASTIC_SEARCH_CONFIG = [{"host": "meilisearch", "port": 7700}]`
5. `Runtime-verified`: Elasticsearch is live and currently has `course_info` and
   `courseware_content` indices, both with `0` documents.
6. `Runtime-verified`: Discovery is live but currently has `0` `Course`,
   `0` `CourseRun`, and `0` `Program` rows.
7. `Runtime-verified`: Meilisearch now accepts the corrected master key from
   `openedx-secrets`, and `/keys` returns the live built-in search/admin keys.
8. `Runtime-verified`: `MEILISEARCH_MASTER_KEY` no longer carries the trailing
   newline byte that previously broke auth.
9. `Runtime-verified`: `MEILISEARCH_API_KEY` in `openedx-secrets` is now aligned
   to the live Meilisearch Default Admin API Key and is accepted for routine
   index/settings writes.
10. `Repo-verified`: the repo now includes a static contract guard at
    `scripts/qa/verify-search-runtime-contract.sh`
    to catch newline-polluted Meilisearch keys, wrong CMS engine drift, missing
    bootstrap repair, SRV-host Mongo misconfiguration, and regression of the
    current non-interactive reindex contract.
11. `Runtime-verified`: the non-interactive reindex path now gets through
    startup, auth, and filterable/sortable attribute setup and fails later on
    Meilisearch `invalid_document_id` task failures.
12. `Repo-verified`: prod app auto-sync is disabled in source, so realization
    currently depends on an explicit manual sync instead of normal Argo
    convergence.
13. `Runtime-verified`: after the vendored CronJob security-context fix was
    merged and a new full sync completed, prod is now `Synced` on infra revision
    `0aebdace...`.
14. `Runtime-verified`: `discovery-sync` and `clickhouse-data-sync-daily` now
    exist live with Kyverno-compliant security contexts.
15. `Runtime-verified`: the active split-brain is now narrower: live LMS still
    reports Elasticsearch, while live CMS and the shipped `course-reindex`
    manifest now target Meilisearch.
16. `Runtime-verified`: live `tutor_course_info` and
    `tutor_courseware_content` indexes currently exist with `primaryKey = None`,
    which causes Meilisearch to reject raw Open edX ids containing `:`.
17. `Runtime-verified`: running `search.meilisearch.create_indexes()` repairs
    filterable and sortable attributes but does not repair an already-created
    wrong-primary-key index, so bootstrap order matters.

## Key Model

| Purpose | Canonical variable | Current state | Decision |
|---|---|---|---|
| Meilisearch server bootstrap | `MEILI_MASTER_KEY` from `MEILISEARCH_MASTER_KEY` | present in Meilisearch Deployment and now accepted by `/keys` | keep |
| Backend index/admin operations | `MEILISEARCH_API_KEY` | present in LMS/CMS secrets and now aligned to the live Default Admin API Key | keep as routine index/admin key; do not fall back to master |
| Frontend search | separate search-only key | not wired | do not invent until Catalog MFE path is chosen |

Rules:

- Only use the master key for API key management.
- Use API keys for routine index, settings, and document operations.
- Strip trailing newlines from runtime-consumed search keys.
- One variable per purpose; no master-key fallback for routine operations.
- Enforce SRV-aware modulestore config in git so Atlas URIs do not get silently
  mixed with hardcoded `port: 27017` assumptions.

## Why `/courses` Is Still On Elasticsearch

What is actually proved today:

- `Runtime-verified`: live LMS is on `search.elastic.ElasticSearchEngine`.
- `Runtime-verified`: live CMS is on `search.meilisearch.MeilisearchEngine`.
- `Runtime-verified`: prod Elasticsearch `course_info` exists but currently has
  `0` docs.
- `Runtime-verified`: the production course reindex job is now non-interactive
  and reaches document indexing in Meilisearch.
- `Runtime-verified`: the current Meilisearch failure mode is no longer auth or
  filter configuration; it is `invalid_document_id` on indexes created without
  `_pk` as the primary key.
- `Runtime-verified`: live `tutor_course_info` and `tutor_courseware_content`
  were auto-created with `primaryKey = None` before bootstrap repair ran.

What is not yet proved:

- whether the new CMS-side bootstrap repair is sufficient by itself once it is
  realized in every lane and the wrong zero-doc indexes are recreated
- whether any additional Meilisearch path still bypasses `_pk` normalization
  after the runtime bootstrap repair is in place

Current conclusion:

- Keep LMS `/courses` on Elasticsearch until the CMS-side Meilisearch bootstrap
  repair is realized and a full reindex populates the learner-facing index.
- The immediate production indexing blocker is wrong Meilisearch index creation,
  not Atlas connectivity, interactive prompts, or auth.
- The repo still carries secret-model debt because `FORUM_MONGODB_HOST` is the
  effective runtime source for modulestore Atlas connectivity in prod.
- The old blanket “colon-id bug” story is still too loose. The proved issue is
  narrower: Meilisearch rejects raw Open edX ids when the index was created
  without `_pk` and therefore never applies edx-search’s id hashing path.
- `Repo-verified`: source-side fixes now exist to make the app repo SRV-safe and
  to make the GitOps prod overlay mount a patched CMS settings configmap for
  `cms`, `cms-worker`, and the CMS-based cronjobs.
- `Runtime-verified`: a full manual sync can realize the patched CMS settings in
  live prod, so the earlier CMS configmap split is no longer the active blocker.
- `Runtime-verified`: the Kyverno admission blocker is now resolved in live
  prod; the remaining blocker is the Meilisearch bootstrap contract itself.

## Discovery Strategy

- `Runtime-verified`: Discovery is still an Elasticsearch-backed compatibility
  service in this estate.
- `Runtime-verified`: its courses API is auth-protected in prod and currently
  empty.
- `Runtime-verified`: Discovery sync CronJob is now deployed in prod, but
  Discovery content remains empty and auth-protected.

Current strategy:

- contain Discovery as compatibility plumbing
- do not expand product dependence on it
- prove whether Catalog MFE enablement can replace browse-path dependence before
  investing heavily in more legacy Discovery behavior

## Forward Path

1. Realize and prove the CMS bootstrap repair:
   - keep course reindex non-interactive
   - ensure every Meilisearch-writing CMS lane carries the `_pk` repair hook
   - recreate any empty wrong-primary-key indexes before the next full reindex
2. Reconcile backend authority:
   - keep LMS `/courses` on Elasticsearch until Meilisearch reindex is proved
   - keep CMS indexing on Meilisearch with an explicit bootstrap contract
3. Decide whether `mereka-lms-prod` should remain on explicit manual sync or
   return to normal auto-sync after stabilization.
4. Clean Meilisearch secret hygiene:
   - keep master-key authority in Infisical newline-safe
   - keep `MEILISEARCH_API_KEY` aligned to a valid routine admin key, not the master key
5. Re-prove learner browse path:
   - valid `/courses/<key>/about`
   - actual course card population
   - actual forum search backend behavior
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
