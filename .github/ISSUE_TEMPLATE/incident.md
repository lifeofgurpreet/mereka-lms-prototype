---
name: Incident Report
about: Report a runtime incident or regression
title: "[INCIDENT] "
labels: incident, triage
assignees: ''
---

## Broken Surface

- Environment: <!-- dev / staging / production -->
- Tenant: <!-- mereka / biji-biji / skillourfuture / all -->
- Domain/host:
- Route/path:
- Symptom: <!-- blank page, 5xx, redirect loop, auth failure, etc. -->

## Owner Layer

<!-- Pick one. See docs/architecture/PLATFORM_AUTHORITY_MAP.md -->

- [ ] Source (contract/spec wrong)
- [ ] Build/render (shipped artifact wrong)
- [ ] Promotion (wrong thing promoted)
- [ ] Realization (Argo/live state wrong)
- [ ] Runtime (user-visible break, config correct)
- [ ] Proof (verifier green while runtime red)

## Evidence

- HTTP status/response:
- Screenshot/browser evidence:
- Relevant logs:

## Source Authority

- Source of truth file:
- Rendered/build artifact currently shipping:
- Realized artifact currently live (image/config hash):
- Current proof artifact status:

## Fix Plan

- [ ] Canonical fix site identified (which file/layer)
- [ ] Generated artifact will be checked post-fix
- [ ] Proof plan: route proof → asset verify → browser canary
- [ ] Regression guard to add:
- [ ] Rollback plan:

## Post-Fix Verification

- [ ] Fix merged to canonical branch
- [ ] Fix present in rendered/build artifact
- [ ] Release object created for promotion
- [ ] Realization verified (Argo + live cluster)
- [ ] Runtime proof rerun against patched live bundle
- [ ] Truth ledger updated
- [ ] Regression guard added at escape layer
