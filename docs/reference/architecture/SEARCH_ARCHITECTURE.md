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
| edx-platform search | Base LMS/CMS settings enable Meilisearch | Production LMS mounts patched config that forces Elasticsearch; production CMS mounts unpatched config and keeps Meilisearch flags | `Runtime-verified` |
| Learner browse UX | Legacy `/courses` still exists; Catalog MFE not yet wired here | `/courses` returns a 200 HTML shell, but the underlying search index is empty in production | `Runtime-verified` |

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
| LMS `/courses` | `lms` Deployment | Legacy LMS discovery UI | Elasticsearch `course_info` | none to render shell | `curl -I https://academyv2.mereka.io/courses` plus ES `_cat/indices` | live patched LMS configmap | `Runtime-verified` | Live LMS `SEARCH_ENGINE` is `search.elastic.ElasticSearchEngine`; current ES `course_info` count is `0`. |
| LMS `/courses/<key>/about` | `lms` Deployment | Legacy LMS course about page | LMS models / CourseOverview | none for anon page | `curl -I https://academyv2.mereka.io/courses/<course-key>/about` | LMS runtime settings | `Runtime-verified` | Sample unknown course key returns `404`; valid-course proof still needed. |
| Learner dashboard MFE | MFE + LMS APIs | MFE | LMS enrollment APIs | session auth | verify through apps domain and config API | prod overlay MFE config | `Hypothesis` | Not yet re-proved in this pass. |
| Catalog MFE route | none in current runtime | not enabled | n/a | n/a | route inspection pending | upstream feature docs + repo wiring | `Hypothesis` | Strategic candidate, not currently proved live. |
| Studio content search | `cms` Deployment | Meilisearch flags enabled in CMS | likely `tutor_studio_content` | `MEILISEARCH_API_KEY` | `kubectl exec deploy/cms -- python manage.py cms shell ...` | CMS configmap + runtime settings | `Runtime-verified` | CMS runtime has `MEILISEARCH_ENABLED=True`, but end-to-end search proof still pending. |
| Forum search | `lms` Deployment | Elasticsearch backend in prod | Elasticsearch | none | `kubectl exec deploy/lms -- python manage.py lms shell ...` | live patched LMS configmap | `Runtime-verified` | Live `FORUM_SEARCH_BACKEND` is `forum.search.es.ElasticsearchBackend`, contradicting base repo intent. |
| Course reindex CronJob | `course-reindex` CronJob | `reindex_course` command | live manifest targets Meilisearch `tutor_course_info`, but live LMS/CMS settings still resolve `SEARCH_ENGINE` through Elasticsearch | secrets via `envFrom` | `kubectl get cronjob course-reindex -o json` plus one-off job logs | `deploy/k8s/base/monitoring/cronjob-course-reindex.yaml` | `Runtime-verified` | Current live contradiction: patched CMS settings are mounted, but the shipped command is still interactive and assumes Meilisearch while runtime settings still report Elasticsearch. |
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
4. `Runtime-verified`: production CMS reports:
   - `SEARCH_ENGINE = "search.elastic.ElasticSearchEngine"`
   - `MEILISEARCH_ENABLED = True`
   - `MEILISEARCH_URL = "http://meilisearch:7700"`
5. `Runtime-verified`: Elasticsearch is live and currently has `course_info` and
   `courseware_content` indices, both with `0` documents.
6. `Runtime-verified`: Discovery is live but currently has `0` `Course`,
   `0` `CourseRun`, and `0` `Program` rows.
7. `Runtime-verified`: the live `openedx-secrets` values for
   `MEILISEARCH_MASTER_KEY` and `MEILISEARCH_API_KEY` do not match each other.
8. `Runtime-verified`: the injected Meilisearch master key currently contains a
   trailing newline byte. That must be treated as a secret-hygiene defect.
9. `Runtime-verified`: the current shipped `course-reindex` CronJob is still
   interactive in live prod and fails with `EOFError` when run non-interactively.
10. `Repo-verified`: the repo now includes a static contract guard at
    `scripts/qa/verify-search-runtime-contract.sh`
    to catch newline-polluted Meilisearch keys, SRV-host Mongo misconfiguration,
    and regression of the current non-interactive reindex contract.
11. `Runtime-verified`: a previous one-off non-interactive reindex job failed
    before indexing because CMS timed out talking to the Atlas modulestore
    replica set, so Atlas connectivity remains the next blocker once the prompt
    is removed from the live CronJob path.
12. `Repo-verified`: prod app auto-sync is disabled in source, so realization
    currently depends on an explicit manual sync instead of normal Argo
    convergence.
