---
id: ADR-007
title: Forum Service Migration from Ruby to Python
decision_status: accepted
decision_type: migration
rollout_state: historical
owner: platform-team
created: '2026-03-07'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on: []
read_next: []
governs: []
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions: []
expiry_date: null
removal_condition: null
historical_reason: Migration history retained for traceability only.
---

# ADR-007: Forum Service Migration from Ruby to Python

**Status:** Accepted and Implemented
**Date:** 2026-02-10
**Deciders:** Engineering Team
**Related:** [specs/forum-service-migration_spec.md](../../specs/forum-service-migration_spec.md), [ADR 001: MongoDB Atlas](001-mongodb-atlas.md)

<!-- Last verified: 2026-02-13 -->

## Context

The Open edX forum service was running on Ruby-based `cs_comments_service` (v18.1.1), which is deprecated by the upstream Open edX community. Tutor v19+ ships with a Python-based forum (`openedx-forum`) integrated directly into the LMS process.

**Key constraints:**
- Must preserve all forum data (threads, posts, votes) in MongoDB Atlas
- Must maintain zero downtime during migration
- Tutor upgrade from v18 to v21 required for Python forum support
- Search functionality needs to migrate from Elasticsearch to Meilisearch

## Decision

We decided to migrate to Python forum via a Tutor v18→v21 upgrade with the following approach:

### 1. Upgrade Path
- **Sequential upgrade:** v18.2.2 (Redwood) → v21.0.0 (Ulmo)
- Upgraded all Tutor plugins to v21-compatible versions
- Created 183MB MySQL backup before upgrade

### 2. Forum Architecture
- **Python forum (openedx-forum v0.3.8)** integrated into LMS process (no separate container)
- **Meilisearch v1.8.4** for search indexing (replaces Elasticsearch)
- MongoDB Atlas connection maintained (same `cs_comments_service` database)

### 3. Deployment Strategy
- Built custom images with `PIP_COMMAND=pip` flag to avoid uv build isolation issues
- Fixed Caddyfile template rendering bug (`.format()` → `.replace()`)
- Fixed collectstatic via sys.modules monkey-patch
- Zero downtime deployment via rolling update

### 4. Secrets Management
- Added Meilisearch secrets to GCP Secret Manager
- ExternalSecrets auto-sync to K8s (1-hour interval)

## Consequences

### Positive
✅ **Operational simplification** - One fewer language runtime (Ruby → Python)
✅ **Security maintenance** - Python dependencies tracked by platform-wide Dependabot
✅ **Future compatibility** - Aligned with upstream Open edX direction
✅ **Image efficiency** - Forum shares LMS base image (reduced build time, storage)
✅ **Zero data loss** - All forum data preserved in MongoDB Atlas
✅ **Zero downtime** - Rolling deployment, site remained accessible

### Negative
⚠️ **Build complexity** - Tutor v21's uv package manager required `PIP_COMMAND=pip` workaround
⚠️ **Search backend change** - Teams must learn Meilisearch instead of Elasticsearch
⚠️ **collectstatic patching** - Required sys.modules monkey-patch for safe_join references

### Neutral
ℹ️ **No API changes** - Forum API endpoints unchanged (`/api/discussion/v1/`)
ℹ️ **MFE compatibility** - Discussions MFE works without modification

## Implementation Details

**Images built:**
- `openedx:20260210-v21-forum-5a725a4` (3.18GB)
- `openedx-mfe:20260210-v21-forum-5a725a4` (277MB)

**Verification:**
```bash
# All 17 deployments healthy
kubectl get deployments -n mereka-lms

# Site accessible
curl -I https://academyv2.mereka.io  # HTTP 200

# Forum API responding
curl -I https://academyv2.mereka.io/api/discussion/v1/threads/  # HTTP 401 (auth required)
```

**Removed components:**
- Ruby forum deployment (`deploy/k8s/base/apps/lms/deployment.yaml`)
- Ruby forum service (port 4567)
- Forum-specific Caddy routing
- Ruby forum patches in `apply-patches.sh`

**Added components:**
- Meilisearch deployment (1Gi PVC, port 7700)
- Meilisearch secrets (master key, API key)
- Python forum configuration in LMS settings

## Lessons Learned

1. **Tutor v21 build issues:** Default `uv pip` has build isolation problems with legacy packages like `loremipsum`. Use `PIP_COMMAND=pip` flag.
2. **Template patching:** Python `.format()` conflicts with Caddy `{$var}` syntax. Use `.replace()` for template string substitution.
3. **Django safe_join:** Monkey-patching only `django.utils._os` doesn't work - must patch ALL loaded modules via `sys.modules` iteration.
4. **Team spawning:** Default tmux spawning clutters NTM sessions. Configure `"defaultBackend": "background"` in `~/.claude/settings.json`.

## References

- [Tutor v21 (Ulmo) Release Notes](https://docs.tutor.edly.io/changelog.html#v21-0-0-ulmo)
- [Open edX Forum v2 Documentation](https://github.com/openedx/forum)
- [Meilisearch Documentation](https://www.meilisearch.com/docs)
- [Forum Migration Spec](../../specs/forum-service-migration_spec.md)
