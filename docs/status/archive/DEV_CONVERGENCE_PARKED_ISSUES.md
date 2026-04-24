# DEV Convergence Parked Issues
_Audience: Operators and reviewers • Owner: Platform Team • Last verified: 2026-03-20 • Status: active_

This is the single canonical parked-issues ledger for the DEV convergence lane. Keep product/UI issues visible here instead of mixing them into the main convergence ledger.

## Parked Issues

| Issue | Owner layer | Blocked by | Proper future lane | Verification URL / proof target |
|---|---|---|---|---|
| `notes.academyv2.mereka.dev` returns HTTP `400`; root cause is proven as live `DisallowedHost` from missing DEV Notes env injection | infra realization + runtime | Repo-complete DEV consumer correction exists; blocked by merge, Argo apply, and post-sync reprobe | Durable platform truth | `https://notes.academyv2.mereka.dev/` plus `kubectl logs deploy/notes -n mereka-lms-dev --tail=400 \| rg 'Invalid HTTP_HOST\|DisallowedHost'` |
| DEV namespace mounts staging-derived bridge ConfigMaps (`caddy-config-staging`, `openedx-config-staging`, `openedx-settings-*-patched-*`) | split: infra realization + runtime | Removal needs a deliberate app/infra contract cleanup, not ad-hoc runtime patching | Durable platform truth | live Argo source `bbi-infrastructure/apps/mereka-lms/overlays/profiles/dev` plus `kubectl get deploy caddy,lms,cms -n mereka-lms-dev -o json` |
| ArgoCD green status can overstate DEV config correctness because the live app ignores ConfigMap `/data`, uses `IgnoreExtraneous`, and keeps `Prune=false` | infra/runtime | Needs explicit replacement proof path before anyone can trust Argo green as config proof | Harness hardening | `kubectl get application mereka-lms-dev -n argocd -o yaml` |
| Legacy production `Site` rows remain in DEV DB | app/runtime | Needs safe cleanup plan driven by a committed apply path | Durable platform truth | `kubectl exec deploy/lms -n mereka-lms-dev -- python manage.py lms shell -c ...` |
| Enterprise browser-auth behavior is still only probe-verified, not fully authenticated end-to-end | app/runtime | Needs staffed browser session proof | Capability model proof | `https://admin.academyv2.mereka.dev/`, `https://learner.academyv2.mereka.dev/` |
| Aspects / analytics runtime status is absent, not merely undocumented | app + infra | Separate analytics deployment decision and readiness gate | Analytics / Aspects lane | `kubectl get deploy,statefulset,job,cronjob -n mereka-lms-dev | rg 'aspect|clickhouse|superset|analytics'` |
| Untracked local convergence notes may exist outside committed docs roots | operator workflow | Local workspace state is not repo-owned truth | Harness hardening | committed docs only |

## Classification Rules

- Structural drift belongs here if it is real but out of scope for the current batch.
- Cosmetic UI follow-up belongs here only when a verified structural owner is already known.
- Anything still `TEMP_RUNTIME` must stay here until a committed source-owned removal trigger exists.