13. `Runtime-verified`: after the vendored CronJob security-context fix was
    merged and a new full sync completed, prod is now `Synced` on infra revision
    `0aebdace...`.
14. `Runtime-verified`: `discovery-sync` and `clickhouse-data-sync-daily` now
    exist live with Kyverno-compliant security contexts.
15. `Runtime-verified`: the active split-brain is now sharper: live LMS/CMS
    settings still report Elasticsearch, while the shipped `course-reindex`
    manifest verifies Meilisearch `tutor_course_info`.

## Key Model

| Purpose | Canonical variable | Current state | Decision |
|---|---|---|---|
| Meilisearch server bootstrap | `MEILI_MASTER_KEY` from `MEILISEARCH_MASTER_KEY` | present in Meilisearch Deployment | keep |
| Backend index/admin operations | `MEILISEARCH_API_KEY` | present in LMS/CMS secrets | keep, but it must be a valid admin-style API key and newline-safe |
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
- `Overlay-verified`: dev overlay explicitly forces `SEARCH_ENGINE` back to
  Elasticsearch and explains it with an old colon-ID comment.
- `Runtime-verified`: prod Elasticsearch `course_info` exists but currently has
  `0` docs.
- `Runtime-verified`: the production course reindex job still fails before
  indexing because it waits for interactive confirmation.
- `Runtime-verified`: after bypassing the prompt in an earlier one-off job, the
  same reindex path failed with `pymongo.errors.ServerSelectionTimeoutError`
  while enumerating courses from the Atlas modulestore cluster.
- `Runtime-verified`: the currently deployed CronJob manifest is no longer the
  Elasticsearch-oriented source tracked on this branch; live prod is running a
  Meilisearch-oriented command path from current `main`.

What is not yet proved:

- whether the upstream Meilisearch failure is really caused by colon-containing
  course keys
- whether `reindex_course` bypasses Meilisearch document-key normalization in
  the exact way claimed in PR #1497

Current conclusion:

- Keep Elasticsearch as the currently proved `/courses` backend until the
  Meilisearch migration failure mode is re-proved from code path plus runtime
  evidence.
- The immediate production indexing blocker is CMS-to-modulestore MongoDB
  connectivity, not Meilisearch document-ID behavior.
- The repo still carries secret-model debt because `FORUM_MONGODB_HOST` is the
  effective runtime source for modulestore Atlas connectivity in prod.
- Do not treat the colon-ID story as canonical yet.
- `Repo-verified`: source-side fixes now exist to make the app repo SRV-safe and
  to make the GitOps prod overlay mount a patched CMS settings configmap for
  `cms`, `cms-worker`, and the CMS-based cronjobs.
- `Runtime-verified`: a full manual sync can realize the patched CMS settings in
  live prod, so the earlier CMS configmap split is no longer the active blocker.
- `Runtime-verified`: the Kyverno admission blocker is now resolved in live
  prod; the remaining blocker is the search/backend contradiction itself.
- `Runtime-verified`: today’s live contradiction is:
  - LMS and CMS still report `SEARCH_ENGINE = search.elastic.ElasticSearchEngine`
  - the shipped `course-reindex` CronJob verifies Meilisearch
    `tutor_course_info`
  - the job remains interactive and therefore fails before exercising either
    backend

## Discovery Strategy

- `Runtime-verified`: Discovery is still an Elasticsearch-backed compatibility
  service in this estate.
- `Runtime-verified`: its courses API is auth-protected in prod and currently
  empty.
- `Runtime-verified`: no Discovery sync CronJob is deployed in prod.

Current strategy:

- contain Discovery as compatibility plumbing
- do not expand product dependence on it
- prove whether Catalog MFE enablement can replace browse-path dependence before
  investing heavily in more legacy Discovery behavior

## Forward Path

1. Fix runtime drift first:
   - keep course reindex non-interactive
   - prove whether indexing should target Elasticsearch or Meilisearch in each lane
   - keep proving that live runtime still consumes the corrected CMS/search
     contract after future syncs and restarts
2. Reconcile backend authority:
   - stop the live contradiction between Elasticsearch runtime settings and the
     Meilisearch-oriented reindex manifest
   - pick one proven backend contract for `/courses` before changing
     verification targets again
3. Decide whether `mereka-lms-prod` should remain on explicit manual sync or
   return to normal auto-sync after stabilization.
4. Clean Meilisearch secret hygiene:
   - remove newline pollution from stored secrets
   - verify the API key has the intended admin/search scopes
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
